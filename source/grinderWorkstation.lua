import "CoreLibs/graphics"
import "playerConfig"
import "juiceRuntime"
import "burstDialog"
import "minceCounter"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local grinder <const> = PlayerConfig.grinder
local systemFont <const> = gfx.getSystemFont()
local smallFont <const> = gfx.font.new("/System/Fonts/Roobert-10-Bold") or systemFont
local juice <const> = Juice
local meatEffectId <const> = "grinder.meat"
local machineEffectId <const> = "grinder.machine"
-- Reused options: refreshing the vibration while cranking preserves phase
-- without allocating a table each frame. A short tail settles after stopping.
local grindShakeOptions <const> = { amplitude = 2, startHz = 10, endHz = 10 }
local machineShakeOptions <const> = { amplitude = 1, startHz = 8, endHz = 8 }
local machineRecoilOptions <const> = { duration = .10, impactWeight = .4 }
local particleEmissionIndex = 0
local lastMachineRecoilTime = -math.huge

-- Meat jam event. After cooldown, select the first, second or third new piece
-- and seize halfway through processing it. Pieces started during cooldown and
-- the remainder of a cleared piece cannot count toward the next event.
local jam <const> = grinder.jam
local jamActive = false
local jamPressesLeft = 0
local jamMeatCount = 0
local jamMeatCounted = false
local jamThisMeat = false
local jamTarget = 0
local jamReadyAt = 0
local jamCount = 0
local jamStartShakeOptions <const> =
    { amplitude = jam.startShakeAmplitude, startHz = 13, endHz = 5 }
local jamPressShakeOptions <const> =
    { amplitude = jam.pressShakeAmplitude, startHz = 14, endHz = 6 }
local jamPressRecoilOptions <const> =
    { duration = .12, impactWeight = jam.pressRecoil }
local bigFont <const> = gfx.font.new("/System/Fonts/Roobert-24-Medium") or systemFont
local jamTitle <const> = "MEAT JAM!"
local jamPrompt <const> = "MASH DOWN"
local jamTitleWidth <const> = bigFont:getTextWidth(jamTitle)
local jamPromptWidth <const> = smallFont:getTextWidth(jamPrompt)
local jamArrowWidth <const> = 26
local jamArrowHeight <const> = 15

local function drawJamContent(width)
    local y = 0
    gfx.setFont(bigFont)
    gfx.drawText(jamTitle, math.floor((width - jamTitleWidth) / 2), y)
    y += bigFont:getHeight() + 4
    gfx.setFont(smallFont)
    gfx.drawText(jamPrompt, math.floor((width - jamPromptWidth) / 2), y)
    y += smallFont:getHeight() + 5
    -- The down arrow the prompt is asking for, drawn rather than typed: the
    -- only font with a ⬇ glyph is 10 point, too small to read at a glance.
    gfx.setColor(gfx.kColorBlack)
    local centerX = width / 2
    gfx.fillTriangle(centerX - jamArrowWidth / 2, y,
        centerX + jamArrowWidth / 2, y, centerX, y + jamArrowHeight)
    gfx.setFont(systemFont)
end

local jamDialog <const> = BurstDialog.new({
    width = math.max(jamTitleWidth, jamPromptWidth, jamArrowWidth),
    height = bigFont:getHeight() + 4 + smallFont:getHeight() + 5 + jamArrowHeight,
    draw = drawJamContent,
})

