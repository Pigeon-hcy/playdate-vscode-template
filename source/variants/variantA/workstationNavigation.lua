import "CoreLibs/graphics"
import "variants/variantA/playerConfig"

-- Screen-space controls: these stay at the edges while stations slide.
WorkstationNavigation = {}
local gfx <const> = playdate.graphics
local size <const> = 17
local margin <const> = 2
local y <const> = math.floor((PlayerConfig.screenHeight - size) / 2)
local feedbackDuration <const> = 0.18
local feedbackRemaining = 0
local feedbackDirection = 0

local function bakeKey(direction, pressed)
    local image = gfx.image.new(size, size, gfx.kColorClear)
    gfx.pushContext(image)
    gfx.setLineWidth(1)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(6, 0, 5, size)
    gfx.fillRect(0, 6, size, 5)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(7, 1, 3, size - 2)
    gfx.fillRect(1, 7, size - 2, 3)
    -- The relevant arm is always filled, with a white directional chevron.
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(direction < 0 and 0 or 9, 6, 8, 5)
    gfx.setColor(gfx.kColorWhite)
    local tip = direction < 0 and 2 or 14
    gfx.drawLine(tip - direction, 7, tip, 8)
    gfx.drawLine(tip, 8, tip - direction, 9)
    if pressed then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(7, 1, 3, size - 2)
        gfx.fillRect(direction < 0 and 9 or 1, 7, 7, 3)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(7, 7, 3, 3)
    end
    gfx.popContext()
    return image
end

local leftKey <const> = bakeKey(-1, false)
local rightKey <const> = bakeKey(1, false)
local leftPressed <const> = bakeKey(-1, true)
local rightPressed <const> = bakeKey(1, true)

function WorkstationNavigation.press(direction)
    feedbackDirection = direction < 0 and -1 or 1
    feedbackRemaining = feedbackDuration
end

function WorkstationNavigation.update(dt)
    feedbackRemaining = math.max(0, feedbackRemaining - dt)
end

function WorkstationNavigation.draw()
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    local pressed = feedbackRemaining > 0
    local nudge = math.floor(2 * feedbackRemaining / feedbackDuration + 0.5)
    local leftDown = pressed and feedbackDirection < 0
    local rightDown = pressed and feedbackDirection > 0
    -- A thin white surround keeps the keys readable over moving scenery.
    local function drawKey(image, x)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(x - 1, y + 5, size + 2, 7)
        gfx.fillRect(x + 5, y - 1, 7, size + 2)
        image:draw(x, y)
    end
    drawKey(leftDown and leftPressed or leftKey, margin - (leftDown and nudge or 0))
    drawKey(rightDown and rightPressed or rightKey,
        PlayerConfig.screenWidth - margin - size + (rightDown and nudge or 0))
    gfx.popContext()
end
