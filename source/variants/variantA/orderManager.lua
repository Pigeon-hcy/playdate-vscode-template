-- Seconds throughout. No drawing, timers or station dependencies.
-- A small chronological queue; each order keeps its own deadline and UI slot.
-- Rush hour is an optional timed state: it halves every remaining wait, then
-- issues short orders at the configured pace until the holder is full. Optional
-- onRushStart / onRushEnd fields are called with the manager when it changes,
-- and onOrderExpired with each order that runs out unserved.
OrderManager = {}
OrderManager.__index = OrderManager

function OrderManager.new(config, randomDelay)
    assert(config.emptyArrivalDelay == nil or config.emptyArrivalDelay > 0,
        "empty queue delay must be positive")
    local rush = config.rush
    if rush ~= nil then
        local durationMin = rush.durationMin or rush.duration
        local durationMax = rush.durationMax or rush.duration
        assert(durationMin ~= nil and durationMax ~= nil and
            durationMin > 0 and durationMax >= durationMin,
            "rush duration must be a positive range")
        assert(rush.minArrivalDelay > 0 and
            rush.cooldownMin > 0 and rush.firstDelayMin >= 0,
            "rush delays must be positive so event replay terminates")
    end
    local self = setmetatable({
        config = config,
        randomDelay = randomDelay or math.random,
        time = 0,
        nextId = 1,
        pending = {},
        completed = 0,
        expired = 0,
        rushActive = false,
        rushCount = 0,
        rushEndsAt = nil,
        nextRushChangeAt = math.huge,
    }, OrderManager)
    self:reset()
    return self
end

function OrderManager:reset()
    self.time = 0
    self.nextId = 1
    self.pending = {}
    self.committedOrder = nil
    self.completed = 0
    self.expired = 0
    self.rushActive = false
    self.rushCount = 0
    self.rushEndsAt = nil
    for _ = 1, self.config.initialCount do self:addOrder(0) end
    self.nextArrivalAt = self:sampleArrivalDelay()
    self:limitEmptyWait(0)
    local rush = self.config.rush
    if rush ~= nil then
        self.nextRushChangeAt =
            self.randomDelay(rush.firstDelayMin, rush.firstDelayMax)
    else
        self.nextRushChangeAt = math.huge
    end
end

