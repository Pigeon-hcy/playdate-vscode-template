-- pdc -k -I source tests/fryingWarning /tmp/frying-warning-tests.pdx
-- Assertions run on launch. LEFT/RIGHT changes the demo's station;
-- A restarts its countdown and B clears the danger.
import "fryingWarning"

local gfx <const> = playdate.graphics
local warning <const> = FryingWarning
local frying <const> = PlayerConfig.frying
local burnAt <const> = frying.rawDurationFrames + frying.cookedDurationFrames
local leadFrames <const> = frying.warning.leadSeconds * PlayerConfig.refreshRate

frying.slots = {}
warning.update()
assert(warning.getDanger() == nil and not warning.isVisible())
assert(warning.getDirection(1) == 1)
assert(warning.getDirection(3) == -1)
assert(warning.getDirection(2) == 0)

frying.slots[1] = { state = "cooked", elapsedFrames = burnAt - leadFrames - 1 }
warning.update()
assert(warning.getMode() == nil, "must not warn before the lead window")
frying.slots[1].elapsedFrames += 1
warning.update()
assert(warning.getMode() == "soon", "exact lead boundary starts the warning")
local seconds, slot = warning.getDanger()
assert(seconds == frying.warning.leadSeconds and slot == 1)
Juice:update(.1)
local dx, dy = warning.getShake()
local frozenX, frozenY = warning.getShake()
assert(dx == frozenX and dy == frozenY, "drawing must not advance a frozen alert")
assert(math.abs(dx) <= frying.warning.maxShake and math.abs(dy) <= frying.warning.maxShake)

frying.slots[2] = { state = "cooked", elapsedFrames = burnAt - 1 }
seconds, slot = warning.getDanger()
assert(slot == 2, "nearest burn wins even if it is in a later slot")
frying.slots[2].elapsedFrames = burnAt
frying.slots[2].state = "burning"
warning.update()
assert(warning.getMode() == "fire", "warning persists when the meat catches fire")
frying.slots[2].animation = "rising"
warning.update()
assert(warning.getMode() == "soon", "discarded meat must not hide another urgent patty")
frying.slots[1].animation = "rising"
warning.update()
assert(warning.getMode() == nil and warning.isVisible(), "last collection starts the exit")
Juice:update(PlayerConfig.burstDialog.exitDuration + .01)
assert(not warning.isVisible(), "empty/rising slots must not leave a stale alert")

local function restart()
    frying.slots = { { state = "cooked", elapsedFrames = burnAt - leadFrames - 30 } }
    warning.update()
end
restart()
PlayerConfig.activeWorkstation = 1
print("FRYING WARNING TESTS PASSED")

playdate.display.setRefreshRate(PlayerConfig.refreshRate)
local last = playdate.getCurrentTimeMilliseconds()
function playdate.update()
    local now = playdate.getCurrentTimeMilliseconds()
    Juice:update(math.max(0, now - last) / 1000)
    last = now
    if playdate.buttonJustPressed(playdate.kButtonLeft) then
        PlayerConfig.activeWorkstation = (PlayerConfig.activeWorkstation - 2) % 3 + 1
    elseif playdate.buttonJustPressed(playdate.kButtonRight) then
        PlayerConfig.activeWorkstation = PlayerConfig.activeWorkstation % 3 + 1
    end
    if playdate.buttonJustPressed(playdate.kButtonA) then restart() end
    if playdate.buttonJustPressed(playdate.kButtonB) then frying.slots = {} end
    local patty = frying.slots[1]
    if patty then
        patty.elapsedFrames += 1
        if patty.elapsedFrames >= burnAt then patty.state = "burning" end
    end
    warning.update()
    gfx.clear(gfx.kColorWhite)
    gfx.drawText("FRYING WARNING TESTS PASSED", 12, 10)
    gfx.drawText("STATION " .. PlayerConfig.activeWorkstation, 12, 34)
    gfx.drawText("LEFT/RIGHT: STATION   A: RESTART", 12, 212)
    warning.draw()
end
