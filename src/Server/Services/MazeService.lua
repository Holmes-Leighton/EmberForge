-- The Hollow Maze (MAZE_DESIGN.md): builds each round's maze far from the world, runs everyone's attempt, moves the Zombie Golem (MazeZombie's rules) and catches the players it
-- reaches, pays them as they go deeper (MazeRewards) and feeds the main game's progression (player XP). A new maze is built every round, the same on every server.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MazeData    = require(game.ReplicatedStorage.Shared.Data.MazeData)
local MazeLayout  = require(game.ReplicatedStorage.Shared.Modules.MazeLayout)
local MazeZombie  = require(game.ReplicatedStorage.Shared.Modules.MazeZombie)
local CourierData = require(game.ReplicatedStorage.Shared.Data.CourierData)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local LiveOpsService = require(script.Parent.LiveOpsService)
local Analytics   = require(script.Parent.AnalyticsHelper)
local MazeRound   = require(script.Parent.MazeRound)
local MazeRewards = require(script.Parent.MazeRewards)
local MazeArt     = require(script.Parent.MazeArt)
local TowerArt    = require(script.Parent.TowerArt)

local MazeService = {}

local SPAWN_HOME = Vector3.new(0, 6, -60)          -- where the way back leaves you (the hub spawn)
local STANDINGS_EVERY = 2
local TELEPORT_JUMP = 70                           -- studs in one tick that cannot be walking (cheat check)

local state = { round = nil, layout = nil, art = nil, root = nil, zombie = nil, zombieState = nil, phase = nil }
local runs = {}                  -- userId -> { player, enteredAt, best, totals, caught, escaped, lastPos }
local paidSection = {}           -- userId -> the deepest section paid in the current round (a section pays once per round, so re-entering cannot farm it)

local function ServerNow() return workspace:GetServerTimeNow() end
local function WallClock() return os.time() end
local function Today() return CourierData.Today() end
local function ToServerTime(wall) return wall + (ServerNow() - WallClock()) end      -- wall-clock seconds -> the server clock clients can read

local function Fire(player, kind, payload)
    if player and player.Parent then RemoteEvents.MazeEvent:FireClient(player, kind, payload) end
end
local function Tell(player, title, message)
    if player and player.Parent then RemoteEvents.Notify:FireClient(player, title, message) end
end

local function Root(player)
    return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function InMaze(player)
    local root = Root(player)
    return root ~= nil and root.Position.X < MazeData.BASE.x + 1000 and root.Position.X > MazeData.BASE.x - 1000 and root.Position.Y > MazeData.BASE.y - 200
end

local function SendHome(player)
    local root = Root(player)
    if root then
        root.CFrame = CFrame.new(SPAWN_HOME)
        root.AssemblyLinearVelocity = Vector3.zero
    end
end

local function SendToLobby(player)
    local root = Root(player)
    if root and state.art then
        root.CFrame = state.art.lobbySpawn
        root.AssemblyLinearVelocity = Vector3.zero
    end
end

local function ClearAttributes(player)
    for _, name in ipairs({ "MazeSection", "MazeTotal", "MazeCaught" }) do player:SetAttribute(name, nil) end
end

-- ── Progression hooks ─────────────────────────────────────────────────────────
local function PaySection(rec, section)
    local player = rec.player
    local data = PlayerDataService.Get(player)
    if not data then return end
    local best = paidSection[player.UserId] or 0
    if section <= best then return end
    paidSection[player.UserId] = section
    local opts = { coinMultiplier = LiveOpsService.GetMultiplier("coins") }
    local result = MazeRewards.PaySection(data, section, Today(), opts)
    local daily = MazeRewards.PayDaily(data, section, Today(), opts)
    if daily then rec.totals.coins += daily.coins end
    local leveled, newLevel = ProgressionService.AddPlayerXP(player, MazeData.PlayerXp(section))
    rec.totals.coins += result.coins
    rec.totals.xp += MazeData.PlayerXp(section)
    if result.material then rec.totals.materials[result.material.id] = (rec.totals.materials[result.material.id] or 0) + result.material.qty end
    if result.rare then rec.totals.materials[result.rare.id] = (rec.totals.materials[result.rare.id] or 0) + result.rare.qty end
    pcall(function() Analytics.Custom(player, "MazeSection", section, { seed = state.round and state.round.seed }) end)
    PlayerDataService.MarkDirty(player)
    Fire(player, "section", {
        section = section, name = MazeData.SECTIONS[section], total = #MazeData.SECTIONS, coins = result.coins, xp = MazeData.PlayerXp(section), material = result.material,
        rare = result.rare, capped = result.capped, playerLevelUp = leveled and newLevel or nil, daily = daily,
    })
end

local function Summary(rec, reason)
    return { best = rec.best, total = #MazeData.SECTIONS, coins = rec.totals.coins, xp = rec.totals.xp, materials = rec.totals.materials, reason = reason,
        escaped = rec.escaped and rec.escape or nil, caught = rec.caught }
end

local function EndRun(rec, reason, send)
    runs[rec.player.UserId] = nil
    ClearAttributes(rec.player)
    local summary = Summary(rec, reason)
    if send then Fire(rec.player, "roundover", summary) end
    return summary
end

local function Escape(rec)
    local player = rec.player
    local data = PlayerDataService.Get(player)
    local now = ServerNow()
    local seconds = MazeRound.RunElapsed(state.round, WallClock())
    rec.escaped = true
    if not data then return end
    local opts = { coinMultiplier = LiveOpsService.GetMultiplier("coins") }
    local chest = MazeRewards.PayEscape(data, #MazeData.SECTIONS, Today(), opts)
    ProgressionService.AddPlayerXP(player, MazeData.ESCAPE_PLAYER_XP)
    local c = MazeRewards.State(data, Today())
    local isNew = false
    if not c.mazeBestTime or seconds < c.mazeBestTime then c.mazeBestTime = math.floor(seconds * 10 + 0.5) / 10 isNew = true end
    rec.totals.coins += chest.coins
    rec.totals.xp += MazeData.ESCAPE_PLAYER_XP
    rec.best = #MazeData.SECTIONS
    rec.escape = { seconds = seconds, medal = MazeData.Medal(seconds), chest = chest, personalBest = isNew }
    PlayerDataService.MarkDirty(player)
    Fire(player, "escape", rec.escape)
    pcall(function() Analytics.Custom(player, "MazeEscape", seconds, {}) end)
    local sped = MazeRound.Escape(state.round, player.UserId, WallClock(), seconds)
    if sped then
        workspace:SetAttribute("MazeEndsAt", ToServerTime(state.round.endsAt))
        for _, other in pairs(runs) do
            if not other.escaped and not other.caught then Fire(other.player, "speedup", { name = player.DisplayName, seconds = MazeData.ESCAPE_SPEEDUP }) end
        end
    end
end

-- ── Entering ──────────────────────────────────────────────────────────────────
local function StartRun(player)
    local data = PlayerDataService.Get(player)
    local root = Root(player)
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not (data and root and hum and hum.Health > 0 and state.layout) then return end
    if (data.PlayerLevel or 1) < MazeData.GATE_LEVEL then
        Tell(player, "Hollow Maze", string.format("The Hollow Maze opens at player level %d (you are level %d). Keep forging, mining and finishing quests.", MazeData.GATE_LEVEL, data.PlayerLevel or 1))
        return
    end
    local clock = WallClock()
    if not MazeRound.CanEnter(state.round, clock) then
        Tell(player, "Hollow Maze", string.format("The Zombie Golem is already hunting. The next maze opens in %d seconds.", math.ceil(MazeRound.UntilNext(state.round, clock))))
        return
    end
    if runs[player.UserId] then
        SendToLobby(player)
        return
    end
    local rec = { player = player, enteredAt = ServerNow(), best = 0, totals = { coins = 0, xp = 0, materials = {} } }
    runs[player.UserId] = rec
    player:SetAttribute("MazeSection", 0)
    player:SetAttribute("MazeTotal", #MazeData.SECTIONS)
    SendToLobby(player)
    local r = state.round
    Fire(player, "start", {
        opensAt = ToServerTime(r.opensAt), wakesAt = ToServerTime(r.wakesAt), endsAt = ToServerTime(r.endsAt), sections = MazeData.SECTIONS, seed = r.seed,
        best = MazeRewards.State(data, Today()).mazeBest or 0, dailyTarget = MazeData.DailyTarget(Today()), dailyDone = MazeRewards.DailyDone(data, Today()),
        zombieHome = state.art.zombieHome, mazeBase = MazeData.BASE,
    })
end

-- ── The hunt ──────────────────────────────────────────────────────────────────
local function Targets()
    local list = {}
    for _, rec in pairs(runs) do
        if not rec.caught and not rec.escaped then
            local root = Root(rec.player)
            local hum = rec.player.Character and rec.player.Character:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then list[#list + 1] = { id = rec.player.UserId, x = root.Position.X, z = root.Position.Z } end
        end
    end
    return list
end

local lastZ = { x = nil, z = nil }
local function PublishZombie(info, speed)
    local model = state.zombie
    if not model then return end
    local z = state.zombieState
    local moving = lastZ.x ~= nil and (math.abs(z.x - lastZ.x) + math.abs(z.z - lastZ.z)) > 0.01
    local yaw = model:GetAttribute("ZYaw") or -math.pi / 2          -- (facing east, into the maze)
    if moving then yaw = math.atan2(-(z.x - lastZ.x), -(z.z - lastZ.z)) end
    lastZ.x, lastZ.z = z.x, z.z
    model:SetAttribute("ZX", z.x)
    model:SetAttribute("ZZ", z.z)
    model:SetAttribute("ZYaw", yaw)
    model:SetAttribute("ZSpeed", moving and speed or 0)
    model:SetAttribute("ZState", z.awake and (info and info.distance and info.distance < 40 and "close" or "hunt") or "asleep")
end

local publishAccum = 0
local function StepZombie(dt)
    if not state.zombieState or not state.layout then return end
    local clock = WallClock()
    local round = state.round
    local hunt = MazeRound.HuntElapsed(round, clock)
    local z = state.zombieState
    z.awake = MazeRound.Phase(round, clock) == "hunt"
    local caught, info
    if z.awake then
        local remaining = dt
        while remaining > 0 do                                           -- (a long frame is split so it never skips past a player)
            local slice = math.min(remaining, 0.1)
            local c, i = MazeZombie.Step(state.layout, z, Targets(), slice, hunt)
            if i then info = i end
            for _, id in ipairs(c) do caught = caught or {} table.insert(caught, id) end
            remaining -= slice
        end
    end
    for _, id in ipairs(caught or {}) do
        local rec = runs[id]
        if rec and not rec.caught then
            rec.caught = true
            rec.player:SetAttribute("MazeCaught", true)
            Fire(rec.player, "caught", Summary(rec, "caught"))
            task.delay(2.5, function() SendToLobby(rec.player) end)        -- a moment to see what happened, then to the lobby to watch
        end
    end
    publishAccum += dt
    if publishAccum >= 0.05 then
        publishAccum = 0
        PublishZombie(info, MazeData.ZombieSpeed(hunt))
    end
end

-- ── Per-player checks (a few times a second) ──────────────────────────────────
local function Tick()
    local clock = WallClock()
    local round = state.round
    for _, rec in pairs(runs) do
        local player = rec.player
        local root = Root(player)
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not (root and hum and hum.Health > 0) then
            Fire(player, "abandon", { reason = "died" })
            EndRun(rec, "died", false)
        elseif not InMaze(player) then
            Fire(player, "abandon", { reason = "left" })
            EndRun(rec, "left", false)
        else
            local p = root.Position
            local jumped = rec.lastPos and (p - rec.lastPos).Magnitude > TELEPORT_JUMP
            rec.lastPos = p
            if jumped and not rec.caught then
                -- a teleport inside the maze (or a long lag spike): put them back where they were seen, no penalty beyond that
                root.CFrame = CFrame.new(rec.lastGood or p) * CFrame.Angles(0, 0, 0)
                rec.lastPos = rec.lastGood or p
            elseif not rec.caught and not rec.escaped then
                rec.lastGood = p
                local cx, cy = MazeLayout.CellOf(state.layout, p.X, p.Z)
                if cx and MazeRound.GateOpen(round, clock) then
                    local section = MazeLayout.SectionOf(state.layout, cx)
                    if section > rec.best then
                        rec.best = section
                        player:SetAttribute("MazeSection", section)
                        PaySection(rec, section)
                    end
                end
                -- through the exit arch into the victory room
                if p.X > state.art.exitX + 6 and MazeRound.GateOpen(round, clock) then
                    if MazeRound.RunElapsed(round, clock) >= MazeData.ESCAPE_MIN_TIME then
                        Escape(rec)
                    else
                        rec.caught = false
                        SendToLobby(player)                               -- faster than anyone can run: not an escape (cheat check)
                    end
                end
            end
        end
    end
end

-- ── Building the maze ─────────────────────────────────────────────────────────
local function OpenGate(open)
    local art = state.art
    if not art then return end
    art.door.CanCollide = not open
    art.door.Transparency = open and 1 or 0.45
end

local function BuildMaze(world, round)
    if state.root then state.root:Destroy() end
    local M = MazeLayout.Build({ seed = round.seed, base = MazeData.BASE })
    state.layout = M
    local root = Instance.new("Folder")
    root.Name = "MazeWorldRoot"
    root.Parent = world
    state.root = root
    local art = MazeArt.Build(root, M)
    state.art = art
    local b = MazeData.BASE
    -- the way back: a portal in the lobby, and one in the victory room
    TowerArt.Portal(root, Vector3.new(b.x - art.lobbyDepth + 4, b.y, b.z), Vector3.new(1, 0, 0), "Back to the cavern", Color3.fromRGB(120, 210, 255), function(player)
        local rec = runs[player.UserId]
        if rec then EndRun(rec, "left", true) end
        SendHome(player)
    end)
    TowerArt.Portal(root, Vector3.new(art.victoryX + 8, b.y, b.z), Vector3.new(-1, 0, 0), "Home", Color3.fromRGB(255, 215, 90), function(player)
        local rec = runs[player.UserId]
        if rec then EndRun(rec, "home", true) end
        SendHome(player)
    end)
    state.zombie = MazeArt.Zombie(root, art.zombieHome)
    state.zombieState = MazeZombie.New(M)
    state.zombieState.x, state.zombieState.z = art.zombieHome.X, art.zombieHome.Z
    lastZ.x, lastZ.z = nil, nil
    state.phase = nil
    OpenGate(false)
    workspace:SetAttribute("MazeOpensAt", ToServerTime(round.opensAt))
    workspace:SetAttribute("MazeWakesAt", ToServerTime(round.wakesAt))
    workspace:SetAttribute("MazeEndsAt", ToServerTime(round.endsAt))
    workspace:SetAttribute("MazeRoundIndex", round.index)
    return M
end

local function NewRound(world, round)
    for _, rec in pairs(runs) do EndRun(rec, "newround", true) end
    for _, player in ipairs(Players:GetPlayers()) do
        if InMaze(player) then SendHome(player) end
    end
    paidSection = {}
    state.round = round
    BuildMaze(world, round)
end

local function Standings()
    local list = {}
    for _, rec in pairs(runs) do
        table.insert(list, { name = rec.player.DisplayName, section = rec.best, userId = rec.player.UserId, caught = rec.caught, escaped = rec.escaped })
    end
    table.sort(list, function(a, b)
        if (a.escaped or false) ~= (b.escaped or false) then return a.escaped end
        if a.section ~= b.section then return a.section > b.section end
        return a.name < b.name
    end)
    return list
end

-- Phase changes, announced once each: the gate opens, then the zombie wakes
local function PhaseChanges()
    local phase = MazeRound.Phase(state.round, WallClock())
    if phase == state.phase then return end
    state.phase = phase
    if phase == "headstart" then
        OpenGate(true)
        for _, rec in pairs(runs) do Fire(rec.player, "gateopen", {}) end
    elseif phase == "hunt" then
        OpenGate(true)
        for _, rec in pairs(runs) do Fire(rec.player, "wake", {}) end
    elseif phase == "intermission" then
        OpenGate(true)
    end
end

function MazeService.Init()
    local world = workspace:FindFirstChild("EmberWorld")
    if not world then
        warn("[MazeService] EmberWorld not found: build the world first")
        return
    end
    state.round = MazeRound.New(WallClock())
    BuildMaze(world, state.round)

    local p = MazeData.PORTAL
    TowerArt.Portal(world, Vector3.new(p.x, 0, p.z), Vector3.new(0.92, 0, 0.38), "HOLLOW MAZE", Color3.fromRGB(120, 255, 150), StartRun, true)       -- walk in to enter

    RunService.Heartbeat:Connect(function(dt)
        local ok, err = pcall(StepZombie, math.min(dt, 0.5))
        if not ok then warn("[MazeService] " .. tostring(err)) end
    end)
    task.spawn(function()
        while true do
            task.wait(0.1)
            local ok, err = pcall(function() PhaseChanges() Tick() end)
            if not ok then warn("[MazeService] " .. tostring(err)) end
        end
    end)
    task.spawn(function()
        local lastStandings = 0
        while true do
            task.wait(1)
            local clock = WallClock()
            -- the hunt is over: everyone is told how they did and brought home; a while later the next maze starts
            if not MazeRound.Running(state.round, clock) and MazeRound.Phase(state.round, clock) == "intermission" and next(runs) ~= nil then
                for _, rec in pairs(runs) do
                    EndRun(rec, rec.escaped and "escaped" or (rec.caught and "caught" or "timeup"), true)
                    SendHome(rec.player)
                end
            end
            local events = MazeRound.Step(state.round, clock)
            for _, e in ipairs(events) do
                if e.kind == "new" then NewRound(world, e.round) end
            end
            if next(runs) ~= nil and ServerNow() - lastStandings >= STANDINGS_EVERY then
                lastStandings = ServerNow()
                local list = Standings()
                for _, rec in pairs(runs) do Fire(rec.player, "standings", { list = list }) end
            end
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        local rec = runs[player.UserId]
        if rec then EndRun(rec, "left", false) end
        paidSection[player.UserId] = nil
    end)
end

-- True while this player is in the maze (the rest of the game uses it to refuse things that make no sense mid-run, like collecting mined resources)
function MazeService.InMaze(player) return InMaze(player) end
function MazeService.Layout() return state.layout end
function MazeService.Round() return state.round end

return MazeService
