--[[
Tiny Playdate game-feel helpers.

    Juice.shake(3, 100)
    Juice.hitstop(2)
    Juice.bump(sprite)
    Juice.squash(sprite, 1.2, 0.8, 100)
    Juice.flash(sprite)
    Juice.popup("+1", 200, 100)
    Juice.burst(200, 100, 5, "spark")

Call Juice.update() before gameplay updates, then Juice.draw() after drawing
the game. Juice.update() keeps its own effects alive during hitstop.
]]

import "CoreLibs/graphics"
import "CoreLibs/easing"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local easing <const> = playdate.easingFunctions

local DEFAULT_FRAME_MS <const> = 1000 / 30
local MAX_DELTA_MS <const> = 50
local MAX_POPUPS <const> = 8
local MAX_PARTICLES <const> = 48
local MAX_BURST_AMOUNT <const> = 8

local SHAKE_PATTERN <const> = {
    { 1.00, 0.00 },
    { -0.70, 0.70 },
    { 0.25, -1.00 },
    { 0.75, 0.45 },
    { -1.00, -0.20 },
    { 0.40, 0.90 },
    { -0.35, -0.75 },
    { 0.90, -0.45 },
}

local PUNCH_PRESETS <const> = {
    soft = { intensity = 1, duration = 70, hitstop = 0 },
    medium = { intensity = 2, duration = 100, hitstop = 1 },
    heavy = { intensity = 4, duration = 140, hitstop = 2 },
}

local PARTICLE_STYLES <const> = {
    crumb = {
        lifeMin = 220,
        lifeMax = 360,
        speedMin = 10,
        speedMax = 25,
        gravity = 0.10,
    },
    grease = {
        lifeMin = 180,
        lifeMax = 300,
        speedMin = 8,
        speedMax = 20,
        gravity = 0.08,
    },
    spark = {
        lifeMin = 150,
        lifeMax = 260,
        speedMin = 18,
        speedMax = 34,
        gravity = 0,
    },
    steam = {
        lifeMin = 320,
        lifeMax = 520,
        speedMin = 6,
        speedMax = 14,
        gravity = -0.015,
    },
}

Juice = {}

local shakeState = {
    intensity = 0,
    remaining = 0,
    patternIndex = 1,
    axis = "both",
}

local freezeFrames = 0
local frozenThisFrame = false
local lastUpdateMilliseconds = nil
local updateFrame = 0

local scaleEffects = {}
local flashEffects = {}
local popups = {}
local particles = {}
local sounds = {}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function lerp(from, to, progress)
    return from + (to - from) * progress
end

