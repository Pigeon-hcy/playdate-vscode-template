-- Variant D advances only while the player shakes the crank at the stove.
-- Its full-width progress bar replaces the old offscreen timer warning.
FryingWarning = {}

function FryingWarning.update() end
function FryingWarning.draw() end
function FryingWarning.isVisible() return false end
function FryingWarning.getMode() return nil end
function FryingWarning.getDanger() return nil end
function FryingWarning.getShake() return 0, 0 end
function FryingWarning.getDirection() return 0 end
