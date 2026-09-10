import "CoreLibs/graphics"
import "CoreLibs/ui"
import "playerConfig"
import "workstationManager"
import "grinderWorkstation"
import "fryingWorkstation"
import "assemblyWorkstation"
import "Juice"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local crankIndicator <const> = pd.ui.crankIndicator
local wasShowingCrankIndicator = false

pd.display.setRefreshRate(PlayerConfig.refreshRate)

local seedSeconds, seedMilliseconds = pd.getSecondsSinceEpoch()
math.randomseed(seedSeconds, seedMilliseconds)

WorkstationManager.register(1, GrinderWorkstation)
WorkstationManager.register(2, FryingWorkstation)
WorkstationManager.register(3, AssemblyWorkstation)
GrinderWorkstation.initialize()
AssemblyWorkstation.initialize()

function playdate.update()
    Juice.update()

    if not Juice.isFrozen() then
        if pd.buttonJustPressed(pd.kButtonLeft) then
            WorkstationManager.switch(-1)
        elseif pd.buttonJustPressed(pd.kButtonRight) then
            WorkstationManager.switch(1)
        end

        WorkstationManager.handleActiveInput()
        WorkstationManager.updateAll()
    end

    gfx.clear()

    if not WorkstationManager.drawActive() then
        gfx.drawText(
            tostring(PlayerConfig.activeWorkstation),
            196,
            110
        )
    end

    Juice.draw()

    local shouldShowCrankIndicator =
        WorkstationManager.shouldShowCrankIndicator(
            pd.isCrankDocked()
        )

    if shouldShowCrankIndicator then
        crankIndicator:draw()
    elseif wasShowingCrankIndicator then
        crankIndicator:resetAnimation()
    end

    wasShowingCrankIndicator = shouldShowCrankIndicator
end
