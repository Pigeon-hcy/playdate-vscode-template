import "CoreLibs/graphics"
import "CoreLibs/crank"
import "playerConfig"
import "juicy"
import "juiceRuntime"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local assembly <const> = PlayerConfig.assembly

local recipePanelRight <const> = 104
local ingredientPanelLeft <const> = 302
-- Sprites are trimmed to their drawn content and stacked by their bottom
-- edge; each layer then rises by the thickness of the one below it, so the
-- burger packs as tightly as the art allows.
local stackCenterX <const> = 203
local stackBottom <const> = 204
local compactStackTop <const> = 8
local recipeListStartY <const> = 52
local recipeListLastY <const> = 190

local wheelCardRight <const> = 396
local wheelCenterY <const> = 116
local wheelSpacing <const> = 39
-- Cards hang off a shared right edge and only stretch in length: longest at
-- the centre, shortest at the ends. Resizing both axes meant re-laying out
-- every frame, and the outline needs no fill -- nothing is drawn behind this
-- panel for it to mask.
local cardHeight <const> = 34
local activeCardWidth <const> = 96
local cardWidthFalloff <const> = 17
local minCardWidth <const> = 46
local wheelClipY <const> = 24
local wheelClipHeight <const> = 184

local systemFont <const> = gfx.getSystemFont()
local smallFont <const> =
    gfx.font.new("/System/Fonts/Roobert-10-Bold") or systemFont

local grayTextImages = {}

local spriteDirectory <const> = "resource/ingredients/"

local spriteWidth = 0
local maxSpriteHeight = 0

local function loadSprite(name)
    local image, loadError = gfx.image.new(spriteDirectory .. name)
    assert(image, loadError)

    local width, height = image:getSize()
    spriteWidth = math.max(spriteWidth, width)
    maxSpriteHeight = math.max(maxSpriteHeight, height)

    return image
end

local ingredientImages <const> = {}

for ingredientCode, spriteName in pairs(assembly.ingredientSprites) do
    ingredientImages[ingredientCode] = loadSprite(spriteName)
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

-- Wheel labels never change, so lay each one out once instead of running
-- drawTextInRect for every visible card on every frame.
local ingredientLabelImages <const> = {}

for _, ingredientCode in ipairs(assembly.ingredientCodes) do
    ingredientLabelImages[ingredientCode] = gfx.imageWithText(
        assembly.ingredientNames[ingredientCode],
        activeCardWidth,
        cardHeight,
        nil,
        nil,
        nil,
        nil,
        smallFont
    )
end

AssemblyWorkstation = {}
AssemblyWorkstation.usesCrank = true
local juice <const> = Juice
local completionPending = false

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
    if assembly.hasTopBread then
        return false
    end

    if ingredientCode == "P" then
        if PlayerConfig.patties <= 0 then
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
    clearBurgerJuice()
    completionPending = false
    local currentRecipe = PlayerConfig.recipe[assembly.currentRecipeIndex]
    local isCorrect = AssemblyWorkstation.isBurgerCorrect(
        currentRecipe,
        assembly.layers,
        assembly.hasTopBread
    )

    if isCorrect then
        PlayerConfig.score += 1
        assembly.lastResult = "CORRECT"
    else
        assembly.lastResult = "WRONG"
    end

    assembly.layers = {}
    assembly.layerRepeats = {}
    assembly.hasTopBread = false
    AssemblyWorkstation.selectRandomRecipe()

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
    if assembly.wheelIsAnimating or direction == 0 then
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
    if completionPending then return "animating" end
    if not assembly.hasTopBread then
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

    if AssemblyWorkstation.serveBurger() then
        return "correct"
    end

    return "wrong"
end

function AssemblyWorkstation.handleInput()
    if pd.buttonJustPressed(pd.kButtonB) then juice:errorShake("error") end
    if (pd.buttonJustPressed(pd.kButtonDown) or pd.buttonJustPressed(pd.kButtonA)) and
        not assembly.wheelIsAnimating then
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

function AssemblyWorkstation.update(isActive)
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

-- Sprites are drawn 1:1 so their dither stays crisp. A recipe too tall for
-- the panel shrinks every step by one shared factor, computed from the recipe
-- rather than the layers placed so far so nothing shifts mid-build.
function AssemblyWorkstation.getStackLayout(recipe)
    local required = assembly.breadThickness.bottom

    for recipeIndex = 2, #recipe do
        required += assembly.spriteThickness[recipe[recipeIndex]] or 0
    end

    local available = stackBottom - compactStackTop - maxSpriteHeight
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

    bottom -= assembly.breadThickness.bottom * scale

    for _, ingredientCode in ipairs(assembly.layers) do
        bottom -= (assembly.spriteThickness[ingredientCode] or 0) * scale
    end

    return bottom
