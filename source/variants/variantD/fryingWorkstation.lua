import "CoreLibs/graphics"
import "variants/variantD/playerConfig"
import "variants/variantD/supplyWarning"
import "variants/variantD/juiceRuntime"

local pd <const> = playdate
local gfx <const> = pd.graphics
local frying <const> = PlayerConfig.frying
local juice <const> = Juice
local systemFont <const> = gfx.getSystemFont()
local smallFont <const> = gfx.font.new("/System/Fonts/Roobert-10-Bold") or systemFont
local effectId <const> = "frying.patty"

local trayScale <const> = 2
local trayX <const> = 40
local trayY <const> = 43
local progressX <const> = 12
local progressY <const> = 3
local progressWidth <const> = 376
local progressHeight <const> = 13

local function loadImage(path)
    local image, loadError = gfx.image.new(path)
    assert(image, loadError)
    return image
end

local function bakeTray()
    local source = loadImage("resource/GrillTray")
    local width, height = source:getSize()
    local baked = gfx.image.new(width * trayScale, height * trayScale, gfx.kColorWhite)
    gfx.pushContext(baked)
        source:drawScaled(0, 0, trayScale)
    gfx.popContext()
    return baked
end

local trayImage <const> = bakeTray()
local pattyImages <const> = {
    raw = loadImage("resource/grill/RawPatty"),
    ready = loadImage("resource/grill/CookedPatty"),
    burnt = loadImage("resource/grill/BurntPatty"),
}
local pattyWidth, pattyHeight = pattyImages.raw:getSize()
local pattyX <const> = math.floor((PlayerConfig.screenWidth - pattyWidth) / 2)
local pattyY <const> = 105

FryingWorkstation = {}
FryingWorkstation.usesCrank = true
FryingWorkstation.help = {
    title = "CRANK GRILL",
    summary = "COOK ONE PATTY AT A TIME. SHAKE THE CRANK, THEN TAKE IT WHILE THE BAR IS BETWEEN 60 AND 80.",
    controls = {
        { "⬇", "PLACE ONE PATTY (" .. frying.pattyCost .. " MINCE)" },
        { "🎣", "SHAKE TO FILL THE COOK BAR" },
        { "⬆", "TAKE IT AT 60-80" },
        { "⬆", "DISCARD IT AFTER 80" },
    },
}

local function getPatty()
    return frying.slots[1]
end

local function setStateFromProgress(patty)
    local previousState = patty.state
    local readyAt = frying.degreesForFullBar * frying.readyMin / 100
    local burnAt = frying.degreesForFullBar * frying.burnAbove / 100
    if patty.crankDegrees > burnAt then
        patty.state = "burnt"
    elseif patty.crankDegrees >= readyAt then
        patty.state = "ready"
    else
        patty.state = "raw"
    end
    if patty.state == "burnt" and previousState ~= "burnt" then
        juice:errorShake(effectId)
        juice:verticalShake(effectId, .35, { amplitude = 4, startHz = 13, endHz = 6 })
    end
end

function FryingWorkstation.getProgress()
    local patty = getPatty()
    return patty ~= nil and patty.progress or 0
end

function FryingWorkstation.getState()
    local patty = getPatty()
    return patty ~= nil and patty.state or "empty"
end

function FryingWorkstation.isOnFire()
    return FryingWorkstation.getState() == "burnt"
end

function FryingWorkstation.isFireDialogVisible()
    return false
end

function FryingWorkstation.placePatty()
    if getPatty() ~= nil then return false end
    if PlayerConfig.mincedMeat < frying.pattyCost then
        SupplyWarning.request("mince")
        return false
    end

    frying.slots[1] = {
        crankDegrees = 0,
        progress = 0,
        state = "raw",
        animation = nil,
        animationFrame = 0,
    }
    PlayerConfig.mincedMeat -= frying.pattyCost
    juice:remove(effectId)
    juice:ingredientLand(effectId, { direction = -1 })
    juice:verticalShake(effectId, Juicy.config.heavyShakeDuration)
    return true
end

function FryingWorkstation.advanceCooking(crankDegrees)
    local patty = getPatty()
    if patty == nil or patty.animation ~= nil or patty.state == "burnt" then
        return false
    end

    local amount = math.abs(crankDegrees or 0)
    if amount <= 0 then return false end
    patty.crankDegrees = math.min(frying.degreesForFullBar,
        (patty.crankDegrees or 0) + amount)
    patty.progress = patty.crankDegrees * 100 / frying.degreesForFullBar
    setStateFromProgress(patty)
    return true
