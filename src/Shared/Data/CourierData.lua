-- Courier Run: carry a freight crate through an obstacle course to the drop-off. Platforming (steps, climbs, moving and crumbling platforms, spinning bars, crushers),
-- checkpoints so a fall only costs a little, and on the harder courses a wall of lava chasing you. Three courses in the north strip of the hub (behind the quarry
-- plots, where the floor is free), raised above the cavern floor so touching the floor means you fell.
-- The geometry comes from CourierLayout (pure maths); this file says which obstacles each course has, what it pays, and how the Courier Level works.
local CourierLayout = require(script.Parent.Parent.Modules.CourierLayout)

local CourierData = {}

CourierData.ZONE = { x1 = 455, x2 = 2045, z1 = 104, z2 = 178, maxY = 85 }     -- the area the courses must stay inside
CourierData.CRATE_SPEED_FACTOR = 0.9         -- carrying the crate slows you a little
CourierData.RESPAWN_PENALTY    = 3           -- seconds added to your time for each fall
CourierData.PAR_SPEED          = 5           -- studs/s a good run averages (Gold is at or under length / this, per course unless `par` is set)
CourierData.MIN_SPEED          = 40          -- a section can't be done faster than this many studs/s (a teleport or fly cheat); the runner checks it
CourierData.IDLE_ABANDON       = 240         -- seconds without reaching a checkpoint before a run is dropped
CourierData.LEAVE_RADIUS       = 140         -- wandering this far from the course drops the run

-- The limits each tier's jumps must respect (checked by the tests). A default character jumps about 8.6 studs flat and 7.2 up.
CourierData.Limits = {
    [1] = { maxGap = 5.0, maxRise = 3.0, minWidth = 8 },
    [2] = { maxGap = 6.0, maxRise = 3.5, minWidth = 4 },
    [3] = { maxGap = 7.0, maxRise = 4.0, minWidth = 3 },      -- (a beam can be narrow)
}

CourierData.Courses = {
    {
        id = "RookieRun", name = "Rookie Run", tier = 1, minLevel = 3, minCourier = 1, rewardMult = 1.0,
        color = Color3 and Color3.fromRGB(120, 210, 255) or nil,
        base = { x = 470, y = 14, z = 142 }, zRange = 12,
        lava = nil,
        par = 75,
        modules = {
            { "rest",    { len = 26, width = 26 } },
            { "steps",   { n = 5, gap = 3.5, len = 9, width = 10, rises = { 1, 0, 1, -1, 0 }, zigs = { 0, 3, -3, 2, -2 } } },
            { "rest",    { gap = 3.5, len = 20, width = 22 } },
            { "climb",   { n = 4, gap = 3.5, rise = 2.5, len = 9, width = 10, zigs = { 0, 2, -2, 2 } } },
            { "mover",   { span = 24, len = 10, width = 12, period = 7, landing = 10, landingWidth = 12 } },
            { "rest",    { gap = 0, len = 20, width = 22 } },
            { "crumble", { n = 5, gap = 4, len = 8, width = 9, delay = 0.8 } },
            { "rest",    { gap = 4, len = 20, width = 22 } },
            { "spinner", { gap = 3.5, len = 36, width = 24, radius = 10, omega = 1.1 } },
            { "finish",  { gap = 3.5, len = 32, width = 28 } },
        },
    },
    {
        id = "CavernCourier", name = "Cavern Courier", tier = 2, minLevel = 8, minCourier = 3, rewardMult = 2.5,
        color = Color3 and Color3.fromRGB(255, 190, 80) or nil,
        base = { x = 910, y = 14, z = 142 }, zRange = 12,
        lava = { speed = 3.4, headStart = 55 },
        par = 110,
        modules = {
            { "rest",    { len = 26, width = 26 } },
            { "steps",   { n = 4, gap = 4.5, len = 7, width = 8, rises = { 1, 0, 1, 0 }, zigs = { 0, 4, -4, 3 } } },
            { "rest",    { gap = 4, len = 18, width = 20 } },
            { "mover",   { span = 26, len = 9, width = 10, period = 6, landing = 9, landingWidth = 10 } },
            { "crusher", { gap = 0, len = 44, width = 14, n = 3, open = 4, closed = 2.5, zone = 6, stagger = 1.8 } },
            { "rest",    { gap = 0, len = 20, width = 22 } },
            { "climb",   { n = 5, gap = 4, rise = 3, len = 8, width = 8, zigs = { 0, 3, -3, 3, -3 } } },
            { "beam",    { gap = 4, len = 24, width = 4 } },
            { "rest",    { gap = 0, len = 20, width = 22 } },
            { "spinner", { gap = 4, len = 40, width = 24, radius = 11, omega = 1.6 } },
            { "crumble", { n = 5, gap = 4.5, len = 7, width = 8, delay = 0.6 } },
            { "finish",  { gap = 4.5, len = 32, width = 28 } },
        },
    },
    {
        id = "DeepCourier", name = "Deep Courier", tier = 3, minLevel = 14, minCourier = 8, rewardMult = 6,
        color = Color3 and Color3.fromRGB(255, 90, 60) or nil,
        base = { x = 1480, y = 14, z = 142 }, zRange = 12,
        lava = { speed = 4.2, headStart = 45 },
        par = 140,
        modules = {
            { "rest",    { len = 26, width = 26 } },
            { "crumble", { n = 5, gap = 5, len = 7, width = 7, delay = 0.5 } },
            { "rest",    { gap = 5, len = 18, width = 20 } },
            { "spinner", { gap = 4, len = 40, width = 22, radius = 10, omega = 2.0 } },
            { "steps",   { n = 5, gap = 5.5, len = 6, width = 6.5, rises = { 1, 0, 1, 0, -1 }, zigs = { 0, 4, -4, 4, -4 } } },
            { "rest",    { gap = 5, len = 18, width = 20 } },
            { "mover",   { span = 28, len = 8, width = 8, period = 5, landing = 8, landingWidth = 8 } },
            { "crusher", { gap = 4, len = 46, width = 12, n = 4, open = 3.5, closed = 2.5, zone = 6, stagger = 1.4 } },
            { "rest",    { gap = 0, len = 20, width = 22 } },
            { "climb",   { n = 6, gap = 4.5, rise = 3.5, len = 7, width = 7, zigs = { 0, 3, -3, 3, -3, 3 } } },
            { "beam",    { gap = 4.5, len = 26, width = 3.2 } },
            { "rest",    { gap = 0, len = 18, width = 20 } },
            { "crumble", { n = 5, gap = 5.5, len = 6, width = 6.5, delay = 0.45 } },
            { "finish",  { gap = 5.5, len = 32, width = 28 } },
        },
    },
}

