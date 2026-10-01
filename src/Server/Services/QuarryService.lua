-- The Quarry (see QuarryData): found it, place nodes and helpers, collect what it mines, upgrade the Core.
-- PlayerData.Quarry = { level, placed = { { id, x, z, rot } }, stored = { [material] = n }, last = unix time }
-- Mining is worked out lazily: `Accrue` credits the time since `last` (up to MAX_OFFLINE_HOURS) at the layout's rates,
-- and is called before anything that changes the layout, so changing it never rewrites the past.

local QuarryData        = require(game.ReplicatedStorage.Shared.Data.QuarryData)
local MaterialData      = require(game.ReplicatedStorage.Shared.Data.MaterialData)
local Utils             = require(game.ReplicatedStorage.Shared.Modules.Utils)
local PlayerDataService = require(script.Parent.PlayerDataService)

local QuarryService = {}

local function Now() return Utils.UnixTimestamp() end

local function Count(placed, id) local n = 0 for _, p in ipairs(placed) do if p.id == id then n += 1 end end return n end
local function NodeCount(placed) local n = 0 for _, p in ipairs(placed) do local d = QuarryData.Pieces[p.id] if d and d.kind == "node" then n += 1 end end return n end
local function StoredTotal(q) local n = 0 for _, v in pairs(q.stored) do n += v end return n end

local function Q(data) return type(data.Quarry) == "table" and data.Quarry.placed and data.Quarry or nil end

-- The Golems really working the Quarry: crew ids that still exist and are not deployed (anything else is dropped)
local function CrewGolems(data, q)
    local list, keep = {}, {}
    for _, id in ipairs(q.crew or {}) do
        for _, g in ipairs(data.Golems or {}) do
            if g.id == id and not g.deployed then table.insert(list, g) table.insert(keep, id) break end
        end
    end
    q.crew = keep
    return list
end

-- Credits the mined materials since the last time, up to the storage limit. Fractions are carried over.
function QuarryService.Accrue(data)
    local q = Q(data)
    if not q then return end
    local now = Now()
    local hours = math.clamp((now - (q.last or now)) / 3600, 0, QuarryData.MAX_OFFLINE_HOURS)
    q.last = now
    if hours <= 0 then return end
    q.frac = q.frac or {}
    local room = QuarryData.Capacity(q.placed, q.level) - StoredTotal(q)
    local crewBoost = QuarryData.CrewMultiplier(CrewGolems(data, q))
    for material, rate in pairs(QuarryData.RatesPerHour(q.placed)) do
        local exact = rate * crewBoost * hours + (q.frac[material] or 0)
        local whole = math.floor(exact)
        local take = math.max(0, math.min(whole, room))
        q.frac[material] = (take < whole) and 0 or (exact - whole)      -- a full silo wastes the overflow
        if take > 0 then q.stored[material] = (q.stored[material] or 0) + take room -= take end
    end
end

function QuarryService.Snapshot(player)
    local data = PlayerDataService.Get(player)
    if not data then return nil end
    local q = Q(data)
    local info = {
        coins = data.EmberCoins or 0, forgeLevel = data.ForgeLevel or 1, unlockLevel = QuarryData.UNLOCK_FORGE_LEVEL,
        foundCost = QuarryData.CORE_COST, founded = q ~= nil,
    }
    if not q then return info end
    QuarryService.Accrue(data)
    local lv = QuarryData.CoreLevel(q.level)
    local nextLv = QuarryData.CoreLevels[(q.level or 1) + 1]
    info.level, info.nodeLimit, info.placed, info.stored = q.level, lv.nodes, q.placed, q.stored
    info.capacity, info.storedTotal = QuarryData.Capacity(q.placed, q.level), StoredTotal(q)
    local crew = CrewGolems(data, q)
    info.crewBoost, info.crewSlots, info.crew = QuarryData.CrewMultiplier(crew), QuarryData.CREW_MAX_SLOTS, {}
    for _, g in ipairs(crew) do table.insert(info.crew, { id = g.id, element = g.element, tier = g.tier, variant = g.variant }) end
    info.idleGolems = {}
    for _, g in ipairs(data.Golems or {}) do
        if not g.deployed and not table.find(q.crew or {}, g.id) then table.insert(info.idleGolems, { id = g.id, element = g.element, tier = g.tier, variant = g.variant }) end
    end
    info.rates, info.nextLevel = QuarryData.RatesPerHour(q.placed), nextLv
    info.owned = {}
    for id in pairs(QuarryData.Pieces) do info.owned[id] = Count(q.placed, id) end
    local inv = {}
    for _, m in ipairs({ "TemperedEmber", "Stormglass", "FrostfireGem", "Voidstone", "PrismaticShard" }) do inv[m] = data.Inventory[m] or 0 end
    info.inventory = inv
    return info
end

function QuarryService.Found(player)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end
    if Q(data) then return false, "You already have a Quarry" end
    if (data.ForgeLevel or 1) < QuarryData.UNLOCK_FORGE_LEVEL then
        return false, string.format("Your Forge must be Level %d to found a Quarry (it is Level %d)", QuarryData.UNLOCK_FORGE_LEVEL, data.ForgeLevel or 1)
    end
    if (data.EmberCoins or 0) < QuarryData.CORE_COST then
        return false, string.format("Founding a Quarry costs %d coins (you have %d)", QuarryData.CORE_COST, data.EmberCoins or 0)
    end
    data.EmberCoins -= QuarryData.CORE_COST
    data.Quarry = { level = 1, placed = { { id = "Core", x = 0, z = 0, rot = 0 } }, stored = {}, frac = {}, last = Now() }
    PlayerDataService.MarkDirty(player)
    return true
end

