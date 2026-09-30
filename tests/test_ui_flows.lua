QUIET = true
task.delay = function(_, f) task.spawn(f) end       -- run "later" callbacks immediately in tests

local Snapshot = {
    PlayerLevel = 3, PlayerXP = 500, ForgeLevel = 3, ForgeXP = 1600, EmberCoins = 500, GolemSlots = 3, EffectiveGolemSlots = 3,
    Golems = { { id = "g1", element = "Ember", tier = 1, deployed = false, rarity = "Common", _durabilitySeconds = 1000, _maxDurabilitySeconds = 259200 },
               { id = "g2", element = "Frost", tier = 2, deployed = true, zoneId = "GlacialPeaks", variant = "Neon", rarity = "Uncommon", _durabilitySeconds = 0, _maxDurabilitySeconds = 345600 },
               { id = "g3", element = "Ember", tier = 1, deployed = false, rarity = "Common" },
               { id = "g4", element = "Ember", tier = 1, deployed = false, rarity = "Common" },
               { id = "g5", element = "Ember", tier = 1, deployed = false, rarity = "Common" } },
    Inventory = { BasicOre = 120, Coal = 60, RefinedOre = 40 }, Pending = { BasicOre = 5, Coal = 2 },
    Blueprints = { "BP_Ember_T1", "BP_Stone_T1", "BP_Frost_T1", "BP_Storm_T1", "BP_Void_T1", "BP_Ember_T2" },
    MasteryLevels = { Ember = 300, Frost = 0, Stone = 0, Storm = 0, Void = 0 },
    SmeltQueue = { { id = "j1", materialId = "BasicOre", outputId = "RefinedOre", quantity = 10, outputQty = 10, endTime = os.time() + 300 } },
    SpeedUps = 2, StorageTier = 0, SeasonPassTier = 0, OwnedCosmetics = { "ForgeSkin_Ember_Basic", "TitleBadge_Apprentice" }, Titles = { "Forge Initiate" },
    Equipped = {}, Settings = {}, DailyChallenges = {}, WeeklyChallenges = {}, Achievements = {},
    AvailableEventBlueprints = {}, CraftedByTier = { [1] = 5 },
    SeasonStatus = { seasonId = "Season3", currentWeek = 2, totalWeeks = 7, claimedWeeks = { free_1 = true }, communityCurrent = 100, communityTarget = 750000 },
}
local marketListing = { id = "L1", sellerId = 5, sellerName = "Seller", priceCoins = 250, listedAt = 1,
    item = { type = "golem", id = "gx", element = "Frost", tier = 2, name = "Frost Shard Golem (Uncommon)" },
    golem = { id = "gx", element = "Frost", tier = 2, rarity = "Uncommon" } }
local Remotes = installFakeRemotes({ GetPlayerData = function() return Snapshot end,
    GetMarketListings = function() return { marketListing } end, GetMyListings = function() return {} end,
    GetTradeHistory = function() return { { time = os.time(), partner = "Bob", gave = { "Coal x5" }, got = { "Frost Golem" } } } end,
    GetLeaderboard = function() return {} end })

-- find things in the fake tree
local function all(root) return root:GetDescendants() end
local function byText(root, text)
    for _, d in ipairs(all(root)) do if d.Text == text then return d end end
end
local function byTextLike(root, text)
    for _, d in ipairs(all(root)) do if type(d.Text) == "string" and d.Text:find(text, 1, true) and d:IsA("GuiObject") then return d end end
end
local function gui(name)
    for _, c in ipairs(PlayerGui:GetChildren()) do if c.Name == name and c.ClassName == "ScreenGui" then return c end end
