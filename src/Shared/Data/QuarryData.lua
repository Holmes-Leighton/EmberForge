-- The Quarry: your own mining zone. You build it on a second plot behind your forge from the Quarry Core, resource nodes
-- and helper buildings. It mines on its own (also while you are away) into a silo you empty from the Quarry menu.
--
--   * Nodes mine a normal material from the main zones.
--   * Put certain pieces NEXT TO a node (within LINK_RANGE studs) and it makes a Quarry-exclusive material instead:
--         Ember node  + Cooling Pool          -> Tempered Ember
--         Storm node  + Sky Spire             -> Stormglass
--         Frost node  + Ember node            -> Frostfire Gem   (both nodes make it)
--         Void node   + Stone node            -> Voidstone       (both nodes make it)
--         3 different nodes + a Prism Cluster -> Prismatic Shard (the cluster's neighbours)
--   * A Drill Rig speeds every node near it; a Silo raises the storage limit.
--   * Quarry materials are tradeable and upgrade the Core (more node slots, more storage), so they always matter.
local QuarryData = {}

QuarryData.LINK_RANGE   = 14        -- studs: how close pieces must be to count as "next to" each other
QuarryData.PLOT_HALF    = 26        -- the Quarry plot is the same size as the forge plot
QuarryData.CLEAR_HALF   = 4         -- keep the very middle free for the Core
QuarryData.SPACING      = 3
QuarryData.UNLOCK_FORGE_LEVEL = 6   -- the Quarry opens at Forge Level 6 (mid-game)
QuarryData.CORE_COST    = 15000     -- coins to found it
QuarryData.PLOT_OFFSET_Z = 70       -- the Quarry plot sits this many studs behind (+Z) your forge plot

-- Pieces. kind: core | node | helper.  rate = units mined per hour (before boosts).  height = studs shown at.
QuarryData.Pieces = {
    Core         = { name = "Quarry Core",   kind = "core",   height = 7,  max = 1, blurb = "The heart of your Quarry. Upgrade it with Quarry materials." },
    EmberNode    = { name = "Ember Crystal Node",  kind = "node", element = "Ember", makes = "IgniteOre",      rate = 90, height = 6, price = 4000,  max = 6, color = Color3.fromRGB(255, 110, 50) },
    FrostNode    = { name = "Frost Crystal Node",  kind = "node", element = "Frost", makes = "GlacialCrystal", rate = 90, height = 6, price = 4000,  max = 6, color = Color3.fromRGB(120, 200, 255) },
    StormNode    = { name = "Storm Crystal Node",  kind = "node", element = "Storm", makes = "ChargedFlint",   rate = 90, height = 6, price = 4000,  max = 6, color = Color3.fromRGB(255, 230, 90) },
    VoidNode     = { name = "Void Geode",          kind = "node", element = "Void",  makes = "ShadowDust",     rate = 60, height = 5, price = 7000,  max = 4, color = Color3.fromRGB(150, 80, 220) },
    StoneNode    = { name = "Granite Vein",        kind = "node", element = "Stone", makes = "GraniteShard",   rate = 90, height = 5, price = 3000,  max = 6, color = Color3.fromRGB(160, 160, 170) },
    CoolingPool  = { name = "Cooling Pool",  kind = "helper", height = 3, price = 6000,  max = 2, blurb = "Next to an Ember node: it makes Tempered Ember." },
    SkySpire     = { name = "Sky Spire",     kind = "helper", height = 12, price = 9000, max = 2, blurb = "Next to a Storm node: it makes Stormglass." },
    PrismCluster = { name = "Prism Cluster", kind = "helper", height = 6, price = 20000, max = 1, blurb = "Next to 3 different nodes: it makes Prismatic Shards." },
    DrillRig     = { name = "Drill Rig",     kind = "helper", height = 6, price = 8000,  max = 3, blurb = "Every node near it mines 35% faster." },
    Silo         = { name = "Storage Silo",  kind = "helper", height = 9, price = 5000,  max = 4, blurb = "Raises the storage limit by 400." },
}
QuarryData.PieceOrder = { "EmberNode", "FrostNode", "StormNode", "StoneNode", "VoidNode", "CoolingPool", "SkySpire", "DrillRig", "Silo", "PrismCluster" }

-- Crew: Golems NOT deployed to a mining zone can work the Quarry instead. Each adds CREW_PER_TIER x its tier to every node's output
-- (so a Tier 3 Golem is +24%), at most CREW_MAX_SLOTS Golems and CREW_CAP in total. Elite and Supreme Golems count for more.
QuarryData.CREW_PER_TIER  = 0.08
QuarryData.CREW_MAX_SLOTS = 4
QuarryData.CREW_CAP       = 1.0
QuarryData.CREW_VARIANT   = { Neon = 1.25, MegaNeon = 1.6 }

-- Output multiplier from a list of crew Golems ({ tier, variant }): 1.0 = no crew
function QuarryData.CrewMultiplier(crew)
    local bonus = 0
    for i, g in ipairs(crew or {}) do
        if i > QuarryData.CREW_MAX_SLOTS then break end
        bonus += QuarryData.CREW_PER_TIER * (g.tier or 1) * (QuarryData.CREW_VARIANT[g.variant] or 1)
    end
    return 1 + math.min(bonus, QuarryData.CREW_CAP)
end

QuarryData.EXCLUSIVE_RATE = 14      -- units/hour of an exclusive material from one linked node
QuarryData.DRILL_BOOST    = 0.35
QuarryData.BASE_STORAGE   = 600
QuarryData.SILO_STORAGE   = 400
QuarryData.MAX_OFFLINE_HOURS = 12   -- the Quarry stops filling after this long unattended (Silos do not extend it)

-- Core levels: what you get, and what it costs (Quarry materials, so upgrading needs the exclusives)
QuarryData.CoreLevels = {
    { level = 1, nodes = 6,  storage = 0,    cost = nil },
    { level = 2, nodes = 9,  storage = 300,  cost = { TemperedEmber = 40, Stormglass = 40 } },
    { level = 3, nodes = 12, storage = 700,  cost = { FrostfireGem = 40, Voidstone = 40, TemperedEmber = 60 } },
    { level = 4, nodes = 16, storage = 1500, cost = { PrismaticShard = 30, FrostfireGem = 80, Voidstone = 80 } },
}

local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) end

