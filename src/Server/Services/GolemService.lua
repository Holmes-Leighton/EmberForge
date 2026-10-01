-- Manages Golem crafting, deployment, collection, and fusion.

local GolemData        = require(game.ReplicatedStorage.Shared.Data.GolemData)
local RecipeData       = require(game.ReplicatedStorage.Shared.Data.RecipeData)
local GameConfig       = require(game.ReplicatedStorage.Shared.Data.GameConfig)
local CraftRules       = require(game.ReplicatedStorage.Shared.Modules.CraftRules)
local Utils            = require(game.ReplicatedStorage.Shared.Modules.Utils)
local PlayerDataService = require(script.Parent.PlayerDataService)

local GolemService = {}

-- ── Craft ────────────────────────────────────────────────────────────────────
-- Returns golem object on success, nil + error string on failure
function GolemService.CraftGolem(player, blueprintId, skinId)
    local data = PlayerDataService.Get(player)
    if not data then return nil, "No player data" end

    local bp = RecipeData.Get(blueprintId)
    if not bp then return nil, "Unknown blueprint" end

    -- Ownership, forge level, tier progression, material slots, live event windows
    local SeasonPassService = require(script.Parent.SeasonPassService)
    local lock = CraftRules.GetLockReason(data, bp, SeasonPassService.GetAvailableEventBlueprints())
    if lock then return nil, lock end

    -- Consume materials
    if not PlayerDataService.ConsumeMaterials(player, bp.materialsRequired) then
        return nil, "Insufficient materials"
    end

    -- Build golem object
    local tierData = GolemData.Tiers[bp.tier]
    local durabilitySeconds = (tierData and tierData.durabilityHours or 72) * 3600
    local golem = {
        id        = Utils.GenerateId(),
        blueprintId = blueprintId,
        element   = bp.element,
        tier      = bp.tier,
        skinId    = skinId or "default",
        deployed  = false,
        zoneId    = nil,
        fusionBonus = nil,
        quality   = CraftRules.QualityFor(bp),       -- stat bonus from the grade of materials used
        rarity    = GolemData.RarityForTier(bp.tier),
        _carriedResources = 0,
        _accumulatedResources = 0,
        _durabilitySeconds = durabilitySeconds,
        _maxDurabilitySeconds = durabilitySeconds,
        craftedAt = Utils.UnixTimestamp(),
    }

    table.insert(data.Golems, golem)
    data.CraftedByTier = data.CraftedByTier or {}
    data.CraftedByTier[bp.tier] = (data.CraftedByTier[bp.tier] or 0) + 1
    PlayerDataService.MarkDirty(player)

    return golem, nil
end

-- ── Deploy ───────────────────────────────────────────────────────────────────
function GolemService.DeployGolem(player, golemId, zoneId)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end

    -- Count currently deployed golems
    local deployedCount = 0
    local targetGolem = nil
    for _, g in ipairs(data.Golems) do
        if g.deployed then deployedCount = deployedCount + 1 end
        if g.id == golemId then targetGolem = g end
    end

    if not targetGolem then return false, "Golem not found" end
    if targetGolem.deployed then return false, "Golem already deployed" end
    local ShopService = require(script.Parent.ShopService)
    local effectiveSlots = ShopService.GetEffectiveGolemSlots(player)
    if deployedCount >= effectiveSlots then return false, "No free deployment slots. Recall a Golem first, or earn more slots by levelling your Forge." end

    -- Verify zone is unlocked
    local MiningZoneData = require(game.ReplicatedStorage.Shared.Data.MiningZoneData)
    local unlocked = MiningZoneData.GetUnlocked(data)
    if not Utils.TableContains(unlocked, zoneId) then
        return false, "Zone not unlocked"
    end

    targetGolem.deployed = true
    targetGolem.zoneId   = zoneId
    targetGolem._carriedResources = 0
    targetGolem._accumulatedResources = 0
    PlayerDataService.MarkDirty(player)

    return true, nil
end

-- ── Return (recall a golem and collect its resources) ────────────────────────
function GolemService.ReturnGolem(player, golemId)
    local data = PlayerDataService.Get(player)
    if not data then return nil, "No player data" end

    local targetGolem = nil
    for _, g in ipairs(data.Golems) do
        if g.id == golemId then targetGolem = g; break end
    end

    if not targetGolem then return nil, "Golem not found" end
    if not targetGolem.deployed then return nil, "Golem not deployed" end

    targetGolem.deployed  = false
    targetGolem.zoneId    = nil
    local carried = targetGolem._carriedResources or 0
    targetGolem._carriedResources = 0
    targetGolem._accumulatedResources = 0

    PlayerDataService.MarkDirty(player)
    return { carried = carried }, nil
end

