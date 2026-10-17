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
local GuildService       = require(script.Services.GuildService)
local LadderService      = require(script.Services.LadderService)
local StreakService      = require(script.Services.StreakService)
local CodeService        = require(script.Services.CodeService)
local ForgeZoneService   = require(script.Services.ForgeZoneService)
local WorldBuilder       = require(script.Services.WorldBuilder)
local PadService         = require(script.Services.PadService)
local GolemVisuals       = require(script.Services.GolemVisuals)
local GolemAssetLoader   = require(script.Services.GolemAssetLoader)
local LiveOpsService     = require(script.Services.LiveOpsService)
local AdminService       = require(script.Services.AdminService)
local CartBountyService  = require(script.Services.CartBountyService)
local CartCourseService  = require(script.Services.CartCourseService)
local CourierService     = require(script.Services.CourierService)
local TowerService       = require(script.Services.TowerService)
local MazeService        = require(script.Services.MazeService)
local CollectService     = require(script.Services.CollectService)
local Utils              = require(game.ReplicatedStorage.Shared.Modules.Utils)
local GolemNames         = require(game.ReplicatedStorage.Shared.Modules.GolemNames)
local GolemData          = require(game.ReplicatedStorage.Shared.Data.GolemData)
local GameConfig        = require(game.ReplicatedStorage.Shared.Data.GameConfig)

-- Build the world (ground, spawn, mining-zone landmarks) before anyone joins
LiveOpsService.Init()
AdminService.Init(LiveOpsService, function(p, title, msg) RemoteEvents.Notify:FireClient(p, title, msg) end)
WorldBuilder.Build()
PadService.Init()
GolemAssetLoader.Init()           -- starts loading uploaded Golem art (if any ids are set) before Golems are shown
GolemVisuals.Init()
CartBountyService.Init()           -- the Mine Cart Delivery bounty
CartCourseService.Init()           -- the Cart Run courses (CartCourseData): winding rails with tunnels, hills, gates and bridges
CourierService.Init()              -- the Courier Run obstacle courses (CourierData): carry a crate to the drop-off
TowerService.Init()                -- the Sky Tower (TOWER_DESIGN.md): a new tower to climb every round
CollectService.Init()              -- banks what the Golems mine, by itself, except in the Sky Tower and the Hollow Maze
MazeService.Init()                 -- the Hollow Maze (MAZE_DESIGN.md): a new maze, and a Zombie Golem to outrun, every round

-- Start periodic auto-save and leaderboard flush
PlayerDataService.StartAutoSave()
LeaderboardService.StartFlushLoop()
GuildService.StartFlushLoop()
LadderService.StartFlushLoop()
require(script.Services.PetService).StartGrowLoop()
require(script.Services.GuildHallService).Start(function(member) return GuildService.GetMine(member) end)

-- ── Player join ───────────────────────────────────────────────────────────────
-- Roblox's default character script loads a facial "mood" animation that Studio can't fetch for an
-- unpublished place, which logs "Failed to load animation ... 114302219876492" on every spawn. The game has
-- no facial animation, so that one animation is removed as the character is created (before it reaches the client).
local function StripMoodAnimation(character)
    local animate = character:WaitForChild("Animate", 5)
    local mood = animate and animate:FindFirstChild("mood")
    if mood then mood:Destroy() end
end

