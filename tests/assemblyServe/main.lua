-- Stage this main.lua beside source/resource, then compile with pdc -I source.
-- Assertions run on launch. Demo: A builds a correct burger; UP serves it.
import "assemblyWorkstation"
local gfx <const> = playdate.graphics
local assembly <const> = PlayerConfig.assembly
local station <const> = AssemblyWorkstation
local function step(dt)
    Juice:update(dt)
    Orders:update(dt)
    station.update(false)
end

station.initialize()
Orders:reset()
PlayerConfig.patties = 10
assembly.currentRecipeIndex = 1
assert(station.serveBurger() == nil, "an open burger cannot be served")
assert(station.addIngredient("P"))
assert(station.addIngredient("A"))
assert(station.pressUp() == "closed")
assert(station.pressUp() == "animating", "closing feedback must finish first")
step(.3)
Juice:verticalShake("grinder.machine", 1)
local oldLayers = assembly.layers
local oldRecipe = assembly.currentRecipeIndex
local oldScore = PlayerConfig.score
local oldPatties = PlayerConfig.patties
local points = Scoring.burgerPoints({ "P", "A" },
    Orders.pending[1].expiresAt - Orders.time, false)
assert(station.pressUp() == "correct")
assert(station.isServing())
assert(PlayerConfig.score == oldScore + points)
assert(assembly.layers == oldLayers and assembly.hasTopBread,
    "the complete burger must remain intact during exit")
assert(assembly.currentRecipeIndex == oldRecipe)
assert(station.getServeOffsetY() == 0)
assert(station.serveBurger() == nil and station.pressUp() == "animating")
assert(PlayerConfig.score == oldScore + points, "repeated serve must not score twice")
assert(not station.addIngredient("P") and PlayerConfig.patties == oldPatties)
assert(not station.startWheelTurn(1))
step(assembly.serveOutDuration / 2)
assert(station.getServeOffsetY() < 0)
assert(assembly.layers == oldLayers and #assembly.layers == 2 and assembly.hasTopBread)
gfx.clear()
station.draw()
step(assembly.serveOutDuration / 2 + .001)
assert(station.isServing() and #assembly.layers == 0 and not assembly.hasTopBread)
assert(station.getServeOffsetY() > 0, "new bottom bun must start below its resting position")
assert(not station.addIngredient("P"), "new bun must arrive before accepting ingredients")
assert(Juice.effects["grinder.machine"] ~= nil, "serving may only retire assembly effects")
local belowOffset = station.getServeOffsetY()
step(assembly.breadInDuration / 2)
assert(station.getServeOffsetY() > 0 and station.getServeOffsetY() < belowOffset)
gfx.clear()
station.draw()
step(assembly.breadInDuration / 2)
assert(not station.isServing() and station.getServeOffsetY() == 0)
assert(station.addIngredient("P") and PlayerConfig.patties == oldPatties - 1)

station.initialize()
Orders:reset()
assembly.currentRecipeIndex = 1
assert(station.pressUp() == "closed")
step(.3)
assert(station.pressUp() == "wrong")
assert(station.isServing() and PlayerConfig.score == oldScore + points - 500)
assert(Orders:count() == 0, "a wrong burger still consumes the order")
step(1)
assert(not station.isServing() and station.getServeOffsetY() == 0,
    "both phases must finish while offscreen or after a long frame")
assert(not assembly.hasTopBread and #assembly.layers == 0)
assert(station.pressUp() == "closed")
step(.3)
Orders:addOrder(Orders.time)
assert(station.serveBurger() == false and station.isServing())
station.initialize()
assert(not station.isServing() and station.getServeOffsetY() == 0,
    "initialization must cancel an unfinished delivery")
print("ASSEMBLY SERVE TESTS PASSED")

PlayerConfig.patties = 99
playdate.display.setRefreshRate(PlayerConfig.refreshRate)
local last = playdate.getCurrentTimeMilliseconds()
function playdate.update()
    local now = playdate.getCurrentTimeMilliseconds()
    Juice:update((now - last) / 1000)
    last = now
    if playdate.buttonJustPressed(playdate.kButtonA) and not station.isServing() then
        station.initialize()
        local recipe = PlayerConfig.recipe[assembly.currentRecipeIndex]
        for i = 2, #recipe do station.addIngredient(recipe[i]) end
        station.pressUp()
    end
    if playdate.buttonJustPressed(playdate.kButtonUp) then station.pressUp() end
    station.update(true)
    gfx.clear()
    station.draw()
end
