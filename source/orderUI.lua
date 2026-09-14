import "CoreLibs/graphics"
import "orderRuntime"

OrderUI = {}
local gfx <const> = playdate.graphics
local function loadHangingHolder()
    local source = assert(gfx.image.new("resource/orders/Holder"))
    local width, height = source:getSize()
    local flipped = gfx.image.new(width, height, gfx.kColorClear)
    gfx.pushContext(flipped)
    source:draw(0, 0, gfx.kImageFlippedY)
    gfx.popContext()
    return flipped
end
local holder <const> = loadHangingHolder()
local receipt <const> = assert(gfx.image.new("resource/orders/Receipt"))
local holderWidth, holderHeight = holder:getSize()
local ticketWidth, ticketHeight = receipt:getSize()
local holderX <const> = math.floor((PlayerConfig.screenWidth - holderWidth) / 2)
local holderY <const> = 0
local ticketRestY <const> = 2
local uiHeight <const> = math.max(holderHeight, ticketRestY + ticketHeight)
local ticketSpacing <const> = 26
local firstTicketX <const> = math.floor((PlayerConfig.screenWidth -
    (PlayerConfig.orders.capacity - 1) * ticketSpacing - ticketWidth) / 2)
local entryTravel <const> = ticketHeight + ticketRestY
-- Read the front lip once so expiry ends exactly behind the actual art.
local lipBottom = 0
while lipBottom < holderHeight and
    holder:sample(math.floor(holderWidth / 2), lipBottom) ~= gfx.kColorClear do
    lipBottom += 1
end
local exitY <const> = lipBottom - ticketHeight
local exitTravel <const> = ticketRestY - exitY

function OrderUI.getTicketY(order, queue)
    queue = queue or Orders
    local age = math.max(0, queue.time - order.createdAt)
    local entryDuration = PlayerConfig.orders.ticketEntryDuration
    if age < entryDuration then
        local progress = age / entryDuration
        return math.floor(ticketRestY - entryTravel * (1 - progress) ^ 3 + .5)
    end
    local y = math.floor(ticketRestY - exitTravel * queue:getSlideProgress(order) + .5)
    -- Keep one last row visible until the actual deadline; pixel rounding
    -- must not hide a still-submittable order a fraction of a second early.
    if queue.time < order.expiresAt then y = math.max(exitY + 1, y) end
    return y
end

function OrderUI.isUrgent(order, queue)
    queue = queue or Orders
    return order.expiresAt - queue.time <= PlayerConfig.orders.urgentSeconds
end

function OrderUI.draw()
    -- Fixed overlay, excluded from station snapshots. Clear its small bounds
    -- so tickets still animate while the two cached stations slide underneath.
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(holderX - 2, 0, holderWidth + 4, uiHeight + 1)
    gfx.setClipRect(holderX, 0, holderWidth, uiHeight)
    -- Tickets in their last seconds flash inverted, on a shared phase so
    -- several urgent orders blink together instead of flickering at random.
    local blinkOn = math.floor(Orders.time * PlayerConfig.orders.blinkHz * 2) % 2 == 0
    for _, order in ipairs(Orders.pending) do
        local urgent = blinkOn and OrderUI.isUrgent(order)
        if urgent then gfx.setImageDrawMode(gfx.kDrawModeInverted) end
        receipt:draw(firstTicketX + (order.slot - 1) * ticketSpacing,
            OrderUI.getTicketY(order))
        if urgent then gfx.setImageDrawMode(gfx.kDrawModeCopy) end
    end
    -- The inverted holder is fixed to the screen top; tickets hang below
    -- its front lip and retract behind it as they age.
    holder:draw(holderX, holderY)
    gfx.popContext()
end
