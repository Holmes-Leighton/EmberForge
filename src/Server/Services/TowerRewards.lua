-- What the Sky Tower pays, with no Roblox objects in it so tests can check the sums. Reaching a new level pays at once (PayLevel); reaching the top pays a chest (PayTop).
-- Coins count against the Courier daily allowance for the tower (so the tower is not an unlimited faucet); materials, rare drops and Courier XP are not capped.
local TowerData      = require(game.ReplicatedStorage.Shared.Data.TowerData)
local CourierData    = require(game.ReplicatedStorage.Shared.Data.CourierData)
local CourierRewards = require(script.Parent.CourierRewards)

local TowerRewards = {}

function TowerRewards.State(data, today)
    local c = CourierRewards.State(data, today)
    if c.towerDay ~= today then c.towerDay, c.towerEarned, c.towerSummit, c.towerBest, c.towerBundles, c.towerZoneChests = today, 0, false, c.towerBest or 0, 0, 0 end
    c.towerZoneChests = c.towerZoneChests or 0
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

    -- clearing a zone (reaching the first level of the next one) pays that zone's chest: a bonus of coins and a pile of the zone's own material
    local zoneClear, zoneCoins = nil, 0
    local cleared = TowerData.ZoneClearedAt(level, total)
    if cleared and c.towerZoneChests < TowerData.ZONE_CHESTS_PER_DAY then
        c.towerZoneChests += 1
        local zone = TowerData.ZONES[cleared]
        local want = math.floor(TowerData.LevelCoins(data.PlayerLevel, level) * TowerData.ZONE_CHEST_MULT * mult)
        local bonus = math.min(want, math.max(0, TowerRewards.DailyCap(data) - c.towerEarned))
        c.towerEarned += bonus
        local paid = math.floor(bonus * (opts.coinMultiplier or 1))
        data.EmberCoins = (data.EmberCoins or 0) + paid
        local qty = math.max(1, math.floor(zone.material.qty * mult))
        data.Inventory[zone.material.id] = (data.Inventory[zone.material.id] or 0) + qty
        zoneClear = { zone = cleared, name = zone.name, coins = paid, material = { id = zone.material.id, qty = qty } }
        zoneCoins = bonus
    end

    local xp = TowerData.LevelXp(level, total)
    local lvl, cur, ups = CourierData.AddXp(c.level, c.xp, xp)
    c.level, c.xp = lvl, cur
    if level > c.towerBest then c.towerBest = level end
    return { coins = math.floor((coins + zoneCoins) * (opts.coinMultiplier or 1)), xp = xp, materials = materials, rare = rare, level = level, levelUps = ups, courierLevel = lvl,
        capped = coins < wanted, zoneClear = zoneClear }
end

-- The daily challenge: the first time today a climb reaches the target level (TowerData.DailyTarget) it pays a bonus chest. Returns { coins, rare, target } or nil.
function TowerRewards.PayDaily(data, level, total, today, opts)
    opts = opts or {}
    local c = TowerRewards.State(data, today)
    local target = TowerData.DailyTarget(today, total)
    if level < target or c.towerDailyDone == today then return nil end
    c.towerDailyDone = today
    local mult = opts.pro and TowerData.PRO_PAY_MULT or 1
    local coins = math.floor(TowerData.LevelCoins(data.PlayerLevel, target) * TowerData.DAILY_COIN_MULT * mult * (opts.coinMultiplier or 1))
    data.EmberCoins = (data.EmberCoins or 0) + coins
    data.Inventory = data.Inventory or {}
    local drop = TowerData.RareFor(target)
    data.Inventory[drop.id] = (data.Inventory[drop.id] or 0) + drop.qty * 2
    return { coins = coins, rare = { id = drop.id, qty = drop.qty * 2 }, target = target }
end

function TowerRewards.DailyDone(data, today)
    return TowerRewards.State(data, today).towerDailyDone == today
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
    -- the last zone is cleared by the summit itself: its chest of material comes with the summit chest
    local topZone = TowerData.ZONES[TowerData.ZONE_COUNT]
    local zoneQty = math.max(1, math.floor(topZone.material.qty * mult))
    data.Inventory[topZone.material.id] = (data.Inventory[topZone.material.id] or 0) + zoneQty
    return { coins = paid, rare = { id = drop.id, qty = qty }, firstToday = first, capped = coins < wanted, zoneMaterial = { id = topZone.material.id, qty = zoneQty, zone = topZone.name } }
end

-- The total coins a perfect climb of `total` levels would pay (for the balance check)
function TowerRewards.FullClimbCoins(playerLevel, total, pro)
    local sum = 0
    for n = 1, total do sum += math.floor(TowerData.LevelCoins(playerLevel, n) * (pro and TowerData.PRO_PAY_MULT or 1)) end
    return sum
end

return TowerRewards
