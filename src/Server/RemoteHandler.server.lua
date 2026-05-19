-- Wires up all RemoteEvent / RemoteFunction handlers with rate limiting.

local Players = game:GetService("Players")

local RemoteEvents      = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local GameConfig        = require(game.ReplicatedStorage.Shared.Data.GameConfig)
local PlayerDataService = require(script.Parent.Services.PlayerDataService)
local IdleEngine        = require(script.Parent.Services.IdleEngine)
local GolemService      = require(script.Parent.Services.GolemService)
local ForgeService      = require(script.Parent.Services.ForgeService)
local ProgressionService = require(script.Parent.Services.ProgressionService)
local ChallengeService  = require(script.Parent.Services.ChallengeService)
local TradingService    = require(script.Parent.Services.TradingService)
local ShopService       = require(script.Parent.Services.ShopService)
local SeasonPassService = require(script.Parent.Services.SeasonPassService)
local LeaderboardService = require(script.Parent.Services.LeaderboardService)
local Utils             = require(game.ReplicatedStorage.Shared.Modules.Utils)

local RemoteHandler = {}

-- Rate limiting: userId → { count, windowStart }
local rateLimits = {}

local function CheckRateLimit(player)
    local userId = tostring(player.UserId)
    local now    = tick()
    local entry  = rateLimits[userId]

    if not entry or (now - entry.windowStart) >= 1.0 then
        rateLimits[userId] = { count = 1, windowStart = now }
        return true
    end

    entry.count = entry.count + 1
    if entry.count > GameConfig.REMOTE_RATE_LIMIT then
        warn("[RemoteHandler] Rate limit exceeded by " .. player.Name)
        return false
    end
    return true
end

local function SafeCall(player, fn)
    if not CheckRateLimit(player) then return end
    local ok, err = pcall(fn)
    if not ok then
        warn("[RemoteHandler] Error for " .. player.Name .. ": " .. tostring(err))
    end
end

-- ── CollectResources ──────────────────────────────────────────────────────────
RemoteEvents.CollectResources.OnServerEvent:Connect(function(player)
    SafeCall(player, function()
        local data  = PlayerDataService.Get(player)
        if not data then return end

        local gains, elapsed = IdleEngine.CalculateOfflineProduction(data)
        local totalGained = 0
        local blueprintDrops = {}
        for matId, qty in pairs(gains) do
            if matId:sub(1, 12) == "__blueprint:" then
                table.insert(blueprintDrops, matId:sub(13))
            else
                PlayerDataService.AddMaterial(player, matId, qty)
                totalGained = totalGained + qty
            end
        end
        -- Strip blueprint signals from gains before sending to client
        for _, bpId in ipairs(blueprintDrops) do
            gains["__blueprint:" .. bpId] = nil
        end

        IdleEngine.ApplyOfflineGains(data, {})  -- update timestamp
        data.LastOnline = Utils.UnixTimestamp()
        PlayerDataService.MarkDirty(player)

        -- Track challenge
        ChallengeService.TrackEvent(player, "GolemCollect", { count = 1 })

        RemoteEvents.ResourcesCollected:FireClient(player, gains, elapsed)
    end)
end)

-- ── StartSmelt ────────────────────────────────────────────────────────────────
RemoteEvents.StartSmelt.OnServerEvent:Connect(function(player, materialId, quantity)
    SafeCall(player, function()
        if type(materialId) ~= "string" then return end
        quantity = math.clamp(tonumber(quantity) or 1, 1, 100)

        local job, err = ForgeService.StartSmelt(player, materialId, quantity)
        if job then
            ProgressionService.AddPlayerXP(player, GameConfig.XP_PER_SMELT * quantity)
            ChallengeService.TrackEvent(player, "SmeltComplete", { count = quantity })
            -- Track SmeltRare if the material is Rare or higher
            local MaterialData_ = require(game.ReplicatedStorage.Shared.Data.MaterialData)
            local mat = MaterialData_.Get(materialId)
            local rarity = mat and mat.rarity or "Common"
            if rarity == "Rare" or rarity == "Epic" or rarity == "Legendary" then
                ChallengeService.TrackEvent(player, "SmeltRare", { count = quantity })
            end
            RemoteEvents.SmeltQueued:FireClient(player, job)
        else
            RemoteEvents.SmeltQueued:FireClient(player, nil, err)
        end
    end)
end)

