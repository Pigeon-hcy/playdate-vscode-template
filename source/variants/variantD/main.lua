-- Startup loading is displayed by the shared launcher in source/main.lua.
import "CoreLibs/ui"
-- main.lua uses crank ticks directly, including during the title.
import "CoreLibs/crank"
import "variants/variantD/playerConfig"
-- Playdate only permits import while loading the program, never in update.
import "variants/variantD/juiceRuntime"
import "variants/variantD/workstationManager"
import "variants/variantD/grinderWorkstation"
import "variants/variantD/fryingWorkstation"
import "variants/variantD/fryingWarning"
import "variants/variantD/supplyWarning"
import "variants/variantD/assemblyWorkstation"
import "variants/variantD/orderUI"
import "variants/variantD/rushBanner"
import "variants/variantD/scorePopup"
import "variants/variantD/helpCard"
import "gameVersions"
import "titleScreen"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local crankIndicator <const> = pd.ui.crankIndicator
local wasShowingCrankIndicator = false
local lastJuiceMilliseconds = pd.getCurrentTimeMilliseconds()

pd.display.setRefreshRate(PlayerConfig.refreshRate)

local seedSeconds, seedMilliseconds = pd.getSecondsSinceEpoch()
math.randomseed(seedSeconds, seedMilliseconds)
TitleScreen.initialize(true)

-- Code and static assets are imported above. Prepare the playable state in
-- separate frames after LOADING is visible; titleScreen then captures it.
local loadingSteps = {
    function()
        Orders:reset()
        Orders.onRushStart = function() RushBanner.show("start") end
        Orders.onRushEnd = function() RushBanner.show("over") end
        Scoring.onChange = function(delta) ScorePopup.show(delta) end
        WorkstationManager.register(1, GrinderWorkstation)
        WorkstationManager.register(2, FryingWorkstation)
        WorkstationManager.register(3, AssemblyWorkstation)
    end,
    function() GrinderWorkstation.initialize() end,
    function() AssemblyWorkstation.initialize() end,
}
local loadingStep = 1
local function prepareGameplay()
    loadingSteps[loadingStep]()
    loadingStep = loadingStep + 1
    return loadingStep > #loadingSteps
end

-- Each station's controls card opens the first time the player settles on
-- it, and again on request from the system menu.
local function showHelp(workstationId, immediately)
    local controller = WorkstationManager.getController(workstationId)
    if controller == nil or controller.help == nil then return false end
    HelpCard.show(controller.help, workstationId, immediately)
    return true
end

pd.getSystemMenu():addMenuItem("versions (new game)", GameVersions.showPicker)

pd.getSystemMenu():addMenuItem("controls", function()
    if not TitleScreen.isActive() and not RushBanner.isActive() then
        showHelp(PlayerConfig.activeWorkstation)
    end
end)

-- Capture this same scene after loading and slide it into place before play.
local function drawGameplay()
    if not WorkstationManager.isSwitching() then
        gfx.clear()
    end
    if not WorkstationManager.drawActive() then
        gfx.drawText(tostring(PlayerConfig.activeWorkstation), 196, 110)
    end
    OrderUI.draw()
    if not WorkstationManager.isSwitching() and
        PlayerConfig.activeWorkstation == 2 then
        -- The crank grill owns the very top of the screen. Redraw its bar
        -- after the shared hanging-order overlay so the cook range stays clear.
        FryingWorkstation.drawProgressBar()
    end
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
end

local function drawInitialGameplay()
    -- Prepare the UI that will exist on the first live frame before capturing
    -- it, so the first live frame matches the completed slide exactly.
    if not HelpCard.hasSeen(PlayerConfig.activeWorkstation) then
        showHelp(PlayerConfig.activeWorkstation, true)
    end
    drawGameplay()
end

-- Loading art and time spent in the system menu must not advance the intro,
-- cook food, or expire orders when the next frame runs.
lastJuiceMilliseconds = pd.getCurrentTimeMilliseconds()
function playdate.gameWillResume()
    lastJuiceMilliseconds = pd.getCurrentTimeMilliseconds()
    TitleScreen.invalidate()
end

function playdate.update()
    local now = pd.getCurrentTimeMilliseconds()
    local dt = math.max(0, now - lastJuiceMilliseconds) / 1000
    lastJuiceMilliseconds = now
    if TitleScreen.isActive() then
        TitleScreen.update(dt, pd.getCrankChange(), pd.isCrankDocked(), prepareGameplay, drawInitialGameplay)
        TitleScreen.draw()
        local showCrankIndicator = TitleScreen.shouldShowCrankIndicator()
        if showCrankIndicator then
            crankIndicator:draw()
        elseif wasShowingCrankIndicator then
            crankIndicator:resetAnimation()
        end
        wasShowingCrankIndicator = showCrankIndicator
        pd.getCrankTicks(PlayerConfig.assembly.crankTicksPerTurn)
        -- Loading and capture time must not skip the entrance animation or
        -- advance gameplay clocks on the first live frame.
        lastJuiceMilliseconds = pd.getCurrentTimeMilliseconds()
        return
    end
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
            -- Discard hidden crank movement so it cannot cook a patty, turn
            -- the ingredient wheel, or grind meat after the transition.
            pd.getCrankTicks(PlayerConfig.assembly.crankTicksPerTurn)
            pd.getCrankChange()
        end
        WorkstationManager.updateAll()
        FryingWarning.update()
        SupplyWarning.update()
    end

    drawGameplay()

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
