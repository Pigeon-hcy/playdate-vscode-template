import "playerConfig"

WorkstationManager = {}

local controllers = {}

function WorkstationManager.register(workstationId, controller)
    controllers[workstationId] = controller
end

function WorkstationManager.switch(direction)
    local currentIndex = PlayerConfig.activeWorkstation
    local workstationCount = PlayerConfig.workstationCount

    PlayerConfig.activeWorkstation =
        ((currentIndex - 1 + direction) % workstationCount) + 1
end

function WorkstationManager.updateAll()
    for index = 1, PlayerConfig.workstationCount do
        local workstation = PlayerConfig.workstations[index]
        workstation.elapsedFrames += 1

        local controller = controllers[index]
        if controller ~= nil and controller.update ~= nil then
            controller.update(index == PlayerConfig.activeWorkstation)
        end
    end
end

function WorkstationManager.handleActiveInput()
    local controller = controllers[PlayerConfig.activeWorkstation]

    if controller ~= nil and controller.handleInput ~= nil then
        controller.handleInput()
    end
end

function WorkstationManager.drawActive()
    local controller = controllers[PlayerConfig.activeWorkstation]

    if controller == nil or controller.draw == nil then
        return false
    end

    controller.draw()
    return true
end
