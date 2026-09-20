-- Stage this main.lua beside source/resource, then compile with pdc -I source.
-- Assertions run on launch and cover Variant D's one-patty crank grill.
import "variants/variantD/fryingWorkstation"

local pd <const> = playdate
local gfx <const> = pd.graphics
local station <const> = FryingWorkstation
local frying <const> = PlayerConfig.frying

local originalButtonJustPressed <const> = pd.buttonJustPressed
local originalGetCrankChange <const> = pd.getCrankChange
local pressed = {}
local crankChange = 0
pd.buttonJustPressed = function(button) return pressed[button] == true end
pd.getCrankChange = function()
    local result = crankChange
    crankChange = 0
    return result
end

local function input(buttons, crank)
    pressed = {}
    for _, button in ipairs(buttons or {}) do pressed[button] = true end
    crankChange = crank or 0
    station.handleInput()
    Juice:update(.05)
end

local function finishRise()
    for _ = 1, frying.riseAnimationDurationFrames do station.update(false) end
end

frying.slots = {}
PlayerConfig.mincedMeat = frying.pattyCost * 4
PlayerConfig.patties = 0
assert(frying.slotCount == 1 and station.getState() == "empty")

input({ pd.kButtonDown })
assert(station.getState() == "raw" and station.getProgress() == 0)
assert(PlayerConfig.mincedMeat == frying.pattyCost * 3)
assert(not station.placePatty(), "only one patty may be on the grill")

input({ pd.kButtonUp })
assert(PlayerConfig.patties == 0 and station.getState() == "raw",
    "an undercooked patty cannot be collected")
input({}, frying.degreesForFullBar * .6 - 1)
assert(station.getProgress() < 60 and station.getState() == "raw")
local beforeIdleUpdate = station.getProgress()
for _ = 1, 60 do station.update(true) end
assert(station.getProgress() == beforeIdleUpdate,
    "time alone must not advance the crank grill")
input({}, 1)
assert(math.abs(station.getProgress() - 60) < .001 and station.getState() == "ready")
input({ pd.kButtonUp })
assert(PlayerConfig.patties == 1 and frying.slots[1].animation == "rising")
finishRise()
assert(station.getState() == "empty")

input({ pd.kButtonDown })
input({}, -frying.degreesForFullBar * .8)
assert(math.abs(station.getProgress() - 80) < .001 and station.getState() == "ready",
    "80 percent remains collectible")
input({ pd.kButtonUp })
assert(PlayerConfig.patties == 2)
finishRise()

input({ pd.kButtonDown })
input({}, frying.degreesForFullBar * .8 + 1)
assert(station.getProgress() > 80 and station.getState() == "burnt",
    "progress above 80 must burn the patty")
assert(station.isOnFire() and not station.isFireDialogVisible())
input({ pd.kButtonUp })
assert(PlayerConfig.patties == 2 and frying.slots[1].animation == "rising",
    "UP discards a burnt patty without crediting inventory")
finishRise()
assert(station.getState() == "empty")

gfx.clear()
station.draw()
station.drawProgressBar()
pd.buttonJustPressed = originalButtonJustPressed
pd.getCrankChange = originalGetCrankChange
print("CRANK GRILL TESTS PASSED")

pd.display.setRefreshRate(PlayerConfig.refreshRate)
function pd.update()
    Juice:update(1 / PlayerConfig.refreshRate)
    station.update(true)
    gfx.clear()
    station.draw()
end
