import "CoreLibs/graphics"
import "variants/variantA/playerConfig"

-- A comic starburst panel for sudden events. The spiky outline and whatever
-- the owner draws inside it are baked into one image when the dialog is
-- built, so showing it costs nothing and every frame is a single blit.
-- Time is passed in rather than counted here, so the caller's clock (the
-- shared Juicy instance) decides when the animation runs.
BurstDialog = {}
BurstDialog.__index = BurstDialog

local gfx <const> = playdate.graphics
local cfg <const> = PlayerConfig.burstDialog

local function easeOutBack(t)
    local u = t - 1
    return 1 + 2.70158 * u * u * u + 1.70158 * u * u
end

-- Alternating outer and inner points around an ellipse. Only the outer
-- points wobble, so the inner ring stays a predictable clearance for the
-- content no matter how ragged the spikes look.
local function burstPoints(centerX, centerY, radiusX, radiusY, spikes)
    local points = {}
    for index = 0, spikes * 2 - 1 do
        local angle = index / (spikes * 2) * 2 * math.pi - math.pi / 2
        local scale = cfg.innerScale
        if index % 2 == 0 then
            -- An irrational step never repeats over one turn, so the spikes
            -- read as drawn by hand while staying identical every run.
            scale = 1 - cfg.spikeJitter * (0.5 + 0.5 * math.sin(index * 2.3999632))
        end
        points[#points + 1] = centerX + math.cos(angle) * radiusX * scale
        points[#points + 1] = centerY + math.sin(angle) * radiusY * scale
    end
    return points
end

-- options: width, height (the content box), draw(width, height).
function BurstDialog.new(options)
    local contentWidth = options.width
    local contentHeight = options.height
    local radiusX = contentWidth / 2 * cfg.burstScale
    local radiusY = contentHeight / 2 * cfg.burstScale
    local imageWidth = math.ceil(radiusX * 2) + cfg.lineWidth * 2
    local imageHeight = math.ceil(radiusY * 2) + cfg.lineWidth * 2
    local image = gfx.image.new(imageWidth, imageHeight, gfx.kColorClear)
    local centerX = imageWidth / 2
    local centerY = imageHeight / 2
    local points = burstPoints(centerX, centerY, radiusX, radiusY, cfg.spikes)

    gfx.pushContext(image)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillPolygon(table.unpack(points))
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(cfg.lineWidth)
    -- Stroked as segments rather than drawPolygon, which wants a geometry
    -- object; this also closes the ring without building one.
    for index = 1, #points, 2 do
        local nextIndex = index + 2
        if nextIndex > #points then nextIndex = 1 end
        gfx.drawLine(points[index], points[index + 1],
            points[nextIndex], points[nextIndex + 1])
    end
    gfx.setLineWidth(1)
    gfx.pushContext()
    gfx.setDrawOffset(math.floor(centerX - contentWidth / 2),
        math.floor(centerY - contentHeight / 2))
    options.draw(contentWidth, contentHeight)
    gfx.popContext()
    gfx.popContext()

    return setmetatable({
        image = image,
        width = imageWidth,
        height = imageHeight,
        shownAt = nil,
        hiddenAt = nil,
        joltAt = -math.huge,
    }, BurstDialog)
end

function BurstDialog:show(now)
    self.shownAt = now
    self.hiddenAt = nil
    self.joltAt = -math.huge
end

-- A brief extra swell, for when the event is struck but not yet resolved.
function BurstDialog:jolt(now)
    self.joltAt = now
end

function BurstDialog:hide(now)
    if self.shownAt ~= nil and self.hiddenAt == nil then
        self.hiddenAt = now
    end
end

function BurstDialog:cancel()
    self.shownAt = nil
    self.hiddenAt = nil
end

function BurstDialog:isVisible(now)
    if self.shownAt == nil then return false end
    if self.hiddenAt == nil then return true end
    return now < self.hiddenAt + cfg.exitDuration
end

-- 0 once the dialog is gone. Springs past 1 on entry, swells on a jolt, and
-- leaves by popping a little wider before collapsing.
function BurstDialog:getScale(now)
    if self.shownAt == nil then return 0 end
    if self.hiddenAt ~= nil then
        local progress = (now - self.hiddenAt) / cfg.exitDuration
        if progress >= 1 then return 0 end
        if progress < cfg.exitPopShare then
            return 1 + (cfg.exitPopScale - 1) * (progress / cfg.exitPopShare)
        end
        local collapse = (progress - cfg.exitPopShare) / (1 - cfg.exitPopShare)
        return cfg.exitPopScale * (1 - collapse)
    end
    local entered = now - self.shownAt
    local scale = 1
    if entered < cfg.enterDuration then
        scale = easeOutBack(entered / cfg.enterDuration)
    end
    local sinceJolt = now - self.joltAt
    if sinceJolt >= 0 and sinceJolt < cfg.joltDuration then
        scale += cfg.joltScale * (1 - sinceJolt / cfg.joltDuration)
    end
    return math.max(0, scale)
end

function BurstDialog:draw(centerX, centerY, now)
    if not self:isVisible(now) then return end
    local scale = self:getScale(now)
    if scale <= 0 then return end
    local x = centerX - self.width * scale / 2
    local y = centerY - self.height * scale / 2
    if scale == 1 then
        self.image:draw(math.floor(x + .5), math.floor(y + .5))
    else
        self.image:drawScaled(x, y, scale)
    end
end
