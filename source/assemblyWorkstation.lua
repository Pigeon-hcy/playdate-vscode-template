import "CoreLibs/graphics"
import "CoreLibs/crank"
import "playerConfig"

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
    gfx.font.new("/System/Fonts/Roobert-11-Medium") or systemFont

local grayTextImages = {}

AssemblyWorkstation = {}

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
    return true
end

function AssemblyWorkstation.selectRandomRecipe()
    assembly.currentRecipeIndex = math.random(#PlayerConfig.recipe)
end

function AssemblyWorkstation.initialize()
    assembly.layers = {}
    assembly.hasTopBread = false
    assembly.lastResult = nil
    assembly.wheelIsAnimating = false
    assembly.wheelAnimationFrame = 0
    assembly.wheelDirection = 0
    AssemblyWorkstation.selectRandomRecipe()
end

function AssemblyWorkstation.serveBurger()
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
    if not assembly.hasTopBread then
        assembly.hasTopBread = true
        return "closed"
    end

    if AssemblyWorkstation.serveBurger() then
        return "correct"
    end

    return "wrong"
end

function AssemblyWorkstation.handleInput()
    if pd.buttonJustPressed(pd.kButtonDown) and
        not assembly.wheelIsAnimating then
        local selectedCode =
            assembly.ingredientCodes[assembly.selectedIngredientIndex]
        AssemblyWorkstation.addIngredient(selectedCode)
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

local function drawRecipe()
    local currentRecipe = PlayerConfig.recipe[assembly.currentRecipeIndex]
    local order, requiredCounts = getRecipeRequirements(currentRecipe)
    local addedCounts = countIngredients(assembly.layers, 1)

    gfx.drawText("RECIPE", 8, 7)
    gfx.drawText(currentRecipe[1], 8, 28)
    gfx.setFont(smallFont)

    for lineIndex, ingredientCode in ipairs(order) do
        local requiredCount = requiredCounts[ingredientCode]
        local text = assembly.ingredientNames[ingredientCode]

        if requiredCount > 1 then
            text = text .. " *" .. requiredCount
        end

        local y = 52 + (lineIndex - 1) * 22
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

local function drawLayer(label, y, isBread)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(
        stackX,
        y,
        stackWidth,
        layerHeight,
        isBread and 8 or 3
    )
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(isBread and 3 or 2)
    gfx.drawRoundRect(
        stackX,
        y,
        stackWidth,
        layerHeight,
        isBread and 8 or 3
    )
    gfx.setFont(smallFont)
    gfx.drawText(
        label,
        stackX + 7,
        y + layerHeight - layerOffset + 2
    )
    gfx.setFont(systemFont)
end

local function drawBurger()
    drawLayer("BREAD", baseLayerY, true)

    for layerIndex, ingredientCode in ipairs(assembly.layers) do
        local layerY = baseLayerY - layerIndex * layerOffset
        drawLayer(
            assembly.ingredientNames[ingredientCode],
            layerY,
            false
        )
    end

    if assembly.hasTopBread then
        local topBreadY =
            baseLayerY - (#assembly.layers + 1) * layerOffset
        drawLayer("BREAD", topBreadY, true)
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

function AssemblyWorkstation.draw()
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(recipePanelRight, 0, recipePanelRight, 210)
    gfx.drawLine(ingredientPanelLeft, 0, ingredientPanelLeft, 210)

    drawRecipe()
    drawBurger()
    drawIngredientWheel()

    gfx.drawText("SCORE: " .. PlayerConfig.score, 112, 7)
    gfx.drawText("PATTY: " .. PlayerConfig.patties, 213, 7)

    if assembly.lastResult ~= nil then
        gfx.drawText(assembly.lastResult, 167, 31)
    end

    if assembly.hasTopBread then
        gfx.drawText("UP: SERVE", 157, 211)
    else
        gfx.drawText("DOWN: ADD   UP: BREAD", 110, 211)
    end
end
