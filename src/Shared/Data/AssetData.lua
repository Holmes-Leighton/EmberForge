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
        Ember = { assetId = 0 },
        Stone = { assetId = 0 },
        Frost = { assetId = 0 },
        Storm = { assetId = 0 },
        Void  = { assetId = 0 },
        All   = { assetId = 0 },
    },
}

local MODES = { Auto = true, Skinned = true, Parts = true, Static = true }

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