-- ── CraftGolem ────────────────────────────────────────────────────────────────
RemoteEvents.CraftGolem.OnServerEvent:Connect(function(player, blueprintId, skinId)
    SafeCall(player, function()
        if type(blueprintId) ~= "string" then return end
        skinId = type(skinId) == "string" and skinId or "default"

        -- Capture unlocked zones before craft for new-zone detection
        local MiningZoneData_ = require(game.ReplicatedStorage.Shared.Data.MiningZoneData)
        local dataBefore = PlayerDataService.Get(player)
        local zonesBefore = MiningZoneData_.GetUnlocked(dataBefore)
        local zonesBeforeSet = {}
        for _, zid in ipairs(zonesBefore) do zonesBeforeSet[zid] = true end

        local golem, err = GolemService.CraftGolem(player, blueprintId, skinId)
        if golem then
            -- XP and progression
            local leveled, level = ProgressionService.OnGolemCrafted(player, golem)
            local forgeXP = GameConfig.XP_PER_CRAFT_TIER[golem.tier] or 50
            local forgeUp = ForgeService.AddForgeXP(player, forgeXP)

            -- Check slot milestones
            GolemService.CheckSlotMilestones(player)

            -- Leaderboard
            LeaderboardService.OnGolemCrafted(player)

            -- Challenges
            ChallengeService.TrackEvent(player, "GolemCrafted", { tier = golem.tier })

            -- Check for newly unlocked zones
            local dataAfter = PlayerDataService.Get(player)
            local zonesAfter = MiningZoneData_.GetUnlocked(dataAfter)
            for _, zid in ipairs(zonesAfter) do
                if not zonesBeforeSet[zid] then
                    ChallengeService.TrackEvent(player, "ZoneUnlocked", { count = 1 })
                end
            end

            -- Check AllElementsCrafted achievement
            local elements = { "Ember", "Stone", "Frost", "Storm", "Void" }
            local elementsSeen = {}
            for _, g in ipairs(dataAfter.Golems or {}) do
                elementsSeen[g.element] = true
            end
            local allFound = true
            for _, el in ipairs(elements) do
                if not elementsSeen[el] then allFound = false; break end
            end
            if allFound then
                ChallengeService.TrackEvent(player, "AllElementsCrafted", { count = 1 })
            end

            -- Community season contribution
            local currentSeason = require(game.ReplicatedStorage.Shared.Data.SeasonData).GetCurrentSeason()
            if currentSeason then
                SeasonPassService.ContributeToCommunity(currentSeason.id, golem.tier * 10)
            end

            RemoteEvents.GolemCrafted:FireClient(player, golem, leveled and level or nil)

            if leveled then
                RemoteEvents.LevelUp:FireClient(player, level)
            end
            if forgeUp then
                RemoteEvents.ForgeUpgraded:FireClient(player, PlayerDataService.Get(player).ForgeLevel)
            end
        else
            RemoteEvents.GolemCrafted:FireClient(player, nil, err)
        end
    end)
end)

-- ── DeployGolem ───────────────────────────────────────────────────────────────
RemoteEvents.DeployGolem.OnServerEvent:Connect(function(player, golemId, zoneId)
    SafeCall(player, function()
        if type(golemId) ~= "string" or type(zoneId) ~= "string" then return end

        local ok, err = GolemService.DeployGolem(player, golemId, zoneId)
        if ok then
            ChallengeService.TrackEvent(player, "GolemDeploy", { count = 1 })
        end
        RemoteEvents.GolemDeployed:FireClient(player, ok, golemId, zoneId, err)
    end)
end)

