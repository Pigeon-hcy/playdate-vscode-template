-- Stage this main.lua beside source/resource, compile with pdc -k -I source.
-- Assertions run on launch. Demo: A shows a gain, B shows a loss.
import "scorePopup"
import "scoring"
local gfx <const> = playdate.graphics
local cfg <const> = PlayerConfig.scorePopup
local popup <const> = ScorePopup

assert(not popup.isActive() and popup.getY() == nil)
popup.show(970)
assert(popup.isActive())
local startY = popup.getY()
assert(startY >= PlayerConfig.screenHeight, "the pill starts below the screen")
popup.update(cfg.riseDuration * .7)
local overshootY = popup.getY()
popup.update(cfg.riseDuration * .3)
local restY = popup.getY()
assert(overshootY < restY, "the pill overshoots its resting height on the way up")
assert(restY < PlayerConfig.screenHeight and restY > PlayerConfig.screenHeight - 60)
gfx.clear()
popup.draw()
popup.update(cfg.holdDuration)
assert(popup.getY() == restY, "the pill rests for the hold")
popup.update(cfg.exitDuration / 2)
assert(popup.getY() > restY, "then drops away")
popup.update(cfg.exitDuration / 2 + .001)
assert(not popup.isActive(), "and disappears")
popup.show(-200)
gfx.clear()
popup.draw()
popup.show(1185)
assert(popup.isActive(), "a new change restarts the pill")

-- Every scoring path announces its change.
local changes = {}
Scoring.onChange = function(delta) changes[#changes + 1] = delta end
PlayerConfig.score = 0
Scoring.awardBurger({ "P", "A" }, 45, false)
Scoring.penalizeWrong()
Scoring.penalizeMissed()
assert(changes[1] == 970 and changes[2] == -500 and changes[3] == -800)
print("SCORE POPUP TESTS PASSED")

Scoring.onChange = function(delta) popup.show(delta) end
playdate.display.setRefreshRate(PlayerConfig.refreshRate)
local last = playdate.getCurrentTimeMilliseconds()
function playdate.update()
    local now = playdate.getCurrentTimeMilliseconds()
    popup.update((now - last) / 1000)
    last = now
    if playdate.buttonJustPressed(playdate.kButtonA) then Scoring.awardBurger({ "P", "A" }, 45, false) end
    if playdate.buttonJustPressed(playdate.kButtonB) then Scoring.penalizeWrong() end
    gfx.clear()
    gfx.drawText("SCORE POPUP TESTS PASSED", 12, 60)
    gfx.drawText("A: +970   B: -500   SCORE " .. PlayerConfig.score, 12, 85)
    popup.draw()
end