local function Near(placed, a, id)
    local out = {}
    for _, p in ipairs(placed) do
        if p ~= a and p.id == id and dist(a, p) <= QuarryData.LINK_RANGE then table.insert(out, p) end
    end
    return out
end

function QuarryData.CoreLevel(level) return QuarryData.CoreLevels[math.clamp(level or 1, 1, #QuarryData.CoreLevels)] end

function QuarryData.Capacity(placed, coreLevel)
    local cap = QuarryData.BASE_STORAGE + QuarryData.CoreLevel(coreLevel).storage
    for _, p in ipairs(placed) do if p.id == "Silo" then cap += QuarryData.SILO_STORAGE end end
    return cap
end

-- What every node is making right now, given the layout: { { piece = p, material = id, rate = n, exclusive = bool } }
function QuarryData.Production(placed)
    local nodes = {}
    for _, p in ipairs(placed) do
        local def = QuarryData.Pieces[p.id]
        if def and def.kind == "node" then table.insert(nodes, p) end
    end
    local out = {}
    local prism = {}                                   -- Prism Clusters that have 3 different nodes near them
    for _, p in ipairs(placed) do
        if p.id == "PrismCluster" then
            local kinds, members = {}, {}
            for _, n in ipairs(nodes) do
                if dist(p, n) <= QuarryData.LINK_RANGE then kinds[n.id] = true table.insert(members, n) end
            end
            local count = 0 for _ in pairs(kinds) do count += 1 end
            if count >= 3 then for _, n in ipairs(members) do prism[n] = true end end
        end
    end
    for _, n in ipairs(nodes) do
        local def = QuarryData.Pieces[n.id]
        local material, exclusive = def.makes, false
        if prism[n] then material, exclusive = "PrismaticShard", true
        elseif n.id == "EmberNode" and #Near(placed, n, "CoolingPool") > 0 then material, exclusive = "TemperedEmber", true
        elseif n.id == "StormNode" and #Near(placed, n, "SkySpire") > 0 then material, exclusive = "Stormglass", true
        elseif (n.id == "FrostNode" and #Near(placed, n, "EmberNode") > 0) or (n.id == "EmberNode" and #Near(placed, n, "FrostNode") > 0) then
            material, exclusive = "FrostfireGem", true
        elseif (n.id == "VoidNode" and #Near(placed, n, "StoneNode") > 0) or (n.id == "StoneNode" and #Near(placed, n, "VoidNode") > 0) then
            material, exclusive = "Voidstone", true
        end
        local rate = exclusive and QuarryData.EXCLUSIVE_RATE or def.rate
        local drills = Near(placed, n, "DrillRig")
        if #drills > 0 then rate *= (1 + QuarryData.DRILL_BOOST) end             -- drills do not stack: one is enough
        table.insert(out, { piece = n, material = material, rate = rate, exclusive = exclusive })
    end
    return out
end

-- Mined per hour, by material: { Voidstone = 28, IgniteOre = 90, ... }
function QuarryData.RatesPerHour(placed)
    local rates = {}
    for _, r in ipairs(QuarryData.Production(placed)) do rates[r.material] = (rates[r.material] or 0) + r.rate end
    return rates
end

return QuarryData
