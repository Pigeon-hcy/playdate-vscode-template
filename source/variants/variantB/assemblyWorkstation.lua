import "CoreLibs/graphics"
import "CoreLibs/crank"
import "variants/variantB/playerConfig"
import "variants/variantB/supplyWarning"
import "variants/variantB/juicy"
import "variants/variantB/juiceRuntime"
import "variants/variantB/orderRuntime"
import "variants/variantB/ingredientCardWheel"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local assembly <const> = PlayerConfig.assembly

-- Leave a narrow gutter for the fixed workstation direction keys.
local recipeLeft <const> = 24
local recipePanelRight <const> = 120
local ingredientPanelLeft <const> = 286
-- Fillings are centred on their visible footprint, then placed using their
-- calibrated contact offset and thickness. Canvas padding is not a contact
-- point, and the bottom bun's support surface must never be compressed.
local stackCenterX <const> = 203
local stackBottom <const> = 204
local compactStackTop <const> = 44
local recipeListStartY <const> = 64
local recipeListLastY <const> = 190

local wheelCardRight <const> = 380
local wheelCenterY <const> = 116
-- Fixed-size cards preserve the large mnemonic, icon, and complete name on
-- neighboring items. Selection is baked into a separate high-contrast state.
local activeCardWidth <const> = assembly.ingredientCards.width
-- Three complete cards at rest; incoming neighbors clip only while turning.
local wheelClipY <const> = 34
local wheelClipHeight <const> = 164

local systemFont <const> = gfx.getSystemFont()
local smallFont <const> =
    gfx.font.new("/System/Fonts/Roobert-10-Bold") or systemFont

local grayTextImages = {}
local recipeTitleImages = {}
local recipeTitleWidth <const> = recipePanelRight - recipeLeft - 4
local function getRecipeTitleImage(name)
    local image = recipeTitleImages[name]
    if image == nil then
        -- Two lines of the smaller font keep complete current recipe names
        -- within the left column. Future longer names truncate inside it.
        image = gfx.imageWithText(name, recipeTitleWidth, 32, gfx.kColorClear,
            0, "...", nil, smallFont)
        recipeTitleImages[name] = image
    end
    return image
end
for _, recipe in ipairs(PlayerConfig.recipe) do getRecipeTitleImage(recipe[1]) end

local spriteDirectory <const> = "resource/ingredients/"

local spriteWidth = 0
local maxSpriteHeight = 0

local function visibleBounds(image)
    local width, height = image:getSize()
    local left, top, right, bottom = width, height, 0, 0
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            if image:sample(x, y) ~= gfx.kColorClear then
                left, top = math.min(left, x), math.min(top, y)
                right, bottom = math.max(right, x + 1), math.max(bottom, y + 1)
            end
        end
    end
    assert(right > left and bottom > top, "assembly sprite must have visible content")
    return left, top, right, bottom
end

local function loadSprite(name, ingredientCode)
    local image, loadError = gfx.image.new(spriteDirectory .. name)
    assert(image, loadError)

    if ingredientCode ~= nil and not assembly.spriteNaturalOverhang[ingredientCode] then
        local left, _, right = visibleBounds(image)
        local width, height = image:getSize()
        local scaleX = math.min(1, assembly.spriteFootprintWidth / (right - left))
        local scaleY = math.min(scaleX, assembly.spriteMaxHeights[ingredientCode] / height)
        if scaleX < 1 or scaleY < 1 then
            -- Bake once, keeping the game's binary black/white pixels and
            -- alpha. No runtime resizing or changes to the shared source art.
            local fitted = gfx.image.new(math.floor(width * scaleX + .5),
                math.floor(height * scaleY + .5), gfx.kColorClear)
            local fittedWidth, fittedHeight = fitted:getSize()
            gfx.pushContext(fitted)
            image:drawScaled(0, 0, fittedWidth / width, fittedHeight / height)
            gfx.popContext()
            image = fitted
        end
    end

    -- Tight bounds put the actual silhouette at the centre in either flip.
    -- The old 160px canvases had different left/right padding for every food.
    local left, top, right, bottom = visibleBounds(image)
    local centred = gfx.image.new(right - left, bottom - top, gfx.kColorClear)
    gfx.pushContext(centred)
    image:draw(-left, -top)
    gfx.popContext()
    image = centred
    local width, height = image:getSize()
    spriteWidth = math.max(spriteWidth, width)
    maxSpriteHeight = math.max(maxSpriteHeight, height)

    return image
