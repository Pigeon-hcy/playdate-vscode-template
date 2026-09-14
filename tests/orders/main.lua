-- Stage this main.lua beside source/resource, compile with pdc -k -I source.
-- Runtime assertions cover time, capacity, priority and the ticket trajectory.
import "orderUI"
local gfx <const> = playdate.graphics
local config <const> = PlayerConfig.orders
-- The same queue rules without rush hour, so the fixed 30-second stub below
-- only drives arrivals.
local calmConfig <const> = {
    capacity = config.capacity, lifetime = config.lifetime,
    minArrivalDelay = config.minArrivalDelay, maxArrivalDelay = config.maxArrivalDelay,
    initialCount = config.initialCount, ticketEntryDuration = config.ticketEntryDuration,
}
local function every30() return 30 end
local q = OrderManager.new(calmConfig, every30)
assert(q:count() == 1 and q.pending[1].createdAt == 0)
assert(q.pending[1].expiresAt == 60)
local first = q.pending[1]
local entryY = OrderUI.getTicketY(first, q)
assert(entryY <= -28, "new receipts start above the screen")
q:update(.1)
assert(OrderUI.getTicketY(first, q) > entryY)
q:update(.1)
assert(OrderUI.getTicketY(first, q) == 2, "ticket hangs under the holder after its 0.2s entry")
q:update(29.8)
assert(q:count() == 2 and q.pending[2].createdAt == 30)
assert(q:getSlideProgress(first) == 0 and OrderUI.getTicketY(first, q) == 2)
q:update(15)
assert(q:getSlideProgress(first) == .5)
assert(q:getSlideProgress(q.pending[2]) == 0, "each ticket has its own age")
assert(OrderUI.getTicketY(first, q) < 2)
assert(not OrderUI.isUrgent(first, q), "15 seconds left is not yet urgent")
q:update(5)
assert(OrderUI.isUrgent(first, q) and not OrderUI.isUrgent(q.pending[2], q),
    "only the ticket inside its last 10 seconds flashes")
q:update(9.999)
assert(q.pending[1] == first, "order remains valid until its own 60s deadline")
assert(OrderUI.getTicketY(first, q) > -23, "a still-valid ticket keeps its last row below the holder lip")
q:update(.0011)
assert(q.expired == 1 and q:count() == 2)
assert(OrderUI.getTicketY(first, q) == -23, "ticket finishes retracting behind the holder at its deadline")
assert(q.pending[1].id == 2 and q.pending[1].slot == 2)
assert(q.pending[2].id == 3 and q.pending[2].slot == 1)
assert(q:completeNext().id == 2, "earliest deadline wins, not leftmost slot")
assert(q.pending[1].id == 3 and q.completed == 1)
q:completeNext()
assert(q:count() == 0 and q:completeNext() == nil and q.completed == 2)

local fastConfig = {
    capacity = 6, lifetime = 60, initialCount = 6,
    minArrivalDelay = 1, maxArrivalDelay = 1,
}
local full = OrderManager.new(fastConfig, function() return 1 end)
full:update(10)
assert(full:count() == 6 and full.nextId == 7)
assert(full:completeNext().id == 1)
full:update(.5)
assert(full:count() == 5, "a skipped arrival must not queue up for immediate delivery")
full:update(.5)
assert(full:count() == 6 and full.pending[6].id == 7)
assert(full.pending[6].createdAt == 11 and full.pending[6].expiresAt == 71)

-- Alternate every range between its bounds so arrivals, the first rush and
-- its cooldown all vary, then check a long frame replays them identically.
local function alternatingDelays()
    local calls = 0
    return function(minimum, maximum)
        calls += 1
        return calls % 2 == 1 and minimum or maximum
    end
end
local whole = OrderManager.new(config, alternatingDelays())
local split = OrderManager.new(config, alternatingDelays())
assert(whole.nextArrivalAt == 20)
whole:update(20)
assert(whole.nextArrivalAt == 40)
whole:update(880)
for _ = 1, 3600 do split:update(.25) end
assert(whole.rushCount >= 2 and whole.rushCount == split.rushCount, "rushes recur across 15 minutes")
assert(whole.time == split.time and whole.nextArrivalAt == split.nextArrivalAt)
assert(whole.nextRushChangeAt == split.nextRushChangeAt and whole.rushActive == split.rushActive)
assert(whole.expired == split.expired and whole:count() == split:count())
for index, order in ipairs(whole.pending) do
    local other = split.pending[index]
    assert(order.id == other.id and order.slot == other.slot and order.expiresAt == other.expiresAt)
