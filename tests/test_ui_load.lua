-- Every client menu script must at least build without crashing.
QUIET = true
local Snapshot = {
    PlayerLevel = 3, PlayerXP = 500, ForgeLevel = 3, ForgeXP = 1600, EmberCoins = 500, GolemSlots = 3, EffectiveGolemSlots = 3,
    Golems = { { id = "g1", element = "Ember", tier = 1, deployed = false, rarity = "Common", _durabilitySeconds = 1000, _maxDurabilitySeconds = 259200 },
               { id = "g2", element = "Frost", tier = 2, deployed = true, zoneId = "GlacialPeaks", variant = "Neon", rarity = "Uncommon", _durabilitySeconds = 0, _maxDurabilitySeconds = 345600 } },
    Inventory = { BasicOre = 120, Coal = 60, RefinedOre = 40 }, Pending = { BasicOre = 5 },
    Blueprints = { "BP_Ember_T1", "BP_Stone_T1", "BP_Frost_T1", "BP_Storm_T1", "BP_Void_T1", "BP_Ember_T2" },
    MasteryLevels = { Ember = 300, Frost = 0, Stone = 0, Storm = 0, Void = 0 },
    SmeltQueue = { { id = "j1", materialId = "BasicOre", outputId = "RefinedOre", quantity = 10, outputQty = 10, endTime = os.time() + 300 } },
    SpeedUps = 2, StorageTier = 0, SeasonPassTier = 0, OwnedCosmetics = { "ForgeSkin_Ember_Basic", "TitleBadge_Apprentice" }, Titles = { "Forge Initiate" },
    Equipped = {}, Settings = {}, DailyChallenges = {}, WeeklyChallenges = {}, Achievements = {},
    AvailableEventBlueprints = {}, SeasonStatus = { seasonId = "Season3", currentWeek = 2, totalWeeks = 7, claimedWeeks = {}, communityCurrent = 100, communityTarget = 750000 },
}
local Remotes = installFakeRemotes({ GetPlayerData = function() return Snapshot end,
    GetMarketListings = function() return {} end, GetMyListings = function() return {} end, GetTradeHistory = function() return {} end,
    GetLeaderboard = function() return {} end })

local builders = {}
for path in pairs(SOURCES) do
    if path:find("^src/StarterGui/") then table.insert(builders, path) end
end
table.sort(builders)

print("== StarterGui scripts build without errors")
for _, path in ipairs(builders) do
    local ok, err = runScriptFile(path)
    expect(ok, path:match("([^/]+)$") .. (ok and "" or ("  ->  " .. tostring(err))))
end

print("== the windows the HUD opens all exist")
local names = { "InventoryMenu", "ForgeMenu", "MarketMenu", "TradeMenu", "ShopMenu", "SeasonMenu", "ChallengesMenu", "LeaderboardMenu", "StyleMenu", "AnvilMenu", "HUD" }
for _, n in ipairs(names) do
    local found
    for _, c in ipairs(PlayerGui:GetChildren()) do if c.Name == n and c.ClassName == "ScreenGui" then found = c end end
    expect(found ~= nil, n .. " ScreenGui was created")
end

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