-- Where the machine sits on screen, and points measured on its art. The
-- mounting values in resource/GENERATED_ASSETS.md are off by up to 19 px, so
-- these were measured on the PNGs themselves.
-- Keep the tall raw meat to the left of the fixed top-centre order holder.
local bodyX <const> = 46
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
-- Shown on the controls card; keep in step with handleInput and update.
GrinderWorkstation.help = {
    title = "GRINDER",
    summary = "RAW MEAT GOES IN, MINCE COMES OUT. THE FRYER USES " ..
        PlayerConfig.frying.pattyCost .. " MINCE PER PATTY.",
    controls = {
        { "🎣", "CRANK TO GRIND THE MEAT" },
        { "⬇", "LOAD A NEW BLOCK OF MEAT" },
        { "⬇⬇⬇", "MASH TO CLEAR A MEAT JAM" },
    },
}
-- Overridable so tests can pin the jam threshold and press count.
GrinderWorkstation.randomInt = math.random

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
    jamMeatCounted = false
    jamThisMeat = false
    particleEmissionIndex = 0
    lastMachineRecoilTime = -math.huge
    -- Appear already seated in the hopper. Shake only render offsets so
    -- grinding can start immediately and the feed position never drifts.
    juice:remove(meatEffectId)
    juice:verticalShake(meatEffectId, Juicy.config.heavyShakeDuration)
    juice:verticalShake(machineEffectId, .25, { amplitude = 2, startHz = 10, endHz = 4 })

    return true
end

-- Draw a fresh target and hold the event off for the cooldown.
function GrinderWorkstation.resetJamSchedule()
    jamActive = false
    jamPressesLeft = 0
    jamMeatCount = 0
    jamThisMeat = false
    jamTarget = GrinderWorkstation.randomInt(jam.minMeatCount, jam.maxMeatCount)
    jamReadyAt = juice.time + jam.cooldown
    jamDialog:cancel()
end

function GrinderWorkstation.initialize()
    grinder.outputParticles = {}
    jamCount = 0
    GrinderWorkstation.resetJamSchedule()
    jamReadyAt = juice.time
    jamMeatCounted = false
    GrinderWorkstation.loadNewMeat()
end

function GrinderWorkstation.isJammed()
    return jamActive
end

function GrinderWorkstation.getJamPressesLeft()
    return jamPressesLeft
end

function GrinderWorkstation.getJamCount()
    return jamCount
end

function GrinderWorkstation.handleInput()
    if pd.buttonJustPressed(pd.kButtonDown) then
        if jamActive then
            GrinderWorkstation.pressJamClear()
        else
            GrinderWorkstation.loadNewMeat()
        end
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
    return meatRestY +
        GrinderWorkstation.getMeatProgress() * meatTravelDistance
end

local function getMachineOffsets()
    local transform = juice:getTransform(machineEffectId)
    return math.floor(transform.offsetX + .5), math.floor(transform.offsetY + .5)
end