end

local ingredientImages <const> = {}

for ingredientCode, spriteName in pairs(assembly.ingredientSprites) do
    ingredientImages[ingredientCode] = loadSprite(spriteName, ingredientCode)
end

local bottomBreadImage <const> = loadSprite(assembly.breadSprites.bottom)
local topBreadImage <const> = loadSprite(assembly.breadSprites.top)

-- Mirrored copies for repeated ingredients: baking them once keeps the
-- variant a plain blit, where flipping at draw time would not.
local function makeFlippedSprite(image)
    local width, height = image:getSize()
    local flipped = gfx.image.new(width, height, gfx.kColorClear)

    gfx.pushContext(flipped)
        image:draw(0, 0, gfx.kImageFlippedX)
    gfx.popContext()

    return flipped
end

local flippedIngredientImages <const> = {}

for ingredientCode, image in pairs(ingredientImages) do
    flippedIngredientImages[ingredientCode] = makeFlippedSprite(image)
end

local ingredientWheel <const> = IngredientCardWheel.new(assembly, {
    right = wheelCardRight,
    centerY = wheelCenterY,
    clipY = wheelClipY,
    clipHeight = wheelClipHeight,
    titleX = ingredientPanelLeft + 8,
    titleY = 7,
}, systemFont)

AssemblyWorkstation = {}
AssemblyWorkstation.usesCrank = true
-- Shown on the controls card; keep in step with handleInput and update.
AssemblyWorkstation.help = {
    title = "ASSEMBLY",
    summary = "BUILD THE RECIPE ON THE LEFT: EXACT COUNTS, ANY ORDER. SERVE IT BEFORE A TICKET RUNS OUT.",
    controls = {
        { "🎣", "TURN TO PICK AN ITEM" },
        { "⬇", "ADD THE PICKED ITEM" },
        { "⬆", "PUT THE TOP BUN ON" },
        { "⬆", "SERVE THE FINISHED BURGER" },
    },
}
local juice <const> = Juice
local completionPending = false
local servePhase = nil
local serveStartTime = 0
local serveOffsetY = 0
local _, bottomBreadHeight = bottomBreadImage:getSize()
local breadEntryDistance <const> = PlayerConfig.screenHeight + bottomBreadHeight + 4 - stackBottom

function AssemblyWorkstation.isServing()
    return servePhase ~= nil
end

function AssemblyWorkstation.getServeOffsetY()
    return serveOffsetY
end

-- Retire only the ids this workstation owns: the shared instance also
-- carries the other workstations' effects, so Juicy:clear would wipe them.
local function clearBurgerJuice()
    for layerIndex = 0, #assembly.layers + 1 do
        juice:remove(layerIndex)
    end

    juice:remove("burger")
    juice:remove("error")
end

local function impactLayers(newIndex)
    local direction = newIndex % 2 == 0 and 1 or -1
    juice:ingredientLand(newIndex, { direction = direction })
    for index = 0, newIndex - 1 do
        local depth = newIndex - index
        juice:ingredientLand(index, {
            secondary = true, direction = direction,
            impactWeight = .2 + .3 * index / math.max(1, newIndex - 1),
            delay = depth * Juicy.config.propagation,
        })
    end
    juice:ingredientLand("burger", { group = true })
end

local function countIngredients(items, firstIndex)
    local counts = {}

    for index = firstIndex, #items do
        local ingredientCode = items[index]
        counts[ingredientCode] = (counts[ingredientCode] or 0) + 1
    end

    return counts
end

