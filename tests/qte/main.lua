-- Stage this main.lua beside source/resource, then compile with pdc -I source.
-- Assertions run on launch and exercise Variant C's real assembly input path.
import "variants/variantC/assemblyWorkstation"

local pd <const> = playdate
local gfx <const> = pd.graphics
local station <const> = AssemblyWorkstation
local assembly <const> = PlayerConfig.assembly

local originalButtonJustPressed <const> = pd.buttonJustPressed
local originalGetCrankChange <const> = pd.getCrankChange
local pressed = {}
local crankChange = 0

pd.buttonJustPressed = function(button)
    return pressed[button] == true
end
pd.getCrankChange = function()
    local change = crankChange
    crankChange = 0
    return change
end

local function input(buttons, crank)
    pressed = {}
    for _, button in ipairs(buttons or {}) do pressed[button] = true end
    crankChange = crank or 0
    station.handleInput()
    Juice:update(.05)
end

PlayerConfig.recipe[1] = {
    "QTE TEST", "P", "L", "T", "K", "O", "E", "M", "B", "A", "S",
}
station.initialize()
Orders:reset()
assembly.currentRecipeIndex = 1
PlayerConfig.patties = 10

assert(station.getQteStep().code == "P")
input({ pd.kButtonA })
assert(#assembly.layers == 0, "a wrong QTE must not place an ingredient")
input({}, 30)
assert(#assembly.layers == 0, "the patty requires a full crank shake")
input({}, 31)
assert(assembly.layers[1] == "P", "the crank shake must place the patty")

input({ pd.kButtonA })
assert(assembly.layers[2] == "L", "A must place lettuce")
input({ pd.kButtonDown })
assert(assembly.layers[3] == "T", "DOWN must place tomato")
input({ pd.kButtonB })
assert(assembly.layers[4] == "K", "B must place pickle")

input({ pd.kButtonA })
Juice:update(assembly.qte.comboWindow + .01)
input({ pd.kButtonDown })
assert(#assembly.layers == 4, "an expired combo must not place onion")
input({ pd.kButtonA })
assert(assembly.layers[5] == "O", "A + DOWN must place onion")

input({ pd.kButtonB })
input({ pd.kButtonDown })
assert(assembly.layers[6] == "E", "B + DOWN must place egg")
input({}, 60)
input({ pd.kButtonDown })
assert(assembly.layers[7] == "M", "crank + DOWN must place mushroom")
input({ pd.kButtonA }, 60)
assert(assembly.layers[8] == "B", "crank + A must place bacon")
input({ pd.kButtonB }, 60)
assert(assembly.layers[9] == "A", "crank + B must place American Cheese")
input({ pd.kButtonA, pd.kButtonB })
assert(assembly.layers[10] == "S", "A + B must place English Cheese")

assert(station.getQteStep().kind == "topBun")
input({ pd.kButtonUp })
assert(not assembly.hasTopBread, "UP alone must not place the top bun")
input({ pd.kButtonA })
assert(assembly.hasTopBread, "UP + A must place the top bun")

Juice:update(1)
assert(station.getQteStep().kind == "serve")
input({ pd.kButtonUp })
assert(not station.isServing(), "UP alone must not serve")
input({ pd.kButtonB })
assert(station.isServing(), "UP + B must serve")

pd.buttonJustPressed = originalButtonJustPressed
pd.getCrankChange = originalGetCrankChange
print("ASSEMBLY QTE TESTS PASSED")

pd.display.setRefreshRate(PlayerConfig.refreshRate)
function pd.update()
    Juice:update(1 / PlayerConfig.refreshRate)
    station.update(false)
    gfx.clear()
    station.draw()
end
