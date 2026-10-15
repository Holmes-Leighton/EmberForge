-- Cart Run: pushing a loaded cart along a winding rail to the depot. Three courses, each harder and better paid, in the hub east of the spawn.
-- Every course mixes the same few ingredients, a different way, so no two stretches play alike:
--   curves + tunnels   keep up with the cart round corners
--   hills              push uphill or it stalls (steep ones roll it back); downhill it runs away from you
--   crusher gates      a door slams down on a timer: arrive while it is shut and the cart stops, get caught under it and it is crushed
--   retracting bridges the rail crosses a pit; arrive when the bridge is out and the cart falls
-- A derailed cart goes back to the last checkpoint. Checkpoints pay a little; the depot pays the most, more for a quick run (under par) and
-- for more pushers. Positions along a course are fractions of its length, so the shape can be reshaped without moving everything by hand.
local CartPath = require(script.Parent.Parent.Modules.CartPath)

local CartCourseData = {}

CartCourseData.DECK_Y        = 0.6      -- height of the road surface on level ground
CartCourseData.DECK_WIDTH    = 16
CartCourseData.RAIL_TOP      = 0.65    -- how far above the road the cart's wheels run
CartCourseData.TUNNEL_HEIGHT = 30
CartCourseData.GATE_CLEARANCE = 15      -- an open gate's door ends this far above the road (the cart is about 13 tall)
CartCourseData.RETURN_AFTER  = 6        -- seconds a delivered cart waits before it is wheeled back
CartCourseData.COOLDOWN      = 25       -- seconds before it can be pushed again
CartCourseData.IDLE_RESET    = 60       -- an abandoned cart (not at the start, nobody pushing) goes home after this long
CartCourseData.DERAIL_TIME   = 1.6      -- seconds a derailed cart waits before it is put back
CartCourseData.MIN_PUSH_TIME = 6        -- a player must have pushed at least this long to be paid for a run

CartCourseData.Courses = {
    {
        id = "EasyHaul", name = "Easy Haul", tier = 1, minLevel = 1, rewardMult = 0.8, parSpeed = 9,
        color = Color3 and Color3.fromRGB(120, 210, 255) or nil,
        -- wide bends and a couple of small hills: steady pushing is enough
        controls = {
            { 180, 0.6, -103 }, { 240, 0.6, -103 }, { 285, 0.6, -88 }, { 325, 0.6, -118 }, { 365, 0.6, -90 },
            { 405, 4, -120 }, { 440, 11, -150 }, { 480, 16, -165 }, { 520, 16, -140 }, { 550, 8, -112 },
            { 585, 0.6, -100 }, { 625, 0.6, -125 }, { 650, 0.6, -165 }, { 655, 0.6, -195 },
        },
        tunnels     = { { 0.08, 0.26 }, { 0.78, 0.92 } },
        checkpoints = { 0.5 },
        hazards     = {},
    },
    {
        id = "CaveRun", name = "Cave Run", tier = 2, minLevel = 4, rewardMult = 2, parSpeed = 9,
        color = Color3 and Color3.fromRGB(255, 190, 80) or nil,
        -- S-bends, a big climb and a steep drop into a tight chicane, two crusher gates
        controls = {
            { 700, 0.6, -103 }, { 745, 0.6, -103 }, { 780, 0.6, -70 }, { 815, 0.6, -120 }, { 850, 0.6, -78 },
            { 885, 0.6, -130 }, { 925, 0.6, -180 }, { 965, 0.6, -205 }, { 1000, 8, -182 }, { 1040, 20, -152 },
            { 1085, 32, -125 }, { 1120, 36, -108 }, { 1165, 22, -92 }, { 1205, 8, -82 }, { 1235, 0.6, -100 },
            { 1255, 0.6, -145 }, { 1285, 0.6, -190 }, { 1315, 0.6, -150 }, { 1340, 0.6, -110 }, { 1365, 0.6, -76 },
            { 1395, 0.6, -105 }, { 1420, 0.6, -101 }, { 1440, 0.6, -101 },
        },
        tunnels     = { { 0.06, 0.20 }, { 0.30, 0.42 }, { 0.80, 0.90 } },
        checkpoints = { 0.3, 0.62 },
        hazards     = {
            { kind = "gate", at = 0.12, open = 4.5, closed = 3.0, phase = 0 },
            { kind = "gate", at = 0.88, open = 3.8, closed = 3.0, phase = 2 },
        },
    },
    {
        id = "DeepRun", name = "Deep Run", tier = 3, minLevel = 10, rewardMult = 4.5, parSpeed = 9,
        color = Color3 and Color3.fromRGB(255, 90, 60) or nil,
        -- a twisting climb, a mountain with a sharp drop, then a long zig-zag descent of hairpins with bridges and gates
        controls = {
            { 1520, 0.6, -103 }, { 1560, 0.6, -103 }, { 1600, 0.6, -75 }, { 1630, 0.6, -110 }, { 1665, 0.6, -72 },
            { 1700, 0.6, -105 }, { 1735, 0.6, -70 }, { 1775, 5, -80 }, { 1815, 16, -95 }, { 1855, 30, -85 },
            { 1895, 44, -100 }, { 1930, 54, -118 }, { 1960, 44, -135 }, { 1990, 32, -160 }, { 1985, 18, -195 },
            { 1950, 6, -215 }, { 1905, 0.6, -150 }, { 1875, 0.6, -215 }, { 1840, 0.6, -150 }, { 1805, 0.6, -216 },
            { 1770, 0.6, -152 }, { 1735, 0.6, -215 }, { 1700, 0.6, -155 }, { 1665, 0.6, -214 }, { 1630, 0.6, -160 },
            { 1595, 0.6, -212 }, { 1560, 0.6, -175 }, { 1535, 0.6, -160 },
        },
        tunnels     = { { 0.04, 0.14 }, { 0.50, 0.58 } },
        checkpoints = { 0.24, 0.45, 0.72 },
        hazards     = {
            { kind = "gate",   at = 0.07, open = 3.6, closed = 3.0, phase = 1 },
            { kind = "bridge", at = 0.62, length = 26, open = 4.0, closed = 3.5, phase = 0 },
            { kind = "gate",   at = 0.73, open = 3.2, closed = 3.0, phase = 3 },
            { kind = "bridge", at = 0.79, length = 26, open = 3.6, closed = 3.5, phase = 2 },
            { kind = "gate",   at = 0.955, open = 3.0, closed = 3.0, phase = 0 },
        },
    },
}

