-- What a finished Courier Run is worth, with no Roblox objects in it so tests can check the sums. Settle() changes the player's data (coins, materials, Courier XP and
-- level, personal best, the day's allowance and daily challenge) and returns a summary the client shows on the results screen.
local CourierData    = require(game.ReplicatedStorage.Shared.Data.CourierData)
local CartBountyData = require(game.ReplicatedStorage.Shared.Data.CartBountyData)

local CourierRewards = {}

CourierRewards.BUNDLE_RUNS_PER_DAY = 15       -- material bundles are paid for this many runs a day; after that a run pays coins and XP only
CourierRewards.CAP_RUNS_BASE = 25             -- the daily coin allowance is this many "base rewards" (so about this many rookie runs)

function CourierRewards.Defaults()
    return { level = 1, xp = 0, runs = 0, best = {}, day = 0, earned = 0, runsToday = 0, dailyDone = 0 }
end

-- The saved Courier table, brought up to today (the allowance and run counts reset each UTC day)
function CourierRewards.State(data, today)
    local c = data.Courier
    if type(c) ~= "table" then c = CourierRewards.Defaults() data.Courier = c end
    c.level = math.clamp(math.floor(c.level or 1), 1, CourierData.MAX_LEVEL)
    c.xp, c.runs = c.xp or 0, c.runs or 0
    c.best = type(c.best) == "table" and c.best or {}
    c.dailyDone = c.dailyDone or 0
    if c.day ~= today then c.day, c.earned, c.runsToday = today, 0, 0 end
    c.earned, c.runsToday = c.earned or 0, c.runsToday or 0
    return c
end

-- Coins a run pays before the medal, the Courier bonus and events: scales with the player's level and the course
function CourierRewards.BaseReward(data, course)
    return math.floor((40 + 5 * (data.PlayerLevel or 1)) * course.rewardMult)
end

function CourierRewards.DailyCap(data)
    return (40 + 5 * (data.PlayerLevel or 1)) * CourierRewards.CAP_RUNS_BASE
end

-- Can this player start this course? Returns ok, reason
function CourierRewards.CanStart(data, course, today)
    if (data.PlayerLevel or 1) < course.minLevel then
        return false, string.format("%s needs player level %d (you are level %d).", course.name, course.minLevel, data.PlayerLevel or 1)
    end
    local c = CourierRewards.State(data, today)
    if c.level < course.minCourier then
        return false, string.format("%s needs Courier Level %d (you are level %d). Finish easier courses to level up.", course.name, course.minCourier, c.level)
    end
    return true
end

-- Applies a finished run. rng(): a function returning a number in [0, 1) (for the rare drop). `coinMultiplier` is a live-event multiplier (1 normally).
-- Returns { medal, coins, xp, levelUps, level, materials = { {id, qty} }, rare = {id, qty} or nil, personalBest, previousBest, daily = { coins, rare } or nil,
--           cappedCoins, bundleSkipped }
function CourierRewards.Settle(data, course, seconds, respawns, today, rng, coinMultiplier)
    local c = CourierRewards.State(data, today)
    local def = course.def or course
    local medal, bonus = CartBountyData.Medal(seconds, course.par)
    local perks = CourierData.Perks(c.level)

    -- coins: base x medal x courier bonus x event, but never past the day's allowance
    local base = CourierRewards.BaseReward(data, def)
    local wanted = math.floor(base * bonus * (1 + perks.coinBonus))
    local room = math.max(0, CourierRewards.DailyCap(data) - c.earned)
    local coins = math.min(wanted, room)
    local paid = math.floor(coins * (coinMultiplier or 1))
    data.EmberCoins = (data.EmberCoins or 0) + paid
    c.earned += coins

    -- materials: a bundle for the first runs of the day, plus a small chance of something rare (scaled up by the medal)
    local materials, rare
    local bundleSkipped = c.runsToday >= CourierRewards.BUNDLE_RUNS_PER_DAY
    if not bundleSkipped then
        materials = {}
        local scale = (medal == "Gold") and 1.5 or ((medal == "Silver") and 1.2 or 1)
        data.Inventory = data.Inventory or {}
        for _, item in ipairs(CourierData.Bundles[def.tier]) do
            local qty = math.max(1, math.floor(item.qty * scale))
            data.Inventory[item.id] = (data.Inventory[item.id] or 0) + qty
            table.insert(materials, { id = item.id, qty = qty })
        end
        local chance = CourierData.RareChance[def.tier] * ((medal == "Gold") and 1.5 or 1)
        if rng() < chance then
            local drop = CourierData.RareDrops[def.tier]
            data.Inventory[drop.id] = (data.Inventory[drop.id] or 0) + drop.qty
            rare = { id = drop.id, qty = drop.qty }
        end
    end
    c.runsToday += 1
    c.runs += 1

    -- Courier XP and level
    local xp = CourierData.RunXp(def, medal)
    local level, curXp, ups = CourierData.AddXp(c.level, c.xp, xp)
    c.level, c.xp = level, curXp

    -- personal best (seconds, one decimal)
    local previousBest = c.best[def.id]
    local personalBest = false
    if type(previousBest) ~= "number" or seconds < previousBest then
        c.best[def.id] = math.floor(seconds * 10 + 0.5) / 10
        personalBest = true
    end

    -- the daily challenge: Gold on today's course, once a day
    local daily
    local challenge = CourierData.DailyChallenge(today)
    if challenge.courseId == def.id and medal == challenge.medal and c.dailyDone ~= today then
        c.dailyDone = today
        local bonusCoins = math.floor(base * challenge.bonusCoinsMult)
        data.EmberCoins = (data.EmberCoins or 0) + bonusCoins
        daily = { coins = bonusCoins }
        local drop = CourierData.RareDrops[def.tier]
        data.Inventory = data.Inventory or {}
        data.Inventory[drop.id] = (data.Inventory[drop.id] or 0) + drop.qty * 2
        daily.rare = { id = drop.id, qty = drop.qty * 2 }
    end

    return {
        medal = medal, coins = paid, xp = xp, levelUps = ups, level = level, xpInto = curXp, xpNeeded = level < CourierData.MAX_LEVEL and CourierData.XpToNext(level) or 0,
        materials = materials, rare = rare, personalBest = personalBest, previousBest = previousBest, daily = daily,
        cappedCoins = coins < wanted, bundleSkipped = bundleSkipped, seconds = seconds, respawns = respawns,
    }
end

return CourierRewards
