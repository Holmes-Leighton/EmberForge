-- The Hollow Maze on the client, driven with the server's events: sound, music scene, mood per section, items, hiding, caught, escape and the Maze Golem piece cards.
QUIET = true
NumberSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }      -- (the mock has no keypoints)
task.delay = function(_, f) task.spawn(f) end
local realGet = game.GetService
rawset(game, "GetService", function(_, name)
    if name == "Debris" then return { AddItem = function() end } end
    return realGet(game, name)
end)

installFakeRemotes({})
local Look  = load("SPS/EmberForge/Controllers/LookController")
local Sound = load("SPS/EmberForge/Controllers/SoundController")
local Maze  = load("SPS/EmberForge/Controllers/MazeController")
local MD    = load("game/ReplicatedStorage/Shared/Data/MazeData")
Look.Init()
Maze.Init()
local hud
for _, c in ipairs(PlayerGui:GetChildren()) do if c.Name == "MazeHUD" then hud = c end end
expect(hud ~= nil and hud.Enabled == false, "the maze HUD exists and starts hidden")

local function findByText(root, text)
    for _, d in ipairs(root:GetDescendants()) do
        if type(d.Text) == "string" and d.Text:find(text, 1, true) then return d end
    end
end
local function played(name)
    for _, e in ipairs(Sound.Log) do if e.name == name then return e end end
end
local fire = function(kind, p) fakeRemotes.MazeEvent.OnClientEvent:Fire(kind, p) end
local now = 1000
local function step() now += 0.1 Maze._Update(0.1, now) end

print("== a run begins")
Sound.Log = {}
LocalPlayerMock:SetAttribute("MazeSection", 0)
fire("start", { hideMax = 8, dailyTarget = 3, dailyDone = false })
expect(hud.Enabled == true and Sound.Scene() == "Maze", "the HUD appears and the music changes to the maze's")
step()
expect(Look.Current() == "MazeStone", "the lobby is lit like the first section")
Sound.Log = {}
fire("wake", {})
expect(played("MazeRoar") ~= nil, "the zombie's waking has its roar")
expect(findByText(hud, "WAKES") ~= nil, "and a banner")

print("== the light follows the section")
LocalPlayerMock:SetAttribute("MazeSection", 3)
step()
expect(Look.Current() == "MazeFrost", "section 3 is lit Frost")
LocalPlayerMock:SetAttribute("MazeSection", 5)
step()
expect(Look.Current() == "MazeVoid", "section 5 is lit Void")
Sound.Log = {}
Sound.ResetThrottle()
fire("section", { section = 2, name = "Ember", coins = 40, xp = 20 })
local ding = played("TowerLevel")
expect(ding ~= nil, "clearing a section dings")

print("== lightning in the Storm section")
LocalPlayerMock:SetAttribute("MazeSection", 4)
Sound.Log = {}
now += 100
step()
expect(played("MazeThunder") ~= nil, "the Storm section has thunder")

print("== items")
local btn = hud:FindFirstChild("MazeItemButton", true)
expect(btn.Visible == false, "no item button with empty hands")
Sound.Log = {}
Sound.ResetThrottle()
fire("pickup", { item = "freeze", name = "Frost Snap", desc = "Slows the Zombie Golem to 40% for 6 seconds." })
LocalPlayerMock:SetAttribute("MazeItem", "freeze")
step()
expect(played("MazePickup") ~= nil, "picking one up has a sound")
expect(findByText(hud, "Frost Snap") ~= nil, "and a banner saying what it is")
expect(btn.Visible == true and btn.Text:find("Frost Snap") and btn.Text:find("%[R%]"), "the button names it and its hotkey (" .. tostring(btn.Text) .. ")")
fakeRemotes.MazeUseItem.fired = {}
btn.MouseButton1Click:Fire()
expect(#fakeRemotes.MazeUseItem.fired == 1, "pressing it asks the server to use it")
local keyHandler = nil
local UIS = game:GetService("UserInputService")
UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.R }, false)
expect(#fakeRemotes.MazeUseItem.fired == 2, "so does the R key")
Sound.Log = {}
Sound.ResetThrottle()
fire("itemused", { kind = "freeze", seconds = 6 })
expect(played("MazeFreeze") ~= nil, "Frost Snap has an icy sound")
for kind, snd in pairs({ stun = "MazeStun", flare = "MazeLight", cloak = "MazeHide" }) do
    Sound.Log = {}
    Sound.ResetThrottle()
    fire("itemused", { kind = kind })
    expect(played(snd) ~= nil, kind .. " plays " .. snd)
end
LocalPlayerMock:SetAttribute("MazeItem", nil)
step()
expect(btn.Visible == false, "the button goes once the item is used")

print("== hiding")
local hideLbl = hud:FindFirstChild("MazeHideLabel", true)
expect(hideLbl.Visible == false, "nothing shown when not hiding")
Sound.Log = {}
Sound.ResetThrottle()
fire("hidden", { seconds = 8 })
LocalPlayerMock:SetAttribute("MazeHidden", true)
step()
expect(played("MazeHide") ~= nil, "climbing in is quiet but audible to you")
expect(hideLbl.Visible == true and hideLbl.Text:find("HIDDEN"), "a countdown shows (" .. tostring(hideLbl.Text) .. ")")
fire("unhidden", {})
LocalPlayerMock:SetAttribute("MazeHidden", nil)
step()
expect(hideLbl.Visible == false, "and goes when you climb out")

print("== the Maze Golem chase")
local function cardText()
    local all = {}
    for _, d in ipairs(hud:GetDescendants()) do if type(d.Text) == "string" then all[#all + 1] = d.Text end end
    return table.concat(all, " | ")
end
Sound.Log = {}
Sound.ResetThrottle()
fire("section", { section = 3, name = "Frost", coins = 60, xp = 30,
    piece = { id = "MazePick", name = "Maze Golem Pickaxe", have = 1, need = MD.PIECE_NEED, total = 1, goal = MD.PIECE_NEED * 5, firstBlueprint = true } })
for _ = 1, 3 do step() end
expect(played("RewardChest") ~= nil, "finding a piece opens the chest sound")
expect(cardText():find("PICKAXE FOUND") ~= nil, "and shows its card")
expect(cardText():find("set 1 / 30") ~= nil, "which shows progress towards the whole set (" .. tostring(cardText():match("set %d+ / %d+")) .. ")")
fire("start", { hideMax = 8 })                                    -- (a new run clears the card stack; cards expire on the real clock)
fire("section", { section = 4, name = "Storm", coins = 80, xp = 30,
    piece = { id = "MazeHeart", name = "Maze Golem Heart", have = 1, need = MD.PIECE_NEED, total = 3, goal = 30, milestone = { at = 3, coins = 400, items = {} } } })
for _ = 1, 6 do step() end
expect(cardText():find("MAZE CACHE") ~= nil, "a cache card announces a milestone")

print("== caught, escape and leaving")
Sound.Log = {}
Sound.ResetThrottle()
fire("caught", {})
expect(played("MazeCaught") ~= nil, "being caught has its own sound")
Sound.Log = {}
Sound.ResetThrottle()
fire("escape", { seconds = 100, chest = { coins = 300 } })
expect(played("MazeEscape") ~= nil and played("RewardChest") ~= nil, "escaping has its fanfare and chest")
fire("roundover", { best = 5, coins = 100, xp = 50, materials = {}, escaped = { seconds = 100 } })
expect(hud.Enabled == false and Sound.Scene() == "Hub", "leaving closes the HUD and brings the hub music back")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
