import "CoreLibs/graphics"
import "CoreLibs/ui"
import "playerConfig"
import "juiceRuntime"
import "workstationManager"
import "grinderWorkstation"
import "fryingWorkstation"
import "assemblyWorkstation"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local crankIndicator <const> = pd.ui.crankIndicator
local wasShowingCrankIndicator = false
local lastJuiceMilliseconds = pd.getCurrentTimeMilliseconds()

pd.display.setRefreshRate(PlayerConfig.refreshRate)

local seedSeconds, seedMilliseconds = pd.getSecondsSinceEpoch()
math.randomseed(seedSeconds, seedMilliseconds)

WorkstationManager.register(1, GrinderWorkstation)
WorkstationManager.register(2, FryingWorkstation)
WorkstationManager.register(3, AssemblyWorkstation)
GrinderWorkstation.initialize()
AssemblyWorkstation.initialize()

function playdate.update()
    local now = pd.getCurrentTimeMilliseconds()
    Juice:update(math.max(0, now - lastJuiceMilliseconds) / 1000)
    lastJuiceMilliseconds = now

    if pd.buttonJustPressed(pd.kButtonLeft) then
        WorkstationManager.switch(-1)
    elseif pd.buttonJustPressed(pd.kButtonRight) then
        WorkstationManager.switch(1)
    end

    WorkstationManager.handleActiveInput()
    WorkstationManager.updateAll()

    gfx.clear()

    if not WorkstationManager.drawActive() then
        gfx.drawText(
            tostring(PlayerConfig.activeWorkstation),
            196,
            110
        )
    end

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
