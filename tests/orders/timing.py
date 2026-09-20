#!/usr/bin/env python3
"""Exercise production queue/config with Lua 5.4 (lupa), without graphics."""
from pathlib import Path
import re
from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[2]
lua = LuaRuntime()
loaded = set()


def load(name):
    if name in loaded:
        return
    loaded.add(name)
    source = (root / 'source' / f'{name}.lua').read_text()
    # Playdate's += extension; these modules use it on standalone lines only.
    source = re.sub(r'(?m)^(\s*)([\w.]+) \+= (.+)$', r'\1\2 = \2 + \3', source)
    lua.execute(source)


lua.globals()['import'] = load
load('playerConfig')
load('orderManager')
lua.execute('''
local config = PlayerConfig.orders
assert(config.minArrivalDelay == 10 and config.maxArrivalDelay == 30)
assert(config.emptyArrivalDelay == 5 and PlayerConfig.frying.pattyCost == 50)
assert(config.rush.firstDelayMin == 90 and config.rush.firstDelayMax == 120)
assert(config.rush.cooldownMin == 105 and config.rush.cooldownMax == 135)
assert(config.rush.durationMin == 60 and config.rush.durationMax == 90)
assert(config.rush.minArrivalDelay == 2 and config.rush.maxArrivalDelay == 2)
local function maximum(a,b) return b end
local q = OrderManager.new(config, maximum)
q:update(1);q:completeNext()
assert(q.nextArrivalAt == 6)
for i=1,19 do q:update(.25);assert(q:count()==0) end
q:update(.25)
assert(q:count()==1 and q.pending[1].createdAt==6 and q.nextArrivalAt==36,
    "empty queue gets an order in 5s, then returns to normal cadence")
q:update(28);q:completeNext()
assert(q.nextArrivalAt==36,"empty cap must keep an earlier arrival")
q:update(2);assert(q:count()==1)

local empty = {capacity=6, lifetime=3, initialCount=0,
    minArrivalDelay=30,maxArrivalDelay=30,emptyArrivalDelay=5}
q=OrderManager.new(empty,maximum)
assert(q.nextArrivalAt==5,"empty startup must get an order in 5s")
q:update(8)
assert(q:count()==0 and q.nextArrivalAt==13,"expiry starts the empty countdown")
q:update(5)
assert(q:count()==1 and q.pending[1].createdAt==13)
local whole=OrderManager.new(empty,maximum)
local split=OrderManager.new(empty,maximum)
whole:update(100)
for i=1,400 do split:update(.25) end
assert(whole.nextArrivalAt==split.nextArrivalAt and whole.expired==split.expired)
assert(whole.nextId==split.nextId and whole:count()==split:count(),
    "long frames must replay empty-queue expiry/refills identically")

q=OrderManager.new(config,maximum)
q:startRush()
q:completeNext()
assert(q.nextArrivalAt==2,"empty rule must not slow rush arrivals")
q:update(1.999);assert(q:count()==0)
q:update(.0011);assert(q:count()==1 and q.pending[1].createdAt==2)
q:update(3.9999)
assert(q:count()==3 and q.pending[3].createdAt==6)

for _,bound in ipairs({function(a,b) return a end, maximum}) do
    q=OrderManager.new(config,bound)
    local start=q.nextRushChangeAt
    q:update(start)
    assert(q:isRushHour() and q.nextArrivalAt==start+2)
    local duration=bound(60,90)
    assert(q:getRushRemaining()==duration,"sample rush duration once at its start")
    q:update(duration-.25)
    assert(q:isRushHour() and q:getRushRemaining()==.25)
    q:update(.25)
    assert(not q:isRushHour())
    assert(q.nextRushChangeAt==q.time+bound(105,135))
end
local function alternating()
    local n=0
    return function(a,b) n=n+1;return n%2==1 and a or b end
end
whole=OrderManager.new(config,alternating())
split=OrderManager.new(config,alternating())
whole:update(900)
for i=1,3600 do split:update(.25) end
assert(whole.expired==split.expired and whole.rushCount==split.rushCount)
assert(whole.nextArrivalAt==split.nextArrivalAt and whole:count()==split:count())
for i,order in ipairs(whole.pending) do
    assert(order.id==split.pending[i].id and order.expiresAt==split.pending[i].expiresAt)
end
-- A commitment survives all deadlines and rushes without protecting others.
q=OrderManager.new(config,maximum)
q:update(10)
local promised=q:commitNext()
assert(promised and q:isCommitted(promised))
assert(q:getRemainingTime(promised)==50,"commitment freezes the current remaining time")
assert(q:commitNext()==promised,"continued work must not commit another customer")
local deadline=promised.expiresAt
q:update(900)
assert(q:isCommitted(promised) and q.pending[1]==promised and q.expired>0)
assert(promised.expiresAt==deadline and q:getRemainingTime(promised)==50,
    "remaining time stays locked through long frames and multiple rushes")
assert(q:getSlideProgress(promised)==0,"promised ticket must stay visible")
assert(q:completeNext()==promised and not q:isCommitted(promised),
    "serve the promised customer first even after the original deadline")
assert(q.committedOrder==nil)
assert(q:getRemainingTime(promised)==50,"completed order retains its frozen time for scoring")
if q:count()==0 then q:addOrder(q.time) end
local nextCustomer=q:commitNext()
assert(nextCustomer and nextCustomer~=promised)
q:reset()
assert(q.committedOrder==nil,"reset clears the promise")

-- Do not retarget a promised order if a newer one has an earlier deadline.
q=OrderManager.new(config,maximum)
promised=q:commitNext()
local impatient=q:addOrder(0)
impatient.expiresAt=1
q:update(.5)
assert(q:completeNext()==promised)
q:update(.5)
assert(q.expired==1,"other customers still leave on time")
q:completeNext()
assert(q:commitNext()==nil,"an empty queue cannot be committed")
q:addOrder(q.time)
assert(q:commitNext()~=nil,"a new customer can be committed after an empty queue")

whole=OrderManager.new(config,alternating())
split=OrderManager.new(config,alternating())
whole:commitNext();split:commitNext()
whole:update(900)
for i=1,3600 do split:update(.25) end
assert(whole.expired==split.expired and whole.nextArrivalAt==split.nextArrivalAt)
assert(whole.committedOrder.id==split.committedOrder.id and whole:count()==split:count())
print("PASS: production cadence, empty queue refill, committed order protection/priority/reset and long-frame replay")
''')
