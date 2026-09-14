import "CoreLibs/graphics"
import "playerConfig"
import "supplyWarning"
import "juiceRuntime"
import "burstDialog"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local frying <const> = PlayerConfig.frying
local juice <const> = Juice
local systemFont <const> = gfx.getSystemFont()
local smallFont <const> = gfx.font.new("/System/Fonts/Roobert-10-Bold") or systemFont
local fire <const> = frying.fire
local fireEffectId <const> = "frying.tray.fire"
local fireStartShake <const> = { amplitude = fire.startShakeAmplitude, startHz = 13, endHz = 6 }
local firePressShake <const> = { amplitude = fire.pressShakeAmplitude, startHz = 14, endHz = 6 }
local firePressRecoil <const> = { duration = .12, impactWeight = .7 }
local fireFont <const> = gfx.font.new("/System/Fonts/Roobert-24-Medium") or systemFont
local fireTitle <const> = "FIRE!"
local firePrompt <const> = "MASH Ⓑ TO PUT OUT"
local fireDialog <const> = BurstDialog.new({
    width = math.max(fireFont:getTextWidth(fireTitle), smallFont:getTextWidth(firePrompt)),
    height = fireFont:getHeight() + smallFont:getHeight() + 4,
    draw = function(width)
        fireFont:drawText(fireTitle, math.floor((width - fireFont:getTextWidth(fireTitle)) / 2), 0)
        smallFont:drawText(firePrompt,
            math.floor((width - smallFont:getTextWidth(firePrompt)) / 2), fireFont:getHeight() + 4)
    end,
})
local fireTarget = nil

local trayScale <const> = 2
local trayX <const> = 40
local trayY <const> = 40

-- Centre of each slot's patty on the scaled tray, relative to its top-left:
-- two zones either side of the divider, two columns each. The grate is drawn
-- in shallow perspective, so the front row spreads wider than the back.
-- Slots 1-4 are the back row and draw first, so the front row overlaps them
-- during a patty's appearance. Centres rather than bottoms, because the sprites'
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
local pattyWidth, pattyHeight = pattyImages.raw:getSize()
local flameFrames <const> = assert(gfx.imagetable.new("resource/grill/flame"))
local oilFrames <const> = assert(gfx.imagetable.new("resource/grill/oil-bubbles"))
local flameFrameCount <const> = flameFrames:getLength()
local oilFrameCount <const> = oilFrames:getLength()
local effectIds <const> = {}
for slotIndex = 1, frying.slotCount do
    effectIds[slotIndex] = "frying.patty." .. slotIndex
end

FryingWorkstation = {}
FryingWorkstation.randomInt = math.random
-- Shown on the controls card; keep in step with handleInput.
FryingWorkstation.help = {
    title = "FRYER",
    summary = "PATTIES COOK BY THEMSELVES, THEN BURN IF THEY ARE LEFT TOO LONG.",
    controls = {
        { "Ⓐ", "GRILL A PATTY (COSTS " .. frying.pattyCost .. " MINCE)" },
        { "Ⓑ", "TAKE A COOKED PATTY" },
        { "ⒷⒷⒷ", "MASH TO PUT OUT EACH FIRE" },
    },
}

local function getBurningPatty()
    for slotIndex = 1, frying.slotCount do
        local patty = frying.slots[slotIndex]
        if patty ~= nil and patty.animation == nil and patty.state == "burning" then
            return patty, slotIndex
        end
    end
end

function FryingWorkstation.isOnFire()
    return getBurningPatty() ~= nil
end

function FryingWorkstation.getFirePressesLeft()
    local patty = getBurningPatty()
    return patty ~= nil and patty.firePressesLeft or 0
end

function FryingWorkstation.isFireDialogVisible()
    return fireDialog:isVisible(juice.time)
end

local function syncFireDialog()
    local patty = getBurningPatty()
    if patty ~= nil and patty.firePressesLeft == nil then
        patty.firePressesLeft = FryingWorkstation.randomInt(fire.minPresses, fire.maxPresses)
    end
    if patty == fireTarget then return end
    fireTarget = patty
    if patty ~= nil then
        fireDialog:show(juice.time)
        juice:verticalShake(fireEffectId, fire.startShakeDuration, fireStartShake)
    else
        fireDialog:hide(juice.time)
    end
end

function FryingWorkstation.placePatty()
    if PlayerConfig.mincedMeat < frying.pattyCost then
        SupplyWarning.request("mince")
        return false
    end

    for slotIndex = 1, frying.slotCount do
        if frying.slots[slotIndex] == nil then
            frying.slots[slotIndex] = {
                elapsedFrames = 0,
                state = "raw",
                animationFrame = 0,
            }
            PlayerConfig.mincedMeat -= frying.pattyCost
            local id = effectIds[slotIndex]
            juice:remove(id)
            juice:ingredientLand(id, { direction = slotIndex % 2 == 0 and 1 or -1 })
            juice:verticalShake(id, Juicy.config.heavyShakeDuration)
            return true
        end
    end

    return false
