import "CoreLibs/graphics"
import "playerConfig"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local grinder <const> = PlayerConfig.grinder

local meatX <const> = 125
local meatStartY <const> = 8
local meatWidth <const> = 36
local meatHeight <const> = 80
local meatTravelDistance <const> = 97
local meatDropStartY <const> = -meatHeight - 8

local inletX <const> = 112
local inletY <const> = 74
local inletWidth <const> = 62

local machineX <const> = 85
local machineY <const> = 105
local machineWidth <const> = 205
local machineHeight <const> = 80

local outletX <const> = machineX + machineWidth - 2
local outletY <const> = 145
local outletWidth <const> = 30
local outletHeight <const> = 24

local crankPivotX <const> = 275
local crankPivotY <const> = 122

local crankImage = gfx.image.new(90, 90)
gfx.pushContext(crankImage)
    gfx.fillRect(45, 39, 39, 12)
gfx.popContext()

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
            (meatStartY - meatDropStartY) * easedProgress
    end

    return meatStartY +
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
            x = outletX + outletWidth - 2,
            y = outletY + math.random(5, outletHeight - 5),
            velocityX = math.random(14, 25) / 10,
            velocityY = math.random(-12, 5) / 10,
            size = math.random(3, 6),
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

    local meatY = GrinderWorkstation.getDisplayedMeatY()

    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(
        meatX,
        math.floor(meatY),
        meatWidth,
        meatHeight,
        5
    )
end

local function drawMachine()
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(
        machineX,
        machineY,
        machineWidth,
        machineHeight,
        10
    )

    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(4)
    gfx.drawRoundRect(
        machineX,
        machineY,
        machineWidth,
        machineHeight,
        8
    )

    gfx.setLineWidth(3)
    gfx.drawLine(inletX, inletY, inletX, machineY)
    gfx.drawLine(
        inletX + inletWidth,
        inletY,
        inletX + inletWidth,
        machineY
    )
    gfx.drawLine(inletX, inletY, inletX + inletWidth, inletY)

    -- The collar is drawn after the meat so it stays in the foreground
    -- and hides the part of the meat that has entered the machine.
    local collarY = machineY - 12
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(
        inletX - 3,
        collarY,
        inletWidth + 6,
        14
    )
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(3)
    gfx.drawRect(
        inletX - 3,
        collarY,
        inletWidth + 6,
        14
    )

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(
        outletX,
        outletY,
        outletWidth,
        outletHeight,
        4
    )
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(3)
    gfx.drawRoundRect(
        outletX,
        outletY,
        outletWidth,
        outletHeight,
        4
    )

    gfx.drawText("GRINDER", machineX + 56, machineY + 43)
    gfx.fillCircleAtPoint(machineX + 18, machineY + 17, 3)
    gfx.fillCircleAtPoint(
        machineX + machineWidth - 18,
        machineY + machineHeight - 17,
        3
    )
end

local function drawCrank()
    crankImage:drawRotated(
        crankPivotX,
        crankPivotY,
        grinder.crankAngle
    )
end

local function drawOutputParticles()
    gfx.setColor(gfx.kColorBlack)

    for _, particle in ipairs(grinder.outputParticles) do
        gfx.fillRect(
            math.floor(particle.x),
            math.floor(particle.y),
            particle.size,
            particle.size
        )
    end
end

function GrinderWorkstation.draw()
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("1  GRINDER", 12, 10)
    gfx.drawText("MEAT", 24, 75)
    gfx.setLineWidth(2)
    gfx.drawLine(64, 84, inletX - 5, 84)
    gfx.drawLine(inletX - 11, 80, inletX - 5, 84)
    gfx.drawLine(inletX - 11, 88, inletX - 5, 84)

    drawMeat()
    drawMachine()
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
