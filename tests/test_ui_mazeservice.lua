-- The Hollow Maze server in the mock: orbs, items, hiding crates, what the zombie hears, and clean-up. (The real feel needs Studio; this proves the rules and the wiring.)
QUIET = true
PhysicalProperties = { new = function() return {} end }

local realGet = game.GetService
rawset(game, "GetService", function(_, name)
    if name == "Debris" then return { AddItem = function() end } end
    return realGet(game, name)
end)
local TowerArt = load("SSS/EmberForge/Services/TowerArt")
TowerArt.Portal = function() return Instance.new("Model") end        -- (the portals are covered by their own art; not what this tests)

local events = {}
installFakeRemotes({})
fakeRemotes.MazeEvent.FireClient = function(_, player, kind, payload) table.insert(events, { to = player.UserId, kind = kind, payload = payload }) end
fakeRemotes.Notify.FireClient = function(_, player, title, msg) table.insert(events, { to = player.UserId, kind = "notify", payload = { title, msg } }) end
local function eventsOf(kind, uid)
    local n = 0
    for _, e in ipairs(events) do if e.kind == kind and (uid == nil or e.to == uid) then n += 1 end end
    return n
end

local MD    = load("game/ReplicatedStorage/Shared/Data/MazeData")
local ML    = load("game/ReplicatedStorage/Shared/Modules/MazeLayout")
local MZ    = load("game/ReplicatedStorage/Shared/Modules/MazeZombie")
local MI    = load("game/ReplicatedStorage/Shared/Modules/MazeItems")
local MR    = load("SSS/EmberForge/Services/MazeRound")
local PDS   = load("SSS/EmberForge/Services/PlayerDataService")
local Maze  = load("SSS/EmberForge/Services/MazeService")

