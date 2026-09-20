#!/usr/bin/env python3
"""Check production queue + ticket positioning with a minimal graphics boundary."""
from pathlib import Path
import runpy

context = runpy.run_path(str(Path(__file__).with_name('timing.py')))
lua, load, loaded = context['lua'], context['load'], context['loaded']
loaded.update(('CoreLibs/graphics', 'orderRuntime'))
lua.execute('''
local noop=function() end
local gfx={kColorClear=2,kColorBlack=0,kImageFlippedY=1}
playdate={graphics=gfx}
gfx.pushContext=noop;gfx.popContext=noop
gfx.image={new=function(path,height)
    local width=path
    if type(path)=="string" then
        width=path:find("Holder") and 168 or 22
        height=path:find("Holder") and 10 or 28
    end
    return {getSize=function() return width,height end,draw=noop,
        sample=function(self,x,y) return y<5 and 0 or 2 end}
end}
''')
load('orderUI')
lua.execute('''
local function queueAt(time)
    local q=OrderManager.new(PlayerConfig.orders,function(a,b) return b end)
    q:update(time)
    return q
end
local duration=PlayerConfig.orders.ticketReturnDuration
local q=queueAt(45)
local order=q.pending[1]
local fromY=OrderUI.getTicketY(order,q)
assert(fromY<2)
assert(q:commitNext()==order)
assert(OrderUI.getTicketY(order,q)==fromY,"commitment must not jump the ticket")
local remaining=q:getRemainingTime(order)
q:update(duration/2)
local midpoint=OrderUI.getTicketY(order,q)
assert(midpoint==math.floor(fromY+(2-fromY)*.5+.5),"midpoint must follow lerp")
assert(q:commitNext()==order and OrderUI.getTicketY(order,q)==midpoint,
    "repeated work must not restart the return")
q:update(0)
assert(OrderUI.getTicketY(order,q)==midpoint,"paused game time freezes the animation")
q:update(duration/2)
assert(OrderUI.getTicketY(order,q)==2 and q:getRemainingTime(order)==remaining)
q:update(300)
assert(OrderUI.getTicketY(order,q)==2 and q:getRemainingTime(order)==remaining)

-- Newly entering and already settled tickets use their own starting pose.
for _,time in ipairs({.1,20}) do
    q=queueAt(time);order=q.pending[1]
    fromY=OrderUI.getTicketY(order,q)
    q:commitNext()
    assert(OrderUI.getTicketY(order,q)==fromY)
    q:update(duration)
    assert(OrderUI.getTicketY(order,q)==2)
end
print("PASS: ticket return lerp, exact start/end, entry continuity, pause and frozen time")
''')
