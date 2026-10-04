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
        id = "EasyHaul", name = "Easy Haul", tier = 1, minLevel = 1, rewardMult = 0.8, parSpeed = 10,
        color = Color3 and Color3.fromRGB(120, 210, 255) or nil,
        controls = {
            { 180, 0.6, -103 }, { 250, 0.6, -103 }, { 310, 0.6, -86 }, { 380, 0.6, -86 }, { 440, 0.6, -108 },
            { 500, 0.6, -108 }, { 550, 3, -101 }, { 600, 0.6, -99 },
        },
        tunnels     = { { 0.30, 0.66 } },
        checkpoints = { 0.5 },
        hazards     = {},
    },
    {
        id = "CaveRun", name = "Cave Run", tier = 2, minLevel = 4, rewardMult = 2, parSpeed = 10,
        color = Color3 and Color3.fromRGB(255, 190, 80) or nil,
        controls = {
            { 700, 0.6, -103 }, { 760, 0.6, -103 }, { 820, 0.6, -122 }, { 880, 0.6, -149 }, { 950, 0.6, -157 },
            { 1010, 8, -157 }, { 1070, 18, -147 }, { 1130, 24, -131 }, { 1190, 16, -113 }, { 1250, 6, -101 },
            { 1310, 0.6, -101 }, { 1380, 0.6, -101 }, { 1440, 0.6, -101 },
        },
        tunnels     = { { 0.12, 0.50 }, { 0.78, 0.94 } },
        checkpoints = { 0.34, 0.68 },
        hazards     = {
            { kind = "gate", at = 0.20, open = 4.5, closed = 3.0, phase = 0 },
            { kind = "gate", at = 0.88, open = 4.0, closed = 3.0, phase = 2 },
        },
    },
    {
        id = "DeepRun", name = "Deep Run", tier = 3, minLevel = 10, rewardMult = 4.5, parSpeed = 10,
        color = Color3 and Color3.fromRGB(255, 90, 60) or nil,
        controls = {
            { 1520, 0.6, -103 }, { 1580, 0.6, -103 }, { 1640, 0.6, -85 }, { 1700, 0.6, -68 }, { 1760, 5, -66 },
            { 1810, 16, -72 }, { 1860, 30, -82 }, { 1900, 44, -96 }, { 1935, 54, -112 }, { 1925, 50, -132 },
            { 1890, 40, -152 }, { 1840, 30, -172 }, { 1780, 20, -190 }, { 1720, 10, -202 }, { 1650, 3, -208 },
            { 1590, 0.6, -208 }, { 1540, 0.6, -196 }, { 1500, 0.6, -182 },
        },
        tunnels     = { { 0.02, 0.20 }, { 0.58, 0.70 }, { 0.84, 0.95 } },
        checkpoints = { 0.28, 0.55, 0.80 },
        hazards     = {
            { kind = "gate",   at = 0.05, open = 4.0, closed = 3.0, phase = 1 },
            { kind = "bridge", at = 0.13, length = 26, open = 4.5, closed = 3.0, phase = 0 },
            { kind = "gate",   at = 0.19, open = 3.5, closed = 3.0, phase = 3 },
            { kind = "bridge", at = 0.90, length = 26, open = 4.0, closed = 3.5, phase = 2 },
            { kind = "gate",   at = 0.96, open = 3.0, closed = 3.0, phase = 0 },
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
