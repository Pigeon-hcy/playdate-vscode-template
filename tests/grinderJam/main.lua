-- Stage this main.lua beside source/resource, compile with pdc -k -I source.
-- Assertions run on launch. Demo: A forces a jam, DOWN mashes it free.
import "grinderWorkstation"
local gfx <const> = playdate.graphics
local grinder <const> = PlayerConfig.grinder
local jam <const> = grinder.jam
local dialogCfg <const> = PlayerConfig.burstDialog
local station <const> = GrinderWorkstation
local function near(a, b, tolerance)
    assert(math.abs(a - b) <= (tolerance or 1e-6), tostring(a) .. " ~= " .. tostring(b))
end

-- Every random range resolves to its minimum: halfway through piece 1,
-- then three presses to clear it.
station.randomInt = function(minimum) return minimum end
station.initialize()
assert(not station.isJammed() and station.getJamCount() == 0)
assert(station.getJamPressesLeft() == 0 and station.pressJamClear() == nil)
local function jamDegrees()
    return grinder.totalYield / grinder.meatPerCrankTurn * 360 * jam.triggerProgress
end
station.processCrank(0)
assert(not station.isJammed(), "loading or idling alone cannot trigger a jam")
station.processCrank(jamDegrees() - 1)
assert(not station.isJammed(), "the machine holds until the threshold is passed")
station.processCrank(1)
assert(station.isJammed() and station.getJamCount() == 1)
assert(station.getJamPressesLeft() == 3, "three to six presses, pinned to three here")

-- Nothing grinds while the machine is seized.
local frozenMeat = PlayerConfig.mincedMeat
local frozenDegrees = grinder.processedDegrees
local frozenProgress = station.getMeatProgress()
station.processCrank(3600)
assert(PlayerConfig.mincedMeat == frozenMeat, "a jammed grinder produces no mince")
assert(grinder.processedDegrees == frozenDegrees)
assert(station.getMeatProgress() == frozenProgress, "the meat stops feeding down")
assert(not station.startJam(), "a running jam cannot restart")
assert(station.getJamCount() == 1)

-- The crank is stuck where it stopped, however the real one is turned.
grinder.crankAngle = 123
station.update(true)
assert(grinder.crankAngle == 123, "the drawn crank freezes while jammed")
assert(PlayerConfig.mincedMeat == frozenMeat, "crank movement while stuck is discarded")
gfx.clear()
station.draw()

assert(station.pressJamClear() == "stuck" and station.getJamPressesLeft() == 2)
gfx.clear()
station.draw()
assert(station.pressJamClear() == "stuck" and station.getJamPressesLeft() == 1)
assert(station.isJammed(), "the jam holds until the last press")
assert(station.pressJamClear() == "cleared" and not station.isJammed())
assert(station.pressJamClear() == nil, "a cleared jam ignores further presses")
station.update(true)
assert(grinder.crankAngle == playdate.getCrankPosition(), "the crank follows again")
gfx.clear()
station.draw()

-- Grinding during the cooldown does not count towards the next jam.
assert(not station.startJam(), "cooldown also guards explicit event starts")
station.processCrank(100000)
assert(not station.isJammed(), "the event stays on cooldown after clearing")
assert(PlayerConfig.mincedMeat > frozenMeat, "but grinding itself works again")
assert(not grinder.hasMeat, "the cleared piece finishes without jamming again")
for piece = 1, 3 do
    assert(station.loadNewMeat())
    station.processCrank(100000)
    assert(not station.isJammed() and not grinder.hasMeat,
        "whole pieces processed during cooldown must not count")
end
assert(station.loadNewMeat())
station.processCrank(1)
Juice:update(jam.cooldown + .001)
station.processCrank(100000)
assert(not station.isJammed() and not grinder.hasMeat,
    "a piece started during cooldown stays exempt after cooldown expires")
assert(station.loadNewMeat())
station.processCrank(jamDegrees() - 1)
assert(not station.isJammed())
station.processCrank(1)
assert(station.isJammed() and station.getJamCount() == 2, "a second jam can follow")
station.pressJamClear()
station.pressJamClear()
station.pressJamClear()
assert(not station.isJammed())

-- Every allowed target counts pieces, regardless of their random meat yield.
for target = 2, 3 do
    station.randomInt = function(minimum, maximum)
        if minimum == jam.minMeatCount and maximum == jam.maxMeatCount then return target end
        return minimum
    end
    grinder.hasMeat = false
    station.initialize()
    for piece = 1, target - 1 do
        station.processCrank(100000)
        assert(not station.isJammed() and not grinder.hasMeat,
            "all pieces before the selected one must finish safely")
        assert(station.loadNewMeat())
    end
    local stockBefore = PlayerConfig.mincedMeat
    station.processCrank(100000)
    assert(station.isJammed() and grinder.hasMeat, "a huge sample cannot skip the jam")
    near(station.getMeatProgress(), jam.triggerProgress)
    assert(PlayerConfig.mincedMeat - stockBefore == math.floor(grinder.totalYield * jam.triggerProgress),
        "only meat processed before the jam may enter inventory")
    station.pressJamClear()
    station.pressJamClear()
    station.pressJamClear()
    assert(not station.isJammed())
    Juice:update(jam.cooldown + .01)
    station.processCrank(100000)
    assert(not station.isJammed() and not grinder.hasMeat,
        "even after waiting out cooldown, the cleared piece cannot count twice")
end

-- An empty machine cannot seize: there is nothing in it to catch.
grinder.hasMeat = false
assert(not station.startJam())
station.initialize()
assert(station.getJamCount() == 0, "initialization clears the event entirely")

-- The starburst panel itself.
local dialog = BurstDialog.new({ width = 100, height = 40, draw = function() end })
assert(not dialog:isVisible(0) and dialog:getScale(0) == 0)
dialog:show(0)
assert(dialog:isVisible(0))
near(dialog:getScale(0), 0, .01)
assert(dialog:getScale(dialogCfg.enterDuration * .7) > 1, "the panel springs past full size")
near(dialog:getScale(dialogCfg.enterDuration), 1, .01)
near(dialog:getScale(5), 1, .01)
dialog:jolt(5)
assert(dialog:getScale(5) > 1 and dialog:getScale(5 + dialogCfg.joltDuration) <= 1.0001)
dialog:hide(6)
assert(dialog:isVisible(6))
assert(dialog:getScale(6 + dialogCfg.exitDuration * dialogCfg.exitPopShare * .99) >
    dialogCfg.exitPopScale * .9, "it swells before collapsing")
assert(not dialog:isVisible(6 + dialogCfg.exitDuration))
dialog:show(7)
dialog:cancel()
assert(not dialog:isVisible(7))
print("GRINDER JAM TESTS PASSED")

station.randomInt = math.random
station.initialize()
playdate.display.setRefreshRate(PlayerConfig.refreshRate)
local last = playdate.getCurrentTimeMilliseconds()
function playdate.update()
    local now = playdate.getCurrentTimeMilliseconds()
    Juice:update((now - last) / 1000)
    last = now
    if playdate.buttonJustPressed(playdate.kButtonA) then station.startJam() end
    station.handleInput()
    station.update(true)
    gfx.clear()
    station.draw()
    gfx.drawText("A: JAM   DOWN: MASH / NEW MEAT", 12, 226)
end
