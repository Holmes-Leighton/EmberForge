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
    Patchwork  = { displayName = "Patches",          rarity = "Uncommon",  stat = "wear",  value = 0.05, text = "Golems wear out 5% slower" },
    Woven      = { displayName = "Knot",             rarity = "Uncommon",  stat = "eff",   value = 0.04, text = "+4% efficiency" },
    Coral      = { displayName = "Reef Buddy",       rarity = "Rare",      stat = "luck",  value = 0.05, text = "+5% luck" },
    Clockwork  = { displayName = "Tick",             rarity = "Rare",      stat = "rate",  value = 0.05, text = "+5% mining speed" },
    Alchemist  = { displayName = "Bubbles",          rarity = "Rare",      stat = "bp",    value = 0.10, text = "+10% blueprint finds" },
    Gargoyle   = { displayName = "Gravel",           rarity = "Rare",      stat = "carry", value = 0.06, text = "+6% carry capacity" },
    StormJar   = { displayName = "Thunder Jar",      rarity = "Epic",      stat = "wear",  value = 0.08, text = "Golems wear out 8% slower" },
    Dragonbone = { displayName = "Bonewyrm",         rarity = "Epic",      stat = "bp",    value = 0.20, text = "+20% blueprint finds" },
    All        = { displayName = "Primordial Spark", rarity = "Legendary", stat = "all",   value = 0.03, text = "+3% mining, carry, luck and efficiency" },
}

-- How each pet is drawn: `size` = its height in studs, `hover` = how far it floats above the ground.
-- Each pet has its own uploaded model (AssetData.PetPack); until then a mini Golem stands in.
PetData.Looks = {
    Ember      = { size = 2.6 },                    -- lava puppy
    Stone      = { size = 2.2 },                    -- rock turtle
    Frost      = { size = 3.0 },                    -- ice bunny
    Storm      = { size = 2.2, hover = 1.6 },       -- floating spark
    Void       = { size = 2.8, hover = 1.4 },       -- shadow ghost
    Patchwork  = { size = 2.6 },                    -- plush bear
    Woven      = { size = 2.6 },                    -- rope fox
    Coral      = { size = 2.4 },                    -- hermit crab
    Clockwork  = { size = 2.0 },                    -- brass beetle
    Alchemist  = { size = 2.6 },                    -- potion slime
    Gargoyle   = { size = 2.6 },                    -- baby gargoyle
    StormJar   = { size = 2.8, hover = 0.3 },       -- jar with a storm
    Dragonbone = { size = 3.4 },                    -- baby bone dragon
    All        = { size = 2.6, hover = 1.6 },       -- marble star spirit
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

-- Merging (same idea as Golem Neon fusion): 4 identical pets become one rarer Neon pet, and 4 identical
-- Neon pets become one Mega Neon pet. A variant pet keeps its type's rarity but boosts more and glows.
PetData.MERGE_COUNT = 4
PetData.Variants = {
    Neon     = { id = "Neon",     label = "Neon",      mult = 1.5, next = "MegaNeon" },
    MegaNeon = { id = "MegaNeon", label = "Mega Neon", mult = 2.0 },
}

function PetData.Get(typeId) return PetData.Pets[typeId] end

-- "Neon Ember Pup"
function PetData.DisplayName(pet)
    local def = PetData.Pets[pet.type]
    if not def then return tostring(pet.type) end
    local v = pet.variant and PetData.Variants[pet.variant]
    return (v and (v.label .. " ") or "") .. def.displayName
end

-- The boost text for a pet, scaled by its variant ("+4.5% luck")
function PetData.BoostText(pet)
    local def = PetData.Pets[pet.type]
    if not def then return "" end
    local v = pet.variant and PetData.Variants[pet.variant]
    if not v then return def.text end
    if def.stat == "wear" then return string.format("Golems wear out %.1f%% slower", def.value * v.mult * 100) end
    if def.stat == "all" then return string.format("+%.1f%% mining, carry, luck and efficiency", def.value * v.mult * 100) end
    local names = { rate = "mining speed", carry = "carry capacity", luck = "luck", eff = "efficiency", bp = "blueprint finds" }
    return string.format("+%.1f%% %s", def.value * v.mult * 100, names[def.stat] or def.stat)
end

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
            local v = pet.variant and PetData.Variants[pet.variant]
            local value = def.value * (v and v.mult or 1)
            if def.stat == "all" then
                b.rate += value; b.carry += value; b.luck += value; b.eff += value
            else
                b[def.stat] += value
            end
        end
    end
    for k, v in pairs(b) do b[k] = math.min(PetData.STAT_CAP, v) end
    return b
end

return PetData
