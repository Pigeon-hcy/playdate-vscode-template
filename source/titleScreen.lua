import "CoreLibs/graphics"
import "titleAssets"
import "loadingAssets"
import "gameVersions"

-- Native bitmap intro followed by a layered, interactive shutter menu.
-- Only the road/zoom is baked; title, particles and door remain independent.
TitleScreen = {}
local gfx <const> = playdate.graphics
local assets <const> = TitleAssets
local loadingAssets <const> = LoadingAssets
local readyAt <const> = 3.6
local titleAt <const> = 2.8
local titleDuration <const> = .22
local burstAt <const> = titleAt + titleDuration * (1 - .25 ^ (1 / 3))
local burstOffset <const> = -375 * .25
local openingDegrees <const> = 360
local crankIdleDelay <const> = .65
local entranceDuration <const> = .7
local minimumLoadingDuration <const> = .35
local state, elapsed, exitElapsed = "done", 0, 0
local road, shutter, title, closed, particles, gameFrame, loadingFrame
local loadingIn, loadingOut
local loadingDrawn, gameplayReady = false, false
local crankTravel, crankIdle = 0, crankIdleDelay
local showCrankHint = false
local departureBob = 0
local lastRoadFrame = nil
local versionCursor = 1

local function clamp(value)
    return math.max(0, math.min(1, value))
end

local function round(value)
    return math.floor(value + .5)
end

local function ease(value)
    if value < .5 then return 4 * value * value * value end
    local u = -2 * value + 2
    return 1 - u * u * u / 2
end

local function bobAt(time)
    return round(math.sin(time * 8.4) * 1.7 + math.sin(time * 17.1) * .55)
        + round((math.sin(time * 7.2) * .6 + math.sin(time * 12.7) * .25)
            * clamp(time - 1.6))
end

local function release()
    road, shutter, title, closed, particles, gameFrame = nil, nil, nil, nil, nil, nil
    loadingFrame = nil
    loadingIn, loadingOut = nil, nil
end

function TitleScreen.invalidate()
    lastRoadFrame = nil
end

function TitleScreen.initialize(showBootLoading)
    release()
    road = assert(gfx.imagetable.new("resource/title/road"), "Missing title road frames")
    shutter = assert(gfx.image.new("resource/title/shutter"), "Missing title shutter")
    title = assert(gfx.image.new("resource/title/title"), "Missing title lettering")
    closed = assert(gfx.image.new("resource/title/closed"), "Missing cached title door")
    loadingFrame = assert(gfx.image.new("SystemAssets/launchImage"))
    loadingIn = assert(gfx.imagetable.new("resource/loading/in"))
    loadingOut = assert(gfx.imagetable.new("resource/loading/out"))
    particles = {}
    for i = 0, 47 do
        particles[i + 1] = {
            life = 1.05 + (i % 6) * .07,
            inverseLife = 1 / (1.05 + (i % 6) * .07),
            width = i % 4 == 0 and 12 or 6,
            height = i % 3 == 0 and 6 or 3,
            x = 190 + (i % 8) * 21 + (i * 7) % 9 + burstOffset,
            y = 14 + math.floor(i / 8) * 8,
            dx = 65 + (i * 29) % 51 - burstOffset,
            dy = -24 + (i * 19) % 59,
        }
    end
    state, elapsed, exitElapsed = showBootLoading and "boot" or "intro", 0, 0
    loadingDrawn, gameplayReady = false, false
    crankTravel, crankIdle, showCrankHint = 0, crankIdleDelay, false
    versionCursor = GameVersions.getIndex()
    if GameVersions.shouldSkipIntro() then
        state = GameVersions.shouldOpenPicker() and "versions" or "menu"
        elapsed = readyAt + 2
        road, shutter, title, particles = nil, nil, nil, nil
    end
    TitleScreen.invalidate()
end

function TitleScreen.isActive()
    return state ~= "done"
end

function TitleScreen.getState()
    return state
end

function TitleScreen.shouldShowCrankIndicator()
    return showCrankHint
end

