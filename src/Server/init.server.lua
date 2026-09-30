-- Server entry point. Initialises all services and wires player lifecycle.

local Players = game:GetService("Players")

-- Create remote events before anything else
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
RemoteEvents.CreateOnServer()

-- Services
local PlayerDataService  = require(script.Services.PlayerDataService)
local IdleEngine         = require(script.Services.IdleEngine)
local GolemService       = require(script.Services.GolemService)
local ForgeService       = require(script.Services.ForgeService)
local ProgressionService = require(script.Services.ProgressionService)
local ChallengeService   = require(script.Services.ChallengeService)
local TradingService     = require(script.Services.TradingService)
local ShopService        = require(script.Services.ShopService)
local SeasonPassService  = require(script.Services.SeasonPassService)
local LeaderboardService = require(script.Services.LeaderboardService)
local ForgeZoneService   = require(script.Services.ForgeZoneService)
local WorldBuilder       = require(script.Services.WorldBuilder)
local PadService         = require(script.Services.PadService)
local GolemVisuals       = require(script.Services.GolemVisuals)
local LiveOpsService     = require(script.Services.LiveOpsService)
local AdminService       = require(script.Services.AdminService)
local Utils              = require(game.ReplicatedStorage.Shared.Modules.Utils)
local GameConfig         = require(game.ReplicatedStorage.Shared.Data.GameConfig)

-- Build the world (ground, spawn, mining-zone landmarks) before anyone joins
LiveOpsService.Init()
AdminService.Init(LiveOpsService, function(p, title, msg) RemoteEvents.Notify:FireClient(p, title, msg) end)
WorldBuilder.Build()
PadService.Init()
GolemVisuals.Init()

-- Start periodic auto-save and leaderboard flush
PlayerDataService.StartAutoSave()
LeaderboardService.StartFlushLoop()

