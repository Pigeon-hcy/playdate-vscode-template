-- Stage beside source/resource; compile with pdc -k -I source.
-- A cycles single ingredients. B cycles full recipes. UP toggles the top bun.
import "assemblyWorkstation"

local gfx <const> = playdate.graphics
local station <const> = AssemblyWorkstation
local assembly <const> = PlayerConfig.assembly
station.initialize()
Orders:reset()
assembly.layers = {}
assembly.currentRecipeIndex = 1
local contact = station.getTopLayerBottom()
local _, _, bottom = station.getStackLayout(PlayerConfig.recipe[1])
assert(contact == bottom - assembly.breadThickness.bottom)
for index = 1, #PlayerConfig.recipe do
    assembly.currentRecipeIndex = index
    assert(station.getTopLayerBottom() == contact,
        "changing recipes must not lower the first ingredient into the bun")
end

-- Even spacing compression must leave the bun's pale support plane intact.
local tall = { "TALL STACK" }
for index = 1, 30 do tall[#tall + 1] = "P" end
PlayerConfig.recipe[#PlayerConfig.recipe + 1] = tall
assembly.currentRecipeIndex = #PlayerConfig.recipe
local _, scale = station.getStackLayout(tall)
assert(scale > 0 and scale < 1)
assert(station.getTopLayerBottom() == contact, "tall stacks must not compress the bun rim")
assembly.layers = { "P" }
assert(math.abs(station.getTopLayerBottom() -
    (contact - assembly.spriteThickness.P * scale)) < .001)
table.remove(PlayerConfig.recipe)
print("ASSEMBLY ALIGNMENT TESTS PASSED")

local ingredientIndex = 3 -- Start on the previously oversized tomato.
local recipeIndex = 1
local function showSingle()
    station.initialize()
    assembly.currentRecipeIndex = 1
    PlayerConfig.patties = 99
    station.addIngredient(assembly.ingredientCodes[ingredientIndex])
    Juice:clear()
end
showSingle()
playdate.display.setRefreshRate(PlayerConfig.refreshRate)
function playdate.update()
    if playdate.buttonJustPressed(playdate.kButtonA) then
        ingredientIndex = ingredientIndex % #assembly.ingredientCodes + 1
        showSingle()
    elseif playdate.buttonJustPressed(playdate.kButtonB) then
        station.initialize()
        assembly.currentRecipeIndex = recipeIndex
        PlayerConfig.patties = 99
        for index = 2, #PlayerConfig.recipe[recipeIndex] do
            station.addIngredient(PlayerConfig.recipe[recipeIndex][index])
        end
        assembly.hasTopBread = true
        recipeIndex = recipeIndex % #PlayerConfig.recipe + 1
        Juice:clear()
    elseif playdate.buttonJustPressed(playdate.kButtonUp) then
        assembly.hasTopBread = not assembly.hasTopBread
    end
    gfx.clear()
    station.draw()
end
