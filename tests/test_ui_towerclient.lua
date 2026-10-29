-- The Sky Tower on the client, driven with the server's events: sound, music scene, the zone strip and sky, mutators, zone chests and the skip button.
QUIET = true
task.delay = function(_, f) task.spawn(f) end       -- run "later" callbacks immediately in tests
local realGet = game.GetService
rawset(game, "GetService", function(_, name)
    if name == "Debris" then return { AddItem = function() end } end
    return realGet(game, name)
end)

local Remotes = installFakeRemotes({})
local Look   = load("SPS/EmberForge/Controllers/LookController")
local Sound  = load("SPS/EmberForge/Controllers/SoundController")
local Tower  = load("SPS/EmberForge/Controllers/TowerController")
local TD     = load("game/ReplicatedStorage/Shared/Data/TowerData")
Look.Init()
Tower.Init()
local hud
for _, c in ipairs(PlayerGui:GetChildren()) do if c.Name == "TowerHUD" then hud = c end end
expect(hud ~= nil and hud.Enabled == false, "the tower HUD exists and starts hidden")

local function findByText(root, text)
    for _, d in ipairs(root:GetDescendants()) do
        if type(d.Text) == "string" and d.Text:find(text, 1, true) then return d end
    end
end
local function played(name)
    for _, e in ipairs(Sound.Log) do if e.name == name then return e end end
end
local function step() services_RenderStepped = nil; game:GetService("RunService").RenderStepped:Fire() end

print("== starting a climb")
Sound.Log = {}
LocalPlayerMock:SetAttribute("TowerLevel", 1)
LocalPlayerMock:SetAttribute("TowerRespawns", 0)
fakeRemotes.TowerEvent.OnClientEvent:Fire("start", { total = 30, roundEnds = os.time() + 600, dailyTarget = 10, dailyDone = false,
    mutator = { id = "moon", name = "Moon Jump", desc = "Everyone jumps 35% higher." }, skips = 3, skipOwned = 0 })
expect(hud.Enabled == true, "the HUD appears")
expect(Sound.Scene() == "Tower", "the music changes to the tower's")
expect(played("TowerStart") ~= nil, "a whoosh plays as you start")
expect(findByText(hud, "Moon Jump") ~= nil, "the round's mutator is announced (Moon Jump)")
step()
local strip = hud:FindFirstChild("ZoneLabel", true)
expect(strip and strip.Text:find("ZONE 1") and strip.Text:find("GRANITE STEPS") and strip.Text:find("MOON JUMP"), "the strip shows the zone and the mutator (" .. tostring(strip and strip.Text) .. ")")
expect(Look.Current() == "TowerStone", "the sky is the Stone zone's")

print("== climbing into the next zone")
LocalPlayerMock:SetAttribute("TowerLevel", 7)
step()
expect(strip.Text:find("ZONE 2") and strip.Text:find("EMBER ASCENT"), "level 7 is zone 2 (" .. strip.Text .. ")")
expect(Look.Current() == "TowerEmber", "and the sky turns to Ember")
Sound.Log = {}
fakeRemotes.TowerEvent.OnClientEvent:Fire("level", { level = 7, total = 30, coins = 64, xp = 22, zone = 2, zoneStart = true,
    zoneClear = { zone = 1, name = "Granite Steps", coins = 48, material = { id = "GraniteShard", qty = 14 } } })
local ding = played("TowerLevel")
expect(ding ~= nil and ding.pitch > 1, "a ding that rises with height plays (x" .. tostring(ding and ding.pitch) .. ")")
expect(played("RewardChest") ~= nil, "clearing a zone opens the chest with its sound")
expect(findByText(hud, "ZONE CLEARED") ~= nil, "and says so")
Sound.Log = {}
Sound.ResetThrottle()
fakeRemotes.TowerEvent.OnClientEvent:Fire("level", { level = 30, total = 30, coins = 10, xp = 5, zone = 5, boss = true })
local top = played("TowerLevel")
expect(top and top.pitch > 1.4, "the top level's ding is a fifth higher (x" .. tostring(top and top.pitch) .. ")")
expect(findByText(hud, "BOSS LEVEL") ~= nil, "a boss level is announced")

print("== falling and the summit")
Sound.Log = {}
fakeRemotes.TowerEvent.OnClientEvent:Fire("respawn", { reason = "fell", level = 7, penalty = 3, dir = 1 })
expect(played("TowerFall") ~= nil, "a fall has its own sound")
expect(findByText(hud, "You fell") ~= nil, "and a banner")
Sound.Log = {}
Sound.ResetThrottle()
fakeRemotes.TowerEvent.OnClientEvent:Fire("summit", { seconds = 300, chest = { coins = 100 } })
expect(played("TowerSummit") ~= nil and played("RewardChest") ~= nil, "the summit has its fanfare and chest")

