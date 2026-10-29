-- Game feel: sound, the lighting moods, and reward feedback (coins flying to the purse).
QUIET = true
task.delay = function(_, f) task.spawn(f) end       -- run "later" callbacks immediately in tests

local MoodData = load("game/ReplicatedStorage/Shared/Data/MoodData")
local AudioData = load("game/ReplicatedStorage/Shared/Data/AudioData")

print("== moods are complete")
local needed = { "ambient", "outdoor", "brightness", "exposure", "density", "offset", "haze", "atmColor", "atmDecay", "tint", "sat", "contrast", "bloomI", "bloomSize", "bloomThreshold" }
local count, bad = 0, {}
for name, m in pairs(MoodData.Moods) do
    count += 1
    for _, k in ipairs(needed) do
        if m[k] == nil then table.insert(bad, name .. "." .. k) end
    end
    for _, k in ipairs({ "ambient", "outdoor", "atmColor", "atmDecay", "tint" }) do
        local c = m[k]
        if c and (#c ~= 3 or c[1] < 0 or c[1] > 255 or c[2] < 0 or c[2] > 255 or c[3] < 0 or c[3] > 255) then table.insert(bad, name .. "." .. k .. " out of range") end
    end
end
expect(#bad == 0, "every mood has every field with valid colours (" .. table.concat(bad, ", ") .. ")")
expect(count >= 17, "hub, 6 caves, 6 tower moods and 5 maze moods exist (" .. count .. ")")
for _, z in ipairs(MoodData.CAVE_ORDER) do expect(MoodData.Moods[z] ~= nil, "cave mood " .. z) end
for _, z in ipairs(MoodData.TOWER_ZONES) do expect(MoodData.Moods["Tower" .. z] ~= nil, "tower zone mood " .. z) end
for s = 1, 5 do expect(MoodData.Moods[MoodData.MazeMood(s)] ~= nil, "maze section " .. s .. " mood") end
expect(MoodData.Moods.Hub.brightness > 1.5, "the hub is brighter than the old murky cavern (brightness 1)")

print("== the mood follows where you stand")
expect(MoodData.MoodAt(0, 0) == "Hub", "spawn is the hub")
expect(MoodData.MoodAt(1500, 0) == "Hub", "a forge far east is still the hub")
expect(MoodData.MoodAt(-350, 260) == "Ember" and MoodData.MoodAt(-210, 260) == "Stone" and MoodData.MoodAt(-70, 260) == "Frost"
    and MoodData.MoodAt(70, 260) == "Storm" and MoodData.MoodAt(210, 260) == "Void" and MoodData.MoodAt(350, 260) == "DeepForge", "each of the six caves has its own mood, in the world builder's order")
expect(MoodData.MoodAt(8100, 20) == "TowerLobby" and MoodData.MoodAt(-8100, 20) == "MazeStone", "the Tower and the Maze are far east and west")
expect(MoodData.TowerMood(1, 30) == "TowerStone" and MoodData.TowerMood(30, 30) == "TowerVoid", "the Tower starts in Stone and tops out in Void")
local seen = {}
for l = 1, 30 do local _, z = MoodData.TowerMood(l, 30); seen[z] = (seen[z] or 0) + 1 end
local even = true
for z = 1, 5 do if seen[z] ~= 6 then even = false end end
expect(even, "five zones of six levels")
expect(MoodData.MazeMood(1) == "MazeStone" and MoodData.MazeMood(5) == "MazeVoid" and MoodData.MazeMood(9) == "MazeVoid", "maze sections map to moods, clamped")

print("== LookController blends to a mood")
local Look = load("SPS/EmberForge/Controllers/LookController")
Look.Init()
expect(Look.Current() == "Hub", "starts on the hub look")
local lighting = game:GetService("Lighting")
expect(lighting.GlobalShadows == true, "real shadows are on")
expect(lighting:FindFirstChildOfClass("Atmosphere") and lighting:FindFirstChildOfClass("ColorCorrectionEffect") and lighting:FindFirstChildOfClass("BloomEffect"), "atmosphere, colour grade and bloom exist")
Look.SetMood("TowerFrost")
expect(Look.Current() == "TowerFrost", "a controller can pick the mood")
Look.SetMood(nil)
Look.Apply("Void")
expect(Look.Current() == "Void", "Apply switches mood")

print("== audio resolves")
expect(AudioData.Resolve("Click") ~= nil, "Click has a built-in fallback so it is never silent")
expect(AudioData.Resolve("MazeRoar") == nil, "a sound with no uploaded id and no fallback is silent, not an error")
expect(AudioData.Resolve("NoSuchSound") == nil, "unknown names are ignored")
expect(AudioData.LevelPitch(1, 30) == 1 and math.abs(AudioData.LevelPitch(30, 30) - 1.5) < 1e-9 and AudioData.LevelPitch(15, 30) > 1 and AudioData.LevelPitch(15, 30) < 1.5, "the tower ding rises from x1 to x1.5")
local names = { "Click", "Notify", "Error", "LevelUp", "Achievement", "Collect", "CoinPop", "RewardChest", "Deploy", "Craft", "CraftRare", "Neon", "Smelt", "TradeDone",
    "TowerStart", "TowerLevel", "TowerFall", "TowerBounce", "TowerSummit", "MazeRoar", "MazeFootstep", "MazeHeartbeat", "MazeCaught", "MazeEscape", "MazePickup",
    "MazeHide", "MazeFreeze", "MazeStun", "MazeLight", "MazeThunder", "AmbientForge", "Music", "MusicTower", "MusicMaze" }
for _, n in ipairs(names) do expect(AudioData.Sounds[n] ~= nil, "AudioData lists " .. n) end

print("== SoundController")
local Sound = load("SPS/EmberForge/Controllers/SoundController")
Sound.Log = {}
Sound.Play("Click")
Sound.Play("Click")
expect(#Sound.Log == 1, "the same sound twice in a moment is played once (a run of clicks must not buzz)")
Sound.Play("TowerLevel", { pitch = 1.25, volume = 0.5 })
local last = Sound.Log[#Sound.Log]
expect(last.name == "TowerLevel" and last.pitch == 1.25 and math.abs(last.volume - 0.25) < 1e-9, "pitch and volume are applied")
expect(Sound.Play("NoSuchSound") == nil, "an unknown sound is ignored")
Sound.SetScene("Tower")
expect(Sound.Scene() == "Tower", "scene switches")
Sound.SetScene("Maze")
expect(Sound.Scene() == "Maze", "scene switches again")
Sound.SetScene("Hub")
expect(Sound.Scenes.Hub[1] == "Music" and Sound.Scenes.Tower[1] == "MusicTower" and Sound.Scenes.Maze[1] == "MusicMaze", "each scene has its own music")

print("== RewardFx")
local Fx = load("SPS/EmberForge/Controllers/RewardFx")
expect(Fx.CoinCount(0) == 0 and Fx.CoinCount(1) == 1, "no coins for nothing, one for one")
expect(Fx.CoinCount(10) < Fx.CoinCount(10000) and Fx.CoinCount(1e12) == Fx.MAX_COINS, "more coins for a bigger payout, never more than the cap")
expect(Fx.PopPitch(1, 8) == 1 and math.abs(Fx.PopPitch(8, 8) - 1.5) < 1e-9 and Fx.PopPitch(1, 1) == 1, "pops rise in pitch")

-- run a tween's whole chain at once so coins "land"
local ts = game:GetService("TweenService")
ts.Create = function()
    local cbs = {}
    local t = { Completed = { Connect = function(_, f) table.insert(cbs, f) end } }
    function t:Play() for _, f in ipairs(cbs) do f() end end
    return t
end
local pops = {}
Fx.Sound = { Play = function(n, o) table.insert(pops, { n = n, pitch = o and o.pitch }) end }
assert(runScriptFile("src/StarterGui/HUDBuilder.client.lua"))
local hud
for _, c in ipairs(PlayerGui:GetChildren()) do if c.Name == "HUD" then hud = c end end
expect(hud ~= nil, "HUD built")
local before = Fx.Flown
local realWait = task.wait
task.wait = function(t) return t or 0 end          -- (the mock's wait would park the count-up forever)
local sent = Fx.CoinBurst(500, hud, 100, 600)
task.wait = realWait
expect(sent == Fx.CoinCount(500), "one coin sprite per coin counted (" .. sent .. ")")
expect(Fx.Flown - before == sent, "every coin landed in the purse")
expect(#pops == sent and pops[1].n == "CoinPop" and pops[#pops].pitch > pops[1].pitch, "each landing pops, rising in pitch")
expect(hud:FindFirstChild("CoinsLabel", true).Text == "600", "the number counted up to the new total")
expect(Fx.CoinBurst(0, hud) == 0, "nothing to fly for a zero payout")

print("== HUD bursts on a coin gain only")
local Snapshot = { PlayerLevel = 1, ForgeLevel = 1, EmberCoins = 100, Golems = {}, Inventory = {}, Pending = {}, MasteryLevels = {}, SmeltQueue = {} }
installFakeRemotes({ GetPlayerData = function() return Snapshot end })
local HUD = load("SPS/EmberForge/Controllers/HUDController")
HUD.Init(Snapshot)
local flown = Fx.Flown
HUD.Refresh(Snapshot)
expect(Fx.Flown == flown, "the first refresh shows the coins without a burst")
Snapshot.EmberCoins = 50
HUD.Refresh(Snapshot)
expect(Fx.Flown == flown, "spending coins is no burst")
Snapshot.EmberCoins = 5000
HUD.Refresh(Snapshot)
expect(Fx.Flown > flown, "earning coins sends a burst to the purse")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
