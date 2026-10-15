-- How a cart on a rail moves: pushed by players, slowed by friction and uphill slopes, and running away downhill. Pure maths, run by the server only
-- (clients draw the result). One state per cart: { s = distance along the route, v = speed along it (negative = rolling back), length = route length }.
local CartSim = {}

CartSim.LENGTH        = 9       -- how long the cart is along the rail (studs); hazards use half of it
CartSim.PUSH_RESPONSE = 1.5     -- how quickly a pusher drags the cart up to their pace (per second)
CartSim.PUSH_MAX      = 14      -- the fastest one player can shove it (a bit under walking speed, 16)
CartSim.TEAM_BONUS    = 0.25    -- each extra pusher adds this share to the target speed
CartSim.TEAM_MAX      = 22
CartSim.MAX_RUN       = 26      -- top speed rolling downhill
CartSim.BACK_MAX      = 14      -- top speed rolling backwards
CartSim.FRICTION      = 2.2     -- studs/s^2 slowing a moving cart
CartSim.GRAVITY       = 22      -- studs/s^2 per unit of slope
CartSim.BRAKE         = 11      -- studs/s^2 when someone walks against the cart to hold it back
CartSim.CORNER_G      = 16      -- sideways pull a bend can take: the fastest safe speed round a bend of radius R is sqrt(CORNER_G * R)
CartSim.CORNER_SLACK  = 1.08    -- a little give before it actually tips
CartSim.STATIC        = 4.8     -- a parked cart stays put while the slope pulls it with less than this (so slopes above ~0.22 roll it back)

-- speeds: the forward speeds (studs/s, each > 0) of the players pushing. Returns the pace the cart is dragged towards, or nil when nobody pushes.
function CartSim.PushTarget(speeds)
    local n, best = 0, 0
    for _, v in ipairs(speeds) do
        n += 1
        if v > best then best = v end
    end
    if n == 0 then return nil end
    return math.min(math.min(best, CartSim.PUSH_MAX) * (1 + CartSim.TEAM_BONUS * (n - 1)), CartSim.TEAM_MAX)
end

-- Advances st by dt seconds. slope: the route's rise at the cart (+ uphill). pushV: from PushTarget, or nil.
-- The fastest the cart can take a bend of the given curvature (1 / radius) without tipping over
function CartSim.CornerLimit(curvature)
    if curvature < 1e-4 then return math.huge end
    return math.sqrt(CartSim.CORNER_G / curvature) * CartSim.CORNER_SLACK
end

-- brake: someone is holding the cart back (walking against it): it slows hard but is never pushed into reverse by the brake
function CartSim.Step(st, dt, slope, pushV, brake)
    local a = -CartSim.GRAVITY * slope
    if pushV and pushV > st.v then a += (pushV - st.v) * CartSim.PUSH_RESPONSE end
    local free = a                                           -- the pull before friction
    local v = st.v

    if math.abs(v) < 0.05 then
        if math.abs(free) <= (pushV and CartSim.FRICTION or CartSim.STATIC) then
            st.v = 0
            return
        end
        a -= CartSim.FRICTION * (free > 0 and 1 or -1)
    else
        a -= CartSim.FRICTION * (v > 0 and 1 or -1)
    end

    if brake and v > 0 then a -= CartSim.BRAKE end
    local nv = math.clamp(v + a * dt, -CartSim.BACK_MAX, CartSim.MAX_RUN)
    if brake and v > 0 and nv < 0 then nv = 0 end
    if v ~= 0 and (nv > 0) ~= (v > 0) and math.abs(free) <= CartSim.STATIC then nv = 0 end      -- friction stops a cart, it never reverses it
    st.v = nv
    st.s += nv * dt
    if st.s <= 0 then st.s, st.v = 0, math.max(st.v, 0) end
    if st.s >= st.length then st.s, st.v = st.length, math.min(st.v, 0) end
end

return CartSim