function CartCourseData.Get(id)
    for _, c in ipairs(CartCourseData.Courses) do
        if c.id == id then return c end
    end
end

-- Is the hazard open (a gate raised / a bridge out) at server time t? Gates and bridges run on a shared clock, so every client draws what the server decides.
function CartCourseData.HazardOpen(h, t)
    local period = h.open + h.closed
    return ((t + (h.phase or 0)) % period) < h.open
end

-- Seconds until the hazard next changes (for a warning light)
function CartCourseData.HazardChangesIn(h, t)
    local period = h.open + h.closed
    local x = (t + (h.phase or 0)) % period
    return x < h.open and (h.open - x) or (period - x)
end

-- The course with its path built and every fraction turned into a distance: { path, length, par, tunnels = { {s0, s1} }, checkpoints = { s },
-- hazards = { { kind, s, ... } } }. Built once and cached.
local resolved = {}
function CartCourseData.Resolve(id)
    if resolved[id] then return resolved[id] end
    local c = CartCourseData.Get(id)
    if not c then return nil end
    local path = CartPath.Build(c.controls, CartCourseData.DECK_Y)
    local r = { def = c, id = c.id, name = c.name, path = path, length = path.length, par = path.length / c.parSpeed,
        tunnels = {}, checkpoints = {}, hazards = {} }
    for _, t in ipairs(c.tunnels or {}) do table.insert(r.tunnels, { t[1] * path.length, t[2] * path.length }) end
    for _, f in ipairs(c.checkpoints or {}) do table.insert(r.checkpoints, f * path.length) end
    for i, h in ipairs(c.hazards or {}) do
        local copy = { index = i, s = h.at * path.length }
        for k, v in pairs(h) do copy[k] = v end
        table.insert(r.hazards, copy)
    end
    resolved[id] = r
    return r
end

-- Is the point (x, z) within `margin` studs of any course's road? The world builder keeps rocks, crystals and the old carts off the routes with this.
local routePoints
function CartCourseData.NearRoute(x, z, margin)
    if not routePoints then
        routePoints = {}
        for _, c in ipairs(CartCourseData.Courses) do
            local r = CartCourseData.Resolve(c.id)
            for _, sm in ipairs(CartPath.Samples(r.path, 6)) do table.insert(routePoints, { sm.x, sm.z }) end
        end
    end
    local m2 = margin * margin
    for _, p in ipairs(routePoints) do
        local dx, dz = x - p[1], z - p[2]
        if dx * dx + dz * dz <= m2 then return true end
    end
    return false
end

return CartCourseData