function TitleScreen.update(dt, crankChange, crankDocked, prepareGameplay, drawGameplay)
    if state == "done" then return end
    dt = math.max(0, dt)
    -- Both directions open the shutter. Ignore dock/undock movement and tiny
    -- sensor jitter; movement during the intro cannot skip its reveal.
    local motion = crankDocked and 0 or math.abs(crankChange or 0)
    if motion < .2 then motion = 0 end
    showCrankHint = false
    if state == "versions" then
        local entries = GameVersions.getEntries()
        if playdate.buttonJustPressed(playdate.kButtonB) then
            state = "menu"
        elseif playdate.buttonJustPressed(playdate.kButtonUp) then
            versionCursor = (versionCursor - 2) % #entries + 1
        elseif playdate.buttonJustPressed(playdate.kButtonDown) then
            versionCursor = versionCursor % #entries + 1
        elseif playdate.buttonJustPressed(playdate.kButtonA) then
            if not GameVersions.select(versionCursor) then state = "menu" end
        end
        return
    end
    if state == "menu" and playdate.buttonJustPressed(playdate.kButtonB) then
        versionCursor = GameVersions.getIndex()
        state = "versions"
        return
    end
    if state == "boot" then
        exitElapsed = exitElapsed + dt
        if exitElapsed >= loadingAssets.duration then
            state, elapsed, exitElapsed = "intro", 0, 0
        end
        return
    end
    if state == "exit" then
        crankTravel = math.min(openingDegrees, crankTravel + motion)
        crankIdle = motion > 0 and 0 or crankIdle + dt
        showCrankHint = crankDocked or crankIdle >= crankIdleDelay
        if crankTravel >= openingDegrees then
            state, exitElapsed = "loading", 0
            closed = nil
            showCrankHint = false
        end
        return
    end
    if state == "loading" then
        exitElapsed = exitElapsed + dt
        -- Return a visible loading frame before doing any expensive work.
        if not loadingDrawn then return end
        if not gameplayReady then
            gameplayReady = prepareGameplay()
            return
        end
        if exitElapsed < loadingAssets.duration + minimumLoadingDuration then return end
        gameFrame = assert(gfx.image.new(400, 240, gfx.kColorWhite))
        gfx.pushContext(gameFrame)
        gfx.setDrawOffset(0, 0)
        gfx.clearClipRect()
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        drawGameplay()
        gfx.popContext()
        state, exitElapsed = "loadingOut", 0
        return
    end
    if state == "loadingOut" then
        exitElapsed = exitElapsed + dt
        if exitElapsed >= loadingAssets.duration then
            state, exitElapsed = "enter", 0
        end
        return
    end
    if state == "enter" then
        exitElapsed = exitElapsed + dt
        return
    end
    local wasReady = state == "menu"
    elapsed = elapsed + dt
    if elapsed >= assets.roadDuration then road = nil end
    if elapsed >= titleAt + titleDuration then shutter, title = nil, nil end
    if elapsed >= readyAt then state = "menu" end
    if elapsed >= burstAt + 1.4 then particles = nil end
    showCrankHint = state == "menu"
    if wasReady and motion > 0 then
        departureBob = bobAt(elapsed)
        state, exitElapsed = "exit", 0
        crankTravel, crankIdle = math.min(openingDegrees, motion), 0
        showCrankHint = false
        road, particles = nil, nil
    end
end

local function drawParticles(yOffset)
    if particles == nil then return end
    local age = elapsed - burstAt
    if age < 0 then return end
    gfx.setColor(gfx.kColorBlack)
    for _, particle in ipairs(particles) do
        if age < particle.life then
            local progress = age * particle.inverseLife
            local u = 1 - progress
            local travel = 1 - u * u * u
            local size = 1 - ease(clamp((progress - .65) / .35))
            local width = math.max(1, round(particle.width * size))
            local height = math.max(1, round(particle.height * size))
            gfx.fillRect(
                round(particle.x + particle.dx * travel + (particle.width - width) / 2),
                round(particle.y + particle.dy * travel + (particle.height - height) / 2) + yOffset,
                width, height)
        end
    end
end

