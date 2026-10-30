-- The Sky Tower server: a level that plays by its own rule changes how the climber moves (and is put back after), on top of the round's mutator.
QUIET = true
PhysicalProperties = { new = function() return {} end }

local realGet = game.GetService
rawset(game, "GetService", function(_, name)
    if name == "Debris" then return { AddItem = function() end } end
    return realGet(game, name)
end)
local TowerArt = load("SSS/EmberForge/Services/TowerArt")
TowerArt.Portal = function() return Instance.new("Model") end        -- (the portals are covered by their own art)

local events = {}
installFakeRemotes({})
fakeRemotes.TowerEvent.FireClient = function(_, player, kind, payload) table.insert(events, { to = player.UserId, kind = kind, payload = payload }) end
local function last(kind)
    for i = #events, 1, -1 do if events[i].kind == kind then return events[i].payload end end
end

local TD    = load("game/ReplicatedStorage/Shared/Data/TowerData")
local SD    = load("game/ReplicatedStorage/Shared/Data/SpeedData")
local PDS   = load("SSS/EmberForge/Services/PlayerDataService")
local Tower = load("SSS/EmberForge/Services/TowerService")

Instance.new("Folder", workspace, "EmberWorld")
Tower.Init()
local I = Tower._internals
local S = I.state
expect(S.layout ~= nil and S.round ~= nil, "the tower is built")

local function player(id, trainedWalk)
    local store = { Name = "HumanoidRootPart", Anchored = false, Position = Vector3.new(0, 0, 0), AssemblyLinearVelocity = Vector3.new(0, 0, 0) }
    local root = setmetatable({}, { __index = store, __newindex = function(_, k, v) store[k] = v if k == "CFrame" then store.Position = v.Position end end })
    local hum = { Health = 100, WalkSpeed = trainedWalk or 16, UseJumpPower = true, JumpPower = 50, JumpHeight = 7.2 }
    local char = { FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return root end end,
        FindFirstChildOfClass = function(_, c) if c == "Humanoid" then return hum end end }
    local attrs = {}
    local p = { UserId = id, Name = "P" .. id, DisplayName = "P" .. id, Parent = true, Character = char,
        SetAttribute = function(_, k, v) attrs[k] = v end, GetAttribute = function(_, k) return attrs[k] end }
    table.insert(game:GetService("Players")._list, p)
    return p, root, hum
end
local function near(a, b) return math.abs(a - b) < 1e-6 end

-- a plain round, so only the level rules show; then give three levels a twist each
S.mutator = TD.Mutators[1]
for _, lv in ipairs(S.layout.levels) do lv.modifier = nil end
S.layout.levels[4].modifier = "dash"
S.layout.levels[6].modifier = "moon"
S.layout.levels[8].modifier = "heavy"
S.layout.levels[10].modifier = "dark"

print("== a plain round, a trained player")
local A, aRoot, aHum = player(201, 31)                -- (speed-trained: the tower still plays at the plain walk)
local d = PDS.Load(A)
d.PlayerLevel = 30
I.StartRun(A)
local rec = I.runs[201]
expect(rec ~= nil, "the climb starts")
expect(aHum.WalkSpeed == 31 and aHum.JumpPower == 50, "level 1 has no rule, so nothing is changed")
expect(A:GetAttribute("TowerRule") == nil, "and no rule is shown")

print("== a Dash level")
rec.run.hooks.onLevel(4, 20)
expect(A:GetAttribute("TowerRule") == "dash", "level 4 names its rule")
expect(near(aHum.WalkSpeed, SD.BASE_WALK * 1.3), "and you run 30% faster than the plain walk (" .. aHum.WalkSpeed .. ")")
expect(aHum.JumpPower == 50, "jumping is unchanged")
local ev = last("level")
expect(ev and ev.rule and ev.rule.id == "dash" and ev.rule.name == "Dash Level" and ev.rule.desc ~= nil, "the level event carries the rule for the banner")

print("== the next plain level puts it back")
rec.run.hooks.onLevel(5, 20)
expect(A:GetAttribute("TowerRule") == nil and near(aHum.WalkSpeed, SD.BASE_WALK), "level 5: no rule, the plain walk again (" .. aHum.WalkSpeed .. ")")
expect(last("level").rule == nil, "and the event has no rule")

