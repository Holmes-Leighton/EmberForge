-- Golem pets: tiny versions of the Golem types that trot along behind you and give SMALL boosts.
-- Pets are hatched from eggs (Ember Coins), you can own many, and you wear up to PetData.SLOTS at once.
-- Boosts are deliberately small: they are a thank-you, not a way to skip the game.
--
--   type    the Golem look it copies (GolemData element or special id, "All" = Primordial)
--   stat    rate (mining speed) | carry (capacity) | luck | eff (efficiency) | wear (less durability wear)
--           | bp (blueprint discovery) | all (a bit of rate + carry + luck + eff)
--   value   fractional boost (0.03 = +3%)

local PetData = {}

PetData.SLOTS = 2
PetData.MAX_OWNED = 200
PetData.STAT_CAP = 0.20            -- no single stat can be boosted past +20% by pets

PetData.Pets = {
    Ember      = { displayName = "Ember Pup",        rarity = "Common",    stat = "rate",  value = 0.03, text = "+3% mining speed" },
    Stone      = { displayName = "Pebble Pal",       rarity = "Common",    stat = "carry", value = 0.04, text = "+4% carry capacity" },
    Frost      = { displayName = "Frost Bud",        rarity = "Common",    stat = "luck",  value = 0.03, text = "+3% luck" },
    Storm      = { displayName = "Spark Sprite",     rarity = "Uncommon",  stat = "eff",   value = 0.03, text = "+3% efficiency" },
    Void       = { displayName = "Shade Wisp",       rarity = "Uncommon",  stat = "luck",  value = 0.04, text = "+4% luck" },
    Patchwork  = { displayName = "Stitch",           rarity = "Uncommon",  stat = "wear",  value = 0.05, text = "Golems wear out 5% slower" },
    Woven      = { displayName = "Knot",             rarity = "Uncommon",  stat = "eff",   value = 0.04, text = "+4% efficiency" },
    Coral      = { displayName = "Reef Buddy",       rarity = "Rare",      stat = "luck",  value = 0.05, text = "+5% luck" },
    Clockwork  = { displayName = "Tick",             rarity = "Rare",      stat = "rate",  value = 0.05, text = "+5% mining speed" },
    Alchemist  = { displayName = "Bubbles",          rarity = "Rare",      stat = "bp",    value = 0.10, text = "+10% blueprint finds" },
    Gargoyle   = { displayName = "Gravel",           rarity = "Rare",      stat = "carry", value = 0.06, text = "+6% carry capacity" },
    StormJar   = { displayName = "Thunder Jar",      rarity = "Epic",      stat = "wear",  value = 0.08, text = "Golems wear out 8% slower" },
    Dragonbone = { displayName = "Bonewyrm",         rarity = "Epic",      stat = "bp",    value = 0.20, text = "+20% blueprint finds" },
    All        = { displayName = "Primordial Spark", rarity = "Legendary", stat = "all",   value = 0.03, text = "+3% mining, carry, luck and efficiency" },
}

-- Eggs: pick one, pay, get a random pet from its pool (weights are shown to the player)
PetData.EggOrder = { "Basic", "Crystal" }
PetData.Eggs = {
    Basic = {
        displayName = "Golem Egg", cost = 150, color = Color3.fromRGB(210, 170, 110),
        blurb = "A plain stone egg. Something small is rattling inside.",
        pool = {
            { item = "Ember", weight = 24 }, { item = "Stone", weight = 24 }, { item = "Frost", weight = 24 },
            { item = "Storm", weight = 10 }, { item = "Void", weight = 10 },
            { item = "Patchwork", weight = 4 }, { item = "Woven", weight = 4 },
        },
    },
    Crystal = {
        displayName = "Crystal Egg", cost = 1000, color = Color3.fromRGB(150, 210, 255),
        blurb = "A glittering egg humming with power. Much rarer pets inside.",
        pool = {
            { item = "Storm", weight = 14 }, { item = "Void", weight = 14 }, { item = "Patchwork", weight = 12 }, { item = "Woven", weight = 12 },
            { item = "Coral", weight = 9 }, { item = "Clockwork", weight = 9 }, { item = "Alchemist", weight = 9 }, { item = "Gargoyle", weight = 9 },
            { item = "StormJar", weight = 4 }, { item = "Dragonbone", weight = 4 }, { item = "All", weight = 1 },
        },
    },
}

function PetData.Get(typeId) return PetData.Pets[typeId] end

-- The chance (0..1) of each pet in an egg, for the odds list in the UI
function PetData.Odds(eggId)
    local egg = PetData.Eggs[eggId]
    if not egg then return {} end
    local total = 0
    for _, e in ipairs(egg.pool) do total += e.weight end
    local out = {}
    for _, e in ipairs(egg.pool) do table.insert(out, { type = e.item, chance = e.weight / total }) end
    return out
end

-- Total boosts from the pets a player is wearing: { rate, carry, luck, eff, wear, bp }, each capped.
function PetData.Boosts(data)
    local b = { rate = 0, carry = 0, luck = 0, eff = 0, wear = 0, bp = 0 }
    local byId = {}
    for _, pet in ipairs(data.OwnedPets or {}) do byId[pet.id] = pet end
    for _, id in ipairs(data.EquippedPets or {}) do
        local pet = byId[id]
        local def = pet and PetData.Pets[pet.type]
        if def then
            if def.stat == "all" then
                b.rate += def.value; b.carry += def.value; b.luck += def.value; b.eff += def.value
            else
                b[def.stat] += def.value
            end
        end
    end
    for k, v in pairs(b) do b[k] = math.min(PetData.STAT_CAP, v) end
    return b
end

return PetData
