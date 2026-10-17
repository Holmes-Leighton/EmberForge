-- A phone (touch only, short screen): the mined-items list is hidden and the event banner is a slim strip that stays out of the way.
QUIET = true
workspace.CurrentCamera.ViewportSize = Vector2.new(640, 360)
local uis = game:GetService("UserInputService")
uis.TouchEnabled, uis.KeyboardEnabled = true, false
local Snapshot = { PlayerLevel = 3, PlayerXP = 500, ForgeLevel = 3, ForgeXP = 1600, EmberCoins = 500, GolemSlots = 3, EffectiveGolemSlots = 3,
    Golems = {}, Inventory = {}, Pending = {}, Blueprints = {}, MasteryLevels = {}, SmeltQueue = {}, SpeedUps = 0, StorageTier = 0, SeasonPassTier = 0,
    OwnedCosmetics = {}, Titles = {}, Equipped = {}, Settings = {}, DailyChallenges = {}, WeeklyChallenges = {}, Achievements = {}, AvailableEventBlueprints = {} }
installFakeRemotes({ GetPlayerData = function() return Snapshot end })
local ScreenMode = load("game/ReplicatedStorage/Shared/Modules/ScreenMode")

print("== the screen is recognised")
expect(ScreenMode.Compact() == true, "touch-only 640x360 is compact")
uis.TouchEnabled, uis.KeyboardEnabled = false, true
workspace.CurrentCamera.ViewportSize = Vector2.new(1920, 1080)
expect(ScreenMode.Compact() == false, "a desktop window is not")
uis.TouchEnabled, uis.KeyboardEnabled = true, false
workspace.CurrentCamera.ViewportSize = Vector2.new(640, 360)

print("== event banner")
assert(runScriptFile("src/StarterGui/EventBannerBuilder.client.lua"))
local eb
for _, c in ipairs(PlayerGui:GetChildren()) do if c.Name == "EventBanner" then eb = c end end
local pill = eb:FindFirstChild("Pill")
expect(pill.Size.Y.Offset <= 30, "the banner is one slim line (" .. pill.Size.Y.Offset .. " px high)")
expect(pill.Size.X.Offset <= 340 and pill.Size.X.Offset >= 200, "and no wider than the middle of a phone screen (" .. pill.Size.X.Offset .. " px)")
expect(eb.IgnoreGuiInset == true and pill.Position.Y.Offset <= 6, "it sits in the top bar, not over the view")
expect(not eb:FindFirstChild("Blurb", true).Visible and not eb:FindFirstChild("Sub", true).Visible, "the description lines are dropped")
local scales = 0
for _, k in ipairs(pill:GetChildren()) do if k.ClassName == "UIScale" then scales += 1 expect(k.Scale == 1, "and it is shown at full size") end end

print("== mined-items list")
assert(runScriptFile("src/StarterGui/HUDBuilder.client.lua"))
local HUDController = load("SPS/EmberForge/Controllers/HUDController")
HUDController.Init(Snapshot)
local hud
for _, c in ipairs(PlayerGui:GetChildren()) do if c.Name == "HUD" then hud = c end end
local many = {}
for i = 1, 9 do many["Mat" .. i] = i * 10 end
HUDController.SetPending(many)
expect(hud:FindFirstChild("PendingFrame", true) == nil and hud:FindFirstChild("CollectButton", true) == nil, "there is no pending list or Collect button on a phone (the server banks it)")

print("== on a desktop there is no list either")
uis.TouchEnabled, uis.KeyboardEnabled = false, true
workspace.CurrentCamera.ViewportSize = Vector2.new(1920, 1080)
HUDController.SetPending(many)
expect(hud:FindFirstChild("PendingFrame", true) == nil and hud:FindFirstChild("PendingLabel", true) == nil, "the mined-items list is gone (it is banked by itself)")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
