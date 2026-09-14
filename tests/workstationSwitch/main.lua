-- pdc -I source tests/workstationSwitch /tmp/workstation-switch-tests.pdx
-- Open in Playdate Simulator; assertions run once on launch.
import "workstationManager"

local gfx <const> = playdate.graphics
local manager <const> = WorkstationManager
local draws = { 0, 0, 0 }
local updates = { 0, 0, 0 }
local active = {}
local inputs = 0

for index = 1, 3 do
    manager.register(index, {
        usesCrank = index ~= 2,
        draw = function()
            draws[index] += 1
            gfx.clear(index == 2 and gfx.kColorBlack or gfx.kColorWhite)
        end,
        update = function(isActive)
            updates[index] += 1
            active[index] = isActive
        end,
        handleInput = function() inputs += 1 end,
    })
end

assert(not manager.isSwitching())
assert(manager.shouldShowCrankIndicator(true))
assert(manager.switch(1))
assert(PlayerConfig.activeWorkstation == 2)
assert(manager.isSwitching())
assert(draws[1] == 1 and draws[2] == 1 and draws[3] == 0)
assert(not manager.switch(-1), "rapid input must not restart or reverse a transition")
assert(not manager.shouldShowCrankIndicator(true))
manager.handleActiveInput()
assert(inputs == 0, "hidden station must not accept buttons")
manager.updateAll()
for index = 1, 3 do
    assert(updates[index] == 1, "background cooking must keep updating")
    assert(active[index] == false, "hidden stations must not process crank gameplay")
end

manager.drawActive()
assert(gfx.getWorkingImage():sample(200, 120) == gfx.kColorWhite)
manager.updateTransition(.125)
manager.drawActive()
local frame = gfx.getWorkingImage()
assert(frame:sample(50, 120) == gfx.kColorWhite)
assert(frame:sample(350, 120) == gfx.kColorBlack, "right destination enters from right")
manager.updateTransition(.374)
assert(manager.isSwitching(), "transition must last the configured 0.5 seconds")
manager.drawActive()
assert(draws[1] == 1 and draws[2] == 1, "animation must reuse both snapshots")
manager.updateTransition(.002)
assert(not manager.isSwitching())
manager.drawActive()
assert(draws[2] == 2, "destination must resume live rendering")
assert(gfx.getWorkingImage():sample(200, 120) == gfx.kColorBlack)
manager.handleActiveInput()
assert(inputs == 1)
manager.updateAll()
assert(active[2] and not active[1] and not active[3])

assert(manager.switch(-1))
manager.updateTransition(.125)
manager.drawActive()
frame = gfx.getWorkingImage()
assert(frame:sample(50, 120) == gfx.kColorWhite, "left destination enters from left")
assert(frame:sample(350, 120) == gfx.kColorBlack)
manager.updateTransition(.375)
assert(not manager.isSwitching(), "exact duration must finish")
assert(PlayerConfig.activeWorkstation == 1)
assert(manager.switch(-1))
assert(PlayerConfig.activeWorkstation == 3, "left wraparound")
manager.updateTransition(1)
assert(not manager.isSwitching(), "long frames must finish cleanly")
assert(manager.switch(1))
assert(PlayerConfig.activeWorkstation == 1, "right wraparound")
manager.updateTransition(.5)
assert(not manager.switch(0))
assert(not manager.isSwitching())
assert(manager.shouldShowCrankIndicator(true))
assert(not manager.shouldShowCrankIndicator(false))

print("WORKSTATION SWITCH TESTS PASSED")
function playdate.update()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("Workstation switch tests passed", 20, 100)
end
