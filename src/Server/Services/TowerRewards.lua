-- What the Sky Tower pays, with no Roblox objects in it so tests can check the sums. Reaching a new level pays at once (PayLevel); reaching the top pays a chest (PayTop).
-- Coins count against the Courier daily allowance for the tower (so the tower is not an unlimited faucet); materials, rare drops and Courier XP are not capped.
local TowerData      = require(game.ReplicatedStorage.Shared.Data.TowerData)
local CourierData    = require(game.ReplicatedStorage.Shared.Data.CourierData)
local CourierRewards = require(script.Parent.CourierRewards)

local TowerRewards = {}

function TowerRewards.State(data, today)
    local c = CourierRewards.State(data, today)
    if c.towerDay ~= today then c.towerDay, c.towerEarned, c.towerSummit, c.towerBest, c.towerBundles = today, 0, false, c.towerBest or 0, 0 end
    c.towerEarned = c.towerEarned or 0
    c.towerBundles = c.towerBundles or 0
    c.towerBest = c.towerBest or 0          -- the highest level ever reached
    return c
end

function TowerRewards.DailyCap(data)
    return (40 + 5 * (data.PlayerLevel or 1)) * TowerData.CAP_RUNS
end

-- What reaching `level` (1-based, the tower has `total` levels) pays. opts: { pro, coinMultiplier, rng }
-- Returns { coins, xp, materials, rare, level, capped }
function TowerRewards.PayLevel(data, level, total, today, opts)
    opts = opts or {}
    local c = TowerRewards.State(data, today)
    local mult = opts.pro and TowerData.PRO_PAY_MULT or 1
    local wanted = math.floor(TowerData.LevelCoins(data.PlayerLevel, level) * mult)
    local room = math.max(0, TowerRewards.DailyCap(data) - c.towerEarned)
    local coins = math.min(wanted, room)
    c.towerEarned += coins
    data.EmberCoins = (data.EmberCoins or 0) + math.floor(coins * (opts.coinMultiplier or 1))

    local materials, rare
    data.Inventory = data.Inventory or {}
    if level % TowerData.BUNDLE_EVERY == 0 and c.towerBundles < TowerData.BUNDLES_PER_DAY then
        c.towerBundles += 1
        materials = {}
        for _, item in ipairs(TowerData.BundleFor(level)) do
            local qty = math.max(1, math.floor(item.qty * mult))
            data.Inventory[item.id] = (data.Inventory[item.id] or 0) + qty
            table.insert(materials, { id = item.id, qty = qty })
        end
    end
    local chance = TowerData.RareChanceBase + TowerData.RareChancePerLevel * level
    if (opts.rng or math.random)() < chance then
        local drop = TowerData.RareFor(level)
        data.Inventory[drop.id] = (data.Inventory[drop.id] or 0) + drop.qty
        rare = { id = drop.id, qty = drop.qty }
    end

    local xp = TowerData.LevelXp(level, total)
    local lvl, cur, ups = CourierData.AddXp(c.level, c.xp, xp)
    c.level, c.xp = lvl, cur
    if level > c.towerBest then c.towerBest = level end
    return { coins = math.floor(coins * (opts.coinMultiplier or 1)), xp = xp, materials = materials, rare = rare, level = level, levelUps = ups, courierLevel = lvl,
        capped = coins < wanted }
end

-- The chest at the top. Returns { coins, materials, rare, firstToday }
function TowerRewards.PayTop(data, total, today, opts)
    opts = opts or {}
    local c = TowerRewards.State(data, today)
    local mult = opts.pro and TowerData.PRO_PAY_MULT or 1
    local first = not c.towerSummit
    c.towerSummit = true
    local wanted = math.floor(TowerData.LevelCoins(data.PlayerLevel, total) * TowerData.TOP_CHEST_MULT * mult * (first and TowerData.FIRST_SUMMIT_MULT or 1))
    local room = math.max(0, TowerRewards.DailyCap(data) - c.towerEarned)
    local coins = math.min(wanted, room)
    c.towerEarned += coins
    local paid = math.floor(coins * (opts.coinMultiplier or 1))
    data.EmberCoins = (data.EmberCoins or 0) + paid
    data.Inventory = data.Inventory or {}
    local drop = TowerData.RareFor(total)
    local qty = drop.qty * (first and 3 or 1)
    data.Inventory[drop.id] = (data.Inventory[drop.id] or 0) + qty
    return { coins = paid, rare = { id = drop.id, qty = qty }, firstToday = first, capped = coins < wanted }
end

-- The total coins a perfect climb of `total` levels would pay (for the balance check)
function TowerRewards.FullClimbCoins(playerLevel, total, pro)
    local sum = 0
    for n = 1, total do sum += math.floor(TowerData.LevelCoins(playerLevel, n) * (pro and TowerData.PRO_PAY_MULT or 1)) end
    return sum
end

return TowerRewards
