import "CoreLibs/graphics"
import "variants/variantB/playerConfig"

StationArrow = {}
local gfx <const> = playdate.graphics
local images = {}
for direction = -1, 1 do
    local image = gfx.image.new(56, 40, gfx.kColorClear)
    gfx.pushContext(image)
    local x, y = 28, 20
    if direction == 0 then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(x - 6, y - 2, 13, 21)
        gfx.fillTriangle(x - 16, y + 2, x + 16, y + 2, x, y - 17)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(x - 3, y, 7, 16)
        gfx.fillTriangle(x - 11, y, x + 11, y, x, y - 13)
    else
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(x - 17, y - 7, 35, 15)
        gfx.fillTriangle(x + direction * 3, y - 17, x + direction * 3, y + 17,
            x + direction * 26, y)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(x - 14, y - 4, 29, 9)
        gfx.fillTriangle(x + direction * 6, y - 12, x + direction * 6, y + 12,
            x + direction * 22, y)
    end
    gfx.popContext()
    images[direction] = image
end

function StationArrow.getDirection(from, target)
    if from == target then return 0 end
    local right = (target - from) % PlayerConfig.workstationCount
    local left = (from - target) % PlayerConfig.workstationCount
    return right <= left and 1 or -1
end

function StationArrow.draw(x, y, direction)
    images[direction]:draw(math.floor(x - 28), math.floor(y - 20))
end