-- ── Player join ───────────────────────────────────────────────────────────────
local function OnPlayerAdded(player)
    -- Load data
    local data = PlayerDataService.Load(player)
    if not data then
        warn("[Main] Failed to load data for " .. player.Name)
        player:Kick("We couldn't load your save safely, so we stopped you playing to protect it. "
            .. "Please rejoin in a minute. Your progress is safe.")
        return
    end

    -- Pick up any pad game passes they already own (bought on the game page or another server)
    ShopService.OnPlayerAdded(player)

    -- Calculate and apply offline production
    local gains, elapsed = IdleEngine.CalculateOfflineProduction(data)
    local capSeconds = IdleEngine.StorageCapSeconds(data.StorageTier or 0)
    if elapsed and elapsed > capSeconds and (data.StorageTier or 0) < 2 then
        task.delay(8, function()
            if player.Parent then
                ShopService.Offer(player, "pass", "Storage24h", string.format(
                    "You were away %d hours but your storage only holds %d. Hold up to 24?",
                    math.floor(elapsed / 3600), math.floor(capSeconds / 3600)))
            end
        end)
    end
    if elapsed and elapsed > 60 then
        -- Offline haul goes into the pending pool so the player collects it with the button
        for matId, qty in pairs(gains) do
            if matId:sub(1, 12) ~= "__blueprint:" then
                PlayerDataService.AddPending(player, matId, qty)
            end
        end
        data.LastOnline = Utils.UnixTimestamp()
        PlayerDataService.MarkDirty(player)
    end

    -- Catch existing saves up on forge-milestone blueprints
    ForgeService.GrantMilestoneBlueprints(player)

    -- Restore smelt jobs
    ForgeService.RestoreSmeltJobs(player)

    -- Pay out any lifetime achievements that were never claimed
    ChallengeService.ClaimPendingLifetime(player)

    -- Check challenge resets; award daily coin if applicable
    local resets = ChallengeService.CheckResets(player)
    if resets.daily then
        RemoteEvents.DailyReward:FireClient(player, resets.coins or GameConfig.DAILY_COIN_REWARD)
        if resets.premium then
            RemoteEvents.Notify:FireClient(player, "Premium bonus", "+25% daily coins and a free Speed-Up. Thanks for being Premium!")
        end
    end

    -- Check slot milestones
    GolemService.CheckSlotMilestones(player)

    -- Tell them about any live events (Double XP weekend etc.)
    task.delay(8, function()
        if not player.Parent then return end
        for _, e in ipairs(LiveOpsService.ActiveEvents()) do
            RemoteEvents.Notify:FireClient(player, e.name or "Event", string.format("%s x%g is active!", e.kind == "xp" and "XP" or "Resource drops", e.multiplier))
        end
    end)

    -- Assign a forge plot in the shared world
    ForgeZoneService.OnPlayerAdded(player)

    print(string.format("[Main] %s joined. ForgeLevel=%d, Golems=%d",
        player.Name, data.ForgeLevel, #data.Golems))
end

-- ── Player leave ──────────────────────────────────────────────────────────────
local function OnPlayerLeave(player)
    ForgeZoneService.OnPlayerLeave(player)
    LeaderboardService.OnPlayerLeave(player)
    PlayerDataService.OnPlayerLeave(player)
    print("[Main] " .. player.Name .. " left — data saved.")
end

-- ── Online production tick ────────────────────────────────────────────────────
-- Runs every 5 seconds for all active players
local TICK_INTERVAL = 5
task.spawn(function()
    while true do
        task.wait(TICK_INTERVAL)

        for _, player in ipairs(Players:GetPlayers()) do
            local data = PlayerDataService.Get(player)
            if data then
                -- Tick idle production
                local rawGains, byElement = IdleEngine.TickOnlineProduction(data, TICK_INTERVAL)
                local gains = {}
                local totalGained = 0
                for matId, qty in pairs(rawGains) do
                    if matId:sub(1, 12) ~= "__blueprint:" then
                        PlayerDataService.AddPending(player, matId, qty)
                        totalGained = totalGained + qty
                        gains[matId] = qty
                    else
                        local RecipeData = require(game.ReplicatedStorage.Shared.Data.RecipeData)
                        local bp = RecipeData.Get(matId:sub(13))
                        RemoteEvents.Notify:FireClient(player, "Blueprint discovered!",
                            bp and string.format("%s Golem (Tier %d)", bp.element, bp.tier) or matId:sub(13))
                    end
                end
                if totalGained > 0 then
                    ChallengeService.TrackEvent(player, "ResourcesMined", { count = totalGained })
                end

                -- Mastery XP goes to the element whose Golems did the mining
                for element, mined in pairs(byElement or {}) do
                    local newMasteryLevel = ProgressionService.OnGolemMined(player, element, mined)
                    if newMasteryLevel then
                        RemoteEvents.MasteryLevelUp:FireClient(player, element, newMasteryLevel)
                        if newMasteryLevel >= 20 then
                            ChallengeService.TrackEvent(player, "MasteryLevel20", { count = 1 })
                        end
                    end
                end
                if totalGained > 0 then
                    LeaderboardService.OnResourcesGained(player, totalGained)
                end

                -- Tick smelt jobs
                local completedSmelts = ForgeService.TickSmeltJobs(player)
                for _, job in ipairs(completedSmelts) do
                    RemoteEvents.SmeltCompleted:FireClient(player, job)
                    ChallengeService.TrackEvent(player, "SmeltComplete", { count = job.quantity })
                end

                -- Tell the client the new pending totals (shown on the Collect button)
                if next(gains) then
                    RemoteEvents.PendingUpdate:FireClient(player, data.Pending)
                end
            end
        end
    end
end)

-- ── Wire player events ────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerLeave)

-- Handle players who joined before this script ran (Studio edge case)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(OnPlayerAdded, player)
end

print("[EmberForge] Server started successfully.")
