-- One place that turns a Golem (or a blueprint) into words and colours.
local GolemData = require(script.Parent.Parent.Data.GolemData)
local Theme     = require(script.Parent.Theme)

local GolemNames = {}

function GolemNames.Rarity(golem)
    return golem.rarity or GolemData.RarityForTier(golem.tier)
end

function GolemNames.RarityColor(rarity)
    return Theme.Colors[rarity] or Theme.Colors.Common
end

-- { name = "Neon Frost Core Golem", tierName = "Core Golem", rarity = "Rare", color = ..., variant = "Neon" }
function GolemNames.Describe(golem)
    local tierDef = GolemData.Tiers[golem.tier or 1]
    local variantDef = golem.variant and GolemData.Variants[golem.variant]
    local rarity = GolemNames.Rarity(golem)
    local base = string.format("%s %s", tostring(golem.element), tierDef and tierDef.name or "Golem")
    return {
        name       = (variantDef and (variantDef.label .. " ") or "") .. base,
        shortName  = (variantDef and (variantDef.label .. " ") or "") .. tostring(golem.element) .. " Golem",
        tierName   = tierDef and tierDef.name or "Golem",
        rarity     = rarity,
        rarityColor = GolemNames.RarityColor(rarity),
        variant    = golem.variant,
        variantLabel = variantDef and variantDef.label or nil,
        elementColor = Theme.Colors[golem.element] or Theme.Colors.TextPrimary,
    }
end

return GolemNames
