import "CoreLibs/graphics"
import "playerConfig"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local grinder <const> = PlayerConfig.grinder

-- Where the machine sits on screen, and points measured on its art. The
-- mounting values in resource/GENERATED_ASSETS.md are off by up to 19 px, so
-- these were measured on the PNGs themselves.
local bodyX <const> = 130
local bodyY <const> = 76
local hopperCenterX <const> = bodyX + 48
local hopperRimY <const> = bodyY + 12
local crankMountX <const> = bodyX + 34
local crankMountY <const> = bodyY + 78
local outletX <const> = bodyX + 154
local outletTopY <const> = bodyY + 66
local outletBottomY <const> = bodyY + 90

-- Where the grip points in the unrotated art, clockwise from straight up.
-- Subtracting it makes the grip follow the physical crank, which reads 0 when
-- pointing up.
local crankGripAngle <const> = 250

-- How far the resting meat sits down into the hopper mouth.
local meatSeat <const> = 6

local function loadImage(path)
    local image, loadError = gfx.image.new(path)
    assert(image, loadError)
    return image
end

local bodyImage <const> = loadImage("resource/GrinderBody")

-- Built by tools/build_station_sprites.py, stood on end and shrunk to
-- feed down into the hopper.
local meatImage <const> = loadImage("resource/grinder/RawMeat")
local meatWidth, meatHeight = meatImage:getSize()
local meatRestY <const> = hopperRimY - meatHeight + meatSeat
local meatTravelDistance <const> = meatHeight - meatSeat
local meatDropStartY <const> = -meatHeight - 8

local function loadFrames(path)
    local frameTable, loadError = gfx.imagetable.new(path)
    assert(frameTable, loadError)

    local frames = {}

    for index = 1, frameTable:getLength() do
        frames[index] = frameTable:getImage(index)
    end

    return frames
end

-- The crank pre-rendered at every rotation step, centred on its hub. Picking
-- a frame is a plain blit, where drawRotated would resample the thin dithered
-- arm into a broken string of dots at most angles.
local crankFrames <const> = loadFrames("resource/grinder/crank")
local crankHalf <const> = math.floor(crankFrames[1]:getSize() / 2)

-- Every fully opaque 4x4 cell of the meat, cut by the build script, so each
-- particle is a real crumb of it rather than a plain square.
local minceImages <const> = loadFrames("resource/grinder/mince")

GrinderWorkstation = {}
GrinderWorkstation.usesCrank = true

