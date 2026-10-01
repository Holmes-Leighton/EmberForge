-- Idle animation sequencer, shared by pets (PetRig) and Golems (GolemAnimator).
-- A character that is standing still performs one of its idle moves, then rests for a few seconds, then picks a DIFFERENT
-- move at random, and so on. Pure maths, no Instances, so it is covered by tests.
--
--   local st = IdleMoves.New(set, seed)
--   local move, k = IdleMoves.Step(st, t, active)    -- k = progress 0..1 through the move; move = nil while resting
--   IdleMoves.Body("pet", move, k, t) -> bob, pitch, roll, yaw     (whole-body offsets for that move)
local IdleMoves = {}

-- name -> seconds. Pets and Golems each have four.
IdleMoves.Sets = {
    pet   = { look = 3.0, stretch = 2.2, shake = 1.6, hop = 0.9 },
    golem = { look = 3.2, flex = 2.4, stomp = 1.8, inspect = 2.8 },
}
IdleMoves.REST_MIN, IdleMoves.REST_MAX = 2.5, 7

local function Order(set) local names = {} for n in pairs(IdleMoves.Sets[set]) do table.insert(names, n) end table.sort(names) return names end

-- restMin/restMax: seconds of rest between moves (defaults suit a standing pet; busy Golems rest longer)
function IdleMoves.New(set, seed, restMin, restMax)
    return { set = set, seed = seed or 0, move = nil, startAt = 0, nextAt = nil, last = nil, count = 0,
        restMin = restMin or IdleMoves.REST_MIN, restMax = restMax or IdleMoves.REST_MAX }
end

local function Rand(st, a, b)
    st.seed = (st.seed * 1103515245 + 12345) % 2147483648                 -- tiny deterministic generator (identical in tests and in game)
    return a + (st.seed / 2147483648) * (b - a)
end

-- Advances the sequencer. `active` = false when the character is walking/busy (the current move is dropped).
function IdleMoves.Step(st, t, active)
    if not active then st.move, st.nextAt = nil, nil return nil, 0 end
    if not st.nextAt then st.nextAt = t + Rand(st, 1, st.restMax) end
    if not st.move then
        if t >= st.nextAt then
            local names = Order(st.set)
            local pick
            repeat pick = names[math.floor(Rand(st, 1, #names + 1))] or names[1] until pick ~= st.last or #names == 1
            st.move, st.startAt, st.last, st.count = pick, t, pick, st.count + 1
        else
            return nil, 0
        end
    end
    local dur = IdleMoves.Sets[st.set][st.move]
    local k = (t - st.startAt) / dur
    if k >= 1 then
        st.move, st.nextAt = nil, t + Rand(st, st.restMin, st.restMax)
        return nil, 0
    end
    return st.move, k
end

-- Whole-body offsets. bob = studs up, pitch/roll/yaw in radians (pitch negative = leaning forward)
function IdleMoves.Body(set, move, k, t)
    if not move then return 0, 0, 0, 0 end
    local env = math.sin(math.clamp(k, 0, 1) * math.pi)
    if set == "pet" then
        if move == "look" then return 0, 0, 0, math.sin(k * math.pi * 3) * 0.5 * env
        elseif move == "stretch" then return 0, -0.3 * env, 0, 0
        elseif move == "shake" then return 0, 0, math.sin(t * 26) * 0.18 * env, 0
        elseif move == "hop" then return env * 1.1, -0.1 * env, 0, k * math.pi * 2 end
    else
        if move == "look" then return 0, 0, 0, math.sin(k * math.pi * 3) * 0.45 * env
        elseif move == "flex" then return 0, 0.1 * env, 0, 0
        elseif move == "stomp" then return math.max(0, math.sin(k * math.pi * 4)) * 0.25, 0, math.sin(k * math.pi * 4) * 0.04, 0
        elseif move == "inspect" then return 0, -0.15 * env, 0, math.sin(k * math.pi * 2) * 0.25 * env end
    end
    return 0, 0, 0, 0
end

return IdleMoves
