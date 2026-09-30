-- Wires up all RemoteEvent / RemoteFunction handlers with rate limiting.

local Players = game:GetService("Players")

local RemoteEvents      = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
RemoteEvents.Load()   -- waits for init.server.lua to create the remotes
local GameConfig        = require(game.ReplicatedStorage.Shared.Data.GameConfig)
local PlayerDataService = require(script.Parent.Services.PlayerDataService)
local IdleEngine        = require(script.Parent.Services.IdleEngine)
local GolemService      = require(script.Parent.Services.GolemService)
local ForgeService      = require(script.Parent.Services.ForgeService)
local ProgressionService = require(script.Parent.Services.ProgressionService)
local ChallengeService  = require(script.Parent.Services.ChallengeService)
local TradingService    = require(script.Parent.Services.TradingService)
local ShopService       = require(script.Parent.Services.ShopService)
local CosmeticService   = require(script.Parent.Services.CosmeticService)
local Analytics         = require(script.Parent.Services.AnalyticsHelper)
local ForgeZoneService  = require(script.Parent.Services.ForgeZoneService)
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

local function Tell(player, title, message)
    if player and player.Parent then RemoteEvents.Notify:FireClient(player, title, message) end
end

-- ── CollectResources ──────────────────────────────────────────────────────────
RemoteEvents.CollectResources.OnServerEvent:Connect(function(player)
    SafeCall(player, function()
        local data  = PlayerDataService.Get(player)
        if not data then return end

        -- Move everything the Golems have mined into the inventory
        local gains, total = {}, 0
        for matId, qty in pairs(data.Pending or {}) do
            if qty > 0 then
                PlayerDataService.AddMaterial(player, matId, qty)
                gains[matId] = qty
                total = total + qty
            end
        end
        data.Pending = {}
        for _, g in ipairs(data.Golems or {}) do
            if g.deployed then g._carriedResources = 0 end   -- empty their bags
        end
        PlayerDataService.MarkDirty(player)
        RemoteEvents.PendingUpdate:FireClient(player, data.Pending)

        if total == 0 then
            RemoteEvents.Notify:FireClient(player, "Nothing to collect",
                "Your Golems haven't mined anything yet. Deploy one from the Forge menu.")
            return
        end

        ChallengeService.TrackEvent(player, "GolemCollect", { count = 1 })
        Analytics.Funnel(player, data, "collect", 4, "FirstCollect")
        RemoteEvents.ResourcesCollected:FireClient(player, gains, -1)   -- -1 marks a manual collect
    end)
end)

