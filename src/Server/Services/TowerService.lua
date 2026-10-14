-- The Sky Tower: builds the current round's tower far above the world, runs every climber's attempt (TowerRunner's rules), pays them as they climb (TowerRewards) and
-- feeds the main game's progression: player XP (so tower levels count towards your level), Quests (daily, weekly and lifetime), the leaderboard and analytics.
-- A new tower is built every round, the same on every server.
local Players = game:GetService("Players")

local TowerData   = require(game.ReplicatedStorage.Shared.Data.TowerData)
local TowerLayout = require(game.ReplicatedStorage.Shared.Modules.TowerLayout)
local CourierData = require(game.ReplicatedStorage.Shared.Data.CourierData)
local CartBountyData = require(game.ReplicatedStorage.Shared.Data.CartBountyData)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local ChallengeService = require(script.Parent.ChallengeService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local LiveOpsService = require(script.Parent.LiveOpsService)
local Analytics   = require(script.Parent.AnalyticsHelper)
local TowerRound  = require(script.Parent.TowerRound)
local TowerRunner = require(script.Parent.TowerRunner)
local TowerRewards = require(script.Parent.TowerRewards)
local TowerArt    = require(script.Parent.TowerArt)
local CourierArt  = require(script.Parent.CourierArt)

local TowerService = {}

local SPAWN_HOME = Vector3.new(0, 6, -60)          -- where the way back leaves you (the hub spawn)
local SAMPLE = 0.1
local STANDINGS_EVERY = 2

local state = { round = nil, layout = nil, folder = nil }
local runs = {}                  -- userId -> { player, run, totals = { coins, xp, materials } }
local roundBest = {}             -- userId -> the highest level paid in the current round (a level pays once per round, so re-entering can't farm it)

local function ServerNow() return workspace:GetServerTimeNow() end
local function WallClock() return os.time() end
local function Today() return CourierData.Today() end

local function Fire(player, kind, payload)
    if player and player.Parent then RemoteEvents.TowerEvent:FireClient(player, kind, payload) end
end
local function Tell(player, title, message)
    if player and player.Parent then RemoteEvents.Notify:FireClient(player, title, message) end
end

local function Root(player)
    return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function InTower(player)
    local root = Root(player)
    return root ~= nil and root.Position.Y > TowerData.BASE.y - 200
end

local function SendHome(player)
    local root = Root(player)
    if root then
        root.CFrame = CFrame.new(SPAWN_HOME)
        root.AssemblyLinearVelocity = Vector3.zero
    end
end

local function LobbyPoint()
    local b = TowerData.BASE
    return CFrame.lookAt(Vector3.new(b.x - 17, b.y + 4, b.z), Vector3.new(b.x + 20, b.y + 4, b.z))
end

local function ClearAttributes(player)
    for _, name in ipairs({ "TowerLevel", "TowerTotal", "TowerStart", "TowerRespawns", "TowerLavaY0", "TowerLavaT0", "TowerLavaRise" }) do
        player:SetAttribute(name, nil)
    end
end

local function SetLavaAttributes(player, run)
    local l = run.lava
    player:SetAttribute("TowerLavaY0", l and l.y0 or nil)
    player:SetAttribute("TowerLavaT0", l and l.t0 or nil)
    player:SetAttribute("TowerLavaRise", l and l.rise or nil)
end

-- ── Progression hooks ─────────────────────────────────────────────────────────
-- Everything a reached level feeds into the rest of the game
local function Feed(player, level, result)
    local data = PlayerDataService.Get(player)
    local leveled, newLevel = ProgressionService.AddPlayerXP(player, TowerData.PlayerXp(level))
    ChallengeService.TrackEvent(player, "TowerLevel", { count = 1, level = level })
    LeaderboardService.OnTowerLevel(player, level)
    pcall(function() Analytics.Custom(player, "TowerLevel", level, { total = state.layout and state.layout.total }) end)
    PlayerDataService.MarkDirty(player)
    return leveled, newLevel
end

local function PayLevel(rec, level)
    local player = rec.player
    local data = PlayerDataService.Get(player)
    if not data then return end
    local total = state.layout.total
    local best = roundBest[player.UserId] or 0
    if level <= best then
        Fire(player, "level", { level = level, total = total, repeatLevel = true, seconds = TowerRunner.Elapsed(rec.run, ServerNow()) })
        return
    end
    roundBest[player.UserId] = level
    local result = TowerRewards.PayLevel(data, level, total, Today(), { coinMultiplier = LiveOpsService.GetMultiplier("coins") })
    local daily = TowerRewards.PayDaily(data, level, total, Today(), { coinMultiplier = LiveOpsService.GetMultiplier("coins") })
    if daily then rec.totals.coins += daily.coins end
    local leveled, newLevel = Feed(player, level, result)
    rec.totals.coins += result.coins
    rec.totals.xp += TowerData.PlayerXp(level)
    for _, m in ipairs(result.materials or {}) do rec.totals.materials[m.id] = (rec.totals.materials[m.id] or 0) + m.qty end
    if result.rare then rec.totals.materials[result.rare.id] = (rec.totals.materials[result.rare.id] or 0) + result.rare.qty end
    PlayerDataService.MarkDirty(player)
    Fire(player, "level", {
        level = level, total = total, coins = result.coins, xp = TowerData.PlayerXp(level), courierXp = result.xp, materials = result.materials, rare = result.rare,
        capped = result.capped, playerLevelUp = leveled and newLevel or nil, courierLevel = result.courierLevel, courierLevelUp = result.levelUps > 0,
        seconds = TowerRunner.Elapsed(rec.run, ServerNow()), daily = daily,
    })
end

-- ── Runs ──────────────────────────────────────────────────────────────────────
local function EndRun(rec, reason, send)
    runs[rec.player.UserId] = nil
    ClearAttributes(rec.player)
    local summary = { best = rec.run.highest, total = state.layout and state.layout.total or 0, respawns = rec.run.respawns, coins = rec.totals.coins, xp = rec.totals.xp,
        materials = rec.totals.materials, reason = reason, summit = rec.summit }
    if send then Fire(rec.player, "roundover", summary) end
    return summary
end

local function StartRun(player)
    local data = PlayerDataService.Get(player)
    local root = Root(player)
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not (data and root and hum and hum.Health > 0 and state.layout) then return end
    if (data.PlayerLevel or 1) < TowerData.GATE_LEVEL then
        Tell(player, "Sky Tower", string.format("The Sky Tower opens at player level %d (you are level %d). Keep forging, mining and finishing quests.", TowerData.GATE_LEVEL, data.PlayerLevel or 1))
        return
    end
    local now = ServerNow()
    local clock = WallClock()
    if not TowerRound.Running(state.round, clock) then
        Tell(player, "Sky Tower", string.format("The next tower is being built. Come back in %d seconds.", math.ceil(TowerRound.UntilNext(state.round, clock))))
        return
    end
    if runs[player.UserId] then
        root.CFrame = LobbyPoint()                                  -- already climbing: the portal just takes you back to the lobby
        root.AssemblyLinearVelocity = Vector3.zero
        return
    end
    local T = state.layout
    local rec = { player = player, totals = { coins = 0, xp = 0, materials = {} } }
    rec.run = TowerRunner.New(T, {
        onLevel = function(level, seconds)
            PayLevel(rec, level)
            player:SetAttribute("TowerLevel", level)
            SetLavaAttributes(player, rec.run)
        end,
        onRespawn = function(reason, level, cp)
            local target = Vector3.new(cp.x, cp.y + 2, cp.z)
            local r = Root(player)
            if r then
                r.CFrame = CFrame.lookAt(target, target + Vector3.new(T.levels[level].dir, 0, 0))
                r.AssemblyLinearVelocity = Vector3.zero
            end
            player:SetAttribute("TowerRespawns", rec.run.respawns)
            SetLavaAttributes(player, rec.run)
            Fire(player, "respawn", { reason = reason, level = level, penalty = TowerData.RESPAWN_PENALTY, respawns = rec.run.respawns })
        end,
        onSummit = function(seconds, respawns)
            local d = PlayerDataService.Get(player)
            local isNew = false
            if d then
                local chest = TowerRewards.PayTop(d, T.total, Today(), { coinMultiplier = LiveOpsService.GetMultiplier("coins") })
                ProgressionService.AddPlayerXP(player, TowerData.SUMMIT_PLAYER_XP)
                ChallengeService.TrackEvent(player, "TowerSummit", { count = 1 })
                local s = TowerRewards.State(d, Today())
                local par = TowerData.PAR_SECONDS_PER_LEVEL * T.total
                local medal = CartBountyData.Medal(seconds, par)
                if not s.towerBestTime or seconds < s.towerBestTime then s.towerBestTime = math.floor(seconds * 10 + 0.5) / 10 isNew = true end
                rec.totals.coins += chest.coins
                rec.summit = { seconds = seconds, medal = medal, chest = chest, personalBest = isNew, par = par, respawns = respawns }
                PlayerDataService.MarkDirty(player)
                Fire(player, "summit", rec.summit)
                pcall(function() Analytics.Custom(player, "TowerSummit", seconds, { respawns = respawns }) end)
            end
            -- everyone still climbing has less time left
            local sped = TowerRound.Summit(state.round, player.UserId, WallClock(), seconds)
            if sped then
                workspace:SetAttribute("TowerRoundEnds", state.round.endsAt)
                for _, other in pairs(runs) do
                    Fire(other.player, "speedup", { name = player.DisplayName, seconds = TowerData.SUMMIT_SPEEDUP })
                end
            end
        end,
        onAbandon = function(reason)
            Fire(player, "abandon", { reason = reason })
            EndRun(rec, reason, false)
        end,
    }, now)
    runs[player.UserId] = rec
    player:SetAttribute("TowerLevel", 1)
    player:SetAttribute("TowerTotal", T.total)
    player:SetAttribute("TowerStart", now)
    player:SetAttribute("TowerRespawns", 0)
    root.CFrame = LobbyPoint()
    root.AssemblyLinearVelocity = Vector3.zero
    PayLevel(rec, 1)                                              -- level 1 is yours the moment you arrive
    Fire(player, "start", { total = T.total, roundEnds = state.round.endsAt, best = (TowerRewards.State(data, Today()).towerBest or 0), seed = state.round.seed,
        dailyTarget = TowerData.DailyTarget(Today(), T.total), dailyDone = TowerRewards.DailyDone(data, Today()) })
end

local function Tick()
    local now = ServerNow()
    for _, rec in pairs(runs) do
        local player = rec.player
        local root = Root(player)
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not (root and hum and hum.Health > 0) then
            Fire(player, "abandon", { reason = "died" })
            EndRun(rec, "died", false)
        elseif not InTower(player) then
            Fire(player, "abandon", { reason = "left" })            -- moved out another way (My Forge, a teleport): the client must close its tower HUD too
            EndRun(rec, "left", false)
        else
            local p = root.Position
            TowerRunner.Step(rec.run, now, p.X, p.Y, p.Z)
        end
    end
end

local function Standings()
    local list = {}
    for _, rec in pairs(runs) do
        table.insert(list, { name = rec.player.DisplayName, level = rec.run.highest, userId = rec.player.UserId })
    end
    table.sort(list, function(a, b) if a.level ~= b.level then return a.level > b.level end return a.name < b.name end)
    return list
end

-- ── Building the tower ────────────────────────────────────────────────────────
local function BuildTower(world, round)
    if state.folder then state.folder:Destroy() end
    local T = TowerLayout.Build({ levels = TowerData.LEVELS, seed = round.seed, base = TowerData.BASE })
    state.layout = T
    local root = Instance.new("Folder")
    root.Name = "SkyTowerRoot"
    root.Parent = world
    state.folder = root
    TowerArt.Build(root, T)

    local b = TowerData.BASE
    CourierArt.P({ Name = "TowerLobby", Material = Enum.Material.Slate, Color = Color3.fromRGB(110, 76, 66), Size = Vector3.new(34, 2, 30), CFrame = CFrame.new(b.x - 17, b.y - 1, b.z) }, root)
    TowerArt.Portal(root, Vector3.new(b.x - 30, b.y, b.z - 6), Vector3.new(1, 0, 0), "Back to the cavern", Color3.fromRGB(120, 210, 255), function(player)
        local rec = runs[player.UserId]
        if rec then EndRun(rec, "left", true) end
        SendHome(player)
    end)
    local f = T.finish
    local dir = T.levels[T.total].dir
    TowerArt.Portal(root, Vector3.new(f.x + dir * 12, f.y - 3, f.z), Vector3.new(-dir, 0, 0), "Home", Color3.fromRGB(255, 215, 90), function(player)
        local rec = runs[player.UserId]
        if rec then EndRun(rec, "home", true) end
        SendHome(player)
    end)
    workspace:SetAttribute("TowerRoundEnds", round.endsAt)
    workspace:SetAttribute("TowerRoundIndex", round.index)
    return T
end

local function NewRound(world, round)
    for _, rec in pairs(runs) do EndRun(rec, "newround", true) end
    for _, player in ipairs(Players:GetPlayers()) do
        if InTower(player) then SendHome(player) end
    end
    roundBest = {}
    state.round = round
    BuildTower(world, round)
end

function TowerService.Init()
    local world = workspace:FindFirstChild("EmberWorld")
    if not world then
        warn("[TowerService] EmberWorld not found: build the world first")
        return
    end
    state.round = TowerRound.New(WallClock())
    BuildTower(world, state.round)

    local p = TowerData.PORTAL
    TowerArt.Portal(world, Vector3.new(p.x, 0, p.z), Vector3.new(0.92, 0, -0.38), "SKY TOWER", Color3.fromRGB(190, 120, 255), StartRun, true)       -- walk in to climb

    task.spawn(function()
        while true do
            task.wait(SAMPLE)
            local ok, err = pcall(Tick)
            if not ok then warn("[TowerService] " .. tostring(err)) end
        end
    end)
    task.spawn(function()
        local lastStandings = 0
        while true do
            task.wait(1)
            local clock = WallClock()
            -- the climbing time is up: everyone is told how they did and brought down; a while later the next tower starts
            if not TowerRound.Running(state.round, clock) and next(runs) ~= nil then
                for _, rec in pairs(runs) do
                    EndRun(rec, "timeup", true)
                    SendHome(rec.player)
                end
            end
            local events, round = TowerRound.Step(state.round, clock)
            for _, e in ipairs(events) do
                if e.kind == "new" then NewRound(world, e.round) end
            end
            if next(runs) ~= nil and ServerNow() - lastStandings >= STANDINGS_EVERY then
                lastStandings = ServerNow()
                local list = Standings()
                for _, rec in pairs(runs) do Fire(rec.player, "standings", { list = list, roundEnds = state.round.endsAt }) end
            end
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        local rec = runs[player.UserId]
        if rec then EndRun(rec, "left", false) end
        roundBest[player.UserId] = nil
    end)
end

-- True while this player is up in the tower (the rest of the game uses it to refuse things that make no sense mid-climb, like collecting mined resources)
function TowerService.InTower(player) return InTower(player) end
function TowerService.Layout() return state.layout end
function TowerService.Round() return state.round end

return TowerService
