import "CoreLibs/graphics"
import "playerConfig"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local frying <const> = PlayerConfig.frying

local fryerX <const> = 14
local fryerY <const> = 38
local fryerWidth <const> = 372
local fryerHeight <const> = 166

local gridX <const> = 27
local gridY <const> = 60
local pattyWidth <const> = 76
local pattyHeight <const> = 50
local columnGap <const> = 16
local rowGap <const> = 24
local dropDistance <const> = 32
local riseDistance <const> = 40

FryingWorkstation = {}

function FryingWorkstation.placePatty()
    if PlayerConfig.mincedMeat < frying.pattyCost then
        return false
    end

    for slotIndex = 1, frying.slotCount do
        if frying.slots[slotIndex] == nil then
            frying.slots[slotIndex] = {
                elapsedFrames = 0,
                state = "raw",
                animation = "dropping",
                animationFrame = 0,
            }
            PlayerConfig.mincedMeat -= frying.pattyCost
            return true
        end
    end

    return false
end

function FryingWorkstation.update(_isActive)
    local burnAt = frying.rawDurationFrames + frying.cookedDurationFrames

    for slotIndex = 1, frying.slotCount do
        local patty = frying.slots[slotIndex]

        if patty ~= nil and patty.animation == "dropping" then
            patty.animationFrame += 1

            if patty.animationFrame >=
                frying.dropAnimationDurationFrames then
                patty.animation = nil
                patty.animationFrame = 0
            end
        elseif patty ~= nil and patty.animation == "rising" then
            patty.animationFrame += 1

            if patty.animationFrame >=
                frying.riseAnimationDurationFrames then
                frying.slots[slotIndex] = nil
            end
        elseif patty ~= nil then
            patty.elapsedFrames += 1

            if patty.elapsedFrames >= burnAt then
                patty.state = "burning"
            elseif patty.elapsedFrames >= frying.rawDurationFrames then
                patty.state = "cooked"
            else
                patty.state = "raw"
            end
        end
    end
end

local function startRiseAnimation(patty)
    patty.animation = "rising"
    patty.animationFrame = 0
end

function FryingWorkstation.collectOrDiscard()
    for slotIndex = 1, frying.slotCount do
        local patty = frying.slots[slotIndex]

        if patty ~= nil and
            patty.animation == nil and
            patty.state == "burning" then
            startRiseAnimation(patty)
            return "discarded"
        end
    end

    for slotIndex = 1, frying.slotCount do
        local patty = frying.slots[slotIndex]

        if patty ~= nil and
            patty.animation == nil and
            patty.state == "cooked" then
            startRiseAnimation(patty)
            PlayerConfig.patties += 1
            return "collected"
        end
    end

    return nil
end

function FryingWorkstation.handleInput()
    if pd.buttonJustPressed(pd.kButtonA) then
        FryingWorkstation.placePatty()
    end

    if pd.buttonJustPressed(pd.kButtonB) then
        FryingWorkstation.collectOrDiscard()
    end
end

local function getSlotPosition(slotIndex)
    local zeroBasedIndex = slotIndex - 1
    local column = zeroBasedIndex % 4
    local row = math.floor(zeroBasedIndex / 4)

    return
        gridX + column * (pattyWidth + columnGap),
        gridY + row * (pattyHeight + rowGap)
end

local function getAnimatedPattyY(patty, targetY)
    if patty.animation == "dropping" then
        local progress = math.min(
            1,
            patty.animationFrame / frying.dropAnimationDurationFrames
        )
        local easedProgress = 1 - (1 - progress) ^ 3

        return targetY - dropDistance * (1 - easedProgress)
    end

    if patty.animation == "rising" then
        local progress = math.min(
            1,
            patty.animationFrame / frying.riseAnimationDurationFrames
        )
        local easedProgress = progress * progress

        return targetY - riseDistance * easedProgress
    end

    return targetY
end

function FryingWorkstation.getFillProgress(patty)
    if patty.state == "raw" then
        return math.min(
            1,
            patty.elapsedFrames / frying.rawDurationFrames
        ), 0
    end

    if patty.state == "cooked" then
        return 1, math.min(
            1,
            (patty.elapsedFrames - frying.rawDurationFrames) /
                frying.cookedDurationFrames
        )
    end

    return 1, 1
end

local function fillPattyByState(patty, x, y)
    local grayProgress, blackProgress =
        FryingWorkstation.getFillProgress(patty)

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(x, y, pattyWidth, pattyHeight)

    local grayWidth = math.floor(pattyWidth * grayProgress)

    if grayWidth > 0 then
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(
            0.5,
            gfx.image.kDitherTypeBayer8x8
        )
        gfx.fillRect(x, y, grayWidth, pattyHeight)
    end

    local blackWidth = math.floor(pattyWidth * blackProgress)

    if blackWidth > 0 then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(x, y, blackWidth, pattyHeight)
    end

    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(3)
    gfx.drawRect(x, y, pattyWidth, pattyHeight)
end

local function drawPatty(slotIndex)
    local x, y = getSlotPosition(slotIndex)
    local patty = frying.slots[slotIndex]

    if patty == nil then
        return
    end

    local animatedY = math.floor(getAnimatedPattyY(patty, y))
    fillPattyByState(patty, x, animatedY)
end

function FryingWorkstation.draw()
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("2  FRYER", 12, 8)
    gfx.drawText("MINCED: " .. PlayerConfig.mincedMeat, 112, 8)
    gfx.drawText("PATTIES: " .. PlayerConfig.patties, 276, 8)

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(fryerX, fryerY, fryerWidth, fryerHeight)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(4)
    gfx.drawRect(fryerX, fryerY, fryerWidth, fryerHeight)

    for slotIndex = 1, frying.slotCount do
        drawPatty(slotIndex)
    end

    gfx.drawText("A: PLACE (-20)    B: FIRE / TAKE", 42, 214)
end
