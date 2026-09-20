import "CoreLibs/graphics"
import "variants/variantD/playerConfig"

-- Full-screen announcement for the start and end of a rush hour. While it is
-- showing, main.lua freezes the game and keeps drawing the frozen frame; the
-- banner whites it out, plays its text, and fades back. Seconds throughout.
-- Word images are baked once at load; drawing is blits, scaled only while a
-- word is still falling. No per-frame allocation.
RushBanner = {}

local gfx <const> = playdate.graphics
local cfg <const> = PlayerConfig.rushBanner
local screenWidth <const> = PlayerConfig.screenWidth
local screenHeight <const> = PlayerConfig.screenHeight
local font <const> = gfx.font.new(cfg.fontPath) or gfx.getSystemFont()
local whiteScreen <const> = gfx.image.new(screenWidth, screenHeight, gfx.kColorWhite)

-- Integer scale keeps the glyph pixels crisp: as large as the widest word and
-- the tallest line count allow, capped so the block does not fill the screen.
local function chooseScale(lines)
    local widest = 0
    for _, text in ipairs(lines) do
        widest = math.max(widest, font:getTextWidth(text))
    end
    local lineHeight = font:getHeight()
    local byWidth = math.floor((screenWidth - 2 * cfg.margin) / widest)
    local byHeight = math.floor(
        (screenHeight - 2 * cfg.margin - (#lines - 1) * cfg.lineGap) / (#lines * lineHeight))
    return math.max(1, math.min(cfg.maxScale, byWidth, byHeight))
end

local function bakeWord(text, scale)
    local base = assert(gfx.imageWithText(text, font:getTextWidth(text) + 2,
        font:getHeight() + 2, nil, nil, nil, nil, font))
    local baseWidth, baseHeight = base:getSize()
    local image = gfx.image.new(baseWidth * scale, baseHeight * scale, gfx.kColorClear)
    gfx.pushContext(image)
    base:drawScaled(0, 0, scale)
    gfx.popContext()
    -- Cumulative pixel width after each character, for the typewriter reveal.
    local reveal = {}
    for index = 1, #text do
        reveal[index] = font:getTextWidth(text:sub(1, index)) * scale
    end
    return { text = text, image = image, width = baseWidth * scale,
        height = baseHeight * scale, reveal = reveal }
end

local function layout(lines, scale, centred)
    local words = {}
    local blockHeight = 0
    local widest = 0
    for index, text in ipairs(lines) do
        local word = bakeWord(text, scale)
        words[index] = word
        blockHeight += word.height
        widest = math.max(widest, word.width)
    end
    blockHeight += (#lines - 1) * cfg.lineGap
    local y = math.floor((screenHeight - blockHeight) / 2)
    local left = math.floor((screenWidth - widest) / 2)
    for _, word in ipairs(words) do
        word.x = centred and math.floor((screenWidth - word.width) / 2) or left
        word.y = y
        y += word.height + cfg.lineGap
    end
    return words
end

local startWords <const> = layout({ "RUSH", "HOUR" }, chooseScale({ "RUSH", "HOUR" }), true)
local overWords <const> = layout({ "RUSH", "HOUR", "OVER" },
    chooseScale({ "RUSH", "HOUR", "OVER" }), false)

-- Start banner: each word falls from far above the screen plane (drawn large)
-- and slams to its resting size; the impact shakes the block and flashes
-- the screen for a moment.
for index, word in ipairs(startWords) do
    word.fallsAt = cfg.fadeInDuration + (index - 1) * (cfg.slamDuration + cfg.wordGap)
    word.landsAt = word.fallsAt + cfg.slamDuration
end
local startTypingAt <const> = cfg.fadeInDuration
local totalCharacters = 0
for _, word in ipairs(overWords) do totalCharacters += #word.text end
local typingEndsAt <const> = startTypingAt + totalCharacters * cfg.typeInterval

local mode = nil
local time = 0
local holdStartsAt = 0
local fadeOutAt = 0
local endsAt = 0
local shakeX, shakeY = 0, 0

function RushBanner.isActive()
    return mode ~= nil
end

function RushBanner.getMode()
    return mode
end

function RushBanner.getTime()
    return time
end

function RushBanner.show(which)
    assert(which == "start" or which == "over", "unknown banner")
    mode = which
    time = 0
    shakeX, shakeY = 0, 0
    if which == "start" then
        holdStartsAt = startWords[#startWords].landsAt
    else
        holdStartsAt = typingEndsAt
    end
    fadeOutAt = holdStartsAt + cfg.holdDuration
    endsAt = fadeOutAt + cfg.fadeOutDuration
end

function RushBanner.cancel()
    mode = nil
end

-- White overlay opacity: snaps in, lingers, then dissolves with the text.
function RushBanner.getOverlayAlpha()
    if mode == nil then return 0 end
    if time < cfg.fadeInDuration then return time / cfg.fadeInDuration end
    if time >= fadeOutAt then
        return math.max(0, 1 - (time - fadeOutAt) / cfg.fadeOutDuration)
    end
    return 1
end

local function isFlashing()
    if mode ~= "start" then return false end
    for _, word in ipairs(startWords) do
        if time >= word.landsAt and time < word.landsAt + cfg.flashDuration then
            return true
        end
    end
    return false
end

function RushBanner.update(dt)
    if mode == nil then return end
    time += dt
    shakeX, shakeY = 0, 0
    if mode == "start" then
        for _, word in ipairs(startWords) do
            local sinceLanding = time - word.landsAt
            if sinceLanding >= 0 and sinceLanding < cfg.shakeDuration then
                local amplitude = cfg.shakeAmplitude * (1 - sinceLanding / cfg.shakeDuration)
                shakeX = (math.random() * 2 - 1) * amplitude
                shakeY = (math.random() * 2 - 1) * amplitude
            end
        end
    end
    if time >= endsAt then
        mode = nil
    end
end

local function drawWord(word, alpha, offsetX, offsetY)
    local x = math.floor(word.x + offsetX + .5)
    local y = math.floor(word.y + offsetY + .5)
    if alpha < 1 then
        word.image:drawFaded(x, y, alpha, gfx.image.kDitherTypeBayer8x8)
    else
        word.image:draw(x, y)
    end
end

local function drawStartWords(alpha)
    for _, word in ipairs(startWords) do
        if time >= word.fallsAt then
            local scaleX, scaleY = 1, 1
            if time < word.landsAt then
                -- Accelerating fall: large and faint far away, sharp on impact.
                local progress = (time - word.fallsAt) / cfg.slamDuration
                local eased = progress * progress
                local scale = cfg.slamStartScale - (cfg.slamStartScale - 1) * eased
                scaleX, scaleY = scale, scale
            elseif time < word.landsAt + cfg.squashDuration then
                local progress = (time - word.landsAt) / cfg.squashDuration
                local rebound = 1 - progress
                scaleX = 1 + cfg.squashAmount * rebound
                scaleY = 1 - cfg.squashAmount * rebound
            end
            if scaleX == 1 and scaleY == 1 then
                drawWord(word, alpha, shakeX, shakeY)
            else
                -- Scale about the word's centre so it lands where it rests.
                word.image:drawScaled(
                    word.x + shakeX - word.width * (scaleX - 1) / 2,
                    word.y + shakeY - word.height * (scaleY - 1) / 2,
                    scaleX, scaleY)
            end
        end
    end
end

local function drawOverWords(alpha)
    local revealed = math.floor((time - startTypingAt) / cfg.typeInterval)
    if revealed < 0 then revealed = 0 end
    local cursorWord, cursorX = nil, 0
    for _, word in ipairs(overWords) do
        local count = math.min(#word.text, revealed)
        revealed -= count
        if count > 0 then
            gfx.setClipRect(word.x, word.y, word.reveal[count], word.height)
            drawWord(word, alpha, 0, 0)
            gfx.clearClipRect()
        end
        if count < #word.text and cursorWord == nil then
            cursorWord = word
            cursorX = word.x + (count > 0 and word.reveal[count] or 0)
        end
    end
    -- A blinking block cursor follows the typing and idles after the last
    -- character until the fade begins.
    if time < fadeOutAt then
        if cursorWord == nil then
            cursorWord = overWords[#overWords]
            cursorX = cursorWord.x + cursorWord.width
        end
        if math.floor(time * cfg.cursorHz * 2) % 2 == 0 then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(cursorX + 2, cursorWord.y,
                math.floor(cursorWord.height * .5), cursorWord.height)
        end
    end
end

function RushBanner.draw()
    if mode == nil then return end
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    local alpha = RushBanner.getOverlayAlpha()
    local flashing = isFlashing()
    if flashing then
        -- Impact frame: the whole screen inverts, text included.
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, screenWidth, screenHeight)
        gfx.setImageDrawMode(gfx.kDrawModeInverted)
    elseif alpha >= 1 then
        whiteScreen:draw(0, 0)
    elseif alpha > 0 then
        whiteScreen:drawFaded(0, 0, alpha, gfx.image.kDitherTypeBayer8x8)
    end
    if mode == "start" then
        drawStartWords(alpha)
    else
        drawOverWords(alpha)
    end
    gfx.popContext()
end
