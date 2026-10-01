-- The shape of a Golem's mining swing. A plain sine wave looks mechanical; a good swing has anticipation, a hold at the top, a fast strike, a small
-- bounce when the pick lands, and an easy recovery. Pure maths (no Instances), covered by tests; GolemAnimator turns the numbers into limb poses.
--
--   GolemMotion.Raise(u)   how high the pick arm is at point u (0..1) of one swing:  0 = pick on the ground, 1 = overhead, REST = hanging ready
--   GolemMotion.IMPACT     the point u at which the pick lands (the moment to puff dust)
--   GolemMotion.Lagged(u, lag)   the same swing seen `lag` of a swing late: the head and shoulders follow through behind the arm

local GolemMotion = {}

GolemMotion.REST = 0.35          -- where the arm hangs between swings (also where one swing ends and the next begins)
GolemMotion.IMPACT = 0.48        -- the pick lands here

-- Phase boundaries (fractions of one swing)
local WINDUP_END, HOLD_END, STRIKE_END, REBOUND_END = 0.30, 0.38, 0.48, 0.62

local function Smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end

function GolemMotion.Raise(u)
    u = u % 1
    local rest = GolemMotion.REST
    if u < WINDUP_END then                                              -- anticipation: draw the pick back and up, easing in and out
        return rest + (1 - rest) * Smooth(u / WINDUP_END)
    elseif u < HOLD_END then                                            -- a beat at the top, with a tiny settle
        return 1 + 0.03 * math.sin((u - WINDUP_END) / (HOLD_END - WINDUP_END) * math.pi)
    elseif u < STRIKE_END then                                          -- the strike: slow to start, fast at the bottom (ease in)
        local k = (u - HOLD_END) / (STRIKE_END - HOLD_END)
        return 1 - k ^ 2.2
    elseif u < REBOUND_END then                                         -- the pick bounces off the ground and settles
        local k = (u - STRIKE_END) / (REBOUND_END - STRIKE_END)
        return 0.16 * math.sin(k * math.pi) * (1 - k * 0.5)
    end
    return rest * Smooth((u - REBOUND_END) / (1 - REBOUND_END))        -- recover to the ready position
end

-- Seen a little late (u minus lag), for parts that follow through
function GolemMotion.Lagged(u, lag)
    return GolemMotion.Raise(u - lag)
end

-- How "committed" the body is to the strike, -1 (leaning back, winding up) to +1 (driving forward at impact), for torso lean and twist
function GolemMotion.Drive(u)
    local r = GolemMotion.Raise(u)
    return math.clamp(0.55 - r, -0.45, 0.55) / 0.55
end

return GolemMotion