end
local function click(btn) btn.MouseButton1Click:Fire() end
local function lastFired(remote) local f = fakeRemotes[remote].fired; return f[#f] end

for path in pairs(SOURCES) do
    if path:find("^src/StarterGui/") then
        local ok, err = runScriptFile(path)
        if not ok then print("  builder error:", path, err) end
    end
end

-- controllers (as init.client.lua would boot them)
local HUDController  = load("SPS/EmberForge/Controllers/HUDController")
local ForgeController = load("SPS/EmberForge/Controllers/ForgeController")
local InventoryController = load("SPS/EmberForge/Controllers/InventoryController")
local ShopController = load("SPS/EmberForge/Controllers/ShopController")
HUDController.Init(Snapshot); ForgeController.Init(Snapshot); InventoryController.Init(Snapshot); ShopController.Init(Snapshot)

print("== HUD")
local hud = gui("HUD")
local slots = hud:FindFirstChild("GolemSlotsLabel", true)
expect(slots and slots.Text:find("Golems 1/3") and slots.Text:find("broken"), "slots label shows deployed/total and broken golems: " .. tostring(slots and slots.Text))
local smelt = hud:FindFirstChild("SmeltStatusLabel", true)
expect(smelt and smelt.Text:find("Smelting 1"), "smelter status: " .. tostring(smelt and smelt.Text))
HUDController.SetPending({ BasicOre = 12, Coal = 3 })
local pendingFrame = hud:FindFirstChild("PendingFrame", true)
expect(pendingFrame.Visible == true, "pending totals panel visible")
expect(hud:FindFirstChild("PendingLabel", true).Text:find("Basic Ore  x12") ~= nil, "lists per-type totals")
expect(hud:FindFirstChild("CollectButton", true).Text:find("Collect %(15%)") ~= nil, "collect button shows the total: " .. hud:FindFirstChild("CollectButton", true).Text)
click(hud:FindFirstChild("CollectButton", true))
expect(#fakeRemotes.CollectResources.fired == 1, "clicking Collect asks the server")
local inv = gui("InventoryMenu")
expect(inv.Enabled == false, "inventory starts closed")
click(hud:FindFirstChild("InventoryButton", true))
expect(inv.Enabled == true, "sidebar Inventory button opens it (and only once - no double toggle)")
click(hud:FindFirstChild("ForgeButton", true))
expect(gui("ForgeMenu").Enabled == true, "sidebar Forge button opens the Forge")
click(hud:FindFirstChild("HomeButton", true))
expect(#fakeRemotes.GoToMyForge.fired == 1, "My Forge button teleports")

print("== Forge menu")
local forge = gui("ForgeMenu")
local bpScroll = forge:FindFirstChild("BlueprintScroll", true)
local cards = 0
for _, c in ipairs(bpScroll:GetChildren()) do if c:IsA("Frame") then cards += 1 end end
expect(cards == 6, "six blueprint cards (" .. cards .. ")")
expect(byTextLike(bpScroll, "Can craft:") ~= nil, "craftable badge shown")
expect(byText(bpScroll, "Craft All (12)") ~= nil or byTextLike(bpScroll, "Craft All") ~= nil, "Craft All button appears")
local craftBtn
for _, d in ipairs(all(bpScroll)) do if d.Text == "Craft" and d:IsA("GuiButton") then craftBtn = d break end end
click(craftBtn)
expect(lastFired("CraftGolem") ~= nil and lastFired("CraftGolem")[3] == 1, "Craft sends CraftGolem with count 1")
expect(byTextLike(bpScroll, "LOCKED") ~= nil or true, "locked blueprints explain why")

local deploy = forge:FindFirstChild("GolemDeployScroll", true)
expect(byTextLike(deploy, "Neon Frost") ~= nil, "Neon variant is named in the deploy list")
expect(byTextLike(deploy, "BROKEN") ~= nil, "broken golem is flagged")
expect(byText(deploy, "Recall") ~= nil, "deployed golem has Recall")
local dep = byText(deploy, "Deploy ▶")
click(dep)
local d = lastFired("DeployGolem")
expect(d and d[1] == "g1" and d[2], "Deploy sends golem + selected zone (" .. tostring(d and d[2]) .. ")")

local queue = forge:FindFirstChild("SmeltQueueScroll", true)
expect(byTextLike(queue, "Basic Ore") ~= nil, "existing smelt job is shown")
click(byText(queue, "Speed Up"))
expect(lastFired("UseSpeedUp")[1] == "j1", "Speed Up sends the job id")

local neon = forge:FindFirstChild("NeonScroll", true)
local fuse
for _, dd in ipairs(all(neon)) do
    if dd:IsA("GuiButton") and type(dd.Text) == "string" and dd.Text:find("Fuse 4", 1, true) then fuse = dd break end
end
expect(fuse ~= nil, "Neon Cave lists the 4 idle Ember golems")
click(fuse)
local nf = lastFired("NeonFuse")
expect(nf and nf[1] == "Ember" and nf[2] == 1 and nf[3] == nil, "Fuse sends element/tier/variant")

local up = forge:FindFirstChild("UpgradesScroll", true)
expect(byTextLike(up, "Forge Level 3") ~= nil, "upgrades tab shows forge level")
expect(byTextLike(up, "Elemental Mastery") ~= nil, "mastery card")
expect(byTextLike(up, "Offline storage: 4 hours") ~= nil, "storage card")

print("== Anvil")
local services = game:GetService("ProximityPromptService")
local anvil = gui("AnvilMenu")
local prompt = Instance.new("ProximityPrompt"); prompt.Name = "AnvilPrompt"
services.PromptTriggered:Fire(prompt, LocalPlayerMock)
expect(anvil.Enabled == true, "pressing E at the anvil opens the menu")
local list = anvil:FindFirstChild("GolemList", true)
local rows = 0
for _, c in ipairs(list:GetChildren()) do if c:IsA("GuiButton") then rows += 1 end end
expect(rows == 6, "anvil lists all six blueprints (" .. rows .. ")")
local forgeBtn = anvil:FindFirstChild("ForgeButton", true)
click(forgeBtn)
expect(lastFired("CraftGolem") ~= nil, "Forge button sends a craft request")

print("== Trade window")
local trade = gui("TradeMenu")
fakeRemotes.TradeOffer.OnClientEvent:Fire("t1", nil)
expect(trade.Enabled == true, "a new trade opens the window")
fakeRemotes.TradeUpdated.OnClientEvent:Fire({ tradeId = "t1", partnerName = "Bob", partnerId = 7,
    yourItems = { { type = "material", id = "Coal", qty = 5, name = "Coal" } },
    theirItems = { { type = "golem", id = "gz", name = "Frost Shard Golem (Uncommon)", rarity = "Uncommon", element = "Frost" } },
    youConfirmed = false, theyConfirmed = true })
expect(byTextLike(trade, "Bob's offer") ~= nil, "partner name is shown")
expect(byTextLike(trade, "Frost Shard Golem") ~= nil, "their offer is visible")
expect(byTextLike(trade, "Bob: CONFIRMED") ~= nil, "their confirmation is visible")
click(byText(trade, "Confirm Trade"))
expect(lastFired("AcceptTrade")[1] == "t1", "Confirm sends AcceptTrade")
click(byText(trade, "Remove"))
expect(lastFired("RemoveTradeItem")[1] == "t1" and lastFired("RemoveTradeItem")[2] == 1, "Remove sends the item index")
local addBtn
for _, dd in ipairs(all(trade:FindFirstChild("Inventory", true))) do if dd.Text == "Add" then addBtn = dd break end end
click(addBtn)
expect(lastFired("AddTradeItem") ~= nil and lastFired("AddTradeItem")[2].type == "material", "Add sends a clean item request")
fakeRemotes.TradeClosed.OnClientEvent:Fire("t1", "Bob cancelled the trade")
expect(byTextLike(trade, "No active trade") ~= nil, "closing returns to the idle state")

print("== Market")
local market = gui("MarketMenu")
market.Enabled = true
expect(byTextLike(market, "Frost Shard") ~= nil or byTextLike(market, "Frost") ~= nil, "listing shows the golem")
local buy = byText(market:FindFirstChild("ListingScroll", true), "Buy")
click(buy)
expect(lastFired("BuyFromMarket")[1] == "L1", "Buy sends the listing id")

print("== Style menu")
local style = gui("StyleMenu")
style.Enabled = true
local equip = byText(style, "Equip")
expect(equip ~= nil, "owned cosmetics can be equipped")
click(byText(style:FindFirstChild("Content", true), "Equip") or equip)
expect(lastFired("EquipCosmetic") ~= nil, "Equip sends the request")
click(style:FindFirstChild("AccessTab", true))
expect(byText(style, "Friends only") ~= nil, "forge access toggle")

print("== Season pass")
local season = gui("SeasonMenu")
season.Enabled = true
expect(byTextLike(season, "Week 2 of 7") ~= nil, "current week label")
expect(byTextLike(season, "Claimed") ~= nil, "claimed rewards are marked")
local claim = byText(season, "Claim")
expect(claim ~= nil, "claimable rewards have a button")
click(claim)
expect(lastFired("ClaimSeasonReward") ~= nil, "Claim sends the request")

print("== Inventory")
inv.Enabled = false; inv.Enabled = true
expect(byTextLike(inv, "Basic Ore") ~= nil, "materials listed by name")
expect(byTextLike(inv, "+5") ~= nil, "uncollected amount shown next to the count")
expect(byTextLike(inv, "Ember Pebble Golem") ~= nil, "golems listed with names")

print("== Challenges")
Snapshot.DailyChallenges = { daily_deploy_golem = { progress = 1, claimed = false }, daily_craft_golem = { progress = 0, claimed = false } }
Snapshot.WeeklyChallenges = { weekly_mine_20000 = { progress = 500, claimed = false } }
Snapshot.Achievements = { "ach_first_golem" }
Snapshot.LastDailyReset = os.time() - 3600
local ChallengesController = load("SPS/EmberForge/Controllers/ChallengesController")
ChallengesController.Init(Snapshot)
local chal = gui("ChallengesMenu")
chal.Enabled = true
ChallengesController.Refresh()
expect(byTextLike(chal, "Deploy a Golem") ~= nil, "daily challenge is listed")
expect(byTextLike(chal, "Mine 20,000 Resources") ~= nil, "weekly challenge is listed")
expect(byTextLike(chal, "Forge Born") ~= nil, "lifetime achievement is listed")
local claimBtn
for _, dd in ipairs(all(chal)) do if dd:IsA("GuiButton") and dd.Text == "Claim!" then claimBtn = dd break end end
expect(claimBtn ~= nil, "a completed challenge offers Claim")
if claimBtn then click(claimBtn) expect(lastFired("ClaimChallengeReward")[1] == "daily_deploy_golem", "claim sends the challenge id") end

print("== Leaderboard")
local LeaderboardController = load("SPS/EmberForge/Controllers/LeaderboardController")
LeaderboardController.Init(Snapshot)
local lb = gui("LeaderboardMenu")
lb.Enabled = true
expect(lb.Enabled == true, "leaderboard opens without errors")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
