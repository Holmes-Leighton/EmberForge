-- Next-goal line, confetti and the welcome-back screen.
QUIET = true
local NG = load("game/ReplicatedStorage/Shared/Modules/NextGoal")
local Celebrate = load("game/ReplicatedStorage/Shared/Modules/Celebrate")

print("== next goal follows the player's progress")
expect(NG.For({}):find("first Golem"), "no Golem yet: forge one")
expect(NG.For({ Golems = { { deployed = false } } }):find("Deploy"), "a Golem but none working: deploy it")
expect(NG.For({ Golems = { { deployed = true } }, Pending = { BasicOre = 4 } }):find("Collect"), "something waiting: collect it")
local early = NG.For({ Golems = { { deployed = true } }, PlayerLevel = 1, PlayerXP = 0, ForgeLevel = 1, ForgeXP = 0 })
expect(early:find("Level 2") and early:find("Pets") and early:find("XP to go"), "early game points at the next unlock (" .. early .. ")")
local forgeGoal = NG.For({ Golems = { { deployed = true } }, PlayerLevel = 50, PlayerXP = 1e9, ForgeLevel = 4, ForgeXP = 3600 })
expect(forgeGoal:find("Forge Level 5") or forgeGoal:find("Forge Level 6"), "with every player-level feature open it points at the Forge (" .. forgeGoal .. ")")
local maxed = NG.For({ Golems = { { deployed = true } }, PlayerLevel = 50, PlayerXP = 1e9, ForgeLevel = 10, ForgeXP = 1e9 })
expect(maxed:find("Ascend"), "at the top it points at Ascension (" .. maxed .. ")")

print("== confetti")
local ok = pcall(function() Celebrate.Burst({ count = 10 }); Celebrate.Craft(1); Celebrate.Craft(5) end)
expect(ok, "bursts run")
local holder = PlayerGui:FindFirstChild("Celebrate")
expect(holder and #holder:GetChildren() > 0, "confetti pieces were made")
local n = #holder:GetChildren()
Celebrate.Burst({ count = 1000 })
expect(#holder:GetChildren() - n <= 80, "never more than 80 pieces alive at once (" .. (#holder:GetChildren() - n) .. " added)")

print("== welcome back screen")
local Snapshot = { PlayerLevel = 1, ForgeLevel = 1, Golems = {}, Inventory = {}, Pending = {}, MasteryLevels = {}, SmeltQueue = {} }
local Remotes = installFakeRemotes({ GetPlayerData = function() return Snapshot end })
assert(runScriptFile("src/StarterGui/WelcomeBackBuilder.client.lua"))
local wb
for _, c in ipairs(PlayerGui:GetChildren()) do if c.Name == "WelcomeBack" then wb = c end end
expect(wb and wb.Enabled == false, "starts hidden")
fakeRemotes.WelcomeBack.OnClientEvent:Fire(3 * 3600, { BasicOre = 120, Coal = 30 }, 4, true)
expect(wb.Enabled == true, "opens when the server says they were away")
local text = wb:FindFirstChild("HaulText", true).Text
expect(text:find("120") and text:find("30"), "lists the haul (" .. tostring(text):gsub("\n", " | ") .. ")")
expect(wb:FindFirstChild("Note", true).Text:find("4 hours"), "explains when storage was the limit")
fakeRemotes.CollectResources.fired = {}
local btn = wb:FindFirstChild("CollectNow", true)
btn.MouseButton1Click:Fire()
expect(#fakeRemotes.CollectResources.fired == 1 and wb.Enabled == false, "Collect now banks it and closes")
wb.Enabled = false
fakeRemotes.WelcomeBack.OnClientEvent:Fire(600, {}, 4, false)
expect(wb.Enabled == false, "an empty haul shows nothing")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