-- Buy a piece and put it down at (x, z) studs from the Quarry centre. Returns true, or false + reason.
function QuarryService.Place(player, id, x, z, rot)
    local data = PlayerDataService.Get(player)
    local q = data and Q(data)
    if not q then return false, "Found your Quarry first" end
    local def = type(id) == "string" and QuarryData.Pieces[id] or nil
    if not def or def.kind == "core" then return false, "Unknown piece" end
    if type(x) ~= "number" or type(z) ~= "number" or x ~= x or z ~= z then return false, "Bad position" end
    QuarryService.Accrue(data)
    if Count(q.placed, id) >= def.max then return false, string.format("You can have at most %d of those", def.max) end
    if def.kind == "node" and NodeCount(q.placed) >= QuarryData.CoreLevel(q.level).nodes then
        return false, string.format("Your Core supports %d nodes. Upgrade it for more.", QuarryData.CoreLevel(q.level).nodes)
    end
    if (data.EmberCoins or 0) < def.price then return false, string.format("You need %d coins (you have %d)", def.price, data.EmberCoins or 0) end
    x, z = math.floor(x + 0.5), math.floor(z + 0.5)
    if math.abs(x) > QuarryData.PLOT_HALF or math.abs(z) > QuarryData.PLOT_HALF then return false, "That's outside your Quarry" end
    for _, p in ipairs(q.placed) do
        local limit = p.id == "Core" and QuarryData.CLEAR_HALF + 3 or QuarryData.SPACING
        if math.sqrt((p.x - x) ^ 2 + (p.z - z) ^ 2) < limit then return false, "Too close to another piece" end
    end
    rot = type(rot) == "number" and rot == rot and (math.floor(rot / 90 + 0.5) * 90) % 360 or 0
    data.EmberCoins -= def.price
    table.insert(q.placed, { id = id, x = x, z = z, rot = rot })
    PlayerDataService.MarkDirty(player)
    return true
end

-- Remove a placed piece for half its price. index = position in the placed list.
function QuarryService.Remove(player, index)
    local data = PlayerDataService.Get(player)
    local q = data and Q(data)
    if not q then return false, "No Quarry" end
    local p = type(index) == "number" and q.placed[index]
    if not p or p.id == "Core" then return false, "Nothing to remove there" end
    QuarryService.Accrue(data)
    table.remove(q.placed, index)
    data.EmberCoins = (data.EmberCoins or 0) + math.floor((QuarryData.Pieces[p.id].price or 0) * 0.5)
    PlayerDataService.MarkDirty(player)
    return true
end

-- Put an idle Golem to work in the Quarry (it can not mine in a zone while it does). Returns true, or false + reason.
function QuarryService.AddCrew(player, golemId)
    local data = PlayerDataService.Get(player)
    local q = data and Q(data)
    if not q then return false, "No Quarry" end
    if type(golemId) ~= "string" then return false, "Pick a Golem" end
    QuarryService.Accrue(data)
    CrewGolems(data, q)
    if #q.crew >= QuarryData.CREW_MAX_SLOTS then return false, string.format("Your crew is full (%d Golems)", QuarryData.CREW_MAX_SLOTS) end
    if table.find(q.crew, golemId) then return false, "That Golem is already working here" end
    for _, g in ipairs(data.Golems or {}) do
        if g.id == golemId then
            if g.deployed then return false, "Recall that Golem from its mining zone first" end
            table.insert(q.crew, golemId)
            PlayerDataService.MarkDirty(player)
            return true
        end
    end
    return false, "You do not have that Golem"
end

function QuarryService.RemoveCrew(player, golemId)
    local data = PlayerDataService.Get(player)
    local q = data and Q(data)
    if not q then return false, "No Quarry" end
    QuarryService.Accrue(data)
    local i = table.find(q.crew or {}, golemId)
    if not i then return false, "That Golem is not working here" end
    table.remove(q.crew, i)
    PlayerDataService.MarkDirty(player)
    return true
end

-- Move everything in the silo into your inventory. Returns the list collected, or nil + reason.
function QuarryService.Collect(player)
    local data = PlayerDataService.Get(player)
    local q = data and Q(data)
    if not q then return nil, "No Quarry" end
    QuarryService.Accrue(data)
    local got, any = {}, false
    for m, n in pairs(q.stored) do
        if n > 0 then
            data.Inventory[m] = (data.Inventory[m] or 0) + n
            got[m] = n any = true
        end
    end
    if not any then return nil, "The silo is empty" end
    q.stored = {}
    PlayerDataService.MarkDirty(player)
    return got
end

-- Spend Quarry materials to raise the Core a level (more nodes, more storage)
function QuarryService.UpgradeCore(player)
    local data = PlayerDataService.Get(player)
    local q = data and Q(data)
    if not q then return false, "No Quarry" end
    local nextLv = QuarryData.CoreLevels[(q.level or 1) + 1]
    if not nextLv then return false, "Your Core is at its highest level" end
    local names = {}
    for m in pairs(nextLv.cost) do table.insert(names, m) end
    table.sort(names)                                   -- the same material is always reported first
    for _, m in ipairs(names) do
        local n = nextLv.cost[m]
        if (data.Inventory[m] or 0) < n then
            return false, string.format("Needs %d %s (you have %d)", n, MaterialData.Get(m).displayName, data.Inventory[m] or 0)
        end
    end
    QuarryService.Accrue(data)
    for m, n in pairs(nextLv.cost) do
        data.Inventory[m] -= n
        if data.Inventory[m] <= 0 then data.Inventory[m] = nil end
    end
    q.level = nextLv.level
    PlayerDataService.MarkDirty(player)
    return true, q.level
end

return QuarryService