local function drawDoor(image, y)
    -- The opaque door covers the screen except a tiny strip exposed by bob.
    -- Clear just that strip, instead of clearing 96,000 pixels every frame.
    if y ~= 0 then
        gfx.setColor(gfx.kColorWhite)
        if y > 0 then gfx.fillRect(0, 0, 400, y)
        else gfx.fillRect(0, 240 + y, 400, -y) end
        gfx.setColor(gfx.kColorBlack)
    end
    image:draw(0, y)
end

function TitleScreen.draw()
    if state == "done" then return end
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    if state == "versions" then
        drawDoor(closed, 0)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(42, 14, 316, 212)
        gfx.setColor(gfx.kColorBlack)
        gfx.setLineWidth(2)
        gfx.drawRect(42, 14, 316, 212)
        local font = gfx.getSystemFont()
        font:drawText("CHOOSE VERSION", 64, 24)
        for index, entry in ipairs(GameVersions.getEntries()) do
            local y = 53 + (index - 1) * 27
            if index == versionCursor then
                gfx.fillRect(56, y - 2, 288, 25)
                gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
            end
            font:drawText(entry.name, 68, y)
            if index == GameVersions.getIndex() then font:drawText("*", 324, y) end
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        end
        font:drawText("UP/DOWN   A: SELECT   B: BACK", 58, 200)
        gfx.setLineWidth(1)
        return
    end
    if state == "boot" then
        local index = math.min(loadingAssets.frames,
            math.floor(clamp(exitElapsed / loadingAssets.duration) * (loadingAssets.frames - 1)) + 1)
        loadingOut:drawImage(index, 0, 0)
        return
    end
    if road ~= nil then
        local index = math.min(assets.roadFrames, math.floor(elapsed * assets.roadFPS) + 1)
        if index == lastRoadFrame then return end
        lastRoadFrame = index
        road:drawImage(index, 0, 0)
        return
    end
    if state == "exit" then
        loadingIn:drawImage(1, 0, 0)
        local progress = clamp(crankTravel / openingDegrees)
        local y = round(departureBob * (1 - progress)) - round(246 * progress)
        closed:draw(0, y)
        gfx.setColor(gfx.kColorBlack)
        gfx.setLineWidth(1)
        gfx.drawRect(0, 0, 400, 240)
        return
    end
    if state == "loading" then
        if exitElapsed < loadingAssets.duration then
            local index = math.floor(clamp(exitElapsed / loadingAssets.duration) * (loadingAssets.frames - 1)) + 1
            loadingIn:drawImage(index, 0, 0)
        else
            loadingFrame:draw(0, 0)
            loadingDrawn = true
        end
        return
    end
    if state == "loadingOut" then
        local index = math.min(loadingAssets.frames,
            math.floor(clamp(exitElapsed / loadingAssets.duration) * (loadingAssets.frames - 1)) + 1)
        loadingOut:drawImage(index, 0, 0)
        return
    end
    if state == "enter" then
        loadingIn:drawImage(1, 0, 0)
        local y = -240 + round(240 * ease(clamp(exitElapsed / entranceDuration)))
        gameFrame:draw(0, y)
        if exitElapsed >= entranceDuration then
            state = "done"
            release()
        end
        return
    end
    local y = bobAt(elapsed)
    -- Repaint under the animated crank notice even when the door's bob is
    -- unchanged, so old notice frames cannot leave trails on the shutter.
    drawDoor(closed and elapsed >= titleAt + titleDuration and closed or shutter, y)
    if title ~= nil and elapsed >= titleAt then
        local progress = clamp((elapsed - titleAt) / titleDuration)
        title:draw(assets.titleX + round(-375 * (1 - progress) ^ 3), assets.titleY + y)
    end
    drawParticles(y)
    if state == "menu" then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(12, 190, 376, 47)
        gfx.setColor(gfx.kColorBlack)
        local font = gfx.getSystemFont()
        font:drawText(GameVersions.getName(), 20, 192)
        font:drawText("B: VERSIONS", 194, 192)
        font:drawText("CRANK TO OPEN", 20, 214)
    end
end