Instance.new("Folder", workspace, "EmberWorld")
Maze.Init()
local I = Maze._internals
local S = I.state
expect(S.layout ~= nil and #S.orbs == #MD.SECTIONS * MD.PICKUPS_PER_SECTION, "the maze is built with " .. #S.orbs .. " item orbs")
local want = 0
for _, n in ipairs(MD.HIDEOUTS_PER_SECTION) do want += n end
expect(#S.hideouts == want, "and " .. #S.hideouts .. " hiding crates")
for _, h in ipairs(S.hideouts) do expect(h.prompt ~= nil and h.prompt.ActionText == "Hide", "crate " .. h.id .. " has a Hide prompt") end

-- put the round in the middle of the hunt
local t = os.time()
local r = MR.New(t)
r.opensAt, r.wakesAt, r.endsAt, r.nextStart = t - 40, t - 10, t + 250, t + 300
S.round = r
S.zombieState.awake = true

local function player(id, x, z)
    local store = { Name = "HumanoidRootPart", Anchored = false, Position = Vector3.new(x, MD.BASE.y + 3, z), AssemblyLinearVelocity = Vector3.new(0, 0, 0) }
    local root = setmetatable({}, { __index = store, __newindex = function(_, k, v) store[k] = v if k == "CFrame" then store.Position = v.Position end end })     -- (setting CFrame moves Position, every time)
    local hum = { Health = 100, WalkSpeed = 16, UseJumpPower = true, JumpPower = 50, JumpHeight = 7.2 }
    local char = { FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return root end end,
        FindFirstChildOfClass = function(_, c) if c == "Humanoid" then return hum end end }
    local attrs = {}
    local p = { UserId = id, Name = "P" .. id, DisplayName = "P" .. id, Parent = true, Character = char,
        SetAttribute = function(_, k, v) attrs[k] = v end, GetAttribute = function(_, k) return attrs[k] end }
    table.insert(game:GetService("Players")._list, p)
    return p, root, hum
end
local function enter(p)
    local d = PDS.Load(p)
    d.PlayerLevel = 10
    local rec = { player = p, enteredAt = os.time() - 30, enteredClock = os.time() - 30, best = 0, totals = { coins = 0, xp = 0, materials = {} } }
    I.runs[p.UserId] = rec
    p:SetAttribute("MazeSection", 0)
    return rec, d
end

print("== picking up an orb")
local orb = S.orbs[1]
local A, aRoot, aHum = player(101, orb.x, orb.z)
local recA = enter(A)
I.Tick()
expect(recA.item == orb.item.id and A:GetAttribute("MazeItem") == orb.item.id, "walking into an orb gives its item (" .. tostring(recA.item) .. ")")
expect(eventsOf("pickup", 101) == 1, "and tells the player")
I.UpdateOrbs()
expect(orb.part.Transparency == 1, "the orb vanishes")
I.Tick()
expect(eventsOf("pickup", 101) == 1, "standing in it again does nothing (hands are full and it is gone)")
advance(MD.PICKUP_RESPAWN + 1)
I.UpdateOrbs()
expect(orb.part.Transparency == 0, "it comes back after " .. MD.PICKUP_RESPAWN .. " seconds")

print("== using items")
aRoot.CFrame = CFrame.new(aRoot.Position.X, aRoot.Position.Y, aRoot.Position.Z + 60)        -- (step away from the orb, which is back by now)
-- Stone's orb is the Sprint Tonic
expect(orb.item.id == "sprint", "the first orb is a Sprint Tonic")
local used = Maze.UseItem(A)
expect(used and recA.item == nil and A:GetAttribute("MazeItem") == nil and eventsOf("itemused", 101) == 1, "using it empties the hands and tells the player")
I.Tick()
expect(aHum.WalkSpeed > 16 and aHum.WalkSpeed <= MD.SPRINT_MAX_WALK, "the sprint raises the walk speed (" .. string.format("%.1f", aHum.WalkSpeed) .. ")")
advance(MD.ITEMS.Stone.seconds + 1)
I.Tick()
expect(aHum.WalkSpeed == 16, "and it is put back when it wears off")
expect(not Maze.UseItem(A), "with empty hands there is nothing to use")

recA.item = "stun"
local z = S.zombieState
expect(Maze.UseItem(A) and MZ.IsStunned(z), "a Storm Jolt stuns the zombie")
recA.item = "freeze"
Maze.UseItem(A)
expect(z.slowFactor == MD.ITEMS.Frost.slow, "a Frost Snap slows it")
recA.item = "flare"
Maze.UseItem(A)
expect(#z.decoys == 1, "a Decoy Flare gives it something else to chase")
recA.item = "cloak"
Maze.UseItem(A)
local targets = I.Targets()
local mine
for _, tg in ipairs(targets) do if tg.id == 101 then mine = tg end end
expect(mine and mine.cloaked == true, "a Void Cloak marks the player as cloaked to the zombie")

print("== what the zombie hears")
advance(10)
I.Tick()
aRoot.CFrame = CFrame.new(aRoot.Position.X + 3, aRoot.Position.Y, aRoot.Position.Z)
advance(0.5)
I.Tick()
local ts = I.Targets()
local tgt
for _, tg in ipairs(ts) do if tg.id == 101 then tgt = tg end end
expect(tgt and (tgt.noise == "walk" or tgt.noise == "run"), "a player who moved is heard (" .. tostring(tgt and tgt.noise) .. ")")
advance(2)
I.Tick()
for _, tg in ipairs(I.Targets()) do if tg.id == 101 then tgt = tg end end
expect(tgt.noise == "still", "and one who stands still is not")

print("== hiding in a crate")
local h = S.hideouts[1]
aRoot.CFrame = CFrame.new(h.outX, MD.BASE.y + 3, h.outZ)
I.Tick()
recA.item = nil
h.prompt.Triggered:Fire(A)
expect(MI.Hidden(recA) and aRoot.Anchored == true and A:GetAttribute("MazeHidden") == true, "pressing E climbs in, and the player is held still")
expect(math.abs(aRoot.Position.X - h.x) < 1e-6 and math.abs(aRoot.Position.Z - h.z) < 1e-6, "inside the crate")
expect(h.prompt.ActionText == "Climb out" and h.occupant == 101, "which now says Climb out, and is taken")
local hidden
for _, tg in ipairs(I.Targets()) do if tg.id == 101 then hidden = tg end end
expect(hidden and hidden.hidden == true, "the zombie is told the player is hidden")
local B, bRoot = player(102, h.outX, h.outZ)
local recB = enter(B)
h.prompt.Triggered:Fire(B)
expect(not MI.Hidden(recB) and eventsOf("notify", 102) == 1, "a second player cannot get into an occupied crate, and is told so")
h.prompt.Triggered:Fire(A)
expect(not MI.Hidden(recA) and aRoot.Anchored == false and A:GetAttribute("MazeHidden") == nil, "pressing E again climbs out")
expect(math.abs(aRoot.Position.X - h.outX) < 1e-6, "into the middle of the cell")
h.prompt.Triggered:Fire(A)
expect(not MI.Hidden(recA) and eventsOf("notify", 101) >= 1, "but not straight back in: a short rest first")
advance(MD.HIDE_COOLDOWN + 1)
h.prompt.Triggered:Fire(A)
expect(MI.Hidden(recA), "after the rest it works again")
advance(MD.HIDE_MAX + 1)
I.Tick()
expect(not MI.Hidden(recA) and aRoot.Anchored == false, "after " .. MD.HIDE_MAX .. " seconds the player is pushed out")

print("== caught")
recA.item = "stun"
A:SetAttribute("MazeItem", "stun")
advance(MD.HIDE_COOLDOWN + 1)
h.prompt.Triggered:Fire(A)
expect(MI.Hidden(recA), "(hiding again)")
S.zombieState.stunUntil = nil
S.zombieState.decoys = {}
S.zombieState.x, S.zombieState.z = h.x + 1, h.z
I.StepZombie(0.2)
expect(recA.caught == true, "the zombie that comes right up to a crate catches whoever is in it")
expect(not MI.Hidden(recA) and aRoot.Anchored == false, "and they are out of the crate")
expect(recA.item == nil and A:GetAttribute("MazeItem") == nil, "an item in hand is lost")
expect(eventsOf("caught", 101) == 1, "and the player is told")

print("== clean-up when a run ends")
local C, cRoot, cHum = player(103, h.outX, h.outZ)
local recC = enter(C)
advance(1)
recC.item = "sprint"
recC.sprintUntil = os.time() + 100
I.Tick()
expect(cHum.WalkSpeed > 16, "(sprinting)")
recC.hideCooldownUntil = nil
recC.caught = false
I.EndRun(recC, "left", false)
expect(cHum.WalkSpeed == 16 and recC.item == nil, "leaving mid-sprint restores the walk speed")
local D, dRoot = player(104, h.outX, h.outZ)
local recD = enter(D)
h.occupant = nil
h.prompt.Triggered:Fire(D)
expect(MI.Hidden(recD) and dRoot.Anchored == true, "(another player hiding)")
I.EndRun(recD, "left", false)
expect(dRoot.Anchored == false and h.occupant == nil and h.prompt.ActionText == "Hide", "leaving while hidden frees the player and the crate")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