-- ── Fusion ───────────────────────────────────────────────────────────────────
-- Fuses two same-tier golems (any elements); sacrifices golem2, boosts golem1
function GolemService.FuseGolems(player, golem1Id, golem2Id)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end

    local g1, g2, g1idx, g2idx
    for i, g in ipairs(data.Golems) do
        if g.id == golem1Id then g1 = g; g1idx = i end
        if g.id == golem2Id then g2 = g; g2idx = i end
    end

    if not g1 or not g2 then return false, "Golem not found" end
    if g1.tier ~= g2.tier then return false, "Tiers must match for fusion" end
    if g1.deployed or g2.deployed then return false, "Cannot fuse deployed Golems" end

    -- Apply fusion stat bonus (+5% to all stats)
    g1.fusionBonus = g1.fusionBonus or {}
    g1.fusionBonus.miningRate    = math.min(0.50, (g1.fusionBonus.miningRate    or 0) + 0.05)
    g1.fusionBonus.carryCapacity = math.min(0.50, (g1.fusionBonus.carryCapacity or 0) + 0.05)
    g1.fusionBonus.efficiency    = math.min(0.50, (g1.fusionBonus.efficiency    or 0) + 0.05)
    g1.fusionBonus.luck          = math.min(0.50, (g1.fusionBonus.luck          or 0) + 0.05)

    -- Remove sacrificed golem
    table.remove(data.Golems, g2idx)
    PlayerDataService.MarkDirty(player)

    return true, nil
end

-- ── Neon fusion (Adopt Me style) ─────────────────────────────────────────────
-- Four identical Golems (same element, tier and variant, none deployed) become one Neon;
-- four identical Neons become one Mega Neon. The best Golem of the four is kept and upgraded.
-- Returns the upgraded golem or nil + reason.
function GolemService.NeonFuse(player, element, tier, variant)
    local data = PlayerDataService.Get(player)
    if not data then return nil, "No player data" end
    if type(element) ~= "string" or type(tier) ~= "number" then return nil, "Bad request" end
    if variant ~= nil and variant ~= "Neon" then return nil, "Bad request" end

    local nextVariant = variant == nil and "Neon" or "MegaNeon"
    local need = GolemData.NEON_FUSION_COUNT

    local pool = {}
    for _, g in ipairs(data.Golems) do
        if g.element == element and g.tier == tier and g.variant == variant and not g.deployed then
            table.insert(pool, g)
        end
    end
    if #pool < need then
        return nil, string.format("You need %d idle %s%s Golems of Tier %d (you have %d)",
            need, variant and "Neon " or "", element, tier, #pool)
    end

    -- keep the strongest: highest fusion bonus, then quality
    local function power(g)
        local fb = g.fusionBonus or {}
        return (fb.miningRate or 0) + (fb.luck or 0) + (g.quality or 0)
    end
    table.sort(pool, function(a, b) return power(a) > power(b) end)
    local keep = pool[1]

    for i = 2, need do
        for idx, g in ipairs(data.Golems) do
            if g == pool[i] then table.remove(data.Golems, idx) break end
        end
    end

    keep.variant = nextVariant
    keep._durabilitySeconds = keep._maxDurabilitySeconds or keep._durabilitySeconds
    PlayerDataService.MarkDirty(player)
    return keep, nil
end

-- ── Repair ───────────────────────────────────────────────────────────────────
-- Costs 20% of the tier's material requirements; restores durability to max.
function GolemService.RepairGolem(player, golemId)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end

    local targetGolem = nil
    for _, g in ipairs(data.Golems) do
        if g.id == golemId then targetGolem = g; break end
    end
    if not targetGolem then return false, "Golem not found" end
    if targetGolem.deployed then return false, "Cannot repair a deployed golem" end

    local tierData = GolemData.Tiers[targetGolem.tier]
    if not tierData then return false, "Unknown tier" end

    -- Build repair cost at 20% of original craft cost (rounded up)
    local repairCost = {}
    for _, req in ipairs(tierData.materialsRequired) do
        table.insert(repairCost, { id = req.id, qty = math.max(1, math.ceil(req.qty * 0.20)) })
    end

    if not PlayerDataService.ConsumeMaterials(player, repairCost) then
        return false, "Insufficient materials"
    end

    local maxDur = (targetGolem._maxDurabilitySeconds or tierData.durabilityHours * 3600)
    targetGolem._durabilitySeconds = maxDur
    PlayerDataService.MarkDirty(player)
    return true, nil
end

-- ── Helpers ──────────────────────────────────────────────────────────────────
function GolemService._CheckUnlockGate(data, gate)
    if gate == "craft_first_tier2" then
        for _, g in ipairs(data.Golems) do
            if g.tier >= 2 then return true end
        end
        return false
    end
    return true
end

-- Check and grant golem slot milestones
function GolemService.CheckSlotMilestones(player)
    local data = PlayerDataService.Get(player)
    if not data then return end

    for _, milestone in ipairs(GolemData.SlotMilestones) do
        if milestone.slots > data.GolemSlots then
            local condition = milestone.condition
            local met = false

            if condition == "start" then
                met = true
            elseif condition == "craft_first_tier2" then
                met = GolemService._CheckUnlockGate(data, "craft_first_tier2")
            elseif condition == "forge_level_5" then
                met = data.ForgeLevel >= 5
            elseif condition == "craft_first_tier4" then
                for _, g in ipairs(data.Golems) do
                    if g.tier >= 4 then met = true; break end
                end
            elseif condition == "forge_mastery_challenge" then
                met = Utils.TableContains(data.Achievements, "ach_forge_mastery")
            end

            if met then
                data.GolemSlots = milestone.slots
                PlayerDataService.MarkDirty(player)
            end
        end
    end
end

return GolemService
