-- The first screen: a new player sees little and more appears as they level; the tutorial is three steps and pays its gift on the first haul.
QUIET = true
task.delay = function(_, f) task.spawn(f) end

local FG = load("game/ReplicatedStorage/Shared/Data/FeatureGates")

print("== the player card grows with the player")
local r1 = FG.CardRows({ PlayerLevel = 1 })
expect(r1.MasteryRow == false and r1.SmeltRow == false and r1.SpeedRow == false, "level 1: no Mastery, Smelter or Speed rows")
local r2 = FG.CardRows({ PlayerLevel = 2 })
expect(r2.SmeltRow and r2.SpeedRow and not r2.MasteryRow, "level 2: Smelter and Speed appear")
expect(FG.CardRows({ PlayerLevel = 3 }).MasteryRow, "level 3: Mastery appears")
expect(FG.CardRows({ PlayerLevel = 1, SmeltQueue = { {} } }).SmeltRow, "a running smelt shows the Smelter row at once")
expect(FG.CardRows({ PlayerLevel = 1, SpeedLevel = 1 }).SpeedRow, "a trained speed shows the Speed row at once")
expect(FG.CardRows(nil).MasteryRow == false, "no data is a level-1 player")

print("== the side column reveals itself")
expect(not FG.Revealed("SeasonButton", { PlayerLevel = 1 }) and FG.Revealed("SeasonButton", { PlayerLevel = 2 }), "Season at level 2")
expect(not FG.Revealed("StyleButton", { PlayerLevel = 1 }) and FG.Revealed("StyleButton", { PlayerLevel = 2 }), "Style at level 2")
expect(not FG.Revealed("LeaderboardBtn", { PlayerLevel = 2 }) and FG.Revealed("LeaderboardBtn", { PlayerLevel = 3 }), "Leaders at level 3")
expect(FG.Revealed("RewardsButton", { PlayerLevel = 1 }) and FG.Revealed("HomeButton", { PlayerLevel = 1 }), "Rewards and My Forge are there from the start")

print("== the HUD follows")
local Snapshot = { PlayerLevel = 1, ForgeLevel = 1, EmberCoins = 200, Golems = {}, Inventory = {}, Pending = {}, MasteryLevels = {}, SmeltQueue = {} }
installFakeRemotes({ GetPlayerData = function() return Snapshot end })
assert(runScriptFile("src/StarterGui/HUDBuilder.client.lua"))
local HUD = load("SPS/EmberForge/Controllers/HUDController")
HUD.Init(Snapshot)
local hud
for _, c in ipairs(PlayerGui:GetChildren()) do if c.Name == "HUD" then hud = c end end
local card = hud:FindFirstChild("MainFrame")
local function row(n) return card:FindFirstChild(n) end
expect(row("MasteryRow").Visible == false and row("SmeltRow").Visible == false and row("SpeedRow").Visible == false, "a new player's card hides Mastery, Smelter and Speed")
expect(row("ForgeRow").Visible and row("GolemRow").Visible and row("GoalRow").Visible, "and keeps Forge, Golems and the next goal")
local shortH = card.Size.Y.Offset
expect(shortH < 330, "so the card is short (" .. shortH .. " px, was 396)")
local ordered = row("ForgeRow").Position.Y.Offset < row("GolemRow").Position.Y.Offset and row("GolemRow").Position.Y.Offset < row("GoalRow").Position.Y.Offset
expect(ordered and row("GolemRow").Position.Y.Offset == 122 + 30 + 6, "the rows close up with no gap where the hidden ones were")
Snapshot.PlayerLevel = 3
HUD.Refresh(Snapshot)
expect(row("MasteryRow").Visible and row("SmeltRow").Visible and row("SpeedRow").Visible, "at level 3 every row is back")
expect(card.Size.Y.Offset == 396, "and the card is its full size (" .. card.Size.Y.Offset .. ")")
expect(row("GoalRow").Position.Y.Offset == 338, "with the goal row where it always was")

print("== the tutorial is three steps")
local Tut = load("SPS/EmberForge/Controllers/TutorialController")
local newPlayer = { Golems = {}, TutorialRewarded = false }
Tut.Init(newPlayer)
local gui
for _, c in ipairs(PlayerGui:GetChildren()) do if c.Name == "TutorialGui" then gui = c end end
local function text(name) local o = gui:FindFirstChild(name, true) return o and o.Text or "" end
expect(text("Title"):find("Step 1/3") ~= nil, "it starts at step 1 of 3 (" .. text("Title") .. ")")
local guideText = ""
for _, d in ipairs(gui:GetDescendants()) do if type(d.Text) == "string" and d.Text:find("Welcome to EmberForge") then guideText = d.Text end end
expect(guideText ~= "", "the welcome is one short page")
local dots = 0
for _, d in ipairs(gui:GetDescendants()) do if d.Name == "Dot" or (d.Name or ""):find("^Dot") then if d.Visible then dots += 1 end end end
expect(dots <= 1, "with a single page dot (" .. dots .. ")")

fakeRemotes.ResourcesCollected.OnClientEvent:Fire({ BasicOre = 10, Coal = 5 }, 0)
expect(text("Title"):find("Step 2/3") ~= nil, "ten ore and five coal from the pad move it on (" .. text("Title") .. ")")
fakeRemotes.ClaimTutorialReward.fired = {}
fakeRemotes.GolemCrafted.OnClientEvent:Fire({ id = "g", tier = 1 })
expect(text("Title"):find("Step 3/3") ~= nil, "forging a Golem is step 3 (" .. text("Title") .. ")")
expect(#fakeRemotes.ClaimTutorialReward.fired == 0, "no gift yet")
fakeRemotes.GolemDeployed.OnClientEvent:Fire(true)
expect(gui:FindFirstChild("Tracker").Visible == false, "deploying finishes the tutorial")
expect(#fakeRemotes.ClaimTutorialReward.fired == 0, "the gift waits for the first haul (the server checks the Golem has really banked something)")
fakeRemotes.ResourcesCollected.OnClientEvent:Fire({ BasicOre = 3 }, -2)
expect(#fakeRemotes.ClaimTutorialReward.fired == 1, "the first haul the Golem banks by itself asks for the welcome gift")
fakeRemotes.ResourcesCollected.OnClientEvent:Fire({ BasicOre = 3 }, -2)
expect(#fakeRemotes.ClaimTutorialReward.fired == 1, "and only once")

print("== nothing about Collect is left in the tutorial")
local src = SOURCES["src/Client/Controllers/TutorialController.lua"]
expect(not src:find("press ⛏ Collect", 1, true) and not src:find("Collect resources", 1, true), "the old Collect step is gone")

print("== a returning player who never got the gift still gets it")
fakeRemotes.ClaimTutorialReward.fired = {}
Tut.Init({ Golems = { { id = "x", deployed = true } }, TutorialRewarded = false })
fakeRemotes.ResourcesCollected.OnClientEvent:Fire({ Coal = 2 }, -2)
expect(#fakeRemotes.ClaimTutorialReward.fired >= 1, "their next banked haul asks for it")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
