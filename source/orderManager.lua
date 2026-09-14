-- Seconds throughout. No drawing, timers or station dependencies.
-- A small chronological queue; each order keeps its own deadline and UI slot.
-- Rush hour is an optional timed state: it halves every remaining wait, then
-- issues short orders every second or two until the holder is full. Optional
-- onRushStart / onRushEnd fields are called with the manager when it changes,
-- and onOrderExpired with each order that runs out unserved.
OrderManager = {}
OrderManager.__index = OrderManager

function OrderManager.new(config, randomDelay)
    local rush = config.rush
    if rush ~= nil then
        assert(rush.minArrivalDelay > 0 and rush.duration > 0 and
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
    self.completed = 0
    self.expired = 0
    self.rushActive = false
    self.rushCount = 0
    self.rushEndsAt = nil
    for _ = 1, self.config.initialCount do self:addOrder(0) end
    self.nextArrivalAt = self:sampleArrivalDelay()
    local rush = self.config.rush
    if rush ~= nil then
        self.nextRushChangeAt =
            self.randomDelay(rush.firstDelayMin, rush.firstDelayMax)
    else
        self.nextRushChangeAt = math.huge
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
        if now >= order.expiresAt then
            table.remove(self.pending, index)
            self.expired += 1
            if self.onOrderExpired ~= nil then self.onOrderExpired(order, self) end
        end
    end
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
    self.rushEndsAt = now + rush.duration
    self.nextRushChangeAt = self.rushEndsAt
    -- Every waiting customer loses patience: remaining time is scaled down,
    -- which also pushes each ticket into its retracting phase at once.
    for _, order in ipairs(self.pending) do
        order.expiresAt = now + (order.expiresAt - now) * rush.lifetimeScale
    end
    -- Empty slots fill one at a time at the rush pace, not all at once.
    self.nextArrivalAt = now + self:sampleArrivalDelay()
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
    if self.onRushEnd ~= nil then self.onRushEnd(self) end
    return true
end

function OrderManager:update(dt)
    assert(type(dt) == "number" and dt >= 0 and dt < math.huge,
        "order dt must be finite nonnegative seconds")
    local targetTime = self.time + dt
    -- Replay arrivals and rush changes in chronological order even across a
    -- long frame. At capacity an arrival is skipped; there is no invisible
    -- backlog. A rush change on the same instant as an arrival goes first,
    -- since it rewrites the arrival schedule.
    while true do
        local eventAt = math.min(self.nextArrivalAt, self.nextRushChangeAt)
        if eventAt > targetTime then break end
        self:expireAt(eventAt)
        if self.nextRushChangeAt <= self.nextArrivalAt then
            if self.rushActive then
                self:endRush(eventAt)
            else
                self:startRush(eventAt)
            end
        else
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

function OrderManager:completeNext()
    self:expireAt(self.time)
    -- Serve the order closest to its deadline. Chronological order is not
    -- enough once a rush has shortened some deadlines but not others.
    local bestIndex = nil
    for index, order in ipairs(self.pending) do
        if bestIndex == nil or order.expiresAt < self.pending[bestIndex].expiresAt then
            bestIndex = index
        end
    end
    if bestIndex == nil then return nil end
    local order = table.remove(self.pending, bestIndex)
    self.completed += 1
    return order
end

-- 0 while a ticket still has more than half a normal lifetime left, rising
-- to 1 at its deadline. Measured from the remaining time, so a rush that
-- shortens a deadline makes the ticket start retracting immediately.
function OrderManager:getSlideProgress(order)
    local slideWindow = self.config.lifetime / 2
    local remaining = order.expiresAt - self.time
    return math.max(0, math.min(1, 1 - remaining / slideWindow))
end
