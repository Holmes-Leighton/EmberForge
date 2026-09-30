QUIET = true
-- Reachability audit: every material, blueprint, zone and Golem type must be obtainable by a normal player.
local RD = load("game/ReplicatedStorage/Shared/Data/RecipeData")
local MD = load("game/ReplicatedStorage/Shared/Data/MaterialData")
local MZ = load("game/ReplicatedStorage/Shared/Data/MiningZoneData")
local SD = load("game/ReplicatedStorage/Shared/Data/SupplierData")
local CD = load("game/ReplicatedStorage/Shared/Data/ChallengeData")
local FD = load("game/ReplicatedStorage/Shared/Data/ForgeData")
local SeD = load("game/ReplicatedStorage/Shared/Data/SeasonData")
local GD = load("game/ReplicatedStorage/Shared/Data/GolemData")

local maxForge, maxTier, maxSlots = 1, 1, 0
for _, lv in ipairs(FD.Levels) do
    if lv.level > maxForge then maxForge = lv.level end
end
for _, lv in ipairs(FD.Levels) do
    local perks = lv.unlocks or lv
    maxTier = math.max(maxTier, lv.maxCraftTier or (lv.unlocks and lv.unlocks.maxCraftTier) or 1)
    maxSlots = math.max(maxSlots, lv.materialSlots or (lv.unlocks and lv.unlocks.materialSlots) or 0)
end
print("forge max level " .. maxForge .. ", max craft tier " .. maxTier .. ", max material slots " .. maxSlots)

-- ---- blueprints a player can get -------------------------------------------------------------
local have = {}          -- blueprint ids obtainable
local function challengeBlueprints()
    local t = {}
    for _, list in ipairs({ CD.Daily, CD.Weekly, CD.Lifetime }) do
        for _, c in ipairs(list) do
            for _, b in ipairs((c.rewards and c.rewards.blueprints) or {}) do t[b] = c.id end
        end
    end
    return t
end
local fromChallenge = challengeBlueprints()

print("== every blueprint has a reachable source")
for id, bp in pairs(RD.Blueprints) do
    local how
    if bp.source == RD.Source.Starting then how = "starting"
    elseif bp.source == RD.Source.ForgeMilestone then
        how = (bp.forgeLevelRequired and bp.forgeLevelRequired <= maxForge) and "forge level" or nil
    elseif bp.source == RD.Source.Challenge then how = fromChallenge[id] and "challenge" or nil
    elseif bp.source == RD.Source.RareDrop then
        how = (not bp.isEventGolem and bp.tier >= 2 and bp.tier <= 4 and (bp.forgeLevelRequired or 1) - 2 <= maxForge) and "rare drop" or nil
    elseif bp.source == RD.Source.SeasonalEvent then
        for _, s in pairs(SeD.Seasons) do
            if s.eventGolemBlueprintId == id then how = "season" end
        end
    end
    expect(how ~= nil, id .. " is obtainable" .. (how and (" (" .. how .. ")") or " -- NO SOURCE"))
    if how then have[id] = true end
    expect(bp.tier <= maxTier or bp.isEventGolem, id .. " can be crafted at some forge level (tier " .. bp.tier .. ")")
    expect(#bp.materialsRequired <= maxSlots, id .. " fits the material slots (" .. #bp.materialsRequired .. " <= " .. maxSlots .. ")")
end

-- ---- every Golem type has a blueprint -------------------------------------------------------
print("== every Golem type can be crafted")
local crafted = {}
for id, bp in pairs(RD.Blueprints) do
    if not bp.isEventGolem then crafted[bp.element] = true end
end
for el in pairs(GD.Elements or {}) do
    if el ~= "All" then expect(crafted[el], el .. " has a blueprint") end
end

-- ---- materials -----------------------------------------------------------------------------
local mat = {}
local function add(id) if id then mat[id] = true end end
for _, it in ipairs(SD.Items) do if it.kind == "material" then add(it.id) end end
for _, c in ipairs(CD.Daily) do for _, m in ipairs((c.rewards and c.rewards.materials) or {}) do add(m.id) end end
for _, c in ipairs(CD.Weekly) do for _, m in ipairs((c.rewards and c.rewards.materials) or {}) do add(m.id) end end

-- zones: a zone is reachable if its unlock is satisfiable
print("== every mining zone can be unlocked")
local zoneOpen = {}
for id, z in pairs(MZ.Zones) do
    local r = z.unlockRequirement
    local ok
    if r.type == "craft_golem" then
        ok = false
        for bid, bp in pairs(RD.Blueprints) do
            if bp.element == r.element and bp.tier <= r.minTier and have[bid] and not bp.isEventGolem then ok = true end
        end
    elseif r.type == "forge_level" then ok = r.level <= maxForge end
    expect(ok, id .. " unlock (" .. r.type .. ") is satisfiable")
    zoneOpen[id] = ok
    if ok then for _, d in ipairs(z.dropTable) do add(d.materialId) end end
end

-- smelting chains
local changed = true
while changed do
    changed = false
    for id in pairs(mat) do
        local def = MD.Get and MD.Get(id) or (MD.Raw and MD.Raw[id])
        local out = def and def.smeltOutput
        if out and not mat[out] then mat[out] = true changed = true end
    end
end

print("== every recipe material is obtainable")
for id, bp in pairs(RD.Blueprints) do
    for _, m in ipairs(bp.materialsRequired) do
        if m.id ~= "EventCatalyst" then
            expect(mat[m.id], id .. " needs " .. m.id .. " -- " .. (mat[m.id] and "obtainable" or "NOT OBTAINABLE"))
        end
    end
end
expect(mat.EventCatalyst, "EventCatalyst is earnable through challenges")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