local function removeBySwap(items, index)
    items[index] = items[#items]
    items[#items] = nil
end

local function getDeltaMilliseconds()
    local now = pd.getCurrentTimeMilliseconds()
    local delta = DEFAULT_FRAME_MS

    if lastUpdateMilliseconds ~= nil then
        delta = now - lastUpdateMilliseconds

        if delta <= 0 then
            delta = DEFAULT_FRAME_MS
        end
    end

    lastUpdateMilliseconds = now
    return math.min(MAX_DELTA_MS, delta)
end

local function startShake(intensity, duration, axis)
    intensity = math.max(0, intensity or 0)
    duration = math.max(0, duration or 0)

    if intensity == 0 or duration == 0 then
        return false
    end

    if shakeState.remaining <= 0 then
        shakeState.patternIndex = 1
        shakeState.axis = axis or "both"
    elseif shakeState.axis ~= (axis or "both") then
        shakeState.axis = "both"
    end

    shakeState.intensity = math.max(shakeState.intensity, intensity)
    shakeState.remaining = math.max(shakeState.remaining, duration)
    return true
end

function Juice.shake(intensity, duration)
    return startShake(intensity or 2, duration or 100, "both")
end

function Juice.hitstop(frames)
    frames = math.max(0, math.floor(frames or 1))
    freezeFrames = math.max(freezeFrames, frames)

    if frames > 0 then
        frozenThisFrame = true
    end
end

function Juice.isFrozen()
    return frozenThisFrame
end

local function findSpriteEffect(effects, sprite)
    for index = 1, #effects do
        if effects[index].sprite == sprite then
            return effects[index]
        end
    end

    return nil
end

local function startScaleEffect(
    sprite,
    kind,
    scaleX,
    scaleY,
    duration
)
    if sprite == nil then
        return false
    end

    local effect = findSpriteEffect(scaleEffects, sprite)

    if effect == nil then
        local baseScaleX, baseScaleY = sprite:getScale()
        effect = {
            sprite = sprite,
            baseScaleX = baseScaleX,
            baseScaleY = baseScaleY,
        }
        scaleEffects[#scaleEffects + 1] = effect
    end

    effect.kind = kind
    effect.targetScaleX = math.max(0.05, scaleX)
    effect.targetScaleY = math.max(0.05, scaleY)
    effect.duration = math.max(1, duration)
    effect.elapsed = 0
    return true
end

function Juice.bump(sprite, amount, duration)
    amount = amount or 1.15
    return startScaleEffect(
        sprite,
        "bump",
        amount,
        amount,
        duration or 120
    )
end

function Juice.squash(sprite, scaleX, scaleY, duration)
    return startScaleEffect(
        sprite,
        "squash",
        scaleX or 1.20,
        scaleY or 0.80,
        duration or 140
    )
end

function Juice.flash(sprite, duration)
    if sprite == nil then
        return false
    end

    local effect = findSpriteEffect(flashEffects, sprite)

    if effect == nil then
        effect = {
            sprite = sprite,
            originallyVisible = sprite:isVisible(),
        }
        flashEffects[#flashEffects + 1] = effect
    end

    effect.duration = math.max(1, duration or 140)
    effect.elapsed = 0
    return true
end

function Juice.popup(text, x, y, options)
    options = options or {}

    if #popups >= MAX_POPUPS then
        table.remove(popups, 1)
    end

    popups[#popups + 1] = {
        text = tostring(text),
        x = x or 200,
        y = y or 120,
        duration = math.max(1, options.duration or 500),
        rise = options.rise or 15,
        font = options.font,
        elapsed = 0,
    }
end

local function randomBetween(minimum, maximum)
    return math.random(minimum, maximum) / 10
end

local function addParticle(x, y, styleName, style)
    if #particles >= MAX_PARTICLES then
        return
    end

    local velocityX
    local velocityY

    if styleName == "steam" then
        velocityX = randomBetween(-4, 4)
        velocityY = -randomBetween(style.speedMin, style.speedMax)
    else
        local angle = math.random() * math.pi * 2
        local speed = randomBetween(style.speedMin, style.speedMax)
        velocityX = math.cos(angle) * speed
        velocityY = math.sin(angle) * speed
    end

    particles[#particles + 1] = {
        x = x,
        y = y,
        velocityX = velocityX,
        velocityY = velocityY,
        gravity = style.gravity,
        style = styleName,
        size = math.random(1, 3),
        elapsed = 0,
        lifetime = math.random(style.lifeMin, style.lifeMax),
        phase = math.random(0, 5),
    }
end

function Juice.burst(x, y, amount, styleName)
    styleName = styleName or "crumb"
    local style = PARTICLE_STYLES[styleName]

    if style == nil then
        styleName = "crumb"
        style = PARTICLE_STYLES.crumb
    end

    amount = clamp(math.floor(amount or 5), 1, MAX_BURST_AMOUNT)

    for _ = 1, amount do
        addParticle(x or 200, y or 120, styleName, style)
    end
end

function Juice.setSound(name, soundPlayer)
    if soundPlayer == nil then
        sounds[name] = nil
    else
        sounds[name] = soundPlayer
    end
end

local function playSound(name)
    local sound = sounds[name]

    if sound == nil then
        return
    end

    if type(sound) == "function" then
        sound()
    else
        sound:play()
    end
end

function Juice.punch(level)
    level = level or "medium"
    local preset = PUNCH_PRESETS[level]

    if preset == nil then
        level = "medium"
        preset = PUNCH_PRESETS.medium
    end

    Juice.shake(preset.intensity, preset.duration)

    if preset.hitstop > 0 then
        Juice.hitstop(preset.hitstop)
    end

    playSound("punch" .. level:sub(1, 1):upper() .. level:sub(2))
end

function Juice.success(x, y)
    Juice.shake(1, 80)
    Juice.popup("SUCCESS!", x, y, { duration = 420, rise = 16 })
    Juice.burst(x, y, 5, "spark")
    playSound("success")
end

function Juice.fail(x, y)
    startShake(3, 160, "x")
    Juice.popup("WRONG!", x, y, { duration = 500, rise = 10 })
    Juice.burst(x, y, 4, "crumb")
    playSound("fail")
end

function Juice.fire(x, y)
    startShake(1, 280, "both")
    Juice.popup("FIRE!", x, y, { duration = 460, rise = 12 })
    Juice.burst(x, y, 3, "spark")
    Juice.burst(x, y, 4, "steam")
    playSound("fire")
end

function Juice.pattyDrop(sprite, x, y)
    Juice.shake(2, 90)
    Juice.squash(sprite, 1.18, 0.72, 130)
    Juice.burst(x, y, 5, "grease")
    playSound("pattyDrop")
end

function Juice.pattyReady(sprite, x, y)
    Juice.bump(sprite, 1.10, 120)
    Juice.flash(sprite, 150)
    Juice.popup("READY!", x, y - 8, { duration = 430, rise = 15 })
    Juice.burst(x, y, 3, "steam")
    playSound("pattyReady")
end

function Juice.pattyBurn(sprite, x, y)
    startShake(1, 240, "both")
    Juice.flash(sprite, 320)
    Juice.burst(x, y, 4, "steam")
    playSound("pattyBurn")
end

function Juice.orderComplete(x, y)
    Juice.punch("heavy")
    Juice.popup(
        "ORDER COMPLETE!",
        x,
        y,
        { duration = 620, rise = 22 }
    )
    Juice.burst(x, y, 8, "spark")
    playSound("orderComplete")
end

function Juice.perfect(x, y)
    Juice.hitstop(2)
    Juice.shake(4, 150)
    Juice.popup("PERFECT!", x, y, { duration = 650, rise = 24 })
    Juice.burst(x, y, 8, "spark")
    playSound("perfect")
end

function Juice.buttonPress(sprite)
    Juice.squash(sprite, 1.06, 0.92, 80)
    playSound("buttonPress")
end

local function updateShake(deltaMilliseconds)
    if shakeState.remaining <= 0 then
        return
    end

    shakeState.remaining -= deltaMilliseconds

    if shakeState.remaining <= 0 then
        shakeState.remaining = 0
        shakeState.intensity = 0
        pd.display.setOffset(0, 0)
        return
    end

    local point = SHAKE_PATTERN[shakeState.patternIndex]
    shakeState.patternIndex =
        (shakeState.patternIndex % #SHAKE_PATTERN) + 1

    local x = math.floor(point[1] * shakeState.intensity)
    local y = math.floor(point[2] * shakeState.intensity)

    if shakeState.axis == "x" then
        y = 0
    elseif shakeState.axis == "y" then
        x = 0
    end

    pd.display.setOffset(x, y)
end

local function updateScaleEffects(deltaMilliseconds)
    for index = #scaleEffects, 1, -1 do
        local effect = scaleEffects[index]
        effect.elapsed += deltaMilliseconds

        local progress = clamp(effect.elapsed / effect.duration, 0, 1)
        local scaleX
        local scaleY

        if effect.kind == "bump" then
            if progress < 0.38 then
                local outward = easing.outBack(
                    progress / 0.38,
                    0,
                    1,
                    1
                )
                scaleX = lerp(1, effect.targetScaleX, outward)
                scaleY = lerp(1, effect.targetScaleY, outward)
            else
                local returning = easing.outCubic(
                    (progress - 0.38) / 0.62,
                    0,
                    1,
                    1
                )
                scaleX = lerp(effect.targetScaleX, 1, returning)
                scaleY = lerp(effect.targetScaleY, 1, returning)
            end
        elseif progress < 0.30 then
            local squashIn = easing.outBack(
                progress / 0.30,
                0,
                1,
                1
            )
            scaleX = lerp(1, effect.targetScaleX, squashIn)
            scaleY = lerp(1, effect.targetScaleY, squashIn)
        elseif progress < 0.55 then
            local rebound = easing.outCubic(
                (progress - 0.30) / 0.25,
                0,
                1,
                1
            )
            local reboundX = 1 - (effect.targetScaleX - 1) * 0.20
            local reboundY = 1 - (effect.targetScaleY - 1) * 0.20
            scaleX = lerp(effect.targetScaleX, reboundX, rebound)
            scaleY = lerp(effect.targetScaleY, reboundY, rebound)
        else
            local returning = easing.outCubic(
                (progress - 0.55) / 0.45,
                0,
                1,
                1
            )
            local reboundX = 1 - (effect.targetScaleX - 1) * 0.20
            local reboundY = 1 - (effect.targetScaleY - 1) * 0.20
            scaleX = lerp(reboundX, 1, returning)
            scaleY = lerp(reboundY, 1, returning)
        end

        effect.sprite:setScale(
            effect.baseScaleX * scaleX,
            effect.baseScaleY * scaleY
        )

        if progress >= 1 then
            effect.sprite:setScale(
                effect.baseScaleX,
                effect.baseScaleY
            )
            removeBySwap(scaleEffects, index)
        end
    end
end

local function updateFlashEffects(deltaMilliseconds)
    for index = #flashEffects, 1, -1 do
        local effect = flashEffects[index]
        effect.elapsed += deltaMilliseconds

        if effect.elapsed >= effect.duration then
            effect.sprite:setVisible(effect.originallyVisible)
            removeBySwap(flashEffects, index)
        else
            local blinkIndex = math.floor(effect.elapsed / 45)
            effect.sprite:setVisible(
                effect.originallyVisible and blinkIndex % 2 == 1
            )
        end
    end
end

local function updatePopups(deltaMilliseconds)
    for index = #popups, 1, -1 do
        local popup = popups[index]
        popup.elapsed += deltaMilliseconds

        if popup.elapsed >= popup.duration then
            removeBySwap(popups, index)
        end
    end
end

local function updateParticles(deltaMilliseconds)
    local frameScale = deltaMilliseconds / DEFAULT_FRAME_MS

    for index = #particles, 1, -1 do
        local particle = particles[index]
        particle.elapsed += deltaMilliseconds
        particle.x += particle.velocityX * frameScale
        particle.y += particle.velocityY * frameScale
        particle.velocityY += particle.gravity * frameScale

        if particle.style == "steam" then
            particle.x += math.sin(
                particle.elapsed / 55 + particle.phase
            ) * 0.35
        end

        if particle.elapsed >= particle.lifetime then
            removeBySwap(particles, index)
        end
    end
end

function Juice.update()
    local deltaMilliseconds = getDeltaMilliseconds()
    updateFrame += 1

    frozenThisFrame = freezeFrames > 0
    if frozenThisFrame then
        freezeFrames -= 1
    end

    updateShake(deltaMilliseconds)
    updateScaleEffects(deltaMilliseconds)
    updateFlashEffects(deltaMilliseconds)
    updatePopups(deltaMilliseconds)
    updateParticles(deltaMilliseconds)

    return frozenThisFrame
end

local function shouldDrawFadingItem(progress, phase)
    if progress < 0.72 then
        return true
    end

    local fadeStep = math.floor((progress - 0.72) * 18)
    return (updateFrame + phase) % 6 > fadeStep
end

local function drawPopups()
    local previousFont = gfx.getFont()

    for index = 1, #popups do
        local popup = popups[index]
        local progress = clamp(popup.elapsed / popup.duration, 0, 1)

        if shouldDrawFadingItem(progress, index) then
            local font = popup.font or previousFont
            gfx.setFont(font)

            local riseProgress = easing.outCubic(progress, 0, 1, 1)
            local bounce = math.sin(math.min(1, progress / 0.22) * math.pi)
            local drawY = popup.y - popup.rise * riseProgress - bounce * 3
            local drawX = popup.x - font:getTextWidth(popup.text) / 2

            if progress < 0.16 then
                font:drawText(popup.text, math.floor(drawX - 1), math.floor(drawY))
                font:drawText(popup.text, math.floor(drawX + 1), math.floor(drawY))
            end

            font:drawText(popup.text, math.floor(drawX), math.floor(drawY))
        end
    end

    gfx.setFont(previousFont)
end

local function drawParticles()
    gfx.setColor(gfx.kColorBlack)

    for index = 1, #particles do
        local particle = particles[index]
        local progress = particle.elapsed / particle.lifetime

        if shouldDrawFadingItem(progress, particle.phase) then
            local x = math.floor(particle.x)
            local y = math.floor(particle.y)

            if particle.style == "grease" then
                gfx.fillCircleAtPoint(x, y, particle.size)
            elseif particle.style == "spark" then
                gfx.setLineWidth(2)
                gfx.drawLine(
                    x,
                    y,
                    math.floor(x - particle.velocityX * 0.32),
                    math.floor(y - particle.velocityY * 0.32)
                )
            elseif particle.style == "steam" then
                gfx.setLineWidth(1)
                gfx.drawCircleAtPoint(x, y, particle.size + 1)
            else
                gfx.fillRect(x, y, particle.size + 1, particle.size)
            end
        end
    end

    gfx.setLineWidth(1)
end

function Juice.draw()
    drawParticles()
    drawPopups()
end

function Juice.clear()
    pd.display.setOffset(0, 0)
    shakeState.intensity = 0
    shakeState.remaining = 0
    freezeFrames = 0
    frozenThisFrame = false

    for index = #scaleEffects, 1, -1 do
        local effect = scaleEffects[index]
        effect.sprite:setScale(effect.baseScaleX, effect.baseScaleY)
        scaleEffects[index] = nil
    end

    for index = #flashEffects, 1, -1 do
        local effect = flashEffects[index]
        effect.sprite:setVisible(effect.originallyVisible)
        flashEffects[index] = nil
    end

    for index = #popups, 1, -1 do
        popups[index] = nil
    end

    for index = #particles, 1, -1 do
        particles[index] = nil
    end
end

-- Test/profiling helper; kept out of the normal public API surface.
function Juice._getActiveEffectCounts()
    return {
        scale = #scaleEffects,
        flash = #flashEffects,
        popup = #popups,
        particle = #particles,
    }
end
