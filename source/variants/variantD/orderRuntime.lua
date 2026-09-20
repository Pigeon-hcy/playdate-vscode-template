import "variants/variantD/playerConfig"
import "variants/variantD/orderManager"
import "variants/variantD/scoring"

Orders = OrderManager.new(PlayerConfig.orders)
-- A missed order costs points wherever the shared queue is used.
Orders.onOrderExpired = function(_, queue)
    Scoring.penalizeMissed(queue:isRushHour())
end
