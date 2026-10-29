-- The Hollow Maze (MAZE_DESIGN.md): builds each round's maze far from the world, runs everyone's attempt, moves the Zombie Golem (MazeZombie's rules) and catches the players it
-- reaches, pays them as they go deeper (MazeRewards) and feeds the main game's progression (player XP). A new maze is built every round, the same on every server.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MazeData    = require(game.ReplicatedStorage.Shared.Data.MazeData)
local MazeLayout  = require(game.ReplicatedStorage.Shared.Modules.MazeLayout)
local MazeZombie  = require(game.ReplicatedStorage.Shared.Modules.MazeZombie)
local MazeItems   = require(game.ReplicatedStorage.Shared.Modules.MazeItems)
local CourierData = require(game.ReplicatedStorage.Shared.Data.CourierData)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local SpeedData = require(game.ReplicatedStorage.Shared.Data.SpeedData)
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

local state = { round = nil, layout = nil, art = nil, root = nil, zombie = nil, zombieState = nil, phase = nil, orbs = {}, hideouts = {}, flares = 0 }
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
    for _, name in ipairs({ "MazeSection", "MazeTotal", "MazeCaught", "MazeItem", "MazeHidden" }) do player:SetAttribute(name, nil) end
end

-- ── Items and hiding ──────────────────────────────────────────────────────────
-- A Sprint Tonic raises the walk speed for a few seconds; this puts it back
local function RestoreSprint(rec)
    if not rec.baseWalk then return end
    local hum = rec.player.Character and rec.player.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = rec.baseWalk end
    rec.baseWalk = nil
end

-- Climb out of a crate (by choice, when the time is up, when caught, or when the run ends)
local function Unhide(rec, silent)
    if not MazeItems.Hidden(rec) then return end
    MazeItems.Unhide(rec, ServerNow())
    local h = rec.hideout
    rec.hideout = nil
    if h then
        h.occupant = nil
        if h.prompt then h.prompt.ActionText = "Hide" end
    end
    local root = Root(rec.player)
    if root then
        root.Anchored = false
        if h then root.CFrame = CFrame.new(h.outX or h.x, (h.y or root.Position.Y) + 3, h.outZ or h.z) end      -- step out into the middle of the cell
        root.AssemblyLinearVelocity = Vector3.zero
    end
    rec.player:SetAttribute("MazeHidden", nil)
    rec.lastPos = nil
    if not silent then Fire(rec.player, "unhidden", {}) end
end

-- E at a crate: climb in (the Zombie Golem finds you only if it comes right up to the crate), or climb out of the one you are in
local function ToggleHide(player, h)
    local rec = runs[player.UserId]
    if not rec or rec.caught or rec.escaped then return end
    local root = Root(player)
    if not root then return end
    if MazeItems.Hidden(rec) then
        if rec.hideout == h then Unhide(rec) end
        return
    end
    if h.occupant then
        Tell(player, "Crate", "Someone is already hiding in there.")
        return
    end
    local ok, why = MazeItems.Hide(rec, ServerNow())
    if not ok then
        if why == "cooldown" then Tell(player, "Crate", "Catch your breath: you can hide again in a moment.") end
        return
    end
    h.occupant = player.UserId
    rec.hideout = h
    root.CFrame = CFrame.new(h.x, (h.y or root.Position.Y) + 3, h.z)
    root.AssemblyLinearVelocity = Vector3.zero
    root.Anchored = true
    rec.lastPos = nil
    player:SetAttribute("MazeHidden", true)
    if h.prompt then h.prompt.ActionText = "Climb out" end
    Fire(player, "hidden", { seconds = MazeData.HIDE_MAX })
end

-- How long this run has lasted: from the gate opening, or from when the player came in if they arrived after that
local function RunSeconds(rec, clock)
    local round = state.round
    return math.max(0, clock - math.max(round.opensAt, rec.enteredClock or round.opensAt))
end

-- ── Progression hooks ─────────────────────────────────────────────────────────
-- Deployed Maze Golems (Labyrinth Mind) add to the coins and XP the maze pays
local function GolemBonus(data)
    local n = 0
    for _, g in ipairs(data.Golems or {}) do if g.element == "Maze" and g.deployed then n += 1 end end
    return MazeRewards.GolemBonus(n)
end

local function PayOptions(data)
    return { coinMultiplier = LiveOpsService.GetMultiplier("coins") * (1 + GolemBonus(data)) }
end

local function PaySection(rec, section)
    local player = rec.player
    local data = PlayerDataService.Get(player)
    if not data then return end
    local best = paidSection[player.UserId] or 0
    if section <= best then return end
    paidSection[player.UserId] = section
    local opts = PayOptions(data)
    local result = MazeRewards.PaySection(data, section, Today(), opts)
    local piece, pieceWhy = MazeRewards.RollPiece(data, section, false, Today())
    if piece then
        rec.totals.materials[piece.id] = (rec.totals.materials[piece.id] or 0) + 1
        Analytics.Funnel(player, data, "piece", 8, "FirstMazePiece")
    end
    local daily = MazeRewards.PayDaily(data, section, Today(), opts)
    if daily then rec.totals.coins += daily.coins end
    local xpGain = math.floor(MazeData.PlayerXp(section) * (1 + GolemBonus(data)))
    local leveled, newLevel = ProgressionService.AddPlayerXP(player, xpGain)
    rec.totals.coins += result.coins
    rec.totals.xp += xpGain
    if result.material then rec.totals.materials[result.material.id] = (rec.totals.materials[result.material.id] or 0) + result.material.qty end
    if result.rare then rec.totals.materials[result.rare.id] = (rec.totals.materials[result.rare.id] or 0) + result.rare.qty end
    pcall(function() Analytics.Custom(player, "MazeSection", section, { seed = state.round and state.round.seed }) end)
    PlayerDataService.MarkDirty(player)
    Fire(player, "section", {
        section = section, name = MazeData.SECTIONS[section], total = #MazeData.SECTIONS, coins = result.coins, xp = MazeData.PlayerXp(section), material = result.material,
        rare = result.rare, capped = result.capped, playerLevelUp = leveled and newLevel or nil, daily = daily, piece = piece, pieceCapped = (pieceWhy == "capped") or nil,
    })
end

local function Summary(rec, reason)
    return { best = rec.best, total = #MazeData.SECTIONS, coins = rec.totals.coins, xp = rec.totals.xp, materials = rec.totals.materials, reason = reason,
        escaped = rec.escaped and rec.escape or nil, caught = rec.caught }
end

local function EndRun(rec, reason, send)
    runs[rec.player.UserId] = nil
    Unhide(rec, true)
    RestoreSprint(rec)
    rec.item = nil
    ClearAttributes(rec.player)
    local summary = Summary(rec, reason)
    if send then Fire(rec.player, "roundover", summary) end
    return summary
end

local function Escape(rec)
    local player = rec.player
    local data = PlayerDataService.Get(player)
    local now = ServerNow()
    local seconds = RunSeconds(rec, WallClock())
    rec.escaped = true
    if not data then return end
    local opts = PayOptions(data)
    local chest = MazeRewards.PayEscape(data, #MazeData.SECTIONS, Today(), opts)
    Analytics.Funnel(player, data, "escape", 9, "FirstMazeEscape")
    local piece, pieceWhy = MazeRewards.RollPiece(data, #MazeData.SECTIONS, true, Today())
    if piece then rec.totals.materials[piece.id] = (rec.totals.materials[piece.id] or 0) + 1 end
    chest.piece, chest.pieceCapped = piece, (pieceWhy == "capped") or nil
    ProgressionService.AddPlayerXP(player, math.floor(MazeData.ESCAPE_PLAYER_XP * (1 + GolemBonus(data))))
    local c = MazeRewards.State(data, Today())
    local isNew = false
    if not c.mazeBestTime or seconds < c.mazeBestTime then c.mazeBestTime = math.floor(seconds * 10 + 0.5) / 10 isNew = true end
    rec.totals.coins += chest.coins
    rec.totals.xp += math.floor(MazeData.ESCAPE_PLAYER_XP * (1 + GolemBonus(data)))
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
        Tell(player, "Hollow Maze", string.format("This maze is nearly over. The next one opens in %d seconds.", math.ceil(MazeRound.UntilNext(state.round, clock))))
        return
    end
    if runs[player.UserId] then
        SendToLobby(player)
        return
    end
    local rec = { player = player, enteredAt = ServerNow(), enteredClock = clock, best = 0, totals = { coins = 0, xp = 0, materials = {} } }
    runs[player.UserId] = rec
    -- Coming in mid-hunt with nobody else running: the Zombie Golem is usually parked at the lobby gate from the last catch, so it would catch you the moment you
    -- arrive. It is sent back to the far end of the maze (the exit) to start its hunt from there.
    local z = state.zombieState
    local others = false
    for _, r in pairs(runs) do if r ~= rec and not r.caught and not r.escaped then others = true end end
    if z and z.awake and not others then
        local sx, _, sz = MazeLayout.CellCenter(state.layout, 1, state.layout.start.y)
        if math.abs(z.x - sx) < 160 and math.abs(z.z - sz) < 160 then
            local ex, _, ez = MazeLayout.CellCenter(state.layout, state.layout.width, state.layout.exit.y)
            z.x, z.z = ex - 7, ez
        end
    end
    player:SetAttribute("MazeSection", 0)
    player:SetAttribute("MazeTotal", #MazeData.SECTIONS)
    SendToLobby(player)
    local r = state.round
    Fire(player, "start", {
        opensAt = ToServerTime(r.opensAt), wakesAt = ToServerTime(r.wakesAt), endsAt = ToServerTime(r.endsAt), sections = MazeData.SECTIONS, seed = r.seed,
        best = MazeRewards.State(data, Today()).mazeBest or 0, dailyTarget = MazeData.DailyTarget(Today()), dailyDone = MazeRewards.DailyDone(data, Today()),
        zombieHome = state.art.zombieHome, mazeBase = MazeData.BASE, hideMax = MazeData.HIDE_MAX,
    })
    Analytics.Funnel(player, data, "maze", 6, "FirstMazeEntered")
    Analytics.TimeTo(player, data, "FirstMaze")
end

-- ── The hunt ──────────────────────────────────────────────────────────────────
-- Back to its starting place at the far end of the maze (the exit), so a new attempt is not caught at the gate
local function ResetZombie()
    local z = state.zombieState
    if not (z and state.layout) then return end
    local ex, _, ez = MazeLayout.CellCenter(state.layout, state.layout.width, state.layout.exit.y)
    z.x, z.z = ex - 7, ez
end

local function Targets()
    local list = {}
    for _, rec in pairs(runs) do
        if not rec.caught and not rec.escaped then
            local root = Root(rec.player)
            local hum = rec.player.Character and rec.player.Character:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                local walk = SpeedData.WalkSpeed(rec.player:GetAttribute("SpeedLevel") or 0)        -- (the trained speed, not whatever the humanoid says)
                list[#list + 1] = MazeItems.TargetFor(rec, rec.player.UserId, root.Position.X, root.Position.Z, MazeData.ZombieScale(walk), rec.speed or 0, walk, ServerNow())
            end
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
    local mode = info and info.mode
    local zstate = "asleep"
    if z.awake then
        if mode == "stunned" then zstate = "stunned"
        elseif mode == "search" then zstate = "search"
        elseif mode == "patrol" then zstate = "patrol"
        elseif info and info.distance and info.distance < 40 then zstate = "close"
        else zstate = "hunt" end
    end
    model:SetAttribute("ZState", zstate)
    model:SetAttribute("ZSlowed", (z.slowUntil ~= nil and z.clock < z.slowUntil) or nil)
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
            Unhide(rec, true)
            RestoreSprint(rec)
            rec.item = nil
            rec.player:SetAttribute("MazeItem", nil)
            rec.player:SetAttribute("MazeCaught", true)
            Fire(rec.player, "caught", Summary(rec, "caught"))
            task.delay(2.5, function()
                -- a moment to see what happened, then straight back to the lobby to try again: a fresh attempt (the rewards for sections already reached are not paid twice),
                -- and the Zombie Golem goes back to the far end if nobody else is running
                if runs[rec.player.UserId] ~= rec or not rec.caught or rec.escaped then return end
                SendToLobby(rec.player)
                rec.caught = false
                rec.enteredClock = WallClock()
                rec.lastPos, rec.lastGood = nil, nil
                rec.player:SetAttribute("MazeCaught", nil)
                local others = false
                for _, r in pairs(runs) do if r ~= rec and not r.caught and not r.escaped then others = true end end
                if not others then ResetZombie() end
                Fire(rec.player, "retry", {})
            end)
        end
    end
    publishAccum += dt
    if publishAccum >= 0.05 then
        publishAccum = 0
        PublishZombie(info, info and info.speed or MazeData.ZombieSpeed(hunt))
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
            local now = ServerNow()
            -- how fast they are moving (the Zombie Golem hears running, walking and standing still differently)
            if rec.lastPos and rec.lastAt and now - rec.lastAt > 0.02 then rec.speed = math.min(60, (p - rec.lastPos).Magnitude / (now - rec.lastAt)) else rec.speed = 0 end
            rec.lastAt = now
            local jumped = rec.lastPos and (p - rec.lastPos).Magnitude > TELEPORT_JUMP
            rec.lastPos = p
            -- a Sprint Tonic: faster while it lasts
            if MazeItems.Sprinting(rec, now) then
                if not rec.baseWalk then
                    rec.baseWalk = hum.WalkSpeed
                    hum.WalkSpeed = MazeItems.SprintSpeed(rec.baseWalk)
                end
            elseif rec.baseWalk then
                RestoreSprint(rec)
            end
            if MazeItems.HideExpired(rec, now) then Unhide(rec) end
            -- an item orb lies where you stand
            if not rec.caught and not rec.escaped and not MazeItems.Hidden(rec) and MazeRound.GateOpen(round, clock) then
                local orb = MazeItems.OrbAt(state.orbs, p.X, p.Z, now)
                if orb then
                    local id = MazeItems.TakeOrb(rec, orb, now)
                    if id then
                        player:SetAttribute("MazeItem", id)
                        Fire(player, "pickup", { item = id, name = orb.item.name, desc = orb.item.desc })
                    end
                end
            end
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
                    if RunSeconds(rec, clock) >= MazeData.ESCAPE_MIN_TIME then
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
    state.orbs = MazeArt.Orbs(root, M, MazeLayout.Pickups(M))
    state.hideouts = MazeArt.Hideouts(root, M, MazeLayout.Hideouts(M))
    for _, h in ipairs(state.hideouts) do
        h.prompt.Triggered:Connect(function(player) ToggleHide(player, h) end)
    end
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

-- The first maze of a server is built before the Golem meshes have finished loading, so its Zombie Golem starts as plain blocks. Once the mesh is there, swap it in
-- (same place, same published numbers; the client picks the new model up by itself).
local function UpgradeZombie()
    local old = state.zombie
    if not (old and old.Parent and old:GetAttribute("Block") and state.root and state.art) then return end
    local assets = game:GetService("ReplicatedStorage"):FindFirstChild("GolemAssets")
    if not (assets and assets:FindFirstChild("Zombie_Maze")) then return end
    local fresh = MazeArt.Zombie(state.root, state.art.zombieHome)
    if fresh:GetAttribute("Block") then fresh:Destroy() return end
    old:Destroy()
    state.zombie = fresh
    lastZ.x, lastZ.z = nil, nil
end

-- The portal's status board: what you can do right now
local function UpdatePortalStatus()
    local text = state.portalStatus
    if not (text and state.round) then return end
    local clock, round = WallClock(), state.round
    local function mmss(s) s = math.max(0, math.ceil(s)) return string.format("%d:%02d", s // 60, s % 60) end
    if MazeRound.CanEnter(round, clock) then
        local phase = MazeRound.Phase(round, clock)
        if phase == "gather" then
            text.Text, text.TextColor3 = string.format("MAZE OPEN - gate opens in %ds", math.ceil(round.opensAt - clock)), Color3.fromRGB(150, 255, 170)
        elseif phase == "headstart" then
            text.Text, text.TextColor3 = string.format("MAZE OPEN - Zombie wakes in %ds", math.ceil(round.wakesAt - clock)), Color3.fromRGB(150, 255, 170)
        else
            text.Text, text.TextColor3 = "HUNT ON - you can still go in", Color3.fromRGB(255, 220, 120)
        end
    else
        text.Text, text.TextColor3 = string.format("CLOSED - next maze in %s", mmss(MazeRound.UntilNext(round, clock))), Color3.fromRGB(255, 130, 110)
    end
end

-- Taken orbs vanish and come back (only touches a part when its state changes)
local function UpdateOrbs()
    local now = ServerNow()
    for _, orb in ipairs(state.orbs) do
        local taken = orb.takenUntil ~= nil and now < orb.takenUntil
        if orb.hiddenNow ~= taken then
            orb.hiddenNow = taken
            orb.part.Transparency = taken and 1 or 0
            if orb.ring then orb.ring.Transparency = taken and 1 or 0.5 end
            for _, d in ipairs(orb.part:GetChildren()) do
                if d:IsA("PointLight") or d:IsA("ParticleEmitter") then d.Enabled = not taken end
            end
            for _, d in ipairs(orb.part:GetChildren()) do
                if d:IsA("BillboardGui") then d.Enabled = not taken end
            end
        end
    end
end

-- Use the item in your hands against the Zombie Golem
function MazeService.UseItem(player)
    local rec = runs[player.UserId]
    if not rec or rec.caught or rec.escaped or not rec.item or MazeItems.Hidden(rec) then return false end
    local root = Root(player)
    local z = state.zombieState
    if not (root and z) then return false end
    state.flares += 1
    local ok, effect = MazeItems.Use(rec, z, root.Position.X, root.Position.Z, ServerNow(), "flare" .. state.flares)
    if not ok then return false end
    player:SetAttribute("MazeItem", nil)
    if effect.kind == "flare" and state.root then MazeArt.Flare(state.root, root.Position, effect.seconds) end
    Fire(player, "itemused", { kind = effect.kind, seconds = effect.seconds })
    pcall(function() Analytics.Custom(player, "MazeItem", 1, { kind = effect.kind }) end)
    return true
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
    local portal = TowerArt.Portal(world, Vector3.new(p.x, 0, p.z), Vector3.new(0.92, 0, 0.38), "HOLLOW MAZE", Color3.fromRGB(120, 255, 150), StartRun, true)       -- walk in to enter
    -- a live status board over the portal, so you can see whether you can walk in (and when it opens) without trying
    local glow = portal:FindFirstChild("PortalGlow")
    if glow then
        local board = Instance.new("BillboardGui")
        board.Name, board.Adornee, board.Size, board.StudsOffset, board.MaxDistance, board.AlwaysOnTop = "MazeStatus", glow, UDim2.new(0, 330, 0, 64), Vector3.new(0, 24, 0), 260, false
        board.Parent = glow
        local text = Instance.new("TextLabel")
        text.Size, text.BackgroundTransparency, text.TextScaled, text.Font = UDim2.new(1, 0, 1, 0), 1, true, Enum.Font.GothamBold
        text.TextStrokeTransparency, text.TextStrokeColor3 = 0.3, Color3.fromRGB(10, 14, 12)
        text.Parent = board
        state.portalStatus = text
    end

    RemoteEvents.LeaveChallenge.OnServerEvent:Connect(function(player)
        local rec = runs[player.UserId]
        if rec then
            EndRun(rec, "left", true)
            SendHome(player)
        end
    end)
    RemoteEvents.MazeUseItem.OnServerEvent:Connect(function(player) MazeService.UseItem(player) end)

    RunService.Heartbeat:Connect(function(dt)
        local ok, err = pcall(StepZombie, math.min(dt, 0.5))
        if not ok then warn("[MazeService] " .. tostring(err)) end
    end)
    task.spawn(function()
        while true do
            task.wait(0.1)
            local ok, err = pcall(function() PhaseChanges() Tick() UpdateOrbs() end)
            if not ok then warn("[MazeService] " .. tostring(err)) end
        end
    end)
    task.spawn(function()
        local lastStandings = 0
        while true do
            task.wait(1)
            pcall(UpdatePortalStatus)
            pcall(UpgradeZombie)
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

-- (for the tests)
MazeService._internals = { runs = runs, state = state, Tick = Tick, StepZombie = StepZombie, UpdateOrbs = UpdateOrbs, ToggleHide = ToggleHide, EndRun = EndRun, Targets = Targets }

return MazeService
