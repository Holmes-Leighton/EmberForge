-- Uploaded 3D art for the Golem. Every id is 0 until the art exists; with no id (or if the
-- load fails) the game keeps using the built-in block Golem, so nothing here is required.
--
-- The server loads each id once at start-up (GolemAssetLoader) and shares the result through
-- ReplicatedStorage.GolemAssets; GolemModel.Build clones from there. See ART_BRIEF.md section 4.
--
-- Upload the finished model with the Roblox Importer under the game's group, then paste the
-- number from the asset's page (the group must own it, or LoadAsset will refuse it).

local AssetData = {}

AssetData.TARGET_HEIGHT = 9.5      -- studs from the ground to the top of the head at tier 1 (matches the block Golem)
AssetData.LOAD_TIMEOUT  = 20       -- seconds the loader waits before logging that an asset is still loading

-- One base model for every Golem, recoloured by element. Set `Elements.<Name>.assetId` to give an
-- element its own model instead (any field left out is inherited from Default).
--
--   assetId       the model's asset id (number, 0 = not made yet)
--   mode          "Auto" | "Skinned" | "Parts" | "Static"
--                   Skinned: rigged FBX, played with the Idle/Mine animations below
--                   Parts:   separate parts named ArmL / ArmR / PickHandle / PickHead, swung in code
--                   Static:  one unsplit mesh, given a bob-and-sway
--                 Auto picks Skinned if the model has a rig AND an Idle or Mine animation id is set,
--                 Parts if it has a part called ArmR, otherwise Static.
--   elementTint   0..1, how strongly the element colour is mixed into an untextured-neutral model
--                 (0 = none). Ignored for an element that has its own model.
--   tierAddOns    true = still add the code-made core (T3), horns (T4) and halo (T5) on top.
--                 Set false once the art has its own tier pieces.
--   facing        degrees to turn the model so it faces -Z (0 if the artist already did)
--   animations    asset ids of the animations uploaded for this rig (0 = none)
AssetData.Golem = {
    Default = {
        assetId     = 85664844143538,
        mode        = "Parts",
        elementTint = 0.35,
        tierAddOns  = true,
        facing      = 0,
        animations  = { Idle = 0, Mine = 0, Walk = 0 },
    },
    Elements = {
        -- the five elements, each with its own body and size (height = studs at tier 1)
        Ember = { assetId = 0, height = 9.5  },   -- stocky molten brute
        Stone = { assetId = 0, height = 10   },   -- massive boulder golem
        Frost = { assetId = 0, height = 10.5 },   -- tall angular ice crystal
        Storm = { assetId = 0, height = 10.5 },   -- armoured, crackling
        Void  = { assetId = 0, height = 10   },   -- slim shard-and-galaxy
        All   = { assetId = 0 },

        -- Special Golems (GolemData.Specials): each has its own body, size and look. Until an id is set the
        -- type falls back to the shared model dressed in code (GolemSkinData.Specials). `height` = studs at tier 1.
        Patchwork  = { assetId = 0, height = 7.5  },   -- squat and round
        Woven      = { assetId = 0, height = 11   },   -- tall and lanky
        Coral      = { assetId = 0, height = 10   },   -- broad reef golem
        Clockwork  = { assetId = 0, height = 10   },   -- slim brass automaton
        Alchemist  = { assetId = 0, height = 9.5  },   -- potbellied
        Gargoyle   = { assetId = 0, height = 10.5 },   -- hunched, winged
        StormJar   = { assetId = 0, height = 9    },   -- a jar on legs
        Dragonbone = { assetId = 0, height = 13   },   -- towering skeleton
    },
}

-- One upload holding every Golem (the easiest way to ship all of them): put the Golems in one Model,
-- each child Model named EF_<Type> (EF_Ember, EF_Stone, EF_Frost, EF_Storm, EF_Void, EF_Patchwork ...),
-- upload it once and set its id here. A type that has its own `assetId` below uses that instead.
AssetData.Pack = { assetId = 0 }

-- The same idea for pets (PetData): one Model whose children are named PET_<Type> (PET_Ember, PET_Coral ...).
-- Each pet is shown at the size in PetData.Looks. Pets without a model show a mini Golem.
AssetData.PetPack = { assetId = 0 }

local MODES = { Auto = true, Skinned = true, Parts = true, Static = true }

-- The per-type settings a Golem Pack model is given: Default's settings with that type's own on top
-- (and no element tint, since a type's own model already has its look).
function AssetData.PackEntries()
    local def = AssetData.Golem.Default
    local out = {}
    for name, own in pairs(AssetData.Golem.Elements) do
        if (own.assetId or 0) <= 0 then
            local cfg = {}
            for k, v in pairs(def) do cfg[k] = v end
            for k, v in pairs(own) do cfg[k] = v end
            if own.elementTint == nil then cfg.elementTint = 0 end
            cfg.animations = own.animations or def.animations
            if not MODES[cfg.mode] then cfg.mode = "Auto" end
            out[name] = cfg
        end
    end
    return out
end

-- Returns the key ("Ember" or "Default") and the merged config for an element, or nil when no
-- asset is configured for it.
function AssetData.Resolve(element)
    local def = AssetData.Golem.Default
    local own = AssetData.Golem.Elements[element]
    local key, cfg = "Default", {}
    for k, v in pairs(def) do cfg[k] = v end
    if own and (own.assetId or 0) > 0 then
        key = element
        for k, v in pairs(own) do cfg[k] = v end
        if own.elementTint == nil then cfg.elementTint = 0 end     -- own model already has its element look
        cfg.animations = own.animations or def.animations
    end
    if (cfg.assetId or 0) <= 0 then return nil end
    if not MODES[cfg.mode] then cfg.mode = "Auto" end
    return key, cfg
end

-- Every distinct (key, config) pair that has an asset id, for the loader.
function AssetData.All()
    local out = {}
    local seen = {}
    local function add(element)
        local key, cfg = AssetData.Resolve(element)
        if key and not seen[key] then
            seen[key] = true
            table.insert(out, { key = key, config = cfg })
        end
    end
    for name in pairs(AssetData.Golem.Elements) do add(name) end
    return out
end

function AssetData.AnimationId(id)
    if type(id) == "number" and id > 0 then return "rbxassetid://" .. math.floor(id) end
    return nil
end

return AssetData