-- ── ReturnGolem ───────────────────────────────────────────────────────────────
RemoteEvents.ReturnGolem.OnServerEvent:Connect(function(player, golemId)
    SafeCall(player, function()
        if type(golemId) ~= "string" then return end
        local result, err = GolemService.ReturnGolem(player, golemId)
        RemoteEvents.GolemReturned:FireClient(player, result, golemId, err)
    end)
end)

-- ── InitiateTrade ─────────────────────────────────────────────────────────────
RemoteEvents.InitiateTrade.OnServerEvent:Connect(function(player, targetUserId)
    SafeCall(player, function()
        local Players_ = game:GetService("Players")
        local target   = Players_:GetPlayerByUserId(tonumber(targetUserId))
        if not target then
            RemoteEvents.TradeOffer:FireClient(player, nil, "Target player not found")
            return
        end
        local tradeId = TradingService.InitiateTrade(player, target)
        -- Notify both parties
        RemoteEvents.TradeOffer:FireClient(player, tradeId, nil)
        RemoteEvents.TradeOffer:FireClient(target, tradeId, nil)
    end)
end)

RemoteEvents.AcceptTrade.OnServerEvent:Connect(function(player, tradeId)
    SafeCall(player, function()
        if type(tradeId) ~= "string" then return end
        local ok, result = TradingService.ConfirmTrade(player, tradeId)
        if ok and type(result) == "table" then
            -- Trade executed — reward both parties exactly once each
            local Players_ = game:GetService("Players")
            local offerer  = Players_:GetPlayerByUserId(result.offererId)
            local target   = Players_:GetPlayerByUserId(result.targetId)

            if offerer then
                ProgressionService.OnTradeCompleted(offerer)
                ChallengeService.TrackEvent(offerer, "TradeComplete", { count = 1 })
                LeaderboardService.OnTradeComplete(offerer)
                RemoteEvents.TradeCompleted:FireClient(offerer, result)
            end
            if target then
                ProgressionService.OnTradeCompleted(target)
                ChallengeService.TrackEvent(target, "TradeComplete", { count = 1 })
                LeaderboardService.OnTradeComplete(target)
                RemoteEvents.TradeCompleted:FireClient(target, result)
            end
        end
    end)
end)

RemoteEvents.DeclineTrade.OnServerEvent:Connect(function(player, tradeId)
    SafeCall(player, function()
        if type(tradeId) ~= "string" then return end
        TradingService.CancelTrade(player, tradeId)
    end)
end)

RemoteEvents.ListOnMarket.OnServerEvent:Connect(function(player, item, priceCoins)
    SafeCall(player, function()
        if type(item) ~= "table" or type(priceCoins) ~= "number" then return end
        local listing, err = TradingService.ListOnMarket(player, item, priceCoins)
        RemoteEvents.PurchaseResult:FireClient(player, listing ~= nil, listing, err)
    end)
end)

RemoteEvents.BuyFromMarket.OnServerEvent:Connect(function(player, listingId)
    SafeCall(player, function()
        if type(listingId) ~= "string" then return end
        local ok, result = TradingService.BuyFromMarket(player, listingId)
        if ok then
            ChallengeService.TrackEvent(player, "TradeComplete", { count = 1 })
            ProgressionService.OnTradeCompleted(player)
            LeaderboardService.OnTradeComplete(player)
        end
        RemoteEvents.PurchaseResult:FireClient(player, ok, result)
    end)
end)

-- ── FuseGolems ────────────────────────────────────────────────────────────────
RemoteEvents.FuseGolems.OnServerEvent:Connect(function(player, golem1Id, golem2Id)
    SafeCall(player, function()
        if type(golem1Id) ~= "string" or type(golem2Id) ~= "string" then return end
        local ok, err = GolemService.FuseGolems(player, golem1Id, golem2Id)
        RemoteEvents.GolemFused:FireClient(player, ok, golem1Id, err)
        if ok then
            ChallengeService.TrackEvent(player, "GolemFused", { count = 1 })
        end
    end)
end)

