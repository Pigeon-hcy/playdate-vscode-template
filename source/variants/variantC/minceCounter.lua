import "CoreLibs/graphics"

-- Bake the gray enlarged digits once. Drawing the live number uses only
-- cached 1:1 glyph blits; no per-frame font layout, fading or scaling.
MinceCounter = {}
local gfx <const> = playdate.graphics
local font <const> = gfx.font.new("/System/Fonts/Roobert-24-Medium") or gfx.getSystemFont()
local digits, advances = {}, {}
for scale = 1, 3 do
    digits[scale], advances[scale] = {}, {}
    for digit = 0, 9 do
        local character = tostring(digit)
        local source = assert(font:getGlyph(character))
        local w, h = source:getSize()
        local large = gfx.image.new(w * scale, h * scale, gfx.kColorClear)
        gfx.pushContext(large)
        source:drawScaled(0, 0, scale)
        gfx.popContext()
        local gray = gfx.image.new(w * scale, h * scale, gfx.kColorClear)
        gfx.pushContext(gray)
        large:drawFaded(0, 0, .28, gfx.image.kDitherTypeBayer8x8)
        gfx.popContext()
        digits[scale][digit] = gray
        advances[scale][digit] = (font:getTextWidth(character) + 1) * scale
    end
end
local previous, text, size, width = nil, "0", 3, 0

function MinceCounter.draw(value)
    value = math.max(0, math.floor(value))
    if value ~= previous then
        previous, text = value, tostring(value)
        for scale = 3, 1, -1 do
            width = 0
            for index = 1, #text do
                width += advances[scale][text:byte(index) - 48]
            end
            size = scale
            if width <= 310 then break end
        end
    end
    local x = math.floor(math.min(260 - width / 2, 374 - width))
    for index = 1, #text do
        local digit = text:byte(index) - 48
        digits[size][digit]:draw(x, 54)
        x += advances[size][digit]
    end
end
