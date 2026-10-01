-- The Forge Builder: buy pieces with Ember Coins from a shop that restocks every few minutes, place them on your
-- own forge plot, pick them up again. Saved in PlayerData.ForgeBuild:
--   { owned = { [pieceId] = count }, placed = { { id, x, z, rot } }, bought = { slot = n, counts = { [id] = n } } }
-- x / z are studs from the plot centre. Visitors see the pieces (ForgeZoneService draws them); perks are read by IdleEngine.

local ForgeBuildData    = require(game.ReplicatedStorage.Shared.Data.ForgeBuildData)
local Utils             = require(game.ReplicatedStorage.Shared.Modules.Utils)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ForgeBuildService = {}

local function State(data)
    data.ForgeBuild = type(data.ForgeBuild) == "table" and data.ForgeBuild or {}
    local s = data.ForgeBuild
    s.owned  = type(s.owned) == "table" and s.owned or {}
    s.placed = type(s.placed) == "table" and s.placed or {}
    s.bought = type(s.bought) == "table" and s.bought or { slot = 0, counts = {} }
    return s
end

local function PlacedCount(s, id)
    local n = 0
    for _, p in ipairs(s.placed) do if p.id == id then n += 1 end end
    return n
end

-- What the Build menu shows: coins, what you own, what is placed, the shop and its restock time
function ForgeBuildService.Snapshot(player)
    local data = PlayerDataService.Get(player)
    if not data then return nil end
    local s = State(data)
    local now = Utils.UnixTimestamp()
    local stock, restockAt = ForgeBuildData.Stock(now)
    local slot = ForgeBuildData.SlotOf(now)
    local counts = (s.bought.slot == slot) and s.bought.counts or {}
    local owned = {}
    for id, n in pairs(s.owned) do owned[id] = { total = n, placed = PlacedCount(s, id) } end
    return {
        coins = data.EmberCoins or 0, owned = owned, placed = s.placed, stock = stock, restockAt = restockAt,
        boughtThisRestock = counts, perks = ForgeBuildData.Perks(s.placed),
    }
end

-- Buy one piece. Returns true, or false + a reason.
function ForgeBuildService.Buy(player, id)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end
    if type(id) ~= "string" then return false, "Unknown piece" end
    local it = ForgeBuildData.Get(id)
    if not it then return false, "Unknown piece" end
    local s = State(data)
    local now = Utils.UnixTimestamp()
    local slot = ForgeBuildData.SlotOf(now)
    if not ForgeBuildData.InStock(id, slot) then return false, it.name .. " is out of stock. Check back after the restock." end
    if s.bought.slot ~= slot then s.bought = { slot = slot, counts = {} } end
    if (s.bought.counts[id] or 0) >= ForgeBuildData.BUY_PER_RESTOCK then
        return false, "You've bought all you can of that this restock"
    end
    if (s.owned[id] or 0) >= it.maxOwned then
        return false, string.format("You can own at most %d of those", it.maxOwned)
    end
    if (data.EmberCoins or 0) < it.price then
        return false, string.format("You need %d coins (you have %d)", it.price, data.EmberCoins or 0)
    end
    data.EmberCoins -= it.price
    s.owned[id] = (s.owned[id] or 0) + 1
    s.bought.counts[id] = (s.bought.counts[id] or 0) + 1
    PlayerDataService.MarkDirty(player)
    return true
end

local function Snap(v) local g = ForgeBuildData.GRID return math.floor(v / g + 0.5) * g end

-- Place an owned piece at (x, z) studs from the plot centre, turned `rot` degrees. Returns true, or false + a reason.
function ForgeBuildService.Place(player, id, x, z, rot)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end
    local it = type(id) == "string" and ForgeBuildData.Get(id) or nil
    if not it then return false, "Unknown piece" end
    if type(x) ~= "number" or type(z) ~= "number" or x ~= x or z ~= z then return false, "Bad position" end
    local s = State(data)
    if (s.owned[id] or 0) - PlacedCount(s, id) <= 0 then return false, "You don't have one to place" end
    if #s.placed >= ForgeBuildData.MAX_PLACED then
        return false, string.format("Your forge is full (%d pieces)", ForgeBuildData.MAX_PLACED)
    end
    x, z = Snap(x), Snap(z)
    local half = ForgeBuildData.PLOT_HALF
    if math.abs(x) > half or math.abs(z) > half then return false, "That's outside your forge" end
    if math.max(math.abs(x), math.abs(z)) < ForgeBuildData.CLEAR_HALF then return false, "Keep the middle of your forge clear" end
    for _, p in ipairs(s.placed) do
        if math.sqrt((p.x - x) ^ 2 + (p.z - z) ^ 2) < ForgeBuildData.SPACING then
            return false, "Too close to another piece"
        end
    end
    rot = type(rot) == "number" and rot == rot and (math.floor(rot / 90 + 0.5) * 90) % 360 or 0
    table.insert(s.placed, { id = id, x = x, z = z, rot = rot })
    PlayerDataService.MarkDirty(player)
    return true
end

-- Pick a placed piece back up (it stays yours). `index` is its place in the placed list.
function ForgeBuildService.Pickup(player, index)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end
    local s = State(data)
    if type(index) ~= "number" or not s.placed[index] then return false, "Nothing there" end
    table.remove(s.placed, index)
    PlayerDataService.MarkDirty(player)
    return true
end

-- Sell a piece you are not using back for a share of its price
function ForgeBuildService.Sell(player, id)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end
    local it = type(id) == "string" and ForgeBuildData.Get(id) or nil
    if not it then return false, "Unknown piece" end
    local s = State(data)
    if (s.owned[id] or 0) - PlacedCount(s, id) <= 0 then return false, "Pick it up first" end
    s.owned[id] -= 1
    if s.owned[id] <= 0 then s.owned[id] = nil end
    local refund = math.floor(it.price * ForgeBuildData.SELL_BACK)
    data.EmberCoins = (data.EmberCoins or 0) + refund
    PlayerDataService.MarkDirty(player)
    return true, refund
end

-- Stat bonuses for IdleEngine: { rate, carry, eff, wear, luck }
function ForgeBuildService.Perks(data)
    return ForgeBuildData.Perks(type(data.ForgeBuild) == "table" and data.ForgeBuild.placed or nil)
end

return ForgeBuildService