local function OnPlayerAdded(player)
    player.CharacterAdded:Connect(function(character) task.spawn(StripMoodAnimation, character) end)
    if player.Character then task.spawn(StripMoodAnimation, player.Character) end

    -- Banned players are removed before anything loads; a mute is restored
    if AdminService.CheckJoin(player) then return end

    -- Load data
    local data = PlayerDataService.Load(player)
    if not data then
        warn("[Main] Failed to load data for " .. player.Name)
        player:Kick("We couldn't load your save safely, so we stopped you playing to protect it. "
            .. "Please rejoin in a minute. Your progress is safe.")
        return
    end

    -- They left while the save was loading: PlayerRemoving had nothing to save then, so release the lock now
    -- (otherwise rejoining within 15 minutes is refused)
    if not player.Parent then
        PlayerDataService.OnPlayerLeave(player)
        return
    end

    -- Pick up any pad game passes they already own (bought on the game page or another server)
    ShopService.OnPlayerAdded(player)

    -- Calculate and apply offline production
    local gains, elapsed, offlineByElement, grewAway = IdleEngine.CalculateOfflineProduction(data)
    if grewAway and #grewAway > 0 then                                -- Golems that reached a new life stage while the player was away
        local bits = {}
        for _, g in ipairs(grewAway) do GolemData.NoteSeen(data, g.golem) end
        for i, g in ipairs(grewAway) do
            if i > 3 then table.insert(bits, string.format("and %d more", #grewAway - 3)) break end
            table.insert(bits, string.format("%s is now %s", GolemNames.Describe(g.golem).shortName, g.stage.id))
        end
        task.delay(9, function()
            if player.Parent then RemoteEvents.Notify:FireClient(player, "Your Golems grew while you were away!", table.concat(bits, ", ")) end
        end)
    end
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
        -- Offline haul goes into the pending pool (CollectService banks it a few seconds after they join)
        local minedAway = 0
        for matId, qty in pairs(gains) do
            if matId:sub(1, 12) ~= "__blueprint:" then
                PlayerDataService.AddPending(player, matId, qty)
                minedAway += qty
            else
                local bp = require(game.ReplicatedStorage.Shared.Data.RecipeData).Get(matId:sub(13))
                task.delay(6, function()
                    if player.Parent then
                        RemoteEvents.Notify:FireClient(player, "Blueprint discovered!",
                            bp and string.format("%s Golem (Tier %d), found while you were away", bp.element, bp.tier) or matId:sub(13))
                    end
                end)
            end
        end
        -- tell them what they came back to
        if minedAway > 0 and elapsed > 300 then
            local haul = {}
            for matId, qty in pairs(gains) do if matId:sub(1, 12) ~= "__blueprint:" then haul[matId] = qty end end
            task.delay(5, function()
                if player.Parent then
                    RemoteEvents.WelcomeBack:FireClient(player, elapsed, haul, capSeconds / 3600, elapsed > capSeconds)
                end
            end)
        end
        -- time away counts for mastery and the mining challenges (not the leaderboards: those stay for active play)
        if minedAway > 0 then ChallengeService.TrackEvent(player, "ResourcesMined", { count = minedAway }) end
        for element, mined in pairs(offlineByElement or {}) do
            local lvl = ProgressionService.OnGolemMined(player, element, mined)
            if lvl then RemoteEvents.MasteryLevelUp:FireClient(player, element, lvl) end
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

    -- Daily login streak reward
    task.delay(5, function()
        if not player.Parent then return end
        local ok, result = pcall(StreakService.OnJoin, player)
        if ok and result then RemoteEvents.Notify:FireClient(player, "Daily streak!", result.message) end
    end)

    -- Tell them about any live events (Double XP weekend etc.)
    task.delay(8, function()
        if not player.Parent then return end
        for _, e in ipairs(LiveOpsService.ActiveEvents()) do
            RemoteEvents.Notify:FireClient(player, e.name or "Event", e.blurb or string.format("%s x%g is active!", e.kind == "xp" and "XP" or "Resource drops", e.multiplier))
        end
    end)

    -- Assign a forge plot in the shared world
    ForgeZoneService.OnPlayerAdded(player)

    -- Publish the pets they are wearing so every client can draw them following along
    require(script.Services.PetService).Sync(player)

    print(string.format("[Main] %s joined. ForgeLevel=%d, Golems=%d",
        player.Name, data.ForgeLevel, #data.Golems))
end

-- ── Player leave ──────────────────────────────────────────────────────────────
local function OnPlayerLeave(player)
    ForgeZoneService.OnPlayerLeave(player)
    LeaderboardService.OnPlayerLeave(player)
    GuildService.OnPlayerLeave(player)
    LadderService.OnPlayerLeave(player)
    CodeService.OnPlayerLeave(player)
    PlayerDataService.OnPlayerLeave(player)
    print("[Main] " .. player.Name .. " left — data saved.")
end

-- ── Online production tick ────────────────────────────────────────────────────
-- Runs every 5 seconds for all active players
local TICK_INTERVAL = 5
local RESET_CHECK_EVERY = 12     -- ticks (a minute): players who leave the game open still get new daily / weekly challenges
local tickCount = 0
task.spawn(function()
    while true do
        task.wait(TICK_INTERVAL)
        tickCount += 1

        for _, player in ipairs(Players:GetPlayers()) do
            local data = PlayerDataService.Get(player)
            if data then
                if tickCount % RESET_CHECK_EVERY == 0 then
                    local resets = ChallengeService.CheckResets(player)
                    if resets.daily then
                        RemoteEvents.DailyReward:FireClient(player, resets.coins or GameConfig.DAILY_COIN_REWARD)
                    end
                end

                -- Tick idle production
                local rawGains, byElement, grew = IdleEngine.TickOnlineProduction(data, TICK_INTERVAL)
                for _, g in ipairs(grew or {}) do                              -- a Golem reached a new life stage
                    GolemData.NoteSeen(data, g.golem)                          -- (it goes in the collection)
                    local name = GolemNames.Describe(g.golem).shortName
                    RemoteEvents.Notify:FireClient(player, "Your Golem grew up!", string.format("%s is now %s: bigger and stronger.", name, g.stage.id))
                    PlayerDataService.MarkDirty(player)
                end
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
                    GuildService.OnResourcesGained(player, totalGained)
                    LadderService.OnResourcesGained(player, totalGained)
                end

                -- Tick smelt jobs
                local completedSmelts = ForgeService.TickSmeltJobs(player)
                for _, job in ipairs(completedSmelts) do
                    RemoteEvents.SmeltCompleted:FireClient(player, job)
                    ChallengeService.TrackEvent(player, "SmeltComplete", { count = job.quantity })
                end

                -- Tell the client the new pending totals (the badge on the Bag)
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
