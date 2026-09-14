import "CoreLibs/graphics"

local gfx <const> = playdate.graphics

IngredientCardWheel = {}

-- The only allocations and text layout happen here, once at station load.
function IngredientCardWheel.new(state, layout, font)
    local cards = assert(gfx.imagetable.new("resource/ingredient-cards/cards"))
    local initials = assert(gfx.imagetable.new("resource/ingredient-cards/initials"))
    local count = #state.ingredientCodes
    assert(#cards == count * 2 and #initials == count, "rebuild ingredient card assets")

    local normalImages, selectedImages, initialImages = {}, {}, {}
    for index = 1, count do
        normalImages[index] = cards:getImage(index * 2 - 1)
        selectedImages[index] = cards:getImage(index * 2)
        initialImages[index] = initials:getImage(index)
    end

    local width, height = state.ingredientCards.width, state.ingredientCards.height
    local x, titleY = layout.right - width, layout.titleY
    local spacing = state.ingredientCards.spacing
    local initialsY = state.ingredientCards.initialsY
    local panelHeight = initialsY + state.ingredientCards.initialsHeight - titleY
    local title = assert(gfx.imageWithText("ITEMS", width, 24,
        nil, nil, nil, nil, font))
    local panel = assert(gfx.image.new(width, panelHeight, gfx.kColorWhite))
    local cachedIndex = nil
    local wheel = {}

    local function drawCards(index, offset, originX, originY)
        for relative = -2, 2 do
            local position = relative + offset
            local y = math.floor(layout.centerY + position * spacing - height / 2)
            if y + height > layout.clipY and y < layout.clipY + layout.clipHeight then
                local ingredient = ((index - 1 + relative) % count) + 1
                local image = math.abs(position) < .5 and selectedImages[ingredient]
                    or normalImages[ingredient]
                image:draw(originX, originY + y)
            end
        end
    end

    local function bakeRestingPanel(index)
        gfx.pushContext(panel)
        gfx.setDrawOffset(0, 0)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        gfx.clearClipRect()
        gfx.clear(gfx.kColorWhite)
        title:draw(layout.titleX - x, 0)
        initialImages[index]:draw(0, initialsY - titleY)
        gfx.setClipRect(0, layout.clipY - titleY, width, layout.clipHeight)
        drawCards(index, 0, 0, -titleY)
        gfx.popContext()
        cachedIndex = index
    end

    function wheel:draw()
        local index = state.selectedIngredientIndex
        if not state.wheelIsAnimating then
            if cachedIndex ~= index then bakeRestingPanel(index) end
            -- One opaque 1:1 blit; no card iteration, font work, or clipping.
            panel:draw(x, titleY)
            return
        end

        -- During motion draw at most four visible cards straight to screen,
        -- avoiding an extra offscreen redraw/copy on each animation frame.
        local progress = state.wheelAnimationFrame / state.wheelAnimationDurationFrames
        progress = progress * progress * (3 - 2 * progress)
        local offset = -state.wheelDirection * progress
        title:draw(layout.titleX, titleY)
        -- The rail follows the thick-bordered card at the animation midpoint.
        local highlight = index
        if progress > .5 then
            highlight = ((index - 1 + state.wheelDirection) % count) + 1
        end
        initialImages[highlight]:draw(x, initialsY)
        gfx.setClipRect(x, layout.clipY, width, layout.clipHeight)
        drawCards(index, offset, x, 0)
        gfx.clearClipRect()
    end

    return wheel
end
