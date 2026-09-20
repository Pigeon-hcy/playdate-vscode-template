import "variants/variantA/playerConfig"
import "variants/variantA/orderManager"
import "variants/variantA/scoring"

Orders = OrderManager.new(PlayerConfig.orders)
-- A missed order costs points wherever the shared queue is used.
Orders.onOrderExpired = function(_, queue)
    Scoring.penalizeMissed(queue:isRushHour())
end
