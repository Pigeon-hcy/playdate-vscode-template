import "playerConfig"

-- All score changes go through here so the formula lives in one place.
-- Points are integers and the score never drops below zero. An optional
-- Scoring.onChange(delta) is called with the nominal change for feedback.
Scoring = {}
local cfg <const> = PlayerConfig.scoring

local function notify(delta)
    if Scoring.onChange ~= nil then Scoring.onChange(delta) end
end

-- base + (kinds * perKind + count * perCount) * ingredientMultiplier
--      + whole seconds left on the order * perRemainingSecond,
-- the whole sum multiplied during rush hour.
function Scoring.burgerPoints(layers, remainingSeconds, isRush)
    local seen = {}
    local kinds = 0
    for _, code in ipairs(layers) do
        if not seen[code] then
            seen[code] = true
            kinds += 1
        end
    end
    local points = cfg.base +
        (kinds * cfg.perKind + #layers * cfg.perCount) * cfg.ingredientMultiplier +
        math.max(0, math.floor(remainingSeconds)) * cfg.perRemainingSecond
    if isRush then points *= cfg.rushMultiplier end
    return math.floor(points + .5)
end

function Scoring.awardBurger(layers, remainingSeconds, isRush)
    local points = Scoring.burgerPoints(layers, remainingSeconds, isRush)
    PlayerConfig.score += points
    notify(points)
    return points
end

local function penalize(penalty)
    PlayerConfig.score = math.max(0, PlayerConfig.score - penalty)
    notify(-penalty)
    return penalty
end

function Scoring.penalizeWrong()
    return penalize(cfg.wrongPenalty)
end

function Scoring.penalizeMissed(isRush)
    local penalty = cfg.missedPenalty
    if isRush then penalty = math.floor(penalty * cfg.rushMissedScale + .5) end
    return penalize(penalty)
end
