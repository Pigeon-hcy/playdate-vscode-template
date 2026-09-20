import "CoreLibs/graphics"
import "variants/variantC/playerConfig"
import "variants/variantC/juiceRuntime"
import "variants/variantC/burstDialog"
import "variants/variantC/stationArrow"

SupplyWarning = {}
local gfx <const> = playdate.graphics
local font <const> = gfx.font.new("/System/Fonts/Roobert-10-Bold") or gfx.getSystemFont()
local function makeDialog(title, destination)
    return BurstDialog.new({
        width = math.max(font:getTextWidth(title), font:getTextWidth(destination)) + 2,
        height = font:getHeight() * 2 + 2,
        draw = function(width)
            font:drawText(title, math.floor((width - font:getTextWidth(title)) / 2), 0)
            font:drawText(destination, math.floor((width - font:getTextWidth(destination)) / 2),
                font:getHeight() + 2)
        end,
    })
end
local dialogs = { mince = makeDialog("MINCE!", "GRINDER"),
    patty = makeDialog("PATTY!", "FRYER") }
local mode, dialog, target, station = nil, nil, nil, nil
local expiresAt = 0

local function isMissing(kind)
    if kind == "mince" then
        return PlayerConfig.mincedMeat < PlayerConfig.frying.pattyCost
    end
    return kind == "patty" and PlayerConfig.patties <= 0
end

-- Only a failed consuming action opens the prompt; empty stock alone is quiet.
function SupplyWarning.request(kind)
    local sourceStation = kind == "mince" and 2 or kind == "patty" and 3
    if PlayerConfig.activeWorkstation ~= sourceStation or not isMissing(kind) then
        return false
    end
    if mode == kind and station == sourceStation then
        dialog:jolt(Juice.time)
    else
        if dialog then dialog:cancel() end
        mode, target, station = kind, sourceStation - 1, sourceStation
        dialog = dialogs[kind]
        dialog:show(Juice.time)
    end
    expiresAt = Juice.time + PlayerConfig.supplyWarning.lifetime
    return true
end

function SupplyWarning.update()
    if dialog == nil then return end
    if PlayerConfig.activeWorkstation ~= station then
        dialog:cancel()
        mode, dialog, target, station = nil, nil, nil, nil
    elseif mode ~= nil and (not isMissing(mode) or Juice.time >= expiresAt) then
        mode = nil
        dialog:hide(Juice.time)
    end
end

function SupplyWarning.isVisible()
    return dialog ~= nil and dialog:isVisible(Juice.time)
end

function SupplyWarning.draw()
    if dialog == nil or not dialog:isVisible(Juice.time) then return end
    local direction = StationArrow.getDirection(PlayerConfig.activeWorkstation, target)
    if direction == 0 then return end
    local scale = math.max(1.12, PlayerConfig.burstDialog.exitPopScale)
    local inset = math.ceil(dialog.width * scale / 2) + 4
    local x = direction < 0 and inset or PlayerConfig.screenWidth - inset
    local y = 175
    local arrowY = y - math.ceil(dialog.height * scale / 2) - 22
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    StationArrow.draw(x, arrowY, direction)
    dialog:draw(x, y, Juice.time)
    gfx.popContext()
end