end
assert(not pcall(function() whole:update(-1) end))

-- Rush hour, with every random range resolving to its minimum: arrivals at
-- 20, 40, ... 160; the first rush starts at 180 and ends at 300; the next
-- starts 210 seconds later. Rush orders then arrive one per second.
local rush = OrderManager.new(config, function(minimum) return minimum end)
assert(not rush:isRushHour() and rush:getRushRemaining() == 0)
rush:update(179.999)
assert(rush:count() == 3, "orders from 120, 140 and 160 are still waiting")
rush:update(.001)
assert(rush:isRushHour() and rush.rushCount == 1 and rush:getRushRemaining() == 120)
assert(rush.expired == 7, "the order from 120 expires as the rush begins, not after")
assert(rush:count() == 2, "a rush does not fill the holder in one go")
local byId = {}
for _, order in ipairs(rush.pending) do byId[order.id] = order end
assert(byId[8].expiresAt == 190 and byId[9].expiresAt == 200,
    "remaining waits of 20 and 40 are halved to 10 and 20")
assert(rush:getSlideProgress(byId[8]) > rush:getSlideProgress(byId[9]) and
    rush:getSlideProgress(byId[9]) > 0, "halved tickets start retracting at once")
rush:update(.5)
assert(rush:completeNext().id == 8, "the order nearest its deadline is served first")
rush:update(.5)
assert(rush:count() == 2 and rush.pending[2].expiresAt == 211,
    "the first rush order arrives one second in and lives half a lifetime")
assert(rush:getSlideProgress(rush.pending[2]) == 0)
rush:update(.5)
assert(rush:getSlideProgress(rush.pending[2]) > 0, "rush orders start retracting immediately")
rush:update(3.5)
assert(rush.time == 185 and rush:count() == 6, "one order per second until the holder is full")
rush:update(15)
assert(rush.time == 200 and rush.expired == 8 and rush:count() == 6,
    "the halved order from 160 expires and its slot refills in the same instant")
rush:update(100)
assert(rush.time == 300 and not rush:isRushHour() and rush.rushCount == 1)
for _, order in ipairs(rush.pending) do
    assert(order.expiresAt <= 330, "rush orders issued before the end keep their short deadlines")
end
assert(rush.nextArrivalAt == 320, "normal arrival pace resumes from the end of the rush")
assert(rush.nextRushChangeAt == 510, "cooldown is counted from the end of the rush")
rush:update(20)
assert(rush:count() == 1 and rush.pending[1].expiresAt == 380,
    "orders after the rush live a full lifetime")
rush:update(190)
assert(rush:isRushHour() and rush.rushCount == 2)
assert(not rush:startRush(), "a running rush cannot restart")

-- Rush hour is optional: a configuration without it never changes state.
local calm = OrderManager.new(fastConfig, function() return 1 end)
calm:update(1000)
assert(not calm:isRushHour() and calm.rushCount == 0 and not calm:startRush())

-- Scoring formula: LONE COW is two kinds, two ingredients.
assert(Scoring.burgerPoints({ "P", "A" }, 45, false) == 970)
assert(Scoring.burgerPoints({ "P", "A" }, 45.9, false) == 970, "only whole seconds count")
assert(Scoring.burgerPoints({ "P", "A" }, 45, true) == 1455, "rush hour multiplies the whole sum")
assert(Scoring.burgerPoints({ "P", "P", "B", "A", "O", "L", "T" }, 0, false) == 1220,
    "six kinds and seven ingredients with no time left")
