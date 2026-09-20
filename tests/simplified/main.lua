-- Stage beside source/resource; compile with pdc -k -I source.
-- Assertions cover the simplified ingredient set and grinder guidance.
import "variants/variantB/grinderWorkstation"

local station <const> = GrinderWorkstation
local grinder <const> = PlayerConfig.grinder

local allowed <const> = { P = true, A = true, T = true, L = true, K = true }
assert(#PlayerConfig.assembly.ingredientCodes == 5)
for _, code in ipairs(PlayerConfig.assembly.ingredientCodes) do
    assert(allowed[code], "unexpected simplified ingredient: " .. code)
end
for _, recipe in ipairs(PlayerConfig.recipe) do
    assert(#recipe - 1 >= 2 and #recipe - 1 <= 5,
        "simplified recipes must contain two to five ingredients")
    for index = 2, #recipe do
        assert(allowed[recipe[index]], "recipe contains a removed ingredient")
    end
end

PlayerConfig.activeWorkstation = 1
PlayerConfig.mincedMeat = 0
station.initialize()
assert(not grinder.hasMeat and station.getGuideMode() == "load",
    "an empty grinder must ask for raw meat")
assert(station.loadNewMeat() and station.getGuideMode() == nil,
    "loading meat must dismiss the load prompt")

PlayerConfig.mincedMeat = grinder.stovePromptThreshold - 1
station.update(true)
assert(station.getGuideMode() == nil, "the stove prompt must wait for 300 mince")
PlayerConfig.mincedMeat = grinder.stovePromptThreshold
station.update(true)
assert(station.getGuideMode() == "stove", "300 mince must open the stove prompt")

-- Going left does not satisfy a prompt that explicitly points right.
PlayerConfig.activeWorkstation = 3
station.update(false)
assert(not station.hasCompletedStoveGuide())
PlayerConfig.activeWorkstation = 1
station.update(true)
assert(station.getGuideMode() == "stove", "the prompt must return until the stove is visited")

PlayerConfig.activeWorkstation = 2
station.update(false)
assert(station.hasCompletedStoveGuide() and station.getGuideMode() == nil,
    "moving right to the stove must complete the one-time prompt")
PlayerConfig.activeWorkstation = 1
station.update(true)
assert(station.getGuideMode() == nil, "the 300-mince prompt must not repeat")

grinder.hasMeat = false
station.update(true)
assert(station.getGuideMode() == "load",
    "the reusable empty-grinder prompt must still work after the stove prompt")

print("SIMPLIFIED VERSION TESTS PASSED")

playdate.display.setRefreshRate(PlayerConfig.refreshRate)
function playdate.update()
    Juice:update(1 / PlayerConfig.refreshRate)
    playdate.graphics.clear()
    station.draw()
end
