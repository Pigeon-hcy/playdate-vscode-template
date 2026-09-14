-- Stage this main.lua beside source/resource, compile with pdc -k -I source.
-- Assertions run on launch. Demo: A plays the start banner, B the over banner.
import "rushBanner"
import "orderRuntime"
local gfx <const> = playdate.graphics
local cfg <const> = PlayerConfig.rushBanner
local banner <const> = RushBanner

assert(not banner.isActive() and banner.getOverlayAlpha() == 0)
banner.show("start")
assert(banner.isActive() and banner.getMode() == "start" and banner.getOverlayAlpha() == 0)
banner.update(cfg.fadeInDuration / 2)
assert(banner.getOverlayAlpha() == .5, "the white-out snaps in over the short fade")
banner.update(cfg.fadeInDuration / 2)
assert(banner.getOverlayAlpha() == 1)
gfx.clear()
banner.draw()
banner.update(cfg.slamDuration + .001)
gfx.clear()
banner.draw()
assert(gfx.getWorkingImage():sample(2, 2) == gfx.kColorBlack,
    "the impact frame inverts the whole screen")
banner.update(cfg.flashDuration)
gfx.clear()
banner.draw()
assert(gfx.getWorkingImage():sample(2, 2) == gfx.kColorWhite)
local secondLanding = cfg.fadeInDuration + 2 * cfg.slamDuration + cfg.wordGap
banner.update(secondLanding - banner.getTime() + cfg.holdDuration - .01)
assert(banner.isActive() and banner.getOverlayAlpha() == 1, "both words hold on screen")
banner.update(.02)
assert(banner.getOverlayAlpha() < 1, "the hold ends after the configured pause")
gfx.clear()
banner.draw()
banner.update(cfg.fadeOutDuration)
assert(not banner.isActive() and banner.getOverlayAlpha() == 0, "start banner finishes")

banner.show("over")
banner.update(cfg.fadeInDuration + cfg.typeInterval * 5)
gfx.clear()
banner.draw()
assert(banner.isActive() and banner.getOverlayAlpha() == 1)
banner.update(cfg.typeInterval * 7 + cfg.holdDuration + cfg.fadeOutDuration + .01)
assert(not banner.isActive(), "twelve characters, a hold and a fade end the over banner")
banner.show("over")
banner.cancel()
assert(not banner.isActive())

-- The order manager announces both transitions.
local shown = {}
Orders.onRushStart = function() shown[#shown + 1] = "start" end
Orders.onRushEnd = function() shown[#shown + 1] = "over" end
Orders:startRush()
Orders:endRush()
assert(shown[1] == "start" and shown[2] == "over" and #shown == 2)
print("RUSH BANNER TESTS PASSED")

Orders.onRushStart = function() banner.show("start") end
Orders.onRushEnd = function() banner.show("over") end
playdate.display.setRefreshRate(PlayerConfig.refreshRate)
local last = playdate.getCurrentTimeMilliseconds()
function playdate.update()
    local now = playdate.getCurrentTimeMilliseconds()
    banner.update((now - last) / 1000)
    last = now
    if playdate.buttonJustPressed(playdate.kButtonA) then banner.show("start") end
    if playdate.buttonJustPressed(playdate.kButtonB) then banner.show("over") end
    gfx.clear()
    gfx.drawText("RUSH BANNER TESTS PASSED", 12, 60)
    gfx.drawText("A: RUSH START   B: RUSH OVER", 12, 85)
    gfx.fillRect(40, 120, 320, 80)
    banner.draw()
end