end

local function drawRecipe()
    local currentRecipe = PlayerConfig.recipe[assembly.currentRecipeIndex]
    local order, requiredCounts = getRecipeRequirements(currentRecipe)
    local addedCounts = countIngredients(assembly.layers, 1)

    gfx.drawText("RECIPE", 8, 7)
    gfx.drawText(currentRecipe[1], 8, 28)
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
            drawGrayText(text, 8, y)
        else
            gfx.drawText(text, 8, y)
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
            t.offsetY + group.offsetY + shakeY + .5
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
    bottom -= assembly.breadThickness.bottom * scale

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

local function getWrappedIngredient(relativeIndex)
    local ingredientCount = #assembly.ingredientCodes
    local index = ((assembly.selectedIngredientIndex - 1 +
        relativeIndex) % ingredientCount) + 1
    return assembly.ingredientCodes[index]
end

function AssemblyWorkstation.getWheelCardWidth(position)
    return math.max(
        minCardWidth,
        activeCardWidth - math.abs(position) * cardWidthFalloff
    )
end

local function drawWheelCard(ingredientCode, position)
    local width = AssemblyWorkstation.getWheelCardWidth(position)
    local x = math.floor(wheelCardRight - width)
    local y = math.floor(
        wheelCenterY + position * wheelSpacing - cardHeight / 2
    )

    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(math.abs(position) < 0.5 and 3 or 1)
    gfx.drawRect(x, y, width, cardHeight)

    local label = ingredientLabelImages[ingredientCode]

    if label == nil then
        return
    end

    -- Clip to the card, kept inside the panel, so a long name truncates
    -- rather than spilling over the border.
    local clipTop = math.max(y, wheelClipY)
    local clipBottom = math.min(y + cardHeight, wheelClipY + wheelClipHeight)

    if clipBottom <= clipTop then
        return
    end

    local labelWidth, labelHeight = label:getSize()
    gfx.setClipRect(x + 5, clipTop, width - 10, clipBottom - clipTop)
    label:draw(
        math.floor(x + (width - labelWidth) / 2),
        math.floor(y + (cardHeight - labelHeight) / 2)
    )
end

local function drawIngredientWheel()
    gfx.drawText("ITEMS", ingredientPanelLeft + 8, 7)

    local panelWidth =
        PlayerConfig.screenWidth - ingredientPanelLeft - 1
    local animationProgress = 0

    if assembly.wheelIsAnimating then
        animationProgress = assembly.wheelAnimationFrame /
            assembly.wheelAnimationDurationFrames
        animationProgress = animationProgress * animationProgress *
            (3 - 2 * animationProgress)
    end

    local positionOffset =
        -assembly.wheelDirection * animationProgress

    for relativeIndex = -3, 3 do
        local position = relativeIndex + positionOffset
        local y = wheelCenterY + position * wheelSpacing

        -- Skip the cards the panel would clip away entirely.
        if y + cardHeight / 2 > wheelClipY and
            y - cardHeight / 2 < wheelClipY + wheelClipHeight then
            gfx.setClipRect(
                ingredientPanelLeft + 1,
                wheelClipY,
                panelWidth,
                wheelClipHeight
            )
            drawWheelCard(
                getWrappedIngredient(relativeIndex),
                position
            )
        end
    end

    gfx.clearClipRect()
end

local function drawInventoryStatus()
    local currentRecipe =
        PlayerConfig.recipe[assembly.currentRecipeIndex]

    if #currentRecipe - 1 > 4 then
        gfx.setFont(smallFont)
        gfx.drawText("SCORE: " .. PlayerConfig.score, 110, 7)
        gfx.drawText("PATTY: " .. PlayerConfig.patties, 250, 7)
        gfx.setFont(systemFont)
        return
    end

    gfx.drawText("SCORE: " .. PlayerConfig.score, 112, 7)
    gfx.drawText("PATTY: " .. PlayerConfig.patties, 213, 7)
end

function AssemblyWorkstation.draw()
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(recipePanelRight, 0, recipePanelRight, 210)
    gfx.drawLine(ingredientPanelLeft, 0, ingredientPanelLeft, 210)

    drawRecipe()
    drawBurger()
    juice:drawParticles()
    drawIngredientWheel()

    drawInventoryStatus()

    if assembly.lastResult ~= nil then
        gfx.drawText(assembly.lastResult, 167, 31)
    end

    if assembly.hasTopBread then
        gfx.drawText("UP: SERVE", 157, 211)
    else
        gfx.drawText("A/DOWN: ADD  UP: BREAD", 110, 211)
    end
end
