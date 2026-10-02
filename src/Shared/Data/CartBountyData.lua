-- The Mine Cart Delivery bounty: the carts along the hub road are loaded with ore, and pushing one to the glowing depot at the end of its rail pays the
-- player who shoved it. The cart then rolls home and is reloaded after a cooldown, so there is always a cart or two to push but no single one can be farmed.
-- A coin source that rewards being active in the hub, scaled to how far a player has got, with a daily allowance like the Supplier's.
local CartBountyData = {}

CartBountyData.DELIVER_AT   = 50        -- studs along its rail from where it started (the rail allows 55) at which it counts as delivered
CartBountyData.RETURN_AFTER = 5         -- seconds after a delivery before the empty cart is wheeled back to its start
CartBountyData.COOLDOWN     = 120       -- seconds before a delivered cart is loaded again
CartBountyData.RANGE        = 18        -- how close a player must be to the cart when it arrives to be paid for it

CartBountyData.BASE, CartBountyData.PER_LEVEL = 30, 4                          -- coins per delivery: 30 + 4 per player level
CartBountyData.CAP_BASE, CartBountyData.CAP_PER_LEVEL, CartBountyData.CAP_MAX = 120, 15, 2500    -- the most a player can earn from deliveries in one UTC day

function CartBountyData.Reward(data)
    return CartBountyData.BASE + CartBountyData.PER_LEVEL * (data.PlayerLevel or 1)
end

function CartBountyData.Cap(data)
    return math.min(CartBountyData.CAP_MAX, CartBountyData.CAP_BASE + CartBountyData.CAP_PER_LEVEL * (data.PlayerLevel or 1))
end

function CartBountyData.Today()
    return math.floor(os.time() / 86400)
end

return CartBountyData