end

function FryingWorkstation.update(_isActive)
    local burnAt = frying.rawDurationFrames + frying.cookedDurationFrames

    for slotIndex = 1, frying.slotCount do
        local patty = frying.slots[slotIndex]

        if patty ~= nil and patty.animation == "rising" then
            patty.animationFrame += 1

            if patty.animationFrame >=
                frying.riseAnimationDurationFrames then
                frying.slots[slotIndex] = nil
                juice:remove(effectIds[slotIndex])
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
    syncFireDialog()
end

local function startRiseAnimation(patty, slotIndex)
    juice:remove(effectIds[slotIndex])
    patty.animation = "rising"
    patty.animationFrame = 0
end

function FryingWorkstation.pressFireClear()
    local patty, slotIndex = getBurningPatty()
    if patty == nil then return nil end
    syncFireDialog()
    patty.firePressesLeft -= 1
    fireDialog:jolt(juice.time)
    juice:verticalShake(fireEffectId, fire.pressShakeDuration, firePressShake)
    juice:errorShake(fireEffectId, firePressRecoil)
    if patty.firePressesLeft > 0 then
        return "burning"
    end

    -- Clearing the ruined patty never credits inventory or also collects a
    -- cooked one. Any other fire needs its own fresh button presses.
    startRiseAnimation(patty, slotIndex)
    syncFireDialog()
    return "extinguished"
end

function FryingWorkstation.collectOrDiscard()
    if FryingWorkstation.isOnFire() then
        return FryingWorkstation.pressFireClear()
    end

    for slotIndex = 1, frying.slotCount do
        local patty = frying.slots[slotIndex]

        if patty ~= nil and
            patty.animation == nil and
            patty.state == "cooked" then
            startRiseAnimation(patty, slotIndex)
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
    if patty.animation == "rising" then
        local progress = math.min(
            1,
            patty.animationFrame / frying.riseAnimationDurationFrames
        )
        local easedProgress = 1 - (1 - progress) ^ 2

        return targetY - frying.riseDistance * easedProgress
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
local function drawPattySprite(patty, x, y, transform)
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

    if transform.scaleX ~= 1 or transform.scaleY ~= 1 then
        -- The same bottom-centred squash/rebound as the assembly patty.
        -- Skip the barely-started cook dissolve during this 0.12s effect,
        -- avoiding a temporary compositing image or per-frame allocation.
        baseImage:drawScaled(x, y, transform.scaleX, transform.scaleY)
        return
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

-- Use cooking time so animation also advances offscreen and freezes with help
-- cards/rush banners. Slots have different phases even when placed together.
function FryingWorkstation.getCookingEffect(patty, slotIndex)
    if patty == nil or patty.animation == "rising" then return nil end
    local burning = patty.state == "burning"
    local fps = burning and frying.flameFramesPerSecond or frying.oilFramesPerSecond
    local count = burning and flameFrameCount or oilFrameCount
    local frame = (math.floor(patty.elapsedFrames * fps / PlayerConfig.refreshRate) +
        (slotIndex - 1) * 3) % count + 1
    return burning and "flame" or "oil", frame
end

local function drawPatty(slotIndex)
    local x, y = getSlotPosition(slotIndex)
    local patty = frying.slots[slotIndex]

    if patty == nil then
        return
    end

    local transform = juice:getTransform(effectIds[slotIndex])
    local drawX = math.floor(x + pattyWidth * (1 - transform.scaleX) / 2 +
        transform.offsetX + .5)
    local drawY = math.floor(getAnimatedPattyY(patty, y) +
        pattyHeight * (1 - transform.scaleY) + transform.offsetY + .5)
    local effect, frame = FryingWorkstation.getCookingEffect(patty, slotIndex)
    if effect == "oil" then
        -- Oil stays on the grate under the meat, including its landing jiggle.
        -- The 84x42 ring is centred at (42,24) with a transparent middle.
        oilFrames:drawImage(frame, x + math.floor(pattyWidth / 2) - 42,
            y + pattyHeight - 10 - 24)
    end
    drawPattySprite(patty, drawX, drawY, transform)
    if effect == "flame" then
        -- Baseline (32,51) seats the flames over the front of the burnt patty.
        flameFrames:drawImage(frame, drawX + math.floor(pattyWidth / 2) - 32,
            drawY + pattyHeight - 10 - 51)
    end
end

function FryingWorkstation.draw()
    gfx.setColor(gfx.kColorBlack)

    local fireTransform = juice:getTransform(fireEffectId)
    local fireX = math.floor(fireTransform.offsetX + .5)
    local fireY = math.floor(fireTransform.offsetY + .5)
    gfx.pushContext()
    gfx.setDrawOffset(fireX, fireY)
    trayImage:draw(trayX, trayY)

    for slotIndex = 1, frying.slotCount do
        drawPatty(slotIndex)
    end
    gfx.popContext()

    fireDialog:draw(fire.dialogCenterX + fireX, fire.dialogCenterY + fireY, juice.time)
end
