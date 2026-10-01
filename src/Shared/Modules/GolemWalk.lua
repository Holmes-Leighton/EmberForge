-- Where a mining Golem is and what its body is doing at time t: it mines at its spot, now and then walks a few steps to a new spot nearby and
-- carries on. Pure maths (no Instances), identical on every client and covered by tests; GolemAnimator turns the numbers into movement.
--
--   local st = GolemWalk.New(seed)
--   local s = GolemWalk.Sample(st, t)
--     s.x, s.z   offset from the Golem's home spot in studs (home = its place in the zone's ring)
--     s.yaw      the turn in radians that points it along its walk (it eases in at the start and back to 0, facing the ring's centre, at the end)
--     s.walking  true while it is on the move
--     s.stride   0..1 how far through the current walk it is (0 when not walking); leg and arm swing use `t * STRIDE_RATE` while walking
--     s.env      0..1 how much of a walk is "full speed" (0 at the start/end), for easing the limbs in and out
--
-- Every CYCLE seconds it does one stretch of mining and one walk. Where it goes is a deterministic point inside RADIUS of home, derived from
-- the cycle number, so no state needs to be kept or networked.

local GolemWalk = {}

GolemWalk.CYCLE = 15              -- seconds for one mine-then-walk loop
GolemWalk.WALK_TIME = 3.6         -- seconds of that spent walking
GolemWalk.RADIUS = 6              -- studs from home it may wander (the ring's Golems are about 19 studs apart)
GolemWalk.STRIDE_RATE = 7.5       -- radians per second of the leg swing while walking
GolemWalk.TURN_TIME = 0.5         -- seconds to turn toward the walk and back again

function GolemWalk.New(seed)
    seed = seed or 0
    return { seed = seed, offset = (seed * 0.6180339) % 1 * GolemWalk.CYCLE }
end

-- A repeatable point in the wander disc for cycle k (cycle 0 starts at home so a Golem always begins where it was placed)
local function Point(seed, k)
    if k <= 0 then return 0, 0 end
    local a = ((seed * 7919 + k * 104729) % 6283) / 1000            -- 0..2pi
    local r = (((seed * 31 + k * 977) % 1000) / 1000) ^ 0.5 * GolemWalk.RADIUS
    return math.cos(a) * r, math.sin(a) * r
end

local function Smooth(u) u = math.clamp(u, 0, 1) return u * u * (3 - 2 * u) end

function GolemWalk.Sample(st, t)
    local c = GolemWalk.CYCLE
    local clock = t + st.offset
    local k = math.floor(clock / c)
    local u = clock - k * c                                             -- seconds into this cycle
    local mineTime = c - GolemWalk.WALK_TIME
    local ax, az = Point(st.seed, k)
    if u < mineTime then
        return { x = ax, z = az, yaw = 0, walking = false, stride = 0, env = 0, k = k }
    end
    local w = (u - mineTime) / GolemWalk.WALK_TIME                       -- 0..1 through the walk
    local bx, bz = Point(st.seed, k + 1)
    local e = Smooth(w)
    local dx, dz = bx - ax, bz - az
    local dist = math.sqrt(dx * dx + dz * dz)
    local heading = dist > 0.01 and math.atan2(-dx, -dz) or 0            -- the yaw that points a Golem (which faces -Z) along its walk
    local turn = math.min(1, (u - mineTime) / GolemWalk.TURN_TIME, (GolemWalk.WALK_TIME - (u - mineTime)) / GolemWalk.TURN_TIME)
    local env = math.clamp(turn, 0, 1)
    return { x = ax + dx * e, z = az + dz * e, yaw = heading * Smooth(env), walking = dist > 0.5, stride = w, env = Smooth(env), k = k, dist = dist }
end

-- How far a leg swings (radians about the hip) at time t during a walk: the two legs are opposite. side = 1 or -1
function GolemWalk.LegSwing(s, t, side)
    if not s.walking then return 0 end
    return math.sin(t * GolemWalk.STRIDE_RATE) * 0.55 * s.env * side
end

-- Whole-body bounce while walking (studs up): one bob per step
function GolemWalk.Bob(s, t)
    if not s.walking then return 0 end
    return math.abs(math.sin(t * GolemWalk.STRIDE_RATE)) * 0.28 * s.env
end

return GolemWalk
