-- Stage this main.lua beside source/resource, then compile with pdc -I source.
-- Assertions run on launch; A reloads, B toggles automatic grinding in the demo.
import "grinderWorkstation"

local gfx <const> = playdate.graphics
local grinder <const> = PlayerConfig.grinder
local station <const> = GrinderWorkstation
-- Keep these visual checks on the two safe pieces and the start of piece 3.
-- The jam suite separately covers every target and the interrupted yield.
station.randomInt = function(minimum, maximum)
    if minimum == grinder.jam.minMeatCount and maximum == grinder.jam.maxMeatCount then
        return maximum
    end
    return minimum
end
Juice:verticalShake("frying.patty.1", 1)
station.initialize()
assert(grinder.hasMeat)
local seatedY = station.getDisplayedMeatY()
assert(seatedY > 0, "meat must appear at the hopper, not above the screen")
assert(Juice.effects["grinder.meat"].vibration.active)
assert(Juice.effects["grinder.machine"].vibration.active)
assert(not station.loadNewMeat(), "occupied hopper cannot be refilled")
Juice:update(.025)
assert(math.abs(Juice:getTransform("grinder.meat").offsetY) > 0)
assert(math.abs(Juice:getTransform("grinder.machine").offsetY) > 0)
assert(station.getDisplayedMeatY() == seatedY, "shake cannot alter feed position")
station.draw()
local stock = PlayerConfig.mincedMeat
station.processCrank(360)
assert(PlayerConfig.mincedMeat == stock + grinder.meatPerCrankTurn,
    "grinding must work immediately while loading feedback plays")
