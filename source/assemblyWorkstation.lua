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
local stackX <const> = 139
local stackWidth <const> = 128
local layerHeight <const> = 96
local layerOffset <const> = 19
local baseLayerY <const> = 108
local compactStackTop <const> = 8
local stackBottom <const> = 204
local recipeListStartY <const> = 52
local recipeListLastY <const> = 190

local wheelCenterX <const> = 351
local wheelCenterY <const> = 116
local wheelSpacing <const> = 39
local outerCardWidth <const> = 60
local outerCardHeight <const> = 30
local nearCardWidth <const> = 74
local nearCardHeight <const> = 38
local activeCardWidth <const> = 96
local activeCardHeight <const> = 50

local systemFont <const> = gfx.getSystemFont()
local smallFont <const> =
    gfx.font.new("/System/Fonts/Roobert-10-Bold") or systemFont

local grayTextImages = {}

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

    assembly.layers[#assembly.layers + 1] = ingredientCode
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
        local _, _, height, offset, baseY = AssemblyWorkstation.getStackLayout(
            #PlayerConfig.recipe[assembly.currentRecipeIndex] - 1)
        juice:burgerComplete("burger", {
            x = 203, y = baseY + height - index * offset, width = 110,
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

function AssemblyWorkstation.getStackLayout(ingredientCount)
    if ingredientCount <= 4 then
        return
            stackX,
            stackWidth,
            layerHeight,
            layerOffset,
            baseLayerY
    end

    local stepCount = ingredientCount + 1
    local availableHeight = stackBottom - compactStackTop
    local compactHeight = math.floor(
        availableHeight / (1 + stepCount * 0.20)
    )
    local compactOffset = math.max(
        smallFont:getHeight(),
        math.floor(compactHeight * 0.20)
    )
    compactHeight = math.min(
        layerHeight,
        availableHeight - stepCount * compactOffset
    )
    local compactWidth = math.floor(compactHeight * 4 / 3)
    local centerPanelWidth = ingredientPanelLeft - recipePanelRight
    local compactX = recipePanelRight + math.floor(
        (centerPanelWidth - compactWidth) / 2
    )
    local compactBaseY = stackBottom - compactHeight

    return
        compactX,
        compactWidth,
        compactHeight,
        compactOffset,
        compactBaseY
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

local function drawLayer(
    label,
    y,
    isBread,
    x,
    width,
    height,
    offset,
    id
)
    local t = juice:getTransform(id)
    local group = juice:getTransform("burger")
    local err = juice:getTransform("error")
    local shakeX, shakeY = juice:getScreenOffset("burger")
    -- Transform the stack about its bottom, then each layer about its own bottom.
    -- These are draw-local values; permanent layout coordinates never change.
    local center = x + width / 2
    local bottom = stackBottom + (y + height - stackBottom) * group.scaleY
    width = math.floor(width * math.max(.90, math.min(1.12, t.scaleX * group.scaleX)) + .5)
    height = math.floor(height * math.max(.82, math.min(1.10, t.scaleY * group.scaleY)) + .5)
    x = math.floor(center - width / 2 + t.offsetX + group.offsetX + err.offsetX + shakeX + .5)
    y = math.floor(bottom - height + t.offsetY + group.offsetY + shakeY + .5)
    local inverted = t.invert or group.invert or err.invert
    gfx.setColor(inverted and gfx.kColorBlack or gfx.kColorWhite)
    gfx.fillRoundRect(
        x,
        y,
        width,
        height,
        isBread and 8 or 3
    )
    gfx.setColor(inverted and gfx.kColorWhite or gfx.kColorBlack)
    gfx.setLineWidth(isBread and 3 or 2)
    gfx.drawRoundRect(
        x,
        y,
        width,
        height,
        isBread and 8 or 3
    )
    gfx.setFont(smallFont)
    local textOffsetY = math.max(
        0,
        math.floor((offset - smallFont:getHeight()) / 2)
    )
    local oldMode = gfx.getImageDrawMode()
    if inverted then gfx.setImageDrawMode(gfx.kDrawModeInverted) end
    gfx.drawText(
        label,
        x + 7,
        y + height - offset + textOffsetY
    )
    gfx.setImageDrawMode(oldMode)
    gfx.setFont(systemFont)
end

local function drawBurger()
    local currentRecipe =
        PlayerConfig.recipe[assembly.currentRecipeIndex]
    local ingredientCount = #currentRecipe - 1
    local x, width, height, offset, baseY =
        AssemblyWorkstation.getStackLayout(ingredientCount)

    drawLayer(
        "BREAD",
        baseY,
        true,
        x,
        width,
        height,
        offset,
        0
    )

    for layerIndex, ingredientCode in ipairs(assembly.layers) do
        local layerY = baseY - layerIndex * offset
        drawLayer(
            assembly.ingredientNames[ingredientCode],
            layerY,
            false,
            x,
            width,
            height,
            offset,
            layerIndex
        )
    end

    if assembly.hasTopBread then
        local topBreadY =
            baseY - (#assembly.layers + 1) * offset
        drawLayer(
            "BREAD",
            topBreadY,
            true,
            x,
            width,
            height,
            offset,
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

function AssemblyWorkstation.getWheelCardSize(position)
    local distance = math.min(2, math.abs(position))

    if distance <= 1 then
        local centerBlend = 1 - distance
        return
            nearCardWidth +
                (activeCardWidth - nearCardWidth) * centerBlend,
            nearCardHeight +
                (activeCardHeight - nearCardHeight) * centerBlend
    end

    local nearBlend = 2 - distance
    return
        outerCardWidth +
            (nearCardWidth - outerCardWidth) * nearBlend,
        outerCardHeight +
            (nearCardHeight - outerCardHeight) * nearBlend
end

local function drawWheelCard(ingredientCode, position)
    local distance = math.min(2, math.abs(position))
    local centerBlend = math.max(0, 1 - distance)
    local width, height =
        AssemblyWorkstation.getWheelCardSize(position)
    local x = math.floor(wheelCenterX - width / 2)
    local y = math.floor(
        wheelCenterY + position * wheelSpacing - height / 2
    )

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(x, y, width, height, 5)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(centerBlend > 0.5 and 4 or 2)
    gfx.drawRoundRect(x, y, width, height, 5)

    gfx.setFont(smallFont)
    gfx.drawTextInRect(
        assembly.ingredientNames[ingredientCode],
        x + 3,
        y + 3,
        width - 6,
        height - 6,
        nil,
        nil,
        kTextAlignment.center
    )
    gfx.setFont(systemFont)
end

local function drawIngredientWheel()
    gfx.drawText("ITEMS", ingredientPanelLeft + 8, 7)
    gfx.setClipRect(
        ingredientPanelLeft + 1,
        24,
        PlayerConfig.screenWidth - ingredientPanelLeft - 1,
        184
    )

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

        if y > -30 and y < 260 then
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
