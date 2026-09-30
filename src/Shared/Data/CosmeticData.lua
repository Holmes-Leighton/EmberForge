-- Cosmetics are described by their id: "<Type>_<Name>" (e.g. GolemAccessory_LavaCrown).
-- This keeps season/level/shop data small: any id that follows the pattern gets a name, a
-- category and a colour theme automatically.
local CosmeticData = {}

CosmeticData.Types = {
    ForgeSkin          = { label = "Forge Skin",        slot = "ForgeSkin" },
    ForgeDecoration    = { label = "Forge Decoration",  slot = "ForgeDecoration" },
    GolemAccessory     = { label = "Golem Accessory",   slot = "GolemAccessory" },
    GolemSkin          = { label = "Golem Skin",        slot = "GolemSkin" },
    ParticleEffect     = { label = "Particle Effect",   slot = "ParticleEffect" },
    AnimatedForgeEffect = { label = "Forge Effect",     slot = "ForgeEffect" },
    TitleBadge         = { label = "Title",             slot = "Title" },
}

-- keyword in the id -> theme colour
local THEMES = {
    { words = { "Ember", "Lava", "Magma", "Molten", "Fire" },        color = Color3.fromRGB(230, 90, 40)  },
    { words = { "Frost", "Ice", "Blizzard", "Glacial", "Crystal" },  color = Color3.fromRGB(120, 190, 240) },
    { words = { "Storm", "Thunder", "Lightning", "Arc", "Rod" },     color = Color3.fromRGB(160, 120, 240) },
    { words = { "Void", "Shadow", "Rift", "Portal", "Obelisk" },     color = Color3.fromRGB(110, 60, 170)  },
    { words = { "Ancient", "Primordial", "Legend", "Titan", "Sovereign", "Veteran" }, color = Color3.fromRGB(255, 200, 60) },
}
local DEFAULT_COLOR = Color3.fromRGB(190, 170, 150)

local function Spaced(name)
    return (name:gsub("(%l)(%u)", "%1 %2"):gsub("_", " "))
end

function CosmeticData.Describe(id)
    local typeName, rest = tostring(id):match("^(%a+)_(.+)$")
    local typeDef = typeName and CosmeticData.Types[typeName]
    if not typeDef then
        return { id = id, type = "Other", label = "Cosmetic", name = Spaced(tostring(id)), color = DEFAULT_COLOR, slot = "Other" }
    end
    local color = DEFAULT_COLOR
    for _, theme in ipairs(THEMES) do
        for _, w in ipairs(theme.words) do
            if rest:find(w) then color = theme.color break end
        end
        if color ~= DEFAULT_COLOR then break end
    end
    return { id = id, type = typeName, label = typeDef.label, slot = typeDef.slot, name = Spaced(rest), color = color }
end

-- One line saying what this item actually changes (shown under its name in the Style menu)
local BLURBS = {
    ForgeSkin       = "Restyles your forge's stone, trim and fire colour",
    ForgeDecoration = "A monument standing in the corner of your forge plot",
    GolemAccessory  = "Worn by all your Golems while they mine",
    GolemSkin       = "Recolours your Golems with a shimmering finish",
    ParticleEffect  = "Sparkles that trail from your Golems' pickaxes",
    ForgeEffect     = "Animated glowing effect around your forge",
    Title           = "Shown under your name on your forge sign",
}
function CosmeticData.Blurb(id)
    local d = CosmeticData.Describe(id)
    return BLURBS[d.slot] or d.label
end

-- Human sentence for a season / level reward table entry
function CosmeticData.RewardText(reward)
    if not reward then return "-" end
    if reward.type == "cosmetic" then
        local d = CosmeticData.Describe(reward.id)
        return d.name .. " (" .. d.label .. ")"
    elseif reward.type == "material" then
        return string.format("%s x%d", reward.id, reward.qty or 1)
    elseif reward.type == "coins" then
        return (reward.qty or 0) .. " Ember Coins"
    elseif reward.type == "speedup" then
        return string.format("%d Speed-Ups", reward.qty or 1)
    elseif reward.type == "storageSlot" then
        return "Storage upgrade"
    end
    return tostring(reward.type)
end

return CosmeticData