-- Cap the existing deadline, rather than moving it forward on every frame.
-- Earlier arrivals (including the rush's 2-second cadence) stay earlier.
function OrderManager:limitEmptyWait(now)
    local delay = self.config.emptyArrivalDelay
    if delay ~= nil and #self.pending == 0 then
        self.nextArrivalAt = math.min(self.nextArrivalAt, now + delay)
    end
end

function OrderManager:sampleArrivalDelay()
    if self.rushActive then
        local rush = self.config.rush
        return self.randomDelay(rush.minArrivalDelay, rush.maxArrivalDelay)
    end
    return self.randomDelay(self.config.minArrivalDelay, self.config.maxArrivalDelay)
end

function OrderManager:getLifetime()
    if self.rushActive then
        return self.config.lifetime * self.config.rush.lifetimeScale
    end
    return self.config.lifetime
end

function OrderManager:addOrder(createdAt)
    if #self.pending >= self.config.capacity then return nil end
    -- Keep surviving tickets in their slots when a neighbour is served or
    -- expires. With six slots, this bounded scan needs no temporary table.
    local slot = 1
    while slot <= self.config.capacity do
        local occupied = false
        for _, order in ipairs(self.pending) do
            if order.slot == slot then occupied = true; break end
        end
        if not occupied then break end
        slot += 1
    end
    local order = {
        id = self.nextId,
        createdAt = createdAt,
        expiresAt = createdAt + self:getLifetime(),
        slot = slot,
    }
    self.nextId += 1
    self.pending[#self.pending + 1] = order
    return order
end

function OrderManager:expireAt(now)
    for index = #self.pending, 1, -1 do
        local order = self.pending[index]
        if not self:isCommitted(order) and now >= order.expiresAt then
            table.remove(self.pending, index)
            self.expired += 1
            if self.onOrderExpired ~= nil then self.onOrderExpired(order, self) end
        end
    end
    self:limitEmptyWait(now)
end

function OrderManager:isRushHour()
    return self.rushActive
end

function OrderManager:getRushRemaining()
    if not self.rushActive then return 0 end
    return math.max(0, self.rushEndsAt - self.time)
end

function OrderManager:startRush(now)
    local rush = self.config.rush
    if self.rushActive or rush == nil then return false end
    now = now or self.time
    self.rushActive = true
    self.rushCount += 1
    local duration = rush.duration
    if rush.durationMin ~= nil then
        duration = self.randomDelay(rush.durationMin, rush.durationMax)
    end
    self.rushEndsAt = now + duration
    self.nextRushChangeAt = self.rushEndsAt
    -- Every waiting customer loses patience: remaining time is scaled down,
    -- which also pushes each ticket into its retracting phase at once.
    for _, order in ipairs(self.pending) do
        if not self:isCommitted(order) then
            order.expiresAt = now + (order.expiresAt - now) * rush.lifetimeScale
        end
    end
    -- Empty slots fill one at a time at the rush pace, not all at once.
    self.nextArrivalAt = now + self:sampleArrivalDelay()
    self:limitEmptyWait(now)
    if self.onRushStart ~= nil then self.onRushStart(self) end
    return true
end

function OrderManager:endRush(now)
    if not self.rushActive then return false end
    local rush = self.config.rush
    now = now or self.time
    self.rushActive = false
    self.rushEndsAt = nil
    self.nextRushChangeAt = now + self.randomDelay(rush.cooldownMin, rush.cooldownMax)
    -- Shortened deadlines already issued stay as they are; the arrival
    -- schedule returns to its normal pace from the end of the rush.
    self.nextArrivalAt = now + self:sampleArrivalDelay()
    self:limitEmptyWait(now)
    if self.onRushEnd ~= nil then self.onRushEnd(self) end
    return true
end

function OrderManager:update(dt)
    assert(type(dt) == "number" and dt >= 0 and dt < math.huge,
        "order dt must be finite nonnegative seconds")
    local targetTime = self.time + dt
    -- Replay expiry, arrivals and rush changes in chronological order across a
    -- long frame. At capacity an arrival is skipped; there is no invisible
    -- backlog. A rush change on the same instant as an arrival goes first,
    -- since it rewrites the arrival schedule.
    while true do
        local eventAt = math.min(self.nextArrivalAt, self.nextRushChangeAt)
        -- An expiry can empty the queue and bring the next arrival forward.
        -- Process its actual deadline even when dt spans several events.
        for _, order in ipairs(self.pending) do
            if not self:isCommitted(order) then
                eventAt = math.min(eventAt, order.expiresAt)
            end
        end
        if eventAt > targetTime then break end
        self:expireAt(eventAt)
        if self.nextRushChangeAt == eventAt then
            if self.rushActive then
                self:endRush(eventAt)
            else
                self:startRush(eventAt)
            end
        elseif self.nextArrivalAt <= eventAt then
            self:addOrder(eventAt)
            self.nextArrivalAt += self:sampleArrivalDelay()
        end
    end
    self.time = targetTime
    self:expireAt(targetTime)
end

function OrderManager:count()
    return #self.pending
end

function OrderManager:isCommitted(order)
    return order ~= nil and self.committedOrder == order
end

-- Keep frozen time on the order itself so submission can use it after the
-- order has been removed from the queue. Never refill it on repeated work.
function OrderManager:getRemainingTime(order)
    if order.lockedRemaining ~= nil then return order.lockedRemaining end
    return math.max(0, order.expiresAt - self.time)
end

function OrderManager:nextOrderIndex()
    local bestIndex = nil
    for index, order in ipairs(self.pending) do
        if self:isCommitted(order) then return index end
        if bestIndex == nil or order.expiresAt < self.pending[bestIndex].expiresAt then
            bestIndex = index
        end
    end
    return bestIndex
end

-- Successful assembly starts a promise to one customer. Repeated work,
-- station changes and rushes cannot silently retarget that promise.
function OrderManager:commitNext()
    if self.committedOrder ~= nil then return self.committedOrder end
    self:expireAt(self.time)
    local index = self:nextOrderIndex()
    if index == nil then return nil end
    self.committedOrder = self.pending[index]
    self.committedOrder.committedAt = self.time
    self.committedOrder.lockedRemaining = self:getRemainingTime(self.committedOrder)
    return self.committedOrder
end

function OrderManager:completeNext()
    self:expireAt(self.time)
    -- Fulfil an existing promise first; otherwise use earliest deadline.
    local bestIndex = self:nextOrderIndex()
    if bestIndex == nil then return nil end
    local order = table.remove(self.pending, bestIndex)
    if self:isCommitted(order) then self.committedOrder = nil end
    self.completed += 1
    self:limitEmptyWait(self.time)
    return order
end

-- 0 while a ticket still has more than half a normal lifetime left, rising
-- to 1 at its deadline. Measured from the remaining time, so a rush that
-- shortens a deadline makes the ticket start retracting immediately.
function OrderManager:getSlideProgress(order)
    if self:isCommitted(order) then return 0 end
    local slideWindow = self.config.lifetime / 2
    local remaining = self:getRemainingTime(order)
    return math.max(0, math.min(1, 1 - remaining / slideWindow))
end