local function chooseMeatYield()
    local choices = grinder.possibleYields
    return choices[math.random(#choices)]
end

function GrinderWorkstation.loadNewMeat()
    if grinder.hasMeat then
        return false
    end

    grinder.hasMeat = true
    grinder.totalYield = chooseMeatYield()
    grinder.producedYield = 0
    grinder.processedDegrees = 0
    grinder.isLoadingMeat = true
    grinder.loadAnimationFrame = 0

    return true
end

function GrinderWorkstation.initialize()
    grinder.outputParticles = {}
    GrinderWorkstation.loadNewMeat()
end

function GrinderWorkstation.handleInput()
    if pd.buttonJustPressed(pd.kButtonDown) then
        GrinderWorkstation.loadNewMeat()
    end
end

function GrinderWorkstation.getMeatProgress()
    if grinder.totalYield <= 0 then
        return 0
    end

    local requiredDegrees =
        (grinder.totalYield / grinder.meatPerCrankTurn) * 360

    return math.min(1, grinder.processedDegrees / requiredDegrees)
end

function GrinderWorkstation.getDisplayedMeatY()
    if grinder.isLoadingMeat then
        local animationProgress = math.min(
            1,
            grinder.loadAnimationFrame /
                grinder.loadAnimationDurationFrames
        )
        local easedProgress = 1 - (1 - animationProgress) ^ 3

        return meatDropStartY +
            (meatRestY - meatDropStartY) * easedProgress
    end

    return meatRestY +
        GrinderWorkstation.getMeatProgress() * meatTravelDistance
end

local function updateMeatLoading()
    if not grinder.isLoadingMeat then
        return
    end

    grinder.loadAnimationFrame = math.min(
        grinder.loadAnimationDurationFrames,
        grinder.loadAnimationFrame + 1
    )

    if grinder.loadAnimationFrame >=
        grinder.loadAnimationDurationFrames then
        grinder.isLoadingMeat = false
    end
end

local function spawnOutputParticles(particleCount)
    for _ = 1, particleCount do
        if #grinder.outputParticles >= grinder.maxOutputParticles then
            return
        end

        grinder.outputParticles[#grinder.outputParticles + 1] = {
            x = outletX,
            y = math.random(outletTopY, outletBottomY),
            velocityX = math.random(14, 25) / 10,
            velocityY = math.random(-12, 5) / 10,
            crumb = math.random(#minceImages),
            life = grinder.particleLifeFrames,
        }
    end
end

local function updateOutputParticles()
    for particleIndex = #grinder.outputParticles, 1, -1 do
        local particle = grinder.outputParticles[particleIndex]

        particle.x += particle.velocityX
        particle.y += particle.velocityY
        particle.velocityY += 0.08
        particle.life -= 1

        if particle.life <= 0 or particle.x > PlayerConfig.screenWidth then
            table.remove(grinder.outputParticles, particleIndex)
        end
    end
end

function GrinderWorkstation.processCrank(crankDegrees)
    if not grinder.hasMeat or
        grinder.isLoadingMeat or
        crankDegrees <= 0 then
        return
    end

    grinder.processedDegrees += crankDegrees

    local producedYield = math.min(
        grinder.totalYield,
        math.floor(
            (grinder.processedDegrees / 360) * grinder.meatPerCrankTurn
        )
    )
    local newlyProduced = producedYield - grinder.producedYield

    if newlyProduced > 0 then
        grinder.producedYield = producedYield
        PlayerConfig.mincedMeat += newlyProduced
        spawnOutputParticles(newlyProduced)
    end

    if grinder.producedYield >= grinder.totalYield then
        grinder.hasMeat = false
    end
end

function GrinderWorkstation.update(isActive)
    grinder.crankAngle = pd.getCrankPosition()
    updateMeatLoading()
    updateOutputParticles()

    if not isActive then
        return
    end

    local crankChange = pd.getCrankChange()
    GrinderWorkstation.processCrank(math.abs(crankChange))
end

local function drawMeat()
    if not grinder.hasMeat then
        return
    end

    -- Only the part above the rim shows; below it the meat has gone into the
    -- hopper. A clip rather than letting the body cover it, because the
    -- funnel narrows and the meat would poke out past its sides.
    gfx.setClipRect(0, 0, PlayerConfig.screenWidth, hopperRimY)
    meatImage:draw(
        hopperCenterX - math.floor(meatWidth / 2),
        math.floor(GrinderWorkstation.getDisplayedMeatY())
    )
    gfx.clearClipRect()
end

local function drawCrank()
    local frameCount = #crankFrames
    local rotation = (grinder.crankAngle - crankGripAngle) % 360
    local frame =
        math.floor(rotation / 360 * frameCount + 0.5) % frameCount + 1

    crankFrames[frame]:draw(
        crankMountX - crankHalf,
        crankMountY - crankHalf
    )
end

local function drawOutputParticles()
    for _, particle in ipairs(grinder.outputParticles) do
        minceImages[particle.crumb]:draw(
            math.floor(particle.x),
            math.floor(particle.y)
        )
    end
end

function GrinderWorkstation.draw()
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("1  GRINDER", 12, 10)

    drawMeat()
    bodyImage:draw(bodyX, bodyY)
    drawCrank()
    drawOutputParticles()

    gfx.drawText(
        "MINCED: " .. math.floor(PlayerConfig.mincedMeat),
        276,
        210
    )

    if grinder.isLoadingMeat then
        gfx.drawText("LOADING...", 12, 210)
    elseif grinder.hasMeat then
        local remainingYield = grinder.totalYield - grinder.producedYield
        gfx.drawText("LEFT: " .. remainingYield, 12, 210)
    else
        gfx.drawText("DOWN: NEW MEAT", 12, 210)
    end
end