-- ── UseSpeedUp ────────────────────────────────────────────────────────────────
RemoteEvents.UseSpeedUp.OnServerEvent:Connect(function(player, jobId)
    SafeCall(player, function()
        if type(jobId) ~= "string" then return end
        local ok, result = ForgeService.SpeedUpSmelt(player, jobId)
        if ok then
            RemoteEvents.SmeltCompleted:FireClient(player, result)
            ChallengeService.TrackEvent(player, "SmeltComplete", { count = result.quantity })
            Tell(player, "Speed-Up used", (PlayerDataService.Get(player).SpeedUps or 0) .. " left")
        else
            Tell(player, "Speed-Up", tostring(result))
        end
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
-- Crafts one Golem. Returns true on success (so "Craft All" knows when to stop).
local function CraftOnce(player, blueprintId, skinId)
    do
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
            Analytics.Funnel(player, PlayerDataService.Get(player), "craft", 2, "FirstGolemCrafted")
            Analytics.Custom(player, "GolemCrafted", 1, { tier = golem.tier, element = golem.element })

            if leveled then
                RemoteEvents.LevelUp:FireClient(player, level)
            end
            return true
        else
            RemoteEvents.GolemCrafted:FireClient(player, nil, err)
            return false
        end
    end
end

RemoteEvents.CraftGolem.OnServerEvent:Connect(function(player, blueprintId, skinId, count)
    SafeCall(player, function()
        if type(blueprintId) ~= "string" then return end
        skinId = type(skinId) == "string" and skinId or "default"
        count = math.clamp(math.floor(tonumber(count) or 1), 1, 50)
        for _ = 1, count do
            if not CraftOnce(player, blueprintId, skinId) then break end
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
            Analytics.Funnel(player, PlayerDataService.Get(player), "deploy", 3, "FirstGolemDeployed")
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

-- ── Direct trading ────────────────────────────────────────────────────────────
-- Send each participant their own view of the trade
local function PushTradeView(tradeId)
    local a, b = TradingService.GetPartners(tradeId)
    for _, p in ipairs({ a, b }) do
        if p then
            local view = TradingService.GetTradeView(p, tradeId)
            if view then RemoteEvents.TradeUpdated:FireClient(p, view) end
        end
    end
end

RemoteEvents.InitiateTrade.OnServerEvent:Connect(function(player, targetUserId)
    SafeCall(player, function()
        if type(targetUserId) ~= "number" then return end
        local target = Players:GetPlayerByUserId(targetUserId)
        if not target then
            Tell(player, "Trade", "That player isn't here any more.")
            return
        end
        local tradeId, err = TradingService.InitiateTrade(player, target)
        if not tradeId then
            Tell(player, "Can't trade", tostring(err))
            return
        end
        RemoteEvents.TradeOffer:FireClient(player, tradeId, nil)
        RemoteEvents.TradeOffer:FireClient(target, tradeId, nil)
        Tell(target, "Trade request", player.DisplayName .. " wants to trade with you.")
        PushTradeView(tradeId)
    end)
end)

RemoteEvents.AddTradeItem.OnServerEvent:Connect(function(player, tradeId, item)
    SafeCall(player, function()
        local ok, err = TradingService.AddToOffer(player, tradeId, item)
        if not ok then Tell(player, "Can't add that", tostring(err)) end
        PushTradeView(tradeId)
    end)
end)

RemoteEvents.RemoveTradeItem.OnServerEvent:Connect(function(player, tradeId, index)
    SafeCall(player, function()
        local ok, err = TradingService.RemoveFromOffer(player, tradeId, index)
        if not ok then Tell(player, "Trade", tostring(err)) end
        PushTradeView(tradeId)
    end)
end)

RemoteEvents.AcceptTrade.OnServerEvent:Connect(function(player, tradeId)
    SafeCall(player, function()
        if type(tradeId) ~= "string" then return end
        local offerer, target = TradingService.GetPartners(tradeId)   -- grab before it may close
        local ok, result = TradingService.ConfirmTrade(player, tradeId)

        if ok and type(result) == "table" then
            -- Executed: reward both parties exactly once each
            for _, p in ipairs({ offerer, target }) do
                if p then
                    ProgressionService.OnTradeCompleted(p)
                    ChallengeService.TrackEvent(p, "TradeComplete", { count = 1 })
                    LeaderboardService.OnTradeComplete(p)
                    RemoteEvents.TradeCompleted:FireClient(p, result)
                end
            end
        elseif ok then
            PushTradeView(tradeId)          -- waiting for the other side
        else
            Tell(player, "Trade", tostring(result))
            for _, p in ipairs({ offerer, target }) do
                if p then RemoteEvents.TradeClosed:FireClient(p, tradeId, tostring(result)) end
            end
        end
    end)
end)

RemoteEvents.DeclineTrade.OnServerEvent:Connect(function(player, tradeId)
    SafeCall(player, function()
        if type(tradeId) ~= "string" then return end
        local offerer, target = TradingService.GetPartners(tradeId)
        if TradingService.CancelTrade(player, tradeId) then
            for _, p in ipairs({ offerer, target }) do
                if p then RemoteEvents.TradeClosed:FireClient(p, tradeId, player.DisplayName .. " cancelled the trade") end
            end
        end
    end)
end)

RemoteEvents.GetTradeHistory.OnServerInvoke = function(player)
    local data = PlayerDataService.Get(player)
    return data and data.TradeHistory or {}
end

-- ── Forge Market ──────────────────────────────────────────────────────────────
RemoteEvents.ListOnMarket.OnServerEvent:Connect(function(player, item, priceCoins)
    SafeCall(player, function()
        local listing, err = TradingService.ListOnMarket(player, item, priceCoins)
        if listing then
            Tell(player, "Listed", (listing.item.name or listing.item.id) .. " for " .. listing.priceCoins .. " coins")
        else
            Tell(player, "Couldn't list it", tostring(err))
        end
        RemoteEvents.PurchaseResult:FireClient(player, listing ~= nil, listing, err)
    end)
end)

RemoteEvents.BuyFromMarket.OnServerEvent:Connect(function(player, listingId)
    SafeCall(player, function()
        local ok, result = TradingService.BuyFromMarket(player, listingId)
        if ok then
            ChallengeService.TrackEvent(player, "TradeComplete", { count = 1 })
            ProgressionService.OnTradeCompleted(player)
            LeaderboardService.OnTradeComplete(player)
            Tell(player, "Purchased", (result.item.name or result.item.id) .. " for " .. result.priceCoins .. " coins")
        else
            Tell(player, "Couldn't buy it", tostring(result))
        end
        RemoteEvents.PurchaseResult:FireClient(player, ok, ok and result or nil, ok and nil or result)
    end)
end)

RemoteEvents.CancelListing.OnServerEvent:Connect(function(player, listingId)
    SafeCall(player, function()
        local ok, err = TradingService.CancelListing(player, listingId)
        Tell(player, ok and "Listing cancelled" or "Couldn't cancel", ok and "Your item was returned." or tostring(err))
        RemoteEvents.PurchaseResult:FireClient(player, ok, nil, err)
    end)
end)

RemoteEvents.GetMyListings.OnServerInvoke = function(player)
    return TradingService.GetMyListings(player)
end

-- ── Style & access ────────────────────────────────────────────────────────────
RemoteEvents.EquipCosmetic.OnServerEvent:Connect(function(player, slot, id)
    SafeCall(player, function()
        local ok, err = CosmeticService.Equip(player, slot, id)
        if not ok then
            Tell(player, "Can't equip", tostring(err))
            return
        end
        if slot == "ForgeSkin" or slot == "ForgeDecoration" or slot == "Title" or slot == "ForgeEffect" then
            ForgeZoneService.Refresh(player)
        end
    end)
end)

RemoteEvents.SetForgeAccess.OnServerEvent:Connect(function(player, friendsOnly)
    SafeCall(player, function()
        if CosmeticService.SetFriendsOnly(player, friendsOnly) then
            ForgeZoneService.Refresh(player)
            Tell(player, "Forge access", friendsOnly and "Only your friends can visit." or "Everyone can visit your forge.")
        end
    end)
end)

RemoteEvents.GoToMyForge.OnServerEvent:Connect(function(player)
    SafeCall(player, function() ForgeZoneService.Teleport(player) end)
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

-- ── NeonFuse ──────────────────────────────────────────────────────────────────
RemoteEvents.NeonFuse.OnServerEvent:Connect(function(player, element, tier, variant)
    SafeCall(player, function()
        local golem, err = GolemService.NeonFuse(player, element, tier, variant)
        if golem then
            ChallengeService.TrackEvent(player, golem.variant == "MegaNeon" and "MegaMade" or "NeonMade", { count = 1 })
            local GolemNames = require(game.ReplicatedStorage.Shared.Modules.GolemNames)
            Tell(player, golem.variant == "MegaNeon" and "MEGA NEON!" or "NEON!", GolemNames.Describe(golem).name .. " created")
            Analytics.Custom(player, "NeonFuse", 1, { variant = golem.variant, tier = golem.tier })
        else
            Tell(player, "Can't fuse", tostring(err))
        end
        RemoteEvents.GolemNeoned:FireClient(player, golem ~= nil, golem or err)
    end)
end)

-- ── ClaimChallengeReward ──────────────────────────────────────────────────────
RemoteEvents.ClaimChallengeReward.OnServerEvent:Connect(function(player, challengeId)
    SafeCall(player, function()
        if type(challengeId) ~= "string" then return end
        local ok, result, newLevel = ChallengeService.ClaimReward(player, challengeId)
        if ok and newLevel then
            RemoteEvents.LevelUp:FireClient(player, newLevel)   -- XP itself is granted inside ClaimReward
        end
        RemoteEvents.ChallengeRewardClaimed:FireClient(player, ok, challengeId, result)
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
        if ok then
            local CosmeticData = require(game.ReplicatedStorage.Shared.Data.CosmeticData)
            Tell(player, "Reward claimed", CosmeticData.RewardText(reward))
        else
            Tell(player, "Can't claim", tostring(reward))
        end
        RemoteEvents.PurchaseResult:FireClient(player, ok, ok and reward or nil, ok and nil or reward)
    end)
end)

-- ── RemoteFunctions (synchronous data requests) ───────────────────────────────
RemoteEvents.GetPlayerData.OnServerInvoke = function(player)
    local data = PlayerDataService.Get(player)
    if not data then return nil end
    -- Return a safe read-only snapshot (strip transient fields)
    local snapshot = Utils.DeepCopy(data)
    snapshot.ProcessedReceipts = nil  -- don't expose to client
    snapshot._lock = nil

    -- Derived, read-only facts the UI needs (all computed here so the client never guesses)
    local events = {}
    for id in pairs(SeasonPassService.GetAvailableEventBlueprints()) do table.insert(events, id) end
    snapshot.AvailableEventBlueprints = events
    snapshot.EffectiveGolemSlots = ShopService.GetEffectiveGolemSlots(player)
    local status = SeasonPassService.GetPlayerSeasonStatus(player)
    if status then
        local current, target = SeasonPassService.GetCommunityProgress(status.seasonId)
        snapshot.SeasonStatus = {
            seasonId = status.seasonId, currentWeek = status.currentWeek, totalWeeks = status.totalWeeks,
            claimedWeeks = status.claimedWeeks, communityCurrent = current, communityTarget = target,
        }
    end
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
    local partnerId = TradingService.OnPlayerLeave(player)
    local partner = partnerId and Players:GetPlayerByUserId(partnerId)
    if partner then RemoteEvents.TradeClosed:FireClient(partner, "", player.DisplayName .. " left the game") end
    ForgeService.OnPlayerLeave(player)
end)

return RemoteHandler
