import "CoreLibs/graphics"
import "variants/variantB/playerConfig"

-- A controls card for one workstation. main.lua opens it the first time the
-- player settles on each station and from the system menu, and freezes the
-- game while it is open. The card is laid out and baked into one image when
-- shown; every frame after that is a blit plus a faded white wash behind it.
--
-- A help table is { title = "GRINDER", summary = "...",
--   controls = { { "Ⓐ", "WHAT A DOES" }, ... } }. Button glyphs come from
-- Roobert 10 Bold, which carries Ⓐ Ⓑ ⬆ ⬇ ⬅ ➡ and the crank 🎣.
HelpCard = {}

local gfx <const> = playdate.graphics
local cfg <const> = PlayerConfig.helpCard
local screenWidth <const> = PlayerConfig.screenWidth
local screenHeight <const> = PlayerConfig.screenHeight
local systemFont <const> = gfx.getSystemFont()
local titleFont <const> = gfx.font.new("/System/Fonts/Roobert-24-Medium") or systemFont
local bodyFont <const> = gfx.font.new("/System/Fonts/Roobert-10-Bold") or systemFont
local whiteScreen <const> = gfx.image.new(screenWidth, screenHeight, gfx.kColorWhite)
local footerLeft <const> = "⬅ ➡  OTHER STATIONS"
local footerRight <const> = "Ⓐ  GOT IT"

local card = nil
local cardWidth, cardHeight = 0, 0
local seen = {}
local open = false
local time = 0
local closedAt = nil

local function easeOutBack(t)
    local u = t - 1
    return 1 + 2.70158 * u * u * u + 1.70158 * u * u
end

local function bake(help, number)
    local width = cfg.width
    local inner = width - 2 * cfg.padding
    local _, summaryHeight =
        gfx.getTextSizeForMaxWidth(help.summary, inner, 0, bodyFont)
    local rowsHeight = #help.controls * cfg.rowHeight
    local height = cfg.headerHeight + cfg.padding + summaryHeight + cfg.sectionGap +
        rowsHeight + cfg.sectionGap + cfg.footerHeight
    local image = gfx.image.new(width + cfg.shadow, height + cfg.shadow, gfx.kColorClear)

    gfx.pushContext(image)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(cfg.shadow, cfg.shadow, width, height, cfg.cornerRadius)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(0, 0, width, height, cfg.cornerRadius)
    gfx.setColor(gfx.kColorBlack)
    -- Header band: station number and name, white on black.
    gfx.fillRoundRect(0, 0, width, cfg.headerHeight + cfg.cornerRadius, cfg.cornerRadius)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, cfg.headerHeight, width, cfg.cornerRadius)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(cfg.borderWidth)
    gfx.drawRoundRect(1, 1, width - 2, height - 2, cfg.cornerRadius)
    gfx.setLineWidth(1)

    local title = number .. "  " .. help.title
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    titleFont:drawText(title, cfg.padding + 2,
        math.floor((cfg.headerHeight - titleFont:getHeight()) / 2) + 1)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)

    local y = cfg.headerHeight + cfg.padding
    gfx.drawTextInRect(help.summary, cfg.padding, y, inner, summaryHeight,
        0, nil, kTextAlignment.left, bodyFont)
    y += summaryHeight + cfg.sectionGap

    -- Keys right-aligned in their own column, so a two-key row and a
    -- one-key row line their descriptions up on the same edge.
    local textX = cfg.padding + cfg.keyColumnWidth + cfg.keyGap
    local rowTextOffset = math.floor((cfg.rowHeight - bodyFont:getHeight()) / 2)
    for _, control in ipairs(help.controls) do
        local keys, description = control[1], control[2]
        bodyFont:drawText(keys,
            cfg.padding + cfg.keyColumnWidth - bodyFont:getTextWidth(keys),
            y + rowTextOffset)
        bodyFont:drawText(description, textX, y + rowTextOffset)
        y += cfg.rowHeight
    end
    y += cfg.sectionGap

    gfx.drawLine(cfg.padding, y, width - cfg.padding, y)
    local footerTextY = y + math.floor((cfg.footerHeight - bodyFont:getHeight()) / 2)
    bodyFont:drawText(footerLeft, cfg.padding, footerTextY)
    bodyFont:drawText(footerRight,
        width - cfg.padding - bodyFont:getTextWidth(footerRight), footerTextY)
    gfx.popContext()

    return image, width + cfg.shadow, height + cfg.shadow
end

-- Whether the card for this station number has been shown this session.
function HelpCard.hasSeen(number)
    return seen[number] == true
end

function HelpCard.resetSeen()
    seen = {}
end

function HelpCard.show(help, number, immediately)
    seen[number] = true
    card, cardWidth, cardHeight = bake(help, number)
    open = true
    -- Startup can reveal an already-settled card in its dissolve target.
    time = immediately and cfg.enterDuration or 0
    closedAt = nil
end

-- Open means the game should stay frozen; the card may still be sliding
-- away for a moment after it closes, while play has already resumed.
function HelpCard.isOpen()
    return open
end

function HelpCard.isVisible()
    return card ~= nil
end

function HelpCard.close()
    if not open then return false end
    open = false
    closedAt = time
    return true
end

-- Call while the card is open instead of the game's own input.
function HelpCard.handleInput()
    if not open then return false end
    if playdate.buttonJustPressed(playdate.kButtonA) or
        playdate.buttonJustPressed(playdate.kButtonB) then
        return HelpCard.close()
    end
    return false
end

function HelpCard.update(dt)
    if card == nil then return end
    time += dt
    if closedAt ~= nil and time - closedAt >= cfg.exitDuration then
        card = nil
        closedAt = nil
    end
end

-- 0 when fully shown, rising towards 1 as the card is off the screen.
local function getProgress()
    if closedAt ~= nil then
        return 1 - math.min(1, (time - closedAt) / cfg.exitDuration)
    end
    if time >= cfg.enterDuration then return 1 end
    return easeOutBack(time / cfg.enterDuration)
end

function HelpCard.getY()
    if card == nil then return nil end
    local restY = math.floor((screenHeight - cardHeight) / 2)
    local progress = getProgress()
    if closedAt ~= nil then
        -- Falls away, accelerating, rather than springing.
        local fall = 1 - progress
        return restY + (screenHeight - restY) * fall * fall
    end
    return restY + (screenHeight - restY) * (1 - progress)
end

function HelpCard.draw()
    if card == nil then return end
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    local wash = cfg.dimAlpha * math.max(0, math.min(1, getProgress()))
    if wash > 0 then
        whiteScreen:drawFaded(0, 0, wash, gfx.image.kDitherTypeBayer8x8)
    end
    card:draw(math.floor((screenWidth - cardWidth) / 2), math.floor(HelpCard.getY() + .5))
    gfx.popContext()
end