-- ── ClaimChallengeReward ──────────────────────────────────────────────────────
RemoteEvents.ClaimChallengeReward.OnServerEvent:Connect(function(player, challengeId)
    SafeCall(player, function()
        if type(challengeId) ~= "string" then return end
        local ok, result = ChallengeService.ClaimReward(player, challengeId)
        if ok and type(result) == "table" and result.xp then
            local leveled, newLevel = ProgressionService.AddPlayerXP(player, result.xp)
            if leveled then
                RemoteEvents.LevelUp:FireClient(player, newLevel)
            end
        end
        RemoteEvents.ChallengeRewardClaimed:FireClient(player, ok, challengeId, ok and result or result)
    end)
end)

-- ── CraftStorageVault ─────────────────────────────────────────────────────────
RemoteEvents.CraftStorageVault.OnServerEvent:Connect(function(player)
    SafeCall(player, function()
        local ok, err = ForgeService.CraftStorageVault(player)
        RemoteEvents.StorageVaultCrafted:FireClient(player, ok, err)
        if ok then
            ChallengeService.TrackEvent(player, "StorageUpgrade", { count = 1 })
        end
    end)
end)

-- ── RepairGolem ───────────────────────────────────────────────────────────────
RemoteEvents.RepairGolem.OnServerEvent:Connect(function(player, golemId)
    SafeCall(player, function()
        if type(golemId) ~= "string" then return end
        local ok, err = GolemService.RepairGolem(player, golemId)
        RemoteEvents.GolemRepaired:FireClient(player, ok, golemId, err)
    end)
end)

-- ── ClaimSeasonReward ─────────────────────────────────────────────────────────
RemoteEvents.ClaimSeasonReward.OnServerEvent:Connect(function(player, seasonId, weekNumber, track)
    SafeCall(player, function()
        if type(seasonId) ~= "string" or type(weekNumber) ~= "number" then return end
        track = type(track) == "string" and track or "free"
        local ok, reward = SeasonPassService.ClaimWeekReward(player, seasonId, weekNumber, track)
        RemoteEvents.PurchaseResult:FireClient(player, ok, reward)
    end)
end)

-- ── RemoteFunctions (synchronous data requests) ───────────────────────────────
RemoteEvents.GetPlayerData.OnServerInvoke = function(player)
    local data = PlayerDataService.Get(player)
    if not data then return nil end
    -- Return a safe read-only snapshot (strip transient fields)
    local snapshot = Utils.DeepCopy(data)
    snapshot.ProcessedReceipts = nil  -- don't expose to client
    return snapshot
end

RemoteEvents.GetMarketListings.OnServerInvoke = function(player, filterType, filterElement)
    return TradingService.GetMarketListings(filterType, filterElement, 50)
end

RemoteEvents.GetLeaderboard.OnServerInvoke = function(player, category)
    local validCategories = { ResourcesMined = true, GolemsCrafted = true, ForgeLevel = true, TradeCount = true }
    if not validCategories[category] then return {} end
    return LeaderboardService.GetTopEntries(category, 20)
end

RemoteEvents.GetForgeZoneData.OnServerInvoke = function(player, targetUserId)
    if type(targetUserId) ~= "number" then return nil end
    local target = Players:GetPlayerByUserId(targetUserId)
    if not target then return nil end
    local data = PlayerDataService.Get(target)
    if not data then return nil end
    return {
        userId      = target.UserId,
        displayName = target.DisplayName,
        forgeLevel  = data.ForgeLevel,
        playerLevel = data.PlayerLevel,
        golemCount  = #(data.Golems or {}),
        golems      = (function()
            local summary = {}
            for _, g in ipairs(data.Golems or {}) do
                table.insert(summary, { element = g.element, tier = g.tier, deployed = g.deployed })
            end
            return summary
        end)(),
        masteryLevels = data.MasteryLevels,
    }
end

-- ── Cleanup ────────────────────────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
    rateLimits[tostring(player.UserId)] = nil
    TradingService.OnPlayerLeave(player)
    ForgeService.OnPlayerLeave(player)
end)

return RemoteHandler