print("== the skip button")
local skip = hud:FindFirstChild("TowerSkipButton", true)
LocalPlayerMock:SetAttribute("TowerLevel", 5)
step()
expect(skip.Visible == true, "Skip level shows mid-climb while skips are left")
fakeRemotes.TowerSkip.fired = {}
skip.MouseButton1Click:Fire()
expect(#fakeRemotes.TowerSkip.fired == 1, "pressing it asks the server to skip")
fakeRemotes.TowerEvent.OnClientEvent:Fire("skipped", { level = 6, left = 2 })
expect(findByText(hud, "SKIPPED TO LEVEL 6") ~= nil, "the skip is announced")
LocalPlayerMock:SetAttribute("TowerLevel", 30)
step()
expect(skip.Visible == false, "no Skip on the last level")
fakeRemotes.TowerEvent.OnClientEvent:Fire("skipped", { level = 31, left = 0 })
LocalPlayerMock:SetAttribute("TowerLevel", 8)
step()
expect(skip.Visible == false, "and none once the round's skips are used")

print("== a foggy round")
fakeRemotes.TowerEvent.OnClientEvent:Fire("abandon", { reason = "left" })
fakeRemotes.TowerEvent.OnClientEvent:Fire("start", { total = 30, roundEnds = os.time() + 600, mutator = { id = "fog", name = "Foggy Peaks", desc = "Thick fog.", fog = true }, skips = 3 })
LocalPlayerMock:SetAttribute("TowerLevel", 1)
step()
expect(Look.Current() == "TowerFog", "Foggy Peaks swaps the sky for fog")
LocalPlayerMock:SetAttribute("TowerLevel", 13)
step()
expect(Look.Current() == "TowerFog", "and it stays foggy in every zone")

print("== after a fall you face the way the level runs")
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Custom
cam.CFrame = CFrame.new(0, 0, 0)
fakeRemotes.TowerEvent.OnClientEvent:Fire("respawn", { reason = "fell", level = 7, penalty = 3, dir = -1, x = 500, y = 80, z = 20 })
expect(cam.CFrame.Position.X == 514 and cam.CFrame.Position.Y == 87, "a level that runs west puts the camera east of the respawn point, behind you (x = " .. tostring(cam.CFrame.Position.X) .. ")")
fakeRemotes.TowerEvent.OnClientEvent:Fire("respawn", { reason = "lava", level = 8, penalty = 3, dir = 1, x = 500, y = 80, z = 20 })
expect(cam.CFrame.Position.X == 486, "a level that runs east puts it west of the point (x = " .. tostring(cam.CFrame.Position.X) .. ")")
cam.CFrame = CFrame.new(0, 0, 0)
LocalPlayerMock.Character = { FindFirstChild = function() return { Position = Vector3.new(7, 8, 9) } end, FindFirstChildOfClass = function() return nil end }
fakeRemotes.TowerEvent.OnClientEvent:Fire("respawn", { reason = "fell", level = 9, penalty = 3, dir = -1 })
expect(cam.CFrame.Position.X == 21, "an old-style event with no point still turns the camera, from where you stand (x = " .. tostring(cam.CFrame.Position.X) .. ")")
LocalPlayerMock.Character = nil
-- the character itself is turned too, but only once it has reached the respawn point
local turned = 0
local nearRoot = setmetatable({ Position = Vector3.new(500, 80, 21) }, { __newindex = function(t, k, v) if k == "CFrame" then turned += 1 end rawset(t, k, v) end })
LocalPlayerMock.Character = { FindFirstChild = function() return nearRoot end, FindFirstChildOfClass = function() return nil end }
fakeRemotes.TowerEvent.OnClientEvent:Fire("respawn", { reason = "burned", level = 5, penalty = 3, dir = -1, x = 500, y = 80, z = 20 })
expect(turned >= 1, "a character that has arrived at the respawn point is turned to face the course (" .. turned .. " times, a yellow-strip respawn)")
turned = 0
nearRoot.Position = Vector3.new(500, 40, 20)                              -- (still down where it fell)
fakeRemotes.TowerEvent.OnClientEvent:Fire("respawn", { reason = "burned", level = 5, penalty = 3, dir = -1, x = 500, y = 80, z = 20 })
expect(turned == 0, "but one still far away is left alone until it gets there")
LocalPlayerMock.Character = nil
cam.CameraType = Enum.CameraType.Scriptable
cam.CFrame = CFrame.new(1, 2, 3)
fakeRemotes.TowerEvent.OnClientEvent:Fire("respawn", { reason = "fell", level = 7, penalty = 3, dir = 1, x = 500, y = 80, z = 20 })
expect(cam.CFrame.Position.X == 1, "and a camera some other script is driving is left alone")
local svc = SOURCES["src/Server/Services/TowerService.lua"]
expect(svc:find("x = target.X, y = target.Y, z = target.Z", 1, true) ~= nil, "the server sends the exact respawn point")

print("== leaving")
fakeRemotes.TowerEvent.OnClientEvent:Fire("abandon", { reason = "left" })
expect(hud.Enabled == false, "the HUD goes away")
expect(Sound.Scene() == "Hub", "the hub music returns")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
