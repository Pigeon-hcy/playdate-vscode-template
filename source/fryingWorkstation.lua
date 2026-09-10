import "CoreLibs/graphics"
import "playerConfig"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local frying <const> = PlayerConfig.frying

local trayScale <const> = 2
local trayX <const> = 40
local trayY <const> = 40
local dropDistance <const> = 32
local riseDistance <const> = 40

-- Centre of each slot's patty on the scaled tray, relative to its top-left:
-- two zones either side of the divider, two columns each. The grate is drawn
-- in shallow perspective, so the front row spreads wider than the back.
-- Slots 1-4 are the back row and draw first, so the front row overlaps them
-- as a patty drops in. Centres rather than bottoms, because the sprites'
-- outline ring pads every side evenly.
local slotAnchors <const> = {
    { 61, 55 }, { 123, 55 }, { 195, 55 }, { 257, 55 },
    { 54, 87 }, { 121, 87 }, { 198, 87 }, { 264, 87 },
}

assert(
    #slotAnchors == frying.slotCount,
    "slotAnchors must list one position per frying slot"
)

local function loadImage(path)
    local image, loadError = gfx.image.new(path)
    assert(image, loadError)
    return image
end

-- The tray is authored at 160 px; an integer scale keeps its 1-bit pixels
-- crisp. Baking it once onto white -- the cleared screen colour, so it looks
-- identical -- leaves each frame a plain opaque blit with no mask.
local function bakeTray()
    local source = loadImage("resource/GrillTray")
    local width, height = source:getSize()
    local baked = gfx.image.new(
        width * trayScale,
        height * trayScale,
        gfx.kColorWhite
    )

    gfx.pushContext(baked)
        source:drawScaled(0, 0, trayScale)
    gfx.popContext()

    return baked
end

local trayImage <const> = bakeTray()

-- Built by tools/build_station_sprites.py at half size, so two fit per zone.
local pattyImages <const> = {
    raw = loadImage("resource/grill/RawPatty"),
    cooked = loadImage("resource/grill/CookedPatty"),
    burning = loadImage("resource/grill/BurntPatty"),
}

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
    local anchor = slotAnchors[slotIndex]
    local width, height = pattyImages.raw:getSize()

    return
        trayX + anchor[1] - math.floor(width / 2),
        trayY + anchor[2] - math.floor(height / 2)
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

-- The next state dissolves in over the current one as it cooks, so the patty
-- itself shows how close it is to done, and then to burning.
local function drawPattySprite(patty, x, y)
    local cookProgress, burnProgress =
        FryingWorkstation.getFillProgress(patty)
    local baseImage, nextImage, progress

    if patty.state == "raw" then
        baseImage, nextImage, progress =
            pattyImages.raw, pattyImages.cooked, cookProgress
    elseif patty.state == "cooked" then
        baseImage, nextImage, progress =
            pattyImages.cooked, pattyImages.burning, burnProgress
    else
        baseImage, nextImage, progress = pattyImages.burning, nil, 0
    end

    baseImage:draw(x, y)

    if nextImage ~= nil and progress > 0 then
        nextImage:drawFaded(
            x,
            y,
            progress,
            gfx.image.kDitherTypeBayer8x8
        )
    end
end

local function drawPatty(slotIndex)
    local x, y = getSlotPosition(slotIndex)
    local patty = frying.slots[slotIndex]

    if patty == nil then
        return
    end

    local animatedY = math.floor(getAnimatedPattyY(patty, y))
    drawPattySprite(patty, x, animatedY)
end

function FryingWorkstation.draw()
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("2  FRYER", 12, 8)
    gfx.drawText("MINCED: " .. PlayerConfig.mincedMeat, 112, 8)
    gfx.drawText("PATTIES: " .. PlayerConfig.patties, 276, 8)

    trayImage:draw(trayX, trayY)

    for slotIndex = 1, frying.slotCount do
        drawPatty(slotIndex)
    end

    gfx.drawText("A: PLACE (-20)    B: FIRE / TAKE", 42, 214)
end