function AssemblyWorkstation.isBurgerCorrect(
    recipe,
    layers,
    hasTopBread
)
    if not hasTopBread or #layers ~= #recipe - 1 then
        return false
    end

    local requiredCounts = countIngredients(recipe, 2)
    local actualCounts = countIngredients(layers, 1)

    for ingredientCode, requiredCount in pairs(requiredCounts) do
        if actualCounts[ingredientCode] ~= requiredCount then
            return false
        end
    end

    for ingredientCode, actualCount in pairs(actualCounts) do
        if requiredCounts[ingredientCode] ~= actualCount then
            return false
        end
    end

    return true
end

function AssemblyWorkstation.addIngredient(ingredientCode)
    if assembly.hasTopBread or servePhase ~= nil then
        return false
    end

    if ingredientCode == "P" then
        if PlayerConfig.patties <= 0 then
            SupplyWarning.request("patty")
            return false
        end

        PlayerConfig.patties -= 1
    end

    local repeatCount = 0

    for _, existingCode in ipairs(assembly.layers) do
        if existingCode == ingredientCode then
            repeatCount += 1
        end
    end

    assembly.layers[#assembly.layers + 1] = ingredientCode
    Orders:commitNext()
    assembly.layerRepeats[#assembly.layers] = repeatCount
    impactLayers(#assembly.layers)
    if ingredientCode == "P" then
        juice:verticalShake(#assembly.layers, Juicy.config.heavyShakeDuration)
    end
    return true
end

function AssemblyWorkstation.selectRandomRecipe()
    assembly.currentRecipeIndex = math.random(#PlayerConfig.recipe)
end

function AssemblyWorkstation.initialize()
    clearBurgerJuice()
    completionPending = false
    servePhase = nil
    serveOffsetY = 0
    assembly.layers = {}
    assembly.layerRepeats = {}
    assembly.hasTopBread = false
    assembly.lastResult = nil
    assembly.wheelIsAnimating = false
    assembly.wheelAnimationFrame = 0
    assembly.wheelDirection = 0
    AssemblyWorkstation.selectRandomRecipe()
end

function AssemblyWorkstation.serveBurger()
    if servePhase ~= nil or completionPending or not assembly.hasTopBread or
        Orders:count() == 0 then
        return nil
    end

    -- Fulfil the promised customer's order, including an incorrect burger.
    local order = Orders:completeNext()
    if order == nil then return nil end

    clearBurgerJuice()
    completionPending = false
    local currentRecipe = PlayerConfig.recipe[assembly.currentRecipeIndex]
    local isCorrect = AssemblyWorkstation.isBurgerCorrect(
        currentRecipe,
        assembly.layers,
        assembly.hasTopBread
    )

    if isCorrect then
        local points = Scoring.awardBurger(assembly.layers,
            Orders:getRemainingTime(order), Orders:isRushHour())
        assembly.lastResult = "CORRECT +" .. points
    else
        assembly.lastResult = "WRONG -" .. Scoring.penalizeWrong()
    end

    -- Keep the full stack and its recipe until it has left the screen.
    -- One shared draw offset moves every layer without altering its layout.
    servePhase = "outgoing"
    serveStartTime = juice.time
    serveOffsetY = 0

    return isCorrect
end

function AssemblyWorkstation.selectIngredient(crankTicks)
    local ingredientCount = #assembly.ingredientCodes

    assembly.selectedIngredientIndex =
        ((assembly.selectedIngredientIndex - 1 + crankTicks) %
            ingredientCount) + 1

    return assembly.ingredientCodes[assembly.selectedIngredientIndex]
end

function AssemblyWorkstation.startWheelTurn(direction)
    if servePhase ~= nil or assembly.wheelIsAnimating or direction == 0 then
        return false
    end

    assembly.wheelIsAnimating = true
    assembly.wheelAnimationFrame = 0
    assembly.wheelDirection = direction > 0 and 1 or -1
    return true
end

function AssemblyWorkstation.advanceWheelAnimation()
    if not assembly.wheelIsAnimating then
        return false
    end

    assembly.wheelAnimationFrame += 1

    if assembly.wheelAnimationFrame >=
        assembly.wheelAnimationDurationFrames then
        AssemblyWorkstation.selectIngredient(assembly.wheelDirection)
        assembly.wheelIsAnimating = false
        assembly.wheelAnimationFrame = 0
        assembly.wheelDirection = 0
    end

    return true
end

function AssemblyWorkstation.pressUp()
    if completionPending or servePhase ~= nil then return "animating" end
    if not assembly.hasTopBread then
        Orders:commitNext()
        assembly.hasTopBread = true
        local index = #assembly.layers + 1
        impactLayers(index)
        juice:ingredientLand(index, { impactWeight = 1, direction = -1, duration = .14 })
        completionPending = true
        juice:burgerComplete("burger", {
            x = stackCenterX,
            y = AssemblyWorkstation.getTopLayerBottom(),
            width = spriteWidth,
            onComplete = function() completionPending = false end,
        })
        return "closed"
    end

    if Orders:count() == 0 then
        juice:errorShake("error")
        return "no_order"
    end

    if AssemblyWorkstation.serveBurger() then
        return "correct"
    end

    return "wrong"
end

function AssemblyWorkstation.handleInput()
    if servePhase ~= nil then return end
    if pd.buttonJustPressed(pd.kButtonB) then juice:errorShake("error") end
    if pd.buttonJustPressed(pd.kButtonDown) and not assembly.wheelIsAnimating then
        local selectedCode =
            assembly.ingredientCodes[assembly.selectedIngredientIndex]
        if not AssemblyWorkstation.addIngredient(selectedCode) then
            juice:errorShake("error")
        end
    end

    if pd.buttonJustPressed(pd.kButtonUp) then
        AssemblyWorkstation.pressUp()
    end
end

local function updateServing()
    if servePhase == nil then return end

    local elapsed = juice.time - serveStartTime
    if servePhase == "outgoing" then
        if elapsed < assembly.serveOutDuration then
            local progress = elapsed / assembly.serveOutDuration
            serveOffsetY = -(stackBottom + 8) * progress * progress
            return
        end

        clearBurgerJuice()
        assembly.layers = {}
        assembly.layerRepeats = {}
        assembly.hasTopBread = false
        AssemblyWorkstation.selectRandomRecipe()
        servePhase = "incoming"
        serveStartTime += assembly.serveOutDuration
        elapsed = juice.time - serveStartTime
    end

    if elapsed >= assembly.breadInDuration then
        servePhase = nil
        serveOffsetY = 0
    else
        local progress = elapsed / assembly.breadInDuration
        serveOffsetY = breadEntryDistance * (1 - progress) ^ 3
    end
end

function AssemblyWorkstation.update(isActive)
    updateServing()
    -- If work began while there were no orders, promise the next available
    -- customer this burger. Keep that promise even on another workstation.
    if servePhase == nil and (#assembly.layers > 0 or assembly.hasTopBread) then
        Orders:commitNext()
    end
    if servePhase ~= nil then
        if assembly.wheelIsAnimating then
            AssemblyWorkstation.advanceWheelAnimation()
        end
        -- Ignore crank movement made while the new bun is not ready.
        if isActive then pd.getCrankTicks(assembly.crankTicksPerTurn) end
        return
    end

    if assembly.wheelIsAnimating then
        AssemblyWorkstation.advanceWheelAnimation()
        return
    end

    if not isActive then
        return
    end

    local crankTicks = pd.getCrankTicks(assembly.crankTicksPerTurn)

    if crankTicks ~= 0 then
        AssemblyWorkstation.startWheelTurn(crankTicks)
    end
end

local function drawGrayText(text, x, y)
    local textImage = grayTextImages[text]

    if textImage == nil then
        textImage = gfx.imageWithText(
            text,
            recipePanelRight - 10,
            20,
            gfx.kColorClear,
            nil,
            nil,
            nil,
            smallFont
        )
        grayTextImages[text] = textImage
    end

    if textImage ~= nil then
        textImage:drawFaded(
            x,
            y,
            0.45,
            gfx.image.kDitherTypeBayer8x8
        )
    end
end

local function getRecipeRequirements(recipe)
    local order = {}
    local counts = {}

    for recipeIndex = 2, #recipe do
        local ingredientCode = recipe[recipeIndex]

        if counts[ingredientCode] == nil then
            order[#order + 1] = ingredientCode
            counts[ingredientCode] = 0
        end

        counts[ingredientCode] += 1
    end

    return order, counts
end

function AssemblyWorkstation.getRecipeLineSpacing(requirementCount)
    if requirementCount <= 1 then
        return 22
    end

    return math.min(
        22,
        math.floor(
            (recipeListLastY - recipeListStartY) /
                (requirementCount - 1)
        )
    )
end

-- Prepared sprites draw 1:1. Tall recipes compress ingredient spacing only;
-- the bun's support surface stays fixed, even when a later recipe is taller.
function AssemblyWorkstation.getStackLayout(recipe)
    local required = 0

    for recipeIndex = 2, #recipe do
        required += assembly.spriteThickness[recipe[recipeIndex]] or 0
    end

    local available = stackBottom - compactStackTop - maxSpriteHeight -
        assembly.breadThickness.bottom
    local scale = 1

    if required > available and required > 0 then
        scale = available / required
    end

    return stackCenterX, scale, stackBottom
end

-- Where the top bun lands, for the completion burst.
function AssemblyWorkstation.getTopLayerBottom()
    local currentRecipe = PlayerConfig.recipe[assembly.currentRecipeIndex]
    local _, scale, bottom =
        AssemblyWorkstation.getStackLayout(currentRecipe)

    bottom -= assembly.breadThickness.bottom

    for _, ingredientCode in ipairs(assembly.layers) do
        bottom -= (assembly.spriteThickness[ingredientCode] or 0) * scale
    end

    return bottom
end

local function drawRecipe()
    if Orders:count() == 0 then
        gfx.setFont(smallFont)
        gfx.drawText("NO ORDERS!", recipeLeft, 52)
        gfx.setFont(systemFont)
        return
    end

    local currentRecipe = PlayerConfig.recipe[assembly.currentRecipeIndex]
    local order, requiredCounts = getRecipeRequirements(currentRecipe)
    local addedCounts = countIngredients(assembly.layers, 1)

    gfx.drawText("RECIPE", recipeLeft, 7)
    local titleImage = getRecipeTitleImage(currentRecipe[1])
    if titleImage then titleImage:draw(recipeLeft, 28) end
    gfx.setFont(smallFont)

    local lineSpacing =
        AssemblyWorkstation.getRecipeLineSpacing(#order)

    for lineIndex, ingredientCode in ipairs(order) do
        local requiredCount = requiredCounts[ingredientCode]
        local text = assembly.ingredientNames[ingredientCode]

        if requiredCount > 1 then
            text = text .. " *" .. requiredCount
        end

        local y = recipeListStartY +
            (lineIndex - 1) * lineSpacing
        local requirementIsMet =
            (addedCounts[ingredientCode] or 0) >= requiredCount

        if requirementIsMet then
            drawGrayText(text, recipeLeft, y)
        else
            gfx.drawText(text, recipeLeft, y)
        end
    end

    gfx.setFont(systemFont)
end

local function drawLayer(image, bottom, seat, rotation, id)
    local t = juice:getTransform(id)

    if not t.visible then
        return
    end

    local group = juice:getTransform("burger")
    local err = juice:getTransform("error")
    local shakeX, shakeY = juice:getScreenOffset("burger")
    local width, height = image:getSize()
    -- Transform the stack about its bottom, then each layer about its own
    -- bottom. These are draw-local values; layout coordinates never change.
    local stackedBottom =
        stackBottom + (bottom - stackBottom) * group.scaleY
    local scaleX = math.max(.90, math.min(1.12, t.scaleX * group.scaleX))
    local scaleY = math.max(.82, math.min(1.10, t.scaleY * group.scaleY))
    local drawWidth = width * scaleX
    local drawHeight = height * scaleY
    local drawX = math.floor(
        stackCenterX - drawWidth / 2 +
            t.offsetX + group.offsetX + err.offsetX + shakeX + .5
    )
    local drawY = math.floor(
        stackedBottom - drawHeight + seat * scaleY +
            t.offsetY + group.offsetY + shakeY + serveOffsetY + .5
    )

    local oldMode = gfx.getImageDrawMode()

    if t.invert or group.invert or err.invert then
        gfx.setImageDrawMode(gfx.kDrawModeInverted)
    end

    -- Most frames carry no juice, so keep the unscaled blit off drawScaled.
    if rotation ~= 0 then
        image:drawRotated(
            drawX + drawWidth / 2,
            drawY + drawHeight / 2,
            rotation,
            scaleX,
            scaleY
        )
    elseif scaleX == 1 and scaleY == 1 then
        image:draw(drawX, drawY)
    else
        image:drawScaled(drawX, drawY, scaleX, scaleY)
    end

    gfx.setImageDrawMode(oldMode)
end

local function drawBurger()
    local currentRecipe =
        PlayerConfig.recipe[assembly.currentRecipeIndex]
    local _, scale, bottom =
        AssemblyWorkstation.getStackLayout(currentRecipe)

    drawLayer(
        bottomBreadImage,
        bottom,
        assembly.breadBaselines.bottom,
        0,
        0
    )
    bottom -= assembly.breadThickness.bottom

    for layerIndex, ingredientCode in ipairs(assembly.layers) do
        local variant = assembly.repeatVariants[
            ((assembly.layerRepeats[layerIndex] or 0) %
                #assembly.repeatVariants) + 1
        ]
        local sprites = variant.flip and flippedIngredientImages
            or ingredientImages

        drawLayer(
            sprites[ingredientCode],
            bottom,
            assembly.spriteBaselines[ingredientCode] or 0,
            variant.rotation,
            layerIndex
        )
        bottom -= (assembly.spriteThickness[ingredientCode] or 0) * scale
    end

    if assembly.hasTopBread then
        drawLayer(
            topBreadImage,
            bottom,
            assembly.breadBaselines.top,
            0,
            #assembly.layers + 1
        )
    end
end

function AssemblyWorkstation.getWheelCardWidth(position)
    return activeCardWidth
end

local function drawIngredientWheel()
    ingredientWheel:draw()
end

local function drawInventoryStatus()
    gfx.setFont(smallFont)
    gfx.drawText("SCORE: " .. PlayerConfig.score, 8, 211)
    gfx.setFont(systemFont)
end

function AssemblyWorkstation.draw()
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(recipePanelRight, 0, recipePanelRight, 210)
    gfx.drawLine(ingredientPanelLeft, 0, ingredientPanelLeft, 210)

    drawRecipe()
    if servePhase ~= nil then
        -- The stack travels behind the fixed header/footer, not over the UI.
        gfx.setClipRect(recipePanelRight + 1, compactStackTop,
            ingredientPanelLeft - recipePanelRight - 1, 210 - compactStackTop)
    end
    drawBurger()
    if servePhase ~= nil then gfx.clearClipRect() end
    juice:drawParticles()
    drawIngredientWheel()

    drawInventoryStatus()

    gfx.setFont(smallFont)
    if servePhase ~= nil then
        gfx.drawText(servePhase == "outgoing" and "SERVING..." or "NEXT...", 130, 211)
    elseif assembly.hasTopBread then
        gfx.drawText(Orders:count() > 0 and "⬆  SERVE" or "WAITING FOR ORDER", 130, 211)
    else
        gfx.drawText("🎣 PICK   ⬇ ADD   ⬆ BUN", 130, 211)
    end
    if assembly.lastResult ~= nil then
        gfx.drawText(assembly.lastResult, 130, 226)
    end
    gfx.setFont(systemFont)
end
