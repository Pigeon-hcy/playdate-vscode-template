-- Stage this main.lua beside source/resource, then compile with pdc -I source.
-- Assertions run on launch; A places patties, B collects after 1s in the demo.
import "fryingWorkstation"

local gfx <const> = playdate.graphics
local frying <const> = PlayerConfig.frying
local station <const> = FryingWorkstation
station.randomInt = function(minimum) return minimum end
PlayerConfig.mincedMeat = frying.pattyCost * (frying.slotCount + 1)
Juice:verticalShake("burger", 1)

assert(station.placePatty())
assert(frying.slots[1].animation == nil, "placement must appear in place without dropping")
assert(PlayerConfig.mincedMeat == frying.pattyCost * frying.slotCount)
local effect = Juice.effects["frying.patty.1"]
assert(effect.kind == "land" and effect.vibration.active)
assert(effect.vibration.duration == Juicy.config.heavyShakeDuration)
assert(Juice:getTransform("frying.patty.1").offsetY == 0, "no drop from above")
assert(station.collectOrDiscard() == nil, "raw patties cannot be collected")
station.update(false)
assert(frying.slots[1].elapsedFrames == 1, "cooking starts immediately, also offscreen")
for i = 2, frying.slotCount do assert(station.placePatty()) end
local stock = PlayerConfig.mincedMeat
assert(not station.placePatty())
assert(PlayerConfig.mincedMeat == stock, "full grill must not consume meat")
for i = 1, 20 do
    Juice:update(1 / 30)
    station.update(false)
    station.draw()
end
local transform = Juice:getTransform("frying.patty.1")
assert(transform.offsetX == 0 and transform.offsetY == 0)
assert(transform.scaleX == 1 and transform.scaleY == 1, "appearance settles exactly")

frying.slots[1].state = "cooked"
frying.slots[2].state = "burning"
for press = 1, frying.fire.minPresses - 1 do
    assert(station.collectOrDiscard() == "burning", "fire takes priority over collecting")
    assert(frying.slots[2].animation == nil, "one press cannot discard a burning patty")
end
assert(station.collectOrDiscard() == "extinguished", "last press puts out and discards the patty")
assert(PlayerConfig.patties == 0)
assert(Juice.effects["frying.patty.2"] == nil)
assert(station.collectOrDiscard() == "collected")
assert(PlayerConfig.patties == 1)
assert(station.collectOrDiscard() == nil, "rising patties cannot be counted twice")
assert(Juice.effects.burger ~= nil, "grill cleanup must not remove assembly effects")
for i = 1, frying.riseAnimationDurationFrames - 1 do station.update(false) end
assert(frying.slots[1] ~= nil and frying.slots[2] ~= nil)
assert(not station.placePatty(), "rising slots remain occupied until exit finishes")
station.update(false)
assert(frying.slots[1] == nil and frying.slots[2] == nil)
assert(frying.riseAnimationDurationFrames / PlayerConfig.refreshRate < .15)
assert(frying.riseDistance == 15)
assert(station.placePatty(), "freed slot can be reused")
assert(Juice.effects["frying.patty.1"].vibration.active)
assert(frying.slots[1].animation == nil)

print("FRYING JUICE TESTS PASSED")
station.randomInt = math.random
Juice:clear()
frying.slots = {}
PlayerConfig.mincedMeat = 999
PlayerConfig.patties = 0
frying.rawDurationFrames = 30
local last = playdate.getCurrentTimeMilliseconds()
playdate.display.setRefreshRate(30)
function playdate.update()
    local now = playdate.getCurrentTimeMilliseconds()
    Juice:update((now - last) / 1000)
    last = now
    station.handleInput()
    station.update(true)
    gfx.clear()
    station.draw()
    gfx.drawText("TESTS PASSED - COOKS IN 1s", 65, 182)
end
