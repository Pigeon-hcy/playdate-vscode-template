import "CoreLibs/graphics"
import "variants/variantA/scoring"

-- Fixed HUD beside the order holder, above the ingredient wheel. Visible on
-- every station, including while station snapshots slide beneath it.
ComboUI = {}
local gfx <const> = playdate.graphics
local font <const> = gfx.font.new("/System/Fonts/Roobert-10-Bold") or gfx.getSystemFont()
local previous, countText, multiplierText = nil, "", ""

function ComboUI.draw()
    if previous ~= PlayerConfig.combo then
        previous = PlayerConfig.combo
        countText = "COMBO " .. previous
        multiplierText = string.format("x%.1f", Scoring.comboMultiplier())
    end
    local boosted = Scoring.comboMultiplier() > 1
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.setColor(boosted and gfx.kColorBlack or gfx.kColorWhite)
    gfx.fillRoundRect(288, 1, 108, 32, 3)
    gfx.setClipRect(290, 2, 104, 30)
    gfx.setImageDrawMode(boosted and gfx.kDrawModeFillWhite or gfx.kDrawModeCopy)
    font:drawText(countText, 294, 3)
    font:drawText(multiplierText, 294, 17)
    gfx.popContext()
end
