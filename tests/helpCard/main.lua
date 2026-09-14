-- Stage this main.lua beside source/resource, compile with pdc -k -I source.
-- Assertions run on launch. Demo: LEFT/RIGHT pick a station, A opens/closes.
import "grinderWorkstation"
import "fryingWorkstation"
import "assemblyWorkstation"
import "helpCard"
local gfx <const> = playdate.graphics
local cfg <const> = PlayerConfig.helpCard
local card <const> = HelpCard
local stations <const> = { GrinderWorkstation, FryingWorkstation, AssemblyWorkstation }

-- Every station documents its controls in the shape the card expects, and
-- every card fits on the screen once it has settled.
for number, station in ipairs(stations) do
    local help = station.help
    assert(type(help) == "table" and type(help.title) == "string" and
        type(help.summary) == "string", "station " .. number .. " needs a help table")
    assert(#help.controls >= 1)
    for _, control in ipairs(help.controls) do
        assert(type(control[1]) == "string" and type(control[2]) == "string")
        -- drawText treats these as bold and italic markers.
        assert(not control[2]:find("[*_]"), "no formatting markers in help text")
    end
    assert(not card.hasSeen(number))
    card.show(help, number)
    assert(card.hasSeen(number), "showing a card marks its station as seen")
    card.update(cfg.enterDuration)
    local restY = card.getY()
    assert(restY >= 0, "card " .. number .. " must fit on the screen")
    gfx.clear()
    card.draw()
    card.close()
    card.update(cfg.exitDuration)
end

card.resetSeen()
assert(not card.hasSeen(1))
assert(not card.isOpen() and not card.isVisible() and card.getY() == nil)
assert(not card.close(), "nothing to close")
card.show(GrinderWorkstation.help, 1)
assert(card.isOpen() and card.isVisible())
assert(card.getY() >= PlayerConfig.screenHeight, "the card starts below the screen")
card.update(cfg.enterDuration * .7)
local overshoot = card.getY()
card.update(cfg.enterDuration * .3)
local restY = card.getY()
assert(overshoot < restY, "the card springs past its resting place")
card.update(5)
assert(card.getY() == restY and card.isOpen(), "and waits there until dismissed")
assert(card.close() and not card.isOpen(), "closing unfreezes the game at once")
assert(card.isVisible(), "while the card is still falling away")
card.update(cfg.exitDuration / 2)
assert(card.getY() > restY)
card.update(cfg.exitDuration / 2)
assert(not card.isVisible() and card.getY() == nil)
assert(not card.handleInput(), "input does nothing with no card open")
print("HELP CARD TESTS PASSED")

GrinderWorkstation.initialize()
AssemblyWorkstation.initialize()
local number = 1
playdate.display.setRefreshRate(PlayerConfig.refreshRate)
local last = playdate.getCurrentTimeMilliseconds()
function playdate.update()
    local now = playdate.getCurrentTimeMilliseconds()
    local dt = (now - last) / 1000
    last = now
    card.update(dt)
    if card.isOpen() then
        card.handleInput()
    else
        if playdate.buttonJustPressed(playdate.kButtonLeft) then number = (number + 1) % 3 + 1 end
        if playdate.buttonJustPressed(playdate.kButtonRight) then number = number % 3 + 1 end
        if playdate.buttonJustPressed(playdate.kButtonA) then card.show(stations[number].help, number) end
    end
    gfx.clear()
    stations[number].draw()
    card.draw()
end
