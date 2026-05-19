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
local Utils              = require(game.ReplicatedStorage.Shared.Modules.Utils)
local GameConfig         = require(game.ReplicatedStorage.Shared.Data.GameConfig)

-- Start periodic auto-save and leaderboard flush
PlayerDataService.StartAutoSave()
LeaderboardService.StartFlushLoop()

-- ── Player join ───────────────────────────────────────────────────────────────
local function OnPlayerAdded(player)
    -- Load data
    local data = PlayerDataService.Load(player)
    if not data then
        warn("[Main] Failed to load data for " .. player.Name)
        return
    end

    -- Calculate and apply offline production
    local gains, elapsed = IdleEngine.CalculateOfflineProduction(data)
    if elapsed and elapsed > 60 then
        IdleEngine.ApplyOfflineGains(data, gains)
        PlayerDataService.MarkDirty(player)
    end

    -- Restore smelt jobs
    ForgeService.RestoreSmeltJobs(player)

    -- Check challenge resets; award daily coin if applicable
    local resets = ChallengeService.CheckResets(player)
    if resets.daily then
        RemoteEvents.DailyReward:FireClient(player, GameConfig.DAILY_COIN_REWARD)
    end

    -- Check slot milestones
    GolemService.CheckSlotMilestones(player)

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
                local rawGains = IdleEngine.TickOnlineProduction(data, TICK_INTERVAL)
                local gains = {}
                local totalGained = 0
                for matId, qty in pairs(rawGains) do
                    if matId:sub(1, 12) ~= "__blueprint:" then
                        PlayerDataService.AddMaterial(player, matId, qty)
                        totalGained = totalGained + qty
                        gains[matId] = qty

                        -- Mastery XP for each element actively mined
                        for _, golem in ipairs(data.Golems) do
                            if golem.deployed then
                                local newMastLvl = ProgressionService.OnGolemMined(player, golem.element, qty)
                                if newMastLvl then
                                    RemoteEvents.MasteryLevelUp:FireClient(player, golem.element, newMastLvl)
                                    if newMastLvl >= 20 then
                                        ChallengeService.TrackEvent(player, "MasteryLevel20", { count = 1 })
                                    end
                                end
                            end
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

                -- Notify client of production update
                if next(gains) then
                    RemoteEvents.ResourcesCollected:FireClient(player, gains, TICK_INTERVAL)
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