assert(Scoring.burgerPoints({}, -3, false) == 200, "negative remaining time earns nothing extra")
PlayerConfig.score = 100
local changes = {}
Scoring.onChange = function(delta) changes[#changes + 1] = delta end
assert(Scoring.penalizeMissed() == 800 and PlayerConfig.score == 0, "the score stops at zero")
assert(Scoring.penalizeWrong() == 500 and PlayerConfig.score == 0)
assert(changes[1] == -800 and changes[2] == -500, "feedback still reports the full penalty")
assert(Scoring.penalizeMissed(true) == 200, "a miss during a rush costs a quarter")
Scoring.onChange = nil

-- Real submission integration, including no-order protection and empty UI.
import "assemblyWorkstation"
local station = AssemblyWorkstation
Orders:reset()
station.initialize()
PlayerConfig.assembly.currentRecipeIndex = 1
PlayerConfig.patties = 5
station.addIngredient("P")
station.addIngredient("A")
station.pressUp()
Juice:update(.3)
Orders:completeNext()
local score = PlayerConfig.score
assert(station.pressUp() == "no_order" and not station.isServing())
assert(PlayerConfig.assembly.hasTopBread and #PlayerConfig.assembly.layers == 2)
assert(PlayerConfig.score == score, "no-order submission must preserve the burger and score")
gfx.clear()
station.draw()
Orders:update(10)
Orders:addOrder(Orders.time)
Orders:update(10)
Orders:addOrder(Orders.time)
local oldestId = Orders.pending[1].id
local expected = Scoring.burgerPoints({ "P", "A" }, 60 - 10, false)
assert(station.pressUp() == "correct")
assert(Orders:count() == 1 and Orders.pending[1].id ~= oldestId)
assert(PlayerConfig.score == score + expected, "the served order's own remaining time is scored")
assert(PlayerConfig.assembly.lastResult == "CORRECT +" .. expected)
assert(station.pressUp() == "animating" and Orders:count() == 1)
Juice:update(1)
station.update(false)
station.initialize()
PlayerConfig.assembly.currentRecipeIndex = 1
station.pressUp()
Juice:update(.3)
assert(Orders:count() == 1)
score = PlayerConfig.score
assert(station.pressUp() == "wrong")
assert(Orders:count() == 0 and PlayerConfig.score == score - 500,
    "incorrect burgers consume an order and cost 500")
assert(PlayerConfig.assembly.lastResult == "WRONG -500")
-- No normal arrivals, so only the opening order and the first rush order
-- (fixed one-second rush arrivals, expiring at 91) can run out here.
Orders.randomDelay = function(minimum)
    return minimum == config.minArrivalDelay and 1000 or minimum
end
Orders:reset()
PlayerConfig.score = 5000
score = PlayerConfig.score
Orders:update(59.999)
assert(PlayerConfig.score == score)
Orders:update(.001)
assert(PlayerConfig.score == score - 800, "an expired order costs 800")
Orders:startRush()
Orders:update(1)
score = PlayerConfig.score
Orders:update(30)
assert(Orders.expired == 2 and PlayerConfig.score == score - 200,
    "an order missed during a rush costs a quarter of the usual penalty")
Orders.randomDelay = math.random
Orders:update(1)
station.initialize()
PlayerConfig.assembly.currentRecipeIndex = 1
station.addIngredient("P")
station.addIngredient("A")
station.pressUp()
Juice:update(.3)
score = PlayerConfig.score
local remaining = Orders.pending[1].expiresAt - Orders.time
assert(station.pressUp() == "correct")
assert(PlayerConfig.score == score + Scoring.burgerPoints({ "P", "A" }, remaining, true),
    "serving during a rush pays the rush bonus")
print("ORDER SYSTEM TESTS PASSED")

-- UI inspection: six independent tickets of staggered ages, then normal
-- 20-40s arrivals. A advances ten seconds; B completes the earliest deadline;
-- LEFT starts a rush hour by hand.
Orders = OrderManager.new({
    capacity = 6, lifetime = 60, initialCount = 1,
    minArrivalDelay = 5, maxArrivalDelay = 5,
}, function() return 5 end)
Orders:update(25)
Orders.config = config
Orders.randomDelay = math.random
Orders.nextArrivalAt = Orders.time + 30
playdate.display.setRefreshRate(30)
local last = playdate.getCurrentTimeMilliseconds()
function playdate.update()
    local now = playdate.getCurrentTimeMilliseconds()
    Orders:update((now - last) / 1000)
    last = now
    if playdate.buttonJustPressed(playdate.kButtonA) then Orders:update(10) end
    if playdate.buttonJustPressed(playdate.kButtonB) then Orders:completeNext() end
    if playdate.buttonJustPressed(playdate.kButtonLeft) then Orders:startRush() end
    gfx.clear()
    OrderUI.draw()
    gfx.drawText("ORDER TESTS PASSED", 12, 60)
    gfx.drawText("A: +10s   B: COMPLETE OLDEST   LEFT: RUSH", 12, 85)
    if Orders:isRushHour() then
        gfx.drawText("RUSH " .. math.ceil(Orders:getRushRemaining()) .. "s", 300, 60)
    end
    for index, order in ipairs(Orders.pending) do
        gfx.drawText("#" .. order.id .. "  slot " .. order.slot .. "  " ..
            math.ceil(order.expiresAt - Orders.time) .. "s", 12, 105 + index * 16)
    end
end
