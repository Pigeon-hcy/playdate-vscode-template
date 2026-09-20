import "CoreLibs/graphics"
import "variants/variantC/playerConfig"
import "variants/variantC/workstationNavigation"

WorkstationManager = {}

local controllers = {}
local gfx <const> = playdate.graphics
local width <const> = PlayerConfig.screenWidth
local height <const> = PlayerConfig.screenHeight
-- Reuse two opaque 1-bit snapshots (about 24 KB of pixel data in total).
-- Only capture at switch time; animation frames are two integer-position blits.
local outgoingImage <const> = gfx.image.new(width, height, gfx.kColorWhite)
local incomingImage <const> = gfx.image.new(width, height, gfx.kColorWhite)
local switching = false
local switchElapsed = 0
local switchDirection = 1

local function captureStation(image, index)
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setLineWidth(1)
    gfx.clear(gfx.kColorWhite)
    local controller = controllers[index]
    if controller ~= nil and controller.draw ~= nil then
        controller.draw()
    else
        gfx.drawText(tostring(index), 196, 110)
    end
    gfx.popContext()
end

function WorkstationManager.register(workstationId, controller)
    controllers[workstationId] = controller
end

function WorkstationManager.getController(workstationId)
    return controllers[workstationId]
end

function WorkstationManager.switch(direction)
    if switching or direction == 0 then
        return false
    end

    local currentIndex = PlayerConfig.activeWorkstation
    local workstationCount = PlayerConfig.workstationCount
    captureStation(outgoingImage, currentIndex)
    switchDirection = direction > 0 and 1 or -1
    PlayerConfig.activeWorkstation =
        ((currentIndex - 1 + switchDirection) % workstationCount) + 1
    captureStation(incomingImage, PlayerConfig.activeWorkstation)
    switchElapsed = 0
    switching = true
    WorkstationNavigation.press(switchDirection)
    return true
end

function WorkstationManager.updateTransition(dt)
    if switching then
        switchElapsed += dt
        if switchElapsed >= PlayerConfig.workstationSwitchDuration then
            switching = false
        end
    end
end

function WorkstationManager.isSwitching()
    return switching
end

function WorkstationManager.updateAll()
    for index = 1, PlayerConfig.workstationCount do
        local workstation = PlayerConfig.workstations[index]
        workstation.elapsedFrames += 1

        local controller = controllers[index]
        if controller ~= nil and controller.update ~= nil then
            -- Cooking and existing animations continue, but crank gameplay
            -- is inactive until the destination is fully visible.
            controller.update(not switching and index == PlayerConfig.activeWorkstation)
        end
    end
end

function WorkstationManager.handleActiveInput()
    if switching then
        return
    end

    local controller = controllers[PlayerConfig.activeWorkstation]

    if controller ~= nil and controller.handleInput ~= nil then
        controller.handleInput()
    end
end

function WorkstationManager.activeUsesCrank()
    local controller = controllers[PlayerConfig.activeWorkstation]
    return controller ~= nil and controller.usesCrank == true
end

function WorkstationManager.shouldShowCrankIndicator(isCrankDocked)
    return not switching and isCrankDocked and WorkstationManager.activeUsesCrank()
end

function WorkstationManager.drawActive()
    if switching then
        local progress = switchElapsed / PlayerConfig.workstationSwitchDuration
        local eased = 1 - (1 - progress) ^ 3
        local offset = math.floor(width * eased + 0.5)
        -- Shared integer edge prevents gaps. Right brings the new page in
        -- from the right; left mirrors the same motion, including wraparound.
        outgoingImage:draw(-switchDirection * offset, 0)
        incomingImage:draw(switchDirection * (width - offset), 0)
        return true
    end

    local controller = controllers[PlayerConfig.activeWorkstation]

    if controller == nil or controller.draw == nil then
        return false
    end

    controller.draw()
    return true
end
