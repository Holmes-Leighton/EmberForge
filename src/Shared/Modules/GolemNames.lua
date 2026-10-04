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
    local special = GolemData.Specials[golem.element]
    -- a special Golem is just "<Name> Golem" (its tier shows as rarity); elements get "<Element> <Tier name>"
    local label = special and special.displayName or tostring(golem.element)
    local base = special and (label .. " Golem") or string.format("%s %s", label, tierDef and tierDef.name or "Golem")
    local fullName  = (variantDef and (variantDef.label .. " ") or "") .. base
    local shortName = (variantDef and (variantDef.label .. " ") or "") .. label .. " Golem"
    -- a Golem its owner has named: "Rocky the Frost Core Golem" in lists, just "Rocky" over its head and in alerts
    local nickname = type(golem.nickname) == "string" and golem.nickname ~= "" and golem.nickname or nil
    if nickname then
        fullName  = nickname .. " the " .. fullName
        shortName = nickname
    end
    return {
        skill      = special and special.skill or nil,
        nickname   = nickname,
        name       = fullName,
        shortName  = shortName,
        tierName   = tierDef and tierDef.name or "Golem",
        rarity     = rarity,
        rarityColor = GolemNames.RarityColor(rarity),
        variant    = golem.variant,
        variantLabel = variantDef and variantDef.label or nil,
        elementColor = Theme.Colors[golem.element] or Theme.Colors.TextPrimary,
    }
end

return GolemNames
