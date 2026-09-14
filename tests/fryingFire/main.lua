-- Stage beside source/resource; compile with pdc -k -I source.
-- Assertions run on launch. Demo: A adds a patty, tap B to fight fires.
import "fryingWorkstation"
import "fryingWarning"

local gfx <const> = playdate.graphics
local station <const> = FryingWorkstation
local frying <const> = PlayerConfig.frying
local burnAt <const> = frying.rawDurationFrames + frying.cookedDurationFrames
local randomCalls = 0
station.randomInt = function(minimum, maximum)
    randomCalls += 1
    assert(minimum == frying.fire.minPresses and maximum == frying.fire.maxPresses)
    return minimum
end
frying.slots = {}
PlayerConfig.patties = 0
assert(not station.isOnFire() and station.pressFireClear() == nil)
frying.slots[1] = { state = "cooked", elapsedFrames = burnAt - 1, animationFrame = 0 }
frying.slots[2] = { state = "cooked", elapsedFrames = frying.rawDurationFrames, animationFrame = 0 }
Juice:verticalShake("burger", 10)
station.update(false)
assert(station.isOnFire() and station.isFireDialogVisible(), "fire starts even offscreen")
assert(station.getFirePressesLeft() == frying.fire.minPresses and randomCalls == 1)
assert(station.getCookingEffect(frying.slots[1], 1) == "flame")
assert(station.collectOrDiscard() == "burning")
assert(PlayerConfig.patties == 0 and frying.slots[2].animation == nil,
    "fire presses cannot collect another cooked patty")
local left = station.getFirePressesLeft()
for i = 1, 10 do
    Juice:update(1 / PlayerConfig.refreshRate)
    station.update(false)
end
assert(station.getFirePressesLeft() == left and randomCalls == 1,
    "leaving the fryer must preserve progress and must not reroll")

-- A held B without a fresh edge must not count as another press.
local originalButtonJustPressed = playdate.buttonJustPressed
playdate.buttonJustPressed = function() return false end
station.handleInput()
assert(station.getFirePressesLeft() == left)
playdate.buttonJustPressed = originalButtonJustPressed

-- A second patty catches fire while the first is being put out.
frying.slots[3] = { state = "cooked", elapsedFrames = burnAt - 1, animationFrame = 0 }
station.update(false)
assert(randomCalls == 1, "another fire must not reset the current target")
for press = 1, left - 1 do assert(station.pressFireClear() == "burning") end
assert(station.pressFireClear() == "extinguished")
assert(frying.slots[1].animation == "rising" and PlayerConfig.patties == 0)
assert(station.getCookingEffect(frying.slots[1], 1) == nil)
assert(station.isOnFire() and station.getFirePressesLeft() == frying.fire.minPresses)
assert(randomCalls == 2 and station.isFireDialogVisible())
FryingWarning.update()
assert(FryingWarning.getMode() == "fire", "another fire keeps the offscreen warning alive")
for press = 1, frying.fire.minPresses - 1 do assert(station.collectOrDiscard() == "burning") end
assert(station.collectOrDiscard() == "extinguished")
assert(not station.isOnFire() and station.getFirePressesLeft() == 0)
assert(PlayerConfig.patties == 0, "the final fire press must not also collect")
assert(station.pressFireClear() == nil)
assert(station.collectOrDiscard() == "collected" and PlayerConfig.patties == 1)
assert(station.collectOrDiscard() == nil, "rising slots cannot be collected twice")
FryingWarning.update()
assert(FryingWarning.getMode() == nil)
assert(Juice.effects.burger ~= nil, "fire effects must not clear other station effects")
Juice:update(PlayerConfig.burstDialog.exitDuration + .01)
assert(not station.isFireDialogVisible())
for frame = 1, frying.riseAnimationDurationFrames do station.update(false) end
assert(frying.slots[1] == nil and frying.slots[2] == nil and frying.slots[3] == nil)
print("FRYING FIRE TESTS PASSED")

station.randomInt = math.random
Juice:clear()
frying.slots = {}
PlayerConfig.mincedMeat = 999
PlayerConfig.activeWorkstation = 2
frying.rawDurationFrames = 30
frying.cookedDurationFrames = 90
station.placePatty()
station.placePatty()
local last = playdate.getCurrentTimeMilliseconds()
playdate.display.setRefreshRate(PlayerConfig.refreshRate)
function playdate.update()
    local now = playdate.getCurrentTimeMilliseconds()
    Juice:update((now - last) / 1000)
    last = now
    station.handleInput()
    station.update(true)
    gfx.clear()
    station.draw()
end
