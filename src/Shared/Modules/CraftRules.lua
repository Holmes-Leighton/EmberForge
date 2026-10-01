-- Who may craft what. Shared so the server enforces it and the client can explain it.
-- Spec: 3.2 (tier unlock conditions), 4.1 (forge level -> max tier + material slots), 4.3 (blueprints).

local ForgeData  = require(script.Parent.Parent.Data.ForgeData)
local GolemData  = require(script.Parent.Parent.Data.GolemData)
local RecipeData = require(script.Parent.Parent.Data.RecipeData)
local MaterialData = require(script.Parent.Parent.Data.MaterialData)

local CraftRules = {}

-- Bonus a Golem earns from the best material grade in its recipe (spec 3.3, "material quality")
local QUALITY_BY_RARITY = { Common = 0, Uncommon = 0.02, Rare = 0.05, Epic = 0.10, Legendary = 0.15 }

function CraftRules.QualityFor(bp)
    local best = 0
    for _, req in ipairs(bp.materialsRequired or {}) do
        local def = MaterialData.Get(req.id)
        best = math.max(best, QUALITY_BY_RARITY[def and def.rarity or "Common"] or 0)
    end
    return best
end

-- Lowest forge level whose max craft tier reaches `tier`
local function ForgeLevelForTier(tier)
    for _, fd in ipairs(ForgeData.Levels) do
        if fd.unlocks.maxCraftTier >= tier then return fd.level end
    end
    return #ForgeData.Levels
end

local function CraftedCount(data, tier)
    return ((data.CraftedByTier or {})[tier]) or ((data.CraftedByTier or {})[tostring(tier)]) or 0
end

-- Returns nil when the player may craft this blueprint right now, otherwise a short reason.
-- `availableEvents` is a set { [blueprintId] = true } of event blueprints currently on offer.
-- The same reason in a few words, for a small badge ("Forge Lv 4"). Anything unrecognised is just "Locked".
function CraftRules.ShortLockReason(reason)
    if not reason then return nil end
    local lvl = reason:match("Forge Level (%d+)")
    if lvl then return "Forge Lv " .. lvl end
    if reason:find("not discovered") then return "Find blueprint" end
    if reason:find("Tier 2 Golem first") then return "Craft Tier 2" end
    if reason:find("Event Golem") then return "Event only" end
    if reason:find("material slots") then return "More slots" end
    return "Locked"
end

function CraftRules.GetLockReason(data, bp, availableEvents)
    if not bp then return "Unknown blueprint" end

    local owned = false
    for _, id in ipairs(data.Blueprints or {}) do
        if id == bp.id then owned = true break end
    end
    if bp.isEventGolem then
        owned = availableEvents and availableEvents[bp.id] == true
        if not owned then return "Event Golem: not available right now" end
    elseif not owned then
        return "Blueprint not discovered yet"
    end

    local forgeLevel = data.ForgeLevel or 1
    if bp.forgeLevelRequired and forgeLevel < bp.forgeLevelRequired then
        return "Requires Forge Level " .. bp.forgeLevelRequired
    end

    local fd = ForgeData.Get(forgeLevel)
    if fd.unlocks.maxCraftTier < bp.tier then
        return "Requires Forge Level " .. ForgeLevelForTier(bp.tier) .. " (Tier " .. bp.tier .. " crafting)"
    end
    if #(bp.materialsRequired or {}) > fd.unlocks.materialSlots then
        return "Your forge only has " .. fd.unlocks.materialSlots .. " material slots"
    end

    if bp.unlockGate == "craft_first_tier2" then
        local has = false
        for _, g in ipairs(data.Golems or {}) do
            if g.tier >= 2 then has = true break end
        end
        if not has then return "Craft a Tier 2 Golem first" end
    end

    -- "craft 3x tier 1" / "craft 2x tier 2" style conditions from the tier table
    local tierDef = GolemData.Tiers[bp.tier]
    local condition = tierDef and tierDef.unlockCondition
    local need, ofTier
    if condition then
        need, ofTier = condition:match("^craft_(%d+)x_tier(%d+)$")
    end
    if need then
        need, ofTier = tonumber(need), tonumber(ofTier)
        if CraftedCount(data, ofTier) < need then
            return string.format("Craft %d Tier %d Golems first (%d/%d)", need, ofTier, CraftedCount(data, ofTier), need)
        end
    end
    return nil
end

function CraftRules.CraftableCount(data, bp)
    local n = math.huge
    for _, req in ipairs(bp.materialsRequired or {}) do
        n = math.min(n, math.floor(((data.Inventory or {})[req.id] or 0) / req.qty))
    end
    return n == math.huge and 0 or n
end

-- Every blueprint the player could ever see in a craft list: owned ones + live event ones
function CraftRules.ListBlueprints(data, availableEvents)
    local list, seen = {}, {}
    for _, id in ipairs(data.Blueprints or {}) do
        local bp = RecipeData.Get(id)
        if bp and bp.element and not seen[id] then seen[id] = true table.insert(list, bp) end
    end
    for id in pairs(availableEvents or {}) do
        local bp = RecipeData.Get(id)
        if bp and not seen[id] then seen[id] = true table.insert(list, bp) end
    end
    return list
end

return CraftRules
