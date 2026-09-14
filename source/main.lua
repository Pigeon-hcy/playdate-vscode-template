import "CoreLibs/graphics"
import "CoreLibs/ui"
import "playerConfig"
import "juiceRuntime"
import "workstationManager"
import "grinderWorkstation"
import "fryingWorkstation"
import "fryingWarning"
import "supplyWarning"
import "assemblyWorkstation"
import "orderUI"
import "rushBanner"
import "scorePopup"
import "helpCard"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local crankIndicator <const> = pd.ui.crankIndicator
local wasShowingCrankIndicator = false
local lastJuiceMilliseconds = pd.getCurrentTimeMilliseconds()

pd.display.setRefreshRate(PlayerConfig.refreshRate)

local seedSeconds, seedMilliseconds = pd.getSecondsSinceEpoch()
math.randomseed(seedSeconds, seedMilliseconds)
Orders:reset()
Orders.onRushStart = function() RushBanner.show("start") end
Orders.onRushEnd = function() RushBanner.show("over") end
Scoring.onChange = function(delta) ScorePopup.show(delta) end

WorkstationManager.register(1, GrinderWorkstation)
WorkstationManager.register(2, FryingWorkstation)
WorkstationManager.register(3, AssemblyWorkstation)
GrinderWorkstation.initialize()
AssemblyWorkstation.initialize()

-- Each station's controls card opens the first time the player settles on
-- it, and again on request from the system menu.
local function showHelp(workstationId)
    local controller = WorkstationManager.getController(workstationId)
    if controller == nil or controller.help == nil then return false end
    HelpCard.show(controller.help, workstationId)
    return true
end

pd.getSystemMenu():addMenuItem("controls", function()
    if not RushBanner.isActive() then
        showHelp(PlayerConfig.activeWorkstation)
    end
end)

function playdate.update()
    local now = pd.getCurrentTimeMilliseconds()
    local dt = math.max(0, now - lastJuiceMilliseconds) / 1000
    lastJuiceMilliseconds = now
    ScorePopup.update(dt)
    HelpCard.update(dt)
    WorkstationNavigation.update(dt)

    if not RushBanner.isActive() and not HelpCard.isOpen() and
        not WorkstationManager.isSwitching() and
        not HelpCard.hasSeen(PlayerConfig.activeWorkstation) then
        showHelp(PlayerConfig.activeWorkstation)
    end

    if RushBanner.isActive() or HelpCard.isOpen() then
        -- The game is frozen under the banner or card: no clocks, cooking
        -- or input. Its last frame is redrawn from the untouched state below.
        if RushBanner.isActive() then
            RushBanner.update(dt)
        else
            HelpCard.handleInput()
        end
        pd.getCrankTicks(PlayerConfig.assembly.crankTicksPerTurn)
        pd.getCrankChange()
    else
        Juice:update(dt)
        -- Expire deadlines before handling submission on this frame.
        Orders:update(dt)
        WorkstationManager.updateTransition(dt)

        if pd.buttonJustPressed(pd.kButtonLeft) then
            WorkstationManager.switch(-1)
        elseif pd.buttonJustPressed(pd.kButtonRight) then
            WorkstationManager.switch(1)
        end

        WorkstationManager.handleActiveInput()
        if WorkstationManager.isSwitching() then
            -- Discard hidden crank movement so it cannot turn the ingredient
            -- wheel or grind meat when the transition finishes.
            pd.getCrankTicks(PlayerConfig.assembly.crankTicksPerTurn)
            pd.getCrankChange()
        end
        WorkstationManager.updateAll()
        FryingWarning.update()
        SupplyWarning.update()
    end

    -- The two opaque transition images already cover the entire screen.
    if not WorkstationManager.isSwitching() then
        gfx.clear()
    end

    if not WorkstationManager.drawActive() then
        gfx.drawText(
            tostring(PlayerConfig.activeWorkstation),
            196,
            110
        )
    end

    OrderUI.draw()
    WorkstationNavigation.draw()
    if not WorkstationManager.isSwitching() and
        not (PlayerConfig.activeWorkstation == 2 and FryingWorkstation.isFireDialogVisible()) then
        if FryingWarning.isVisible() then
            FryingWarning.draw()
        else
            SupplyWarning.draw()
        end
    end
    ScorePopup.draw()
    HelpCard.draw()
    RushBanner.draw()

    local shouldShowCrankIndicator = not RushBanner.isActive() and
        not HelpCard.isVisible() and
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
