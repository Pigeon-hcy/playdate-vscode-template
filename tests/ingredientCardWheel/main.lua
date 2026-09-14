-- Stage beside source/resource, then compile with pdc -I source.
-- Runtime regression: cached output must equal a plain redraw, including
-- wrapping, animation endpoints, the selection frame and persistent initials.
import "playerConfig"
import "ingredientCardWheel"
local gfx <const> = playdate.graphics
local state = PlayerConfig.assembly
local layout = { right = 380, centerY = 116, clipY = 34, clipHeight = 164,
    titleX = 294, titleY = 7 }
local wheel = IngredientCardWheel.new(state, layout, gfx.getSystemFont())
local cards = assert(gfx.imagetable.new("resource/ingredient-cards/cards"))
local initials = assert(gfx.imagetable.new("resource/ingredient-cards/initials"))
local actual = gfx.image.new(400, 240, gfx.kColorWhite)
local expected = gfx.image.new(400, 240, gfx.kColorWhite)
local originalPush, originalNew, originalText = gfx.pushContext, gfx.image.new, gfx.imageWithText
local bakes, allocations, textLayouts = 0, 0, 0
gfx.pushContext = function(target)
    if target ~= actual and target ~= expected then bakes += 1 end
    return originalPush(target)
end
gfx.image.new = function(...)
    allocations += 1
    return originalNew(...)
end
gfx.imageWithText = function(...)
    textLayouts += 1
    return originalText(...)
end

local function compare()
    gfx.pushContext(actual)
    gfx.clear(gfx.kColorWhite)
    wheel:draw()
    gfx.popContext()

    gfx.pushContext(expected)
    gfx.clear(gfx.kColorWhite)
    gfx.setFont(gfx.getSystemFont())
    gfx.drawText("ITEMS", 294, 7)
    local progress = 0
    if state.wheelIsAnimating then
        progress = state.wheelAnimationFrame / state.wheelAnimationDurationFrames
        progress = progress * progress * (3 - 2 * progress)
    end
    local highlight = state.selectedIngredientIndex
    if progress > .5 then highlight = ((highlight - 1 + state.wheelDirection) % 10) + 1 end
    initials:getImage(highlight):draw(288, 213)
    gfx.setClipRect(288, 34, 92, 164)
    for relative = -3, 3 do
        local position = relative - state.wheelDirection * progress
        local index = ((state.selectedIngredientIndex - 1 + relative) % 10) + 1
        local frame = index * 2 - (math.abs(position) < .5 and 0 or 1)
        cards:getImage(frame):draw(288, math.floor(116 + position * 53 - 24))
    end
    gfx.popContext()
    for y = 7, 236 do
        for x = 288, 379 do
            assert(actual:sample(x, y) == expected:sample(x, y),
                "cached wheel differs from the uncached reference")
        end
    end
end

state.wheelIsAnimating = false
state.wheelDirection = 0
for index = 1, 10 do
    state.selectedIngredientIndex = index
    compare()
    local before = bakes
    compare()
    assert(bakes == before, "an unchanged selection must reuse its cached panel")
end
for _, index in ipairs({ 1, 10 }) do
    state.selectedIngredientIndex = index
    for _, direction in ipairs({ -1, 1 }) do
        state.wheelIsAnimating = true
        state.wheelDirection = direction
        local before = bakes
        for frame = 0, state.wheelAnimationDurationFrames do
            state.wheelAnimationFrame = frame
            compare()
        end
        assert(bakes == before, "animation must draw directly, without rebuilding the panel")
    end
end
state.wheelIsAnimating = false
state.wheelDirection = 0
state.selectedIngredientIndex = 1
compare()
assert(allocations == 0 and textLayouts == 0, "drawing must not allocate images or lay out text")
gfx.pushContext, gfx.image.new, gfx.imageWithText = originalPush, originalNew, originalText
print("INGREDIENT CARD WHEEL TESTS PASSED")
function playdate.update()
    gfx.clear(gfx.kColorWhite)
    actual:draw(0, 0)
end