local function spawnOutputParticles(particleCount, force)
    local launchSpeed = grinder.particleMinSpeed +
        (grinder.particleMaxSpeed - grinder.particleMinSpeed) * force
    local machineOffsetX, machineOffsetY = getMachineOffsets()
    for _ = 1, particleCount do
        if #grinder.outputParticles >= grinder.maxOutputParticles then
            return
        end

        particleEmissionIndex += 1
        local isHopper = particleEmissionIndex % grinder.hopperParticleEvery == 0
        local particle
        if isHopper then
            -- Alternate sides of the meat so crumbs read clearly at the rim.
            -- These replace outlet crumbs, sharing the same 48-particle cap.
            local side = (particleEmissionIndex / grinder.hopperParticleEvery) % 2 == 0 and 1 or -1
            local rimY = hopperRimY - 4 + machineOffsetY
            particle = {
                source = "hopper",
                x = hopperCenterX + side * (meatWidth * .4 + math.random(0, 4)) + machineOffsetX,
                y = rimY,
                returnY = rimY,
                velocityX = side * (.7 + .8 * force) * math.random(85, 115) / 100,
                velocityY = -(2.3 + 1.2 * force) * math.random(85, 115) / 100,
                life = grinder.hopperParticleLifeFrames,
            }
        else
            particle = {
                source = "outlet",
                x = outletX + machineOffsetX,
                y = math.random(outletTopY, outletBottomY) + machineOffsetY,
                velocityX = launchSpeed * math.random(85, 115) / 100,
                velocityY = -(0.8 + 1.8 * force) + math.random(-4, 4) / 10,
                life = grinder.particleLifeFrames,
            }
        end
        particle.crumb = math.random(#minceImages)
        grinder.outputParticles[#grinder.outputParticles + 1] = particle
    end
end

local function updateOutputParticles()
    for particleIndex = #grinder.outputParticles, 1, -1 do
        local particle = grinder.outputParticles[particleIndex]

        particle.x += particle.velocityX
        particle.y += particle.velocityY
        particle.velocityX *= grinder.particleDrag
        particle.velocityY += particle.source == "hopper" and
            grinder.hopperParticleGravity or grinder.particleGravity
        particle.life -= 1

        local returnedToRim = particle.source == "hopper" and
            particle.velocityY > 0 and particle.y >= particle.returnY
        if particle.life <= 0 or particle.x > PlayerConfig.screenWidth or
            particle.x < -4 or particle.y > PlayerConfig.screenHeight or returnedToRim then
            table.remove(grinder.outputParticles, particleIndex)
        end
    end
end

-- Seize the machine. Grinding and the crank stop until the player mashes it
-- free; the meat keeps its place in the hopper because nothing is processed.
function GrinderWorkstation.startJam()
    if jamActive or not grinder.hasMeat or juice.time < jamReadyAt then
        return false
    end

    jamActive = true
    jamMeatCounted = true
    jamCount += 1
    jamPressesLeft = GrinderWorkstation.randomInt(jam.minPresses, jam.maxPresses)
    jamDialog:show(juice.time)
    juice:verticalShake(machineEffectId, jam.startShakeDuration, jamStartShakeOptions)
    return true
end

function GrinderWorkstation.pressJamClear()
    if not jamActive then
        return nil
    end

    jamPressesLeft -= 1
    juice:verticalShake(machineEffectId, jam.pressShakeDuration, jamPressShakeOptions)
    juice:errorShake(machineEffectId, jamPressRecoilOptions)
    -- Crumbs shaken loose by the blow; these carry no yield.
    spawnOutputParticles(jam.pressParticles, 1)

    if jamPressesLeft > 0 then
        jamDialog:jolt(juice.time)
        return "stuck"
    end

    local now = juice.time
    GrinderWorkstation.resetJamSchedule()
    jamDialog:show(now)
    jamDialog:hide(now)
    return "cleared"
end

function GrinderWorkstation.processCrank(crankDegrees)
    if jamActive or not grinder.hasMeat or crankDegrees <= 0 then
        return
    end

    -- Count only the first actual crank movement on each piece, not loading,
    -- elapsed time, or further turns on the same piece.
    if not jamMeatCounted then
        jamMeatCounted = true
        if juice.time >= jamReadyAt then
            jamMeatCount += 1
            jamThisMeat = jamMeatCount >= jamTarget
        end
    end
    local jamAtDegrees = grinder.totalYield / grinder.meatPerCrankTurn * 360 * jam.triggerProgress

    local force = math.min(1, crankDegrees / grinder.fullForceCrankDegrees)
    grindShakeOptions.amplitude = 1.5 + 1.3 * force
    grindShakeOptions.startHz = 9 + 3 * force
    grindShakeOptions.endHz = grindShakeOptions.startHz
    juice:verticalShake(meatEffectId, grinder.grindShakeDuration, grindShakeOptions)
    machineShakeOptions.amplitude = .7 + force
    machineShakeOptions.startHz = 7 + 3 * force
    machineShakeOptions.endHz = machineShakeOptions.startHz
    juice:verticalShake(machineEffectId, grinder.grindShakeDuration, machineShakeOptions)

    grinder.processedDegrees += crankDegrees
    if jamThisMeat then
        -- Even one huge crank sample must stop at the jam, leaving real meat
        -- in the hopper. Extra movement is discarded rather than banked.
        grinder.processedDegrees = math.min(grinder.processedDegrees, jamAtDegrees)
    end

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
        -- Render only the short horizontal recoil; no inversion or scaling
        -- of the dithered machine. Its vertical vibration keeps its phase.
        if juice.time - lastMachineRecoilTime >= machineRecoilOptions.duration then
            machineRecoilOptions.impactWeight = .25 + .30 * force
            juice:errorShake(machineEffectId, machineRecoilOptions)
            lastMachineRecoilTime = juice.time
        end
        spawnOutputParticles(newlyProduced, force)
    end

    if grinder.producedYield >= grinder.totalYield then
        grinder.hasMeat = false
        juice:remove(meatEffectId)
        return
    end

    if jamThisMeat and grinder.processedDegrees >= jamAtDegrees then
        GrinderWorkstation.startJam()
    end
end

function GrinderWorkstation.update(isActive)
    -- A jammed crank is stuck where it stopped, however the real one is held.
    if not jamActive then
        grinder.crankAngle = pd.getCrankPosition()
    end
    updateOutputParticles()

    if not isActive then
        return
    end

    local crankChange = pd.getCrankChange()
    if jamActive then
        -- Read and discard, so rotation made while stuck is not banked up
        -- and spent the instant the jam clears.
        return
    end
    GrinderWorkstation.processCrank(math.abs(crankChange))
end

local function drawMeat(machineOffsetX, machineOffsetY)
    if not grinder.hasMeat then
        return
    end

    -- Only the part above the rim shows; below it the meat has gone into the
    -- hopper. A clip rather than letting the body cover it, because the
    -- funnel narrows and the meat would poke out past its sides.
    gfx.setClipRect(0, 0, PlayerConfig.screenWidth, hopperRimY + machineOffsetY)
    meatImage:draw(
        hopperCenterX - math.floor(meatWidth / 2) + machineOffsetX,
        math.floor(GrinderWorkstation.getDisplayedMeatY() +
            juice:getTransform(meatEffectId).offsetY + .5) + machineOffsetY
    )
    gfx.clearClipRect()
end

local function drawCrank(machineOffsetX, machineOffsetY)
    local frameCount = #crankFrames
    local rotation = (grinder.crankAngle - crankGripAngle) % 360
    local frame =
        math.floor(rotation / 360 * frameCount + 0.5) % frameCount + 1

    crankFrames[frame]:draw(
        crankMountX - crankHalf + machineOffsetX,
        crankMountY - crankHalf + machineOffsetY
    )
end

local function drawOutputParticles()
    local oldLineWidth = gfx.getLineWidth()
    gfx.setLineWidth(1)
    for _, particle in ipairs(grinder.outputParticles) do
        local x, y = math.floor(particle.x), math.floor(particle.y)
        -- A short launch streak emphasizes the initial impulse; existing
        -- crumb sprites carry the rest of the arc. No extra particles/images.
        if particle.source == "outlet" and
            particle.life > grinder.particleLifeFrames - grinder.particleTrailFrames then
            gfx.drawLine(x, y,
                x - math.min(8, math.floor(particle.velocityX)),
                y - math.floor(particle.velocityY))
        end
        minceImages[particle.crumb]:draw(
            x,
            y
        )
    end
    gfx.setLineWidth(oldLineWidth)
end

function GrinderWorkstation.draw()
    gfx.setColor(gfx.kColorBlack)
    MinceCounter.draw(PlayerConfig.mincedMeat)

    -- Move the hopper clip, body and crank together using integer blits.
    local machineOffsetX, machineOffsetY = getMachineOffsets()
    drawMeat(machineOffsetX, machineOffsetY)
    bodyImage:draw(bodyX + machineOffsetX, bodyY + machineOffsetY)
    drawCrank(machineOffsetX, machineOffsetY)
    drawOutputParticles()

    -- Roobert 10 Bold for the whole line: it carries the button glyphs.
    gfx.setFont(smallFont)
    if jamActive then
        gfx.drawText("⬇⬇⬇  MASH TO UNJAM", 12, 212)
    elseif grinder.hasMeat then
        gfx.drawText("🎣  GRIND", 12, 212)
    else
        gfx.drawText("⬇  NEW MEAT", 12, 212)
    end
    gfx.setFont(systemFont)

    jamDialog:draw(jam.dialogCenterX, jam.dialogCenterY, juice.time)
end