assert(station.getDisplayedMeatY() > seatedY, "crank still feeds meat into hopper")
local feedY = station.getDisplayedMeatY()
Juice:update(.5)
assert(Juice:getTransform("grinder.meat").offsetY == 0)
assert(Juice:getTransform("grinder.machine").offsetY == 0)
assert(station.getDisplayedMeatY() == feedY, "settling must not move the feed")
local totalYield = grinder.totalYield
station.processCrank(360 * totalYield / grinder.meatPerCrankTurn)
assert(not grinder.hasMeat)
assert(PlayerConfig.mincedMeat == stock + totalYield, "yield remains capped")
assert(Juice.effects["grinder.meat"] == nil, "consumed meat releases its effect")
assert(Juice.effects["frying.patty.1"] ~= nil, "other stations keep their effects")
assert(#grinder.outputParticles <= grinder.maxOutputParticles)
assert(station.loadNewMeat())
assert(station.getDisplayedMeatY() == seatedY)
assert(Juice.effects["grinder.meat"].vibration.active, "refilling replays feedback")

Juice:update(.5)
station.processCrank(1)
assert(Juice.effects["grinder.meat"].vibration.active,
    "even crank movement too small to produce mince must refresh the shake")
local movingFrames = 0
local movingMachineFrames = 0
for i = 1, 30 do
    Juice:update(1 / 30)
    station.processCrank(3)
    if math.abs(Juice:getTransform("grinder.meat").offsetY) >= .5 then
        movingFrames += 1
    end
    if math.abs(Juice:getTransform("grinder.machine").offsetY) >= .5 then
        movingMachineFrames += 1
    end
end
assert(movingFrames > 15, "meat must keep visibly shaking beyond the initial load effect")
assert(movingMachineFrames > 10, "machine must keep vibrating during sustained grinding")
Juice:update(grinder.grindShakeDuration + .01)
assert(Juice:getTransform("grinder.meat").offsetY == 0,
    "stopping must settle quickly without residual displacement")
assert(Juice:getTransform("grinder.machine").offsetY == 0 and
    Juice:getTransform("grinder.machine").offsetX == 0, "machine must settle in both axes")

grinder.outputParticles = {}
for i = 1, 4 do station.processCrank(6) end
-- Compare the same emitter now that some crumbs are diverted to the inlet.
local function firstOutlet(from)
    for i = from, #grinder.outputParticles do
        if grinder.outputParticles[i].source == "outlet" then
            return grinder.outputParticles[i]
        end
    end
end
local slowParticle = firstOutlet(1)
if slowParticle == nil then
    for i = 1, 4 do station.processCrank(6) end
    slowParticle = firstOutlet(1)
end
assert(slowParticle ~= nil)
local oldCount = #grinder.outputParticles
station.processCrank(48)
local fastParticle = firstOutlet(oldCount + 1)
assert(fastParticle.velocityX > slowParticle.velocityX,
    "faster cranking must launch mince with greater forward force")
assert(fastParticle.velocityY < slowParticle.velocityY,
    "a stronger launch must have more upward lift")
local x, vx, vy = fastParticle.x, fastParticle.velocityX, fastParticle.velocityY
station.update(false)
assert(fastParticle.x > x and fastParticle.velocityX < vx,
    "the initial impulse must travel then lose speed")
assert(fastParticle.velocityY > vy, "gravity must bend the spray downward")
station.processCrank(100000)
assert(#grinder.outputParticles <= grinder.maxOutputParticles,
    "fast bursts must respect the existing particle budget")
for i = 1, grinder.particleLifeFrames do station.update(false) end
assert(#grinder.outputParticles == 0, "spent spray must be retired")
assert(not grinder.hasMeat and Juice.effects["grinder.meat"] == nil)
station.loadNewMeat()

grinder.outputParticles = {}
local beforeYield = PlayerConfig.mincedMeat
station.processCrank(72)
assert(PlayerConfig.mincedMeat == beforeYield + 3,
    "diverting visual crumbs must not divert inventory")
assert(#grinder.outputParticles == 3, "inlet crumbs replace output crumbs, not add to them")
local hopperParticle = grinder.outputParticles[3]
assert(hopperParticle.source == "hopper")
assert(grinder.outputParticles[1].source == "outlet" and grinder.outputParticles[2].source == "outlet")
assert(hopperParticle.x < grinder.outputParticles[1].x and
    hopperParticle.y < grinder.outputParticles[1].y, "inlet is above and left of the outlet")
assert(hopperParticle.velocityY < 0, "inlet crumbs launch upward")
local inletY = hopperParticle.y
local machineRecoil = Juice.effects["grinder.machine"]
Juice:update(.02)
assert(math.abs(Juice:getTransform("grinder.machine").offsetX) > 0,
    "mince output must kick the machine sideways")
local recoilElapsed = machineRecoil.elapsed
station.processCrank(72)
assert(machineRecoil.elapsed == recoilElapsed, "rapid production must let the recoil play")
assert(grinder.outputParticles[6].source == "hopper")
assert(hopperParticle.velocityX * grinder.outputParticles[6].velocityX < 0,
    "inlet spray must alternate sides")
station.update(false)
assert(hopperParticle.y < inletY)
local stoppedCount = #grinder.outputParticles
station.processCrank(0)
assert(#grinder.outputParticles == stoppedCount, "no new spray when stopped")
for i = 1, grinder.particleLifeFrames do station.update(false) end
assert(#grinder.outputParticles == 0, "both emitters must clean up their particles")
Juice:update(.5)
assert(Juice:getTransform("grinder.machine").offsetX == 0 and
    Juice:getTransform("grinder.machine").offsetY == 0)
print("GRINDER JUICE TESTS PASSED")
station.randomInt = math.random

playdate.display.setRefreshRate(PlayerConfig.refreshRate)
local last = playdate.getCurrentTimeMilliseconds()
local autoGrind = false
function playdate.update()
    local now = playdate.getCurrentTimeMilliseconds()
    Juice:update((now - last) / 1000)
    last = now
    if playdate.buttonJustPressed(playdate.kButtonA) then
        grinder.hasMeat = false
        station.loadNewMeat()
    end
    if playdate.buttonJustPressed(playdate.kButtonB) then
        autoGrind = not autoGrind
    end
    station.handleInput()
    station.update(true)
    if autoGrind then
        if not grinder.hasMeat then station.loadNewMeat() end
        station.processCrank(12)
    end
    gfx.clear()
    station.draw()
    gfx.drawText("TEST PASS  A: LOAD  B: AUTO", 12, 32)
end
