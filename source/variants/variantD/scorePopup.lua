import "CoreLibs/graphics"
import "variants/variantD/playerConfig"

-- A pill with the last score change that springs up from the bottom edge,
-- rests for a moment and drops away. Drawn over every station. The label is
-- baked when shown (once per score change), so each frame is one blit.
ScorePopup = {}

local gfx <const> = playdate.graphics
local cfg <const> = PlayerConfig.scorePopup
local font <const> = gfx.font.new(cfg.fontPath) or gfx.getSystemFont()
local screenWidth <const> = PlayerConfig.screenWidth
local screenHeight <const> = PlayerConfig.screenHeight

local label = nil
local width, height = 0, 0
local time = 0
local endsAt = 0

local function easeOutBack(t)
    local u = t - 1
    return 1 + 2.70158 * u * u * u + 1.70158 * u * u
end

function ScorePopup.isActive()
    return label ~= nil
end

function ScorePopup.show(delta)
    local negative = delta < 0
    local text = (negative and "-" or "+") .. math.floor(math.abs(delta) + .5)
    local base = assert(gfx.imageWithText(text, font:getTextWidth(text) + 2,
        font:getHeight() + 2, nil, nil, nil, nil, font))
    local textWidth, textHeight = base:getSize()
    width = textWidth + 2 * cfg.paddingX
    height = textHeight + 2 * cfg.paddingY
    label = gfx.image.new(width, height, gfx.kColorClear)
    gfx.pushContext(label)
    -- Gains are a white pill with black digits; losses invert.
    gfx.setColor(negative and gfx.kColorBlack or gfx.kColorWhite)
    gfx.fillRoundRect(0, 0, width, height, cfg.cornerRadius)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(cfg.borderWidth)
    gfx.drawRoundRect(1, 1, width - 2, height - 2, cfg.cornerRadius)
    if negative then gfx.setImageDrawMode(gfx.kDrawModeInverted) end
    base:draw(cfg.paddingX, cfg.paddingY)
    gfx.popContext()
    time = 0
    endsAt = cfg.riseDuration + cfg.holdDuration + cfg.exitDuration
end

function ScorePopup.update(dt)
    if label == nil then return end
    time += dt
    if time >= endsAt then label = nil end
end

-- Top edge of the pill for the current time.
function ScorePopup.getY()
    if label == nil then return nil end
    local restY = screenHeight - cfg.bottomMargin - height
    local hiddenY = screenHeight + 2
    if time < cfg.riseDuration then
        -- Overshoots its resting height a little, then settles.
        local progress = easeOutBack(time / cfg.riseDuration)
        return hiddenY + (restY - hiddenY) * progress
    end
    local sinceHold = time - cfg.riseDuration - cfg.holdDuration
    if sinceHold <= 0 then return restY end
    local progress = sinceHold / cfg.exitDuration
    return restY + (hiddenY - restY) * progress * progress
end

function ScorePopup.draw()
    if label == nil then return end
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    label:draw(math.floor((screenWidth - width) / 2),
        math.floor(ScorePopup.getY() + .5))
    gfx.popContext()
end