print("== Low Gravity and Heavy Boots")
rec.run.hooks.onLevel(6, 20)
expect(near(aHum.JumpPower, 50 * math.sqrt(1.4)), "Low Gravity: the jump is higher (power " .. string.format("%.1f", aHum.JumpPower) .. ")")
expect(near(aHum.WalkSpeed, SD.BASE_WALK), "at the plain walk")
rec.run.hooks.onLevel(8, 20)
expect(near(aHum.JumpPower, 50 * math.sqrt(0.85)) and aHum.JumpPower < 50, "Heavy Boots: lower (power " .. string.format("%.1f", aHum.JumpPower) .. ")")

print("== Lights Out")
rec.run.hooks.onLevel(10, 20)
expect(A:GetAttribute("TowerRule") == "dark" and last("level").rule.dark == true, "level 10 is dark (the client dims the sky for the dark flag)")
expect(near(aHum.JumpPower, 50) and near(aHum.WalkSpeed, SD.BASE_WALK), "and nothing else changes")

print("== skipping into a level with a rule")
rec.run.highest = 3
d.TowerSkips = 1
I.runs[201].skips = 0
Tower.RequestSkip(A)
expect(rec.run.highest == 4 and A:GetAttribute("TowerRule") == "dash" and near(aHum.WalkSpeed, SD.BASE_WALK * 1.3), "a skip onto a Dash level applies it too")

print("== the climb ends: everything is put back")
I.EndRun(rec, "left", false)
expect(aHum.WalkSpeed == 31 and aHum.JumpPower == 50 and aHum.JumpHeight == 7.2, "the player's own speed and jump return (" .. aHum.WalkSpeed .. ")")
expect(A:GetAttribute("TowerRule") == nil and A:GetAttribute("TowerLevel") == nil, "and the rule is cleared")

print("== with the round's mutator on top")
S.mutator = TD.MutatorById.turbo
local B, bRoot, bHum = player(202, 16)
PDS.Load(B).PlayerLevel = 30
I.StartRun(B)
local recB = I.runs[202]
expect(near(bHum.WalkSpeed, 16 * 1.3), "Turbo alone: x1.3 (" .. bHum.WalkSpeed .. ")")
recB.run.hooks.onLevel(4, 20)
expect(near(bHum.WalkSpeed, 16 * 1.3 * 1.3), "Turbo and a Dash level multiply (" .. bHum.WalkSpeed .. ")")
expect(bHum.WalkSpeed <= TD.MAX_WALK, "but stay under the anti-cheat's limit")
S.mutator = TD.MutatorById.moon
recB.run.hooks.onLevel(8, 20)
expect(near(bHum.JumpPower, 50 * math.sqrt(1.35 * 0.85)), "Moon Jump and Heavy Boots cancel part-way (power " .. string.format("%.1f", bHum.JumpPower) .. ")")
I.EndRun(recB, "left", false)
expect(bHum.WalkSpeed == 16 and bHum.JumpPower == 50, "and all is put back")

print("== the maze is not the tower")
-- both are built 1500 studs up, on opposite sides of the world: a maze runner must not count as a climber (the tower's round change sends climbers home)
local MD = load("game/ReplicatedStorage/Shared/Data/MazeData")
expect(MD.BASE.y == TD.BASE.y, "(the maze and the tower share a height)")
local M1, mRoot = player(301)
mRoot.CFrame = CFrame.new(MD.BASE.x + 100, MD.BASE.y + 3, MD.BASE.z)
expect(not Tower.InTower(M1), "a player in the Hollow Maze is not in the Sky Tower")
local T1, tRoot = player(302)
tRoot.CFrame = CFrame.new(TD.BASE.x + 100, TD.BASE.y + 3, TD.BASE.z)
expect(Tower.InTower(T1), "a player in the Sky Tower is")
local H1, hRoot = player(303)
hRoot.CFrame = CFrame.new(0, 6, -60)
expect(not Tower.InTower(H1), "and a player at home is not")

print("== a tower that fails to build does not end the rounds")
local realTowerBuild = TowerArt.Build
local world = workspace:FindFirstChild("EmberWorld")
local oldRound = S.round
S.round.nextStart = os.time() - 1
TowerArt.Build = function() error("Script timeout: exhausted allowed execution time") end
local okAdvance = pcall(I.AdvanceRound, world, os.time())
expect(okAdvance, "a failed build is caught, not thrown at the round loop")
expect(S.round == oldRound, "the old round is put back")
TowerArt.Build = realTowerBuild
I.AdvanceRound(world, os.time())
expect(S.round == oldRound, "it waits a few seconds before trying again")
advance(6)
I.AdvanceRound(world, os.time())
expect(S.round ~= oldRound and S.round.nextStart > os.time() and S.layout ~= nil, "and then the new tower is built (round " .. tostring(S.round.index) .. ")")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
