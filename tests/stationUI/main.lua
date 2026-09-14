-- Stage this file beside source/resource and compile with pdc -k -I source.
-- Assertions run when launched in the simulator; A/RIGHT previews stations.
import "grinderWorkstation"
import "fryingWorkstation"
import "assemblyWorkstation"

local gfx <const> = playdate.graphics
local cost <const> = PlayerConfig.frying.pattyCost
local warning <const> = SupplyWarning
PlayerConfig.activeWorkstation = 2
PlayerConfig.mincedMeat = 0
PlayerConfig.frying.slots = {}
warning.update()
assert(not warning.isVisible(), "empty stock must remain quiet without input")
assert(not FryingWorkstation.placePatty())
assert(warning.isVisible(), "failed mince consumption opens the prompt")
assert(PlayerConfig.mincedMeat == 0 and next(PlayerConfig.frying.slots) == nil)
Juice:update(.3)
assert(not FryingWorkstation.placePatty(), "repeated attempts must not consume anything")
assert(warning.isVisible())
PlayerConfig.mincedMeat = cost
warning.update()
Juice:update(PlayerConfig.burstDialog.exitDuration + .01)
assert(not warning.isVisible(), "enough supply dismisses the prompt")
assert(FryingWorkstation.placePatty(), "exact price must succeed")
warning.update()
assert(PlayerConfig.mincedMeat == 0 and not warning.isVisible(),
    "successfully spending the last mince must not warn")
PlayerConfig.mincedMeat = cost - 1
assert(not FryingWorkstation.placePatty(), "one below the price must fail")
assert(warning.isVisible())
PlayerConfig.activeWorkstation = 1
warning.update()
PlayerConfig.activeWorkstation = 2
warning.update()
assert(not warning.isVisible(), "returning to an empty station must stay quiet")

PlayerConfig.activeWorkstation = 3
PlayerConfig.patties = 0
PlayerConfig.assembly.layers = {}
PlayerConfig.assembly.layerRepeats = {}
PlayerConfig.assembly.hasTopBread = false
warning.update()
assert(not warning.isVisible())
assert(AssemblyWorkstation.addIngredient("L"))
assert(not warning.isVisible(), "unrelated ingredients must not request patties")
assert(not AssemblyWorkstation.addIngredient("P"))
assert(warning.isVisible(), "attempting to add a missing patty opens the prompt")
assert(#PlayerConfig.assembly.layers == 1 and PlayerConfig.patties == 0)
PlayerConfig.activeWorkstation = 2
warning.update()
PlayerConfig.activeWorkstation = 3
warning.update()
assert(not warning.isVisible())
PlayerConfig.assembly.hasTopBread = true
assert(not AssemblyWorkstation.addIngredient("P"))
assert(not warning.isVisible(), "a closed burger must not ask for more patties")
PlayerConfig.assembly.hasTopBread = false
PlayerConfig.patties = 1
assert(AssemblyWorkstation.addIngredient("P"))
warning.update()
assert(PlayerConfig.patties == 0 and not warning.isVisible())

-- Both shortage prompts expire, refresh on another press, and can reopen
-- during or after the exit. Repeated updates with a frozen clock do not age them.
for _, kind in ipairs({ "mince", "patty" }) do
    PlayerConfig.activeWorkstation = 1
    warning.update()
    PlayerConfig.activeWorkstation = kind == "mince" and 2 or 3
    PlayerConfig.mincedMeat, PlayerConfig.patties = 0, 0
    local lifetime = PlayerConfig.supplyWarning.lifetime
    assert(warning.request(kind))
    for _ = 1, 120 do warning.update() end
    assert(warning.isVisible(), "paused time must not expire the prompt")
    Juice:update(lifetime - .1)
    warning.update()
    assert(warning.request(kind), "another failed press refreshes its lifetime")
    Juice:update(.2)
    warning.update()
    Juice:update(PlayerConfig.burstDialog.exitDuration + .01)
    warning.update()
    assert(warning.isVisible(), "the old deadline must not hide a refreshed prompt")
    Juice:update(lifetime)
    warning.update()
    assert(warning.isVisible(), "expiry should play the pop-away animation")
    assert(warning.request(kind), "a press during exit must reopen the prompt")
    Juice:update(lifetime + .01)
    warning.update()
    Juice:update(PlayerConfig.burstDialog.exitDuration + .01)
    warning.update()
    assert(not warning.isVisible(), "missing stock must not prevent expiry")
    warning.update()
    assert(not warning.isVisible(), "empty stock must not reopen an expired prompt")
    assert(warning.request(kind) and warning.isVisible(), "a fresh press can reopen it")
end

local font <const> = gfx.font.new("/System/Fonts/Roobert-10-Bold")
for _, recipe in ipairs(PlayerConfig.recipe) do
    local image, truncated = gfx.imageWithText(recipe[1], 92, 32,
        gfx.kColorClear, 0, "...", nil, font)
    assert(image and not truncated, "full recipe title must fit: " .. recipe[1])
    local w, h = image:getSize()
    assert(w <= 92 and h <= 32)
end
print("STATION UI TESTS PASSED")
PlayerConfig.activeWorkstation = 1
PlayerConfig.mincedMeat = 120
local stations <const> = { GrinderWorkstation, FryingWorkstation, AssemblyWorkstation }
function playdate.update()
    Juice:update(1 / PlayerConfig.refreshRate)
    if playdate.buttonJustPressed(playdate.kButtonRight) then
        PlayerConfig.activeWorkstation = PlayerConfig.activeWorkstation % 3 + 1
    end
    if playdate.buttonJustPressed(playdate.kButtonA) then
        if PlayerConfig.activeWorkstation == 2 then
            PlayerConfig.mincedMeat = 0
            FryingWorkstation.placePatty()
        elseif PlayerConfig.activeWorkstation == 3 then
            AssemblyWorkstation.addIngredient("P")
        end
    end
    warning.update()
    gfx.clear(gfx.kColorWhite)
    stations[PlayerConfig.activeWorkstation].draw()
    warning.draw()
end