function CourierData.Get(id)
    for _, c in ipairs(CourierData.Courses) do
        if c.id == id then return c end
    end
    return nil
end

local resolved = {}
-- The course with its geometry built (cached): { def, id, name, layout, length, par }
function CourierData.Resolve(id)
    if resolved[id] then return resolved[id] end
    local c = CourierData.Get(id)
    if not c then return nil end
    local layout = CourierLayout.Build(c)
    local r = { def = c, id = c.id, name = c.name, layout = layout, length = layout.length, par = c.par or (layout.length / CourierData.PAR_SPEED) }
    resolved[id] = r
    return r
end

-- ── Courier Level ─────────────────────────────────────────────────────────────
CourierData.MAX_LEVEL = 20

-- Courier XP needed to go from `level` to the next
function CourierData.XpToNext(level)
    return math.floor(60 * level ^ 1.4)
end

-- XP for a finished run: more on the harder courses, more for a quick one
function CourierData.RunXp(course, medal)
    local base = 40 * course.tier
    return math.floor(base * (medal == "Gold" and 1.5 or (medal == "Silver" and 1.2 or 1)))
end

-- Adds xp; returns the new { level, xp } and how many levels were gained
function CourierData.AddXp(level, xp, gained)
    local lvl, cur, ups = level, xp + gained, 0
    while lvl < CourierData.MAX_LEVEL and cur >= CourierData.XpToNext(lvl) do
        cur -= CourierData.XpToNext(lvl)
        lvl += 1
        ups += 1
    end
    if lvl >= CourierData.MAX_LEVEL then cur = 0 end
    return lvl, cur, ups
end

-- What a Courier Level gives while you run: a share more coins, a little more speed, a little more jump
function CourierData.Perks(level)
    level = math.clamp(level or 1, 1, CourierData.MAX_LEVEL)
    return {
        coinBonus = 0.01 * (level - 1),                         -- up to +19%
        walkBonus = math.min(0.35 * (level - 1), 4),            -- studs/s, up to +4 (on the base 16)
        jumpBonus = math.min(0.12 * (level - 1), 1.5),          -- studs of jump height (base 7.2)
    }
end

-- ── Rewards ───────────────────────────────────────────────────────────────────
-- What a delivery pays besides coins: a bundle of raw materials, and a small chance of a rare one. Scaled by the medal.
CourierData.Bundles = {
    [1] = { { id = "BasicOre", qty = 30 }, { id = "Coal", qty = 15 } },
    [2] = { { id = "RefinedOre", qty = 10 }, { id = "EmberDust", qty = 6 } },
    [3] = { { id = "ElementalIngot", qty = 4 }, { id = "CrystalFragment", qty = 3 } },
}
CourierData.RareChance = { [1] = 0.05, [2] = 0.10, [3] = 0.18 }
CourierData.RareDrops  = {
    [1] = { id = "RefinedOre", qty = 5 },
    [2] = { id = "ElementalIngot", qty = 2 },
    [3] = { id = "EssenceShard", qty = 2 },
}

-- ── Daily challenge ───────────────────────────────────────────────────────────
-- One course a day, in rotation: earn the Gold medal on it for a bonus chest (once a day).
function CourierData.DailyChallenge(day)
    local list = CourierData.Courses
    local course = list[(day % #list) + 1]
    return { courseId = course.id, medal = "Gold", bonusCoinsMult = 3 }
end

function CourierData.Today()
    return math.floor(os.time() / 86400)
end

return CourierData
