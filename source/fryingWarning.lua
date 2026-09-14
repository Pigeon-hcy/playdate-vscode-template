import "CoreLibs/graphics"
import "playerConfig"
import "juiceRuntime"
import "burstDialog"
import "stationArrow"

-- A non-modal, screen-space warning. Cooking and controls keep running;
-- main updates this after all stations, including the offscreen fryer.
FryingWarning = {}
local gfx <const> = playdate.graphics
local frying <const> = PlayerConfig.frying
local cfg <const> = frying.warning
local font <const> = gfx.font.new("/System/Fonts/Roobert-10-Bold") or gfx.getSystemFont()
local fryerId <const> = 2

local function makeDialog(message)
    return BurstDialog.new({
        width = math.max(64, font:getTextWidth(message) + 4),
        height = font:getHeight() * 2 + 2,
        draw = function(width)
            font:drawText("FRYER!", math.floor((width - font:getTextWidth("FRYER!")) / 2), 0)
            font:drawText(message, math.floor((width - font:getTextWidth(message)) / 2),
                font:getHeight() + 2)
        end,
    })
end

local soonDialog <const> = makeDialog("HURRY!")
local fireDialog <const> = makeDialog("ON FIRE!")
local dialog = nil
local mode = nil
local remainingSeconds = nil
local startedAt = 0

-- Returns the most urgent patty. Rising/empty slots never keep an alarm alive.
function FryingWarning.getDanger()
    local burnAt = frying.rawDurationFrames + frying.cookedDurationFrames
    local nearest, target = nil, nil
    for index = 1, frying.slotCount do
        local patty = frying.slots[index]
        if patty ~= nil and patty.animation ~= "rising" and
            (patty.state == "cooked" or patty.state == "burning") then
            local seconds = patty.state == "burning" and 0 or
                math.max(0, (burnAt - patty.elapsedFrames) / PlayerConfig.refreshRate)
            if seconds <= cfg.leadSeconds and (nearest == nil or seconds < nearest) then
                nearest, target = seconds, index
            end
        end
    end
    return nearest, target
end

function FryingWarning.getDirection(stationId)
    return StationArrow.getDirection(stationId, fryerId)
end

function FryingWarning.update()
    remainingSeconds = FryingWarning.getDanger()
    local nextMode = nil
    if remainingSeconds ~= nil then
        nextMode = remainingSeconds <= 0 and "fire" or "soon"
    end
    if nextMode == mode then return end
    mode = nextMode
    if mode == nil then
        if dialog ~= nil then dialog:hide(Juice.time) end
    else
        if dialog ~= nil then dialog:cancel() end
        dialog = mode == "fire" and fireDialog or soonDialog
        dialog:show(Juice.time)
        startedAt = Juice.time
    end
end

function FryingWarning.getMode()
    return mode
end

function FryingWarning.isVisible()
    return dialog ~= nil and dialog:isVisible(Juice.time)
end

function FryingWarning.getShake()
    if mode == nil then return 0, 0 end
    local urgency = 1 - math.min(1, remainingSeconds / math.max(.001, cfg.leadSeconds))
    local amplitude = cfg.minShake + (cfg.maxShake - cfg.minShake) * urgency
    local phase = (Juice.time - startedAt) * cfg.shakeHz * math.pi * 2
    return math.floor(math.cos(phase) * amplitude + .5),
        math.floor(math.sin(phase * .73) * amplitude + .5)
end

local drawArrow = StationArrow.draw

function FryingWarning.draw()
    if not FryingWarning.isVisible() then return end
    local direction = FryingWarning.getDirection(PlayerConfig.activeWorkstation)
    -- Leave room for the starburst's entry overshoot, shake, and screen edges.
    local maxScale = math.max(1.12, PlayerConfig.burstDialog.exitPopScale)
    local halfHeight = math.ceil(dialog.height * maxScale / 2)
    local edgeInset = math.ceil(dialog.width * maxScale / 2) + cfg.maxShake + 3
    local centerX = direction == 0 and 200 or
        (direction < 0 and edgeInset or PlayerConfig.screenWidth - edgeInset)
    local dialogY = direction == 0 and
        (PlayerConfig.screenHeight - 32 - halfHeight - cfg.maxShake) or 164
    local arrowY = dialogY - halfHeight - 23
    local dx, dy = FryingWarning.getShake()
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    drawArrow(centerX + dx, arrowY + dy, direction)
    dialog:draw(centerX + dx, dialogY + dy, Juice.time)
    gfx.popContext()
end
