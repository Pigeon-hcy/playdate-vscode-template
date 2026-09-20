-- Stage beside source/resource; pdc -k -I source <stage> <output.pdx>.
-- Real SDK integration assertions plus HUD demo: LEFT/RIGHT switch stations,
-- A serves a correct order, B serves a wrong one, UP expires an order.
import "variants/variantA/assemblyWorkstation"
import "variants/variantA/grinderWorkstation"
import "variants/variantA/fryingWorkstation"
import "variants/variantA/workstationManager"
import "variants/variantA/orderUI"
import "variants/variantA/comboUI"
import "variants/variantA/scorePopup"

local gfx <const> = playdate.graphics
local assembly <const> = PlayerConfig.assembly
local station <const> = AssemblyWorkstation
local function serve(correct)
    station.initialize()
    Orders:reset()
    PlayerConfig.patties = 99
    assembly.currentRecipeIndex = 1
    if correct then
        assert(station.addIngredient("P"))
        assert(station.addIngredient("A"))
    end
    assert(station.pressUp() == "closed")
    Juice:update(.3)
    assert(station.serveBurger() == correct)
end

for count = 1, 20 do
    local before = PlayerConfig.score
    serve(true)
    local expected = math.floor(1120 * (1 + math.floor(count / 5) * .1) + .5)
    assert(PlayerConfig.combo == count and PlayerConfig.score == before + expected)
    -- Repeated submission during the outgoing animation must not count twice.
    assert(station.serveBurger() == nil and PlayerConfig.combo == count)
end
serve(false)
assert(PlayerConfig.combo == 0 and Scoring.comboMultiplier() == 1)
serve(true)
assert(PlayerConfig.combo == 1)
station.initialize()
Orders:reset()
assert(station.serveBurger() == nil and PlayerConfig.combo == 1)
Orders:update(60)
assert(PlayerConfig.combo == 0)

-- Burnt food is a station incident, not an order failure.
PlayerConfig.combo = 5
PlayerConfig.frying.slots[1] = {
    elapsedFrames = PlayerConfig.frying.rawDurationFrames + PlayerConfig.frying.cookedDurationFrames - 1,
    state = "cooked", animationFrame = 0,
}
FryingWorkstation.update(false)
assert(PlayerConfig.frying.slots[1].state == "burning" and PlayerConfig.combo == 5)
PlayerConfig.frying.slots = {}
FryingWorkstation.update(false)

GrinderWorkstation.initialize()
WorkstationManager.register(1, GrinderWorkstation)
WorkstationManager.register(2, FryingWorkstation)
WorkstationManager.register(3, AssemblyWorkstation)
PlayerConfig.activeWorkstation = 3
PlayerConfig.score, PlayerConfig.combo = 0, 4
Scoring.onChange = function(delta) ScorePopup.show(delta) end
serve(true)
Juice:update(1)
station.update(false)
print("COMBO INTEGRATION TESTS PASSED: real deliveries, repeat input, wrong orders, expiry and burns")

playdate.display.setRefreshRate(30)
function playdate.update()
    Juice:update(1 / 30)
    WorkstationManager.updateTransition(1 / 30)
    ScorePopup.update(1 / 30)
    station.update(false)
    if playdate.buttonJustPressed(playdate.kButtonLeft) then WorkstationManager.switch(-1) end
    if playdate.buttonJustPressed(playdate.kButtonRight) then WorkstationManager.switch(1) end
    if playdate.buttonJustPressed(playdate.kButtonA) then serve(true) end
    if playdate.buttonJustPressed(playdate.kButtonB) then serve(false) end
    if playdate.buttonJustPressed(playdate.kButtonUp) then
        Orders:reset()
        Orders:update(60)
    end
    gfx.clear()
    WorkstationManager.drawActive()
    OrderUI.draw()
    ComboUI.draw()
    ScorePopup.draw()
end