end

local function startRiseAnimation(patty)
    juice:remove(effectId)
    patty.animation = "rising"
    patty.animationFrame = 0
end

function FryingWorkstation.takePatty()
    local patty = getPatty()
    if patty == nil or patty.animation ~= nil then return nil end

    if patty.state == "ready" then
        startRiseAnimation(patty)
        PlayerConfig.patties += 1
        return "collected"
    end
    if patty.state == "burnt" then
        startRiseAnimation(patty)
        return "discarded"
    end

    juice:errorShake(effectId)
    return "undercooked"
end

function FryingWorkstation.collectOrDiscard()
    return FryingWorkstation.takePatty()
end

function FryingWorkstation.handleInput()
    local crankChange = math.abs(pd.getCrankChange())
    if crankChange > 0 then FryingWorkstation.advanceCooking(crankChange) end

    if pd.buttonJustPressed(pd.kButtonDown) then
        FryingWorkstation.placePatty()
    end
    if pd.buttonJustPressed(pd.kButtonUp) then
        FryingWorkstation.takePatty()
    end
end

function FryingWorkstation.update(_isActive)
    local patty = getPatty()
    if patty == nil or patty.animation ~= "rising" then return end
    patty.animationFrame += 1
    if patty.animationFrame >= frying.riseAnimationDurationFrames then
        frying.slots[1] = nil
        juice:remove(effectId)
    end
end

local function progressStatus()
    local state = FryingWorkstation.getState()
    if state == "empty" then return "EMPTY - DOWN TO PLACE" end
    if state == "raw" then return "SHAKE CRANK - " .. math.floor(FryingWorkstation.getProgress() + .5) .. "%" end
    if state == "ready" then return "READY - UP TO TAKE" end
    return "BURNT - UP TO DISCARD"
end

function FryingWorkstation.drawProgressBar()
    local progress = FryingWorkstation.getProgress()
    local innerWidth = progressWidth - 4
    local readyX = progressX + 2 + math.floor(innerWidth * frying.readyMin / 100)
    local burnX = progressX + 2 + math.floor(innerWidth * frying.burnAbove / 100)

    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, PlayerConfig.screenWidth, 34)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(progressX, progressY, progressWidth, progressHeight)
    local fillWidth = math.floor(innerWidth * progress / 100)
    if fillWidth > 0 then
        gfx.fillRect(progressX + 2, progressY + 2,
            fillWidth, progressHeight - 4)
    end
    gfx.drawLine(readyX, progressY, readyX, progressY + progressHeight - 1)
    gfx.drawLine(burnX, progressY, burnX, progressY + progressHeight - 1)
    smallFont:drawText(progressStatus(), 12, 18)
    smallFont:drawText("60", readyX - 7, 18)
    smallFont:drawText("80", burnX - 7, 18)
    gfx.popContext()
end

local function drawPatty()
    local patty = getPatty()
    if patty == nil then return end

    local transform = juice:getTransform(effectId)
    local rise = 0
    if patty.animation == "rising" then
        local progress = math.min(1,
            patty.animationFrame / frying.riseAnimationDurationFrames)
        rise = frying.riseDistance * (1 - (1 - progress) ^ 2)
    end
    local x = math.floor(pattyX + pattyWidth * (1 - transform.scaleX) / 2 +
        transform.offsetX + .5)
    local y = math.floor(pattyY - rise +
        pattyHeight * (1 - transform.scaleY) + transform.offsetY + .5)
    local image = pattyImages[patty.state]
    if transform.scaleX == 1 and transform.scaleY == 1 then
        image:draw(x, y)
    else
        image:drawScaled(x, y, transform.scaleX, transform.scaleY)
    end
end

function FryingWorkstation.draw()
    gfx.setColor(gfx.kColorBlack)
    trayImage:draw(trayX, trayY)
    drawPatty()
    FryingWorkstation.drawProgressBar()

    local state = FryingWorkstation.getState()
    local prompt
    if state == "empty" then
        prompt = "DOWN: PLACE PATTY - " .. frying.pattyCost .. " MINCE"
    elseif state == "raw" then
        prompt = "SHAKE CRANK TO COOK"
    elseif state == "ready" then
        prompt = "READY! UP: TAKE PATTY"
    else
        prompt = "BURNT! UP: DISCARD"
    end
    smallFont:drawText(prompt, 20, 216)
end
