-- Loads the uploaded Golem model(s) named in AssetData once, at server start, and shares them with
-- every client through ReplicatedStorage.GolemAssets. GolemModel.Build clones from there, and falls
-- back to the block Golem when nothing is loaded. Everything is logged to Output with the prefix
-- [GolemAssets] so you can see at a glance whether your art was used.

local InsertService     = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetData = require(game.ReplicatedStorage.Shared.Data.AssetData)

local GolemAssetLoader = {}

local FOLDER_NAME = "GolemAssets"
local MAX_PARTS   = 120        -- warn above this; phones struggle with many parts per Golem

local folder
local pending = 0
local version = 0

local SCRIPT_CLASSES = { Script = true, LocalScript = true, ModuleScript = true }

local function log(...) print("[GolemAssets]", ...) end

-- LoadAsset returns a container Model; the artwork is usually the single Model inside it.
local function Unwrap(container)
    local inner
    for _, c in ipairs(container:GetChildren()) do
        if c:IsA("Model") then
            if inner then return container end        -- several models: keep the container
            inner = c
        elseif c:IsA("BasePart") then
            return container
        end
    end
    return inner or container
end

-- Artists deliver meshes only. Strip anything executable so a loaded asset can never run code.
local function Sanitise(model)
    local removed = 0
    for _, d in ipairs(model:GetDescendants()) do
        if SCRIPT_CLASSES[d.ClassName] then
            d:Destroy()
            removed += 1
        end
    end
    return removed
end

local function CountParts(model)
    local n = 0
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then n += 1 end
    end
    return n
end

local function HasRig(model)
    for _, d in ipairs(model:GetDescendants()) do
        local c = d.ClassName
        if c == "Bone" or c == "Motor6D" or c == "Humanoid" or c == "AnimationController" or c == "Animator" then
            return true
        end
    end
    return false
end

local function DetectMode(model, cfg)
    if cfg.mode ~= "Auto" then return cfg.mode end
    local a = cfg.animations or {}
    local hasAnim = (a.Idle or 0) > 0 or (a.Mine or 0) > 0
    if HasRig(model) and hasAnim then return "Skinned" end
    local arm = model:FindFirstChild("ArmR", true)
    if arm and arm:IsA("BasePart") then return "Parts" end
    return "Static"
end

local function Describe(model, mode, cfg)
    local names = {}
    for _, n in ipairs({ "Idle", "Mine", "Walk" }) do
        if AssetData.AnimationId((cfg.animations or {})[n]) then table.insert(names, n) end
    end
    return string.format("mode=%s, %d parts, animations: %s", mode, CountParts(model),
        #names > 0 and table.concat(names, "/") or "none")
end


-- Sanitises a loaded model, detects how it moves, and publishes it in ReplicatedStorage.GolemAssets under
-- `key`. `assetId` is whatever was loaded (a single model's id, or the pack's id). Returns true on success.
local function Register(key, model, cfg, assetId)
    local removed = Sanitise(model)
    local parts = CountParts(model)
    if parts == 0 then
        warn(string.format("[GolemAssets] '%s' (asset %d) loaded but contains no parts. Using the block Golem instead.", key, assetId))
        return false
    end
    if removed > 0 then
        warn(string.format("[GolemAssets] '%s': removed %d script(s) from the model (art must not contain code)", key, removed))
    end
    if parts > MAX_PARTS then
        warn(string.format("[GolemAssets] '%s' has %d parts; keep Golems under %d for phones", key, parts, MAX_PARTS))
    end

    local mode = DetectMode(model, cfg)
    if mode == "Skinned" and not (AssetData.AnimationId((cfg.animations or {}).Idle) or AssetData.AnimationId((cfg.animations or {}).Mine)) then
        warn(string.format("[GolemAssets] '%s' is set to Skinned but has no Idle or Mine animation id; it will stand still", key))
    end

    model.Name = key
    model:SetAttribute("AssetId", assetId)
    model:SetAttribute("RigMode", mode)
    model:SetAttribute("ElementTint", cfg.elementTint or 0)
    model:SetAttribute("OwnModel", key ~= "Default")          -- a model made for one type carries its own look
    if cfg.height then model:SetAttribute("Height", cfg.height) end
    model:SetAttribute("TierAddOns", cfg.tierAddOns ~= false)
    model:SetAttribute("Facing", cfg.facing or 0)
    for _, n in ipairs({ "Idle", "Mine", "Walk" }) do
        local id = AssetData.AnimationId((cfg.animations or {})[n])
        if id then model:SetAttribute("Anim" .. n, id) end
    end

    local old = folder:FindFirstChild(key)
    if old then old:Destroy() end
    model.Parent = folder
    version += 1
    folder:SetAttribute("Version", version)
    log(string.format("LOADED '%s' (asset %d): %s", key, assetId, Describe(model, mode, cfg)))
    return true
end

-- One model per asset id
local function LoadOne(key, cfg)
    pending += 1
    local ok, result = pcall(function() return InsertService:LoadAsset(cfg.assetId) end)
    if not ok or not result then
        warn(string.format("[GolemAssets] '%s' (asset %d) FAILED to load: %s. Using the block Golem instead. "
            .. "Check the id, and that the asset is owned by this game's creator or group.", key, cfg.assetId, tostring(result)))
    else
        Register(key, Unwrap(result), cfg, cfg.assetId)
    end
    pending -= 1
end

-- One asset id holding every Golem (a "Golem Pack"): a model whose children are named EF_<Type>
-- (EF_Ember, EF_Coral ...). Only types without their own asset id are taken from the pack.
local function LoadPack(packId, entries)
    pending += 1
    local ok, result = pcall(function() return InsertService:LoadAsset(packId) end)
    if not ok or not result then
        warn(string.format("[GolemAssets] Golem Pack (asset %d) FAILED to load: %s. Using the block Golem instead. "
            .. "Check the id, and that the asset is owned by this game's creator or group.", packId, tostring(result)))
        pending -= 1
        return
    end
    local found = 0
    for _, d in ipairs(result:GetDescendants()) do
        local key = d:IsA("Model") and d.Name:match("^EF_(.+)$")
        local entry = key and entries[key]
        if entry and Register(key, d, entry, packId) then found += 1 end
    end
    log(string.format("Golem Pack (asset %d): %d of %d Golem(s) loaded", packId, found, (function() local n = 0 for _ in pairs(entries) do n += 1 end return n end)()))
    pending -= 1
end

-- Pets: one asset holding every pet model (children named PET_<Type>) -> ReplicatedStorage.PetAssets
local function LoadPetPack(packId, petFolder)
    pending += 1
    local ok, result = pcall(function() return InsertService:LoadAsset(packId) end)
    if not ok or not result then
        warn(string.format("[GolemAssets] Pet Pack (asset %d) FAILED to load: %s. Pets will use mini Golems instead. "
            .. "Check the id, and that the asset is owned by this game's creator or group.", packId, tostring(result)))
        pending -= 1
        return
    end
    local found = 0
    for _, d in ipairs(result:GetDescendants()) do
        local petType = d:IsA("Model") and d.Name:match("^PET_(.+)$")
        if petType then
            Sanitise(d)
            if CountParts(d) > 0 then
                d.Name = petType
                local old = petFolder:FindFirstChild(petType)
                if old and old:GetAttribute("Rigged") and not d:GetAttribute("Rigged") then
                    -- never swap a segmented (animated) pet for an old one-piece model
                else
                    if old then old:Destroy() end
                    d.Parent = petFolder
                    found += 1
                end
            end
        end
    end
    petFolder:SetAttribute("Version", found)
    log(string.format("Pet Pack (asset %d): %d pet model(s) loaded", packId, found))
    pending -= 1
end

-- Crowns: one asset holding every crown (children named CROWN_<Type>) -> ReplicatedStorage.CrownAssets
local function LoadCrownPack(packId, crownFolder)
    pending += 1
    local ok, result = pcall(function() return InsertService:LoadAsset(packId) end)
    if not ok or not result then
        warn(string.format("[GolemAssets] Crown Pack (asset %d) FAILED to load: %s. Elite/Supreme will use a plain circlet. "
            .. "Check the id, and that the asset is owned by this game's creator or group.", packId, tostring(result)))
        pending -= 1
        return
    end
    local found = 0
    for _, d in ipairs(result:GetDescendants()) do
        local crownType = d:IsA("Model") and d.Name:match("^CROWN_(.+)$")
        if crownType then
            Sanitise(d)
            if CountParts(d) > 0 then
                d.Name = crownType
                local old = crownFolder:FindFirstChild(crownType)
                if old then old:Destroy() end
                d.Parent = crownFolder
                found += 1
            end
        end
    end
    crownFolder:SetAttribute("Version", found)
    log(string.format("Crown Pack (asset %d): %d crown(s) loaded", packId, found))
    pending -= 1
end

-- Forge build pieces: one asset holding every piece (children named after ForgeBuildData ids) -> ReplicatedStorage.BuildAssets
local function LoadBuildPack(packId, buildFolder)
    pending += 1
    local ok, result = pcall(function() return InsertService:LoadAsset(packId) end)
    if not ok or not result then
        warn(string.format("[GolemAssets] Build Pack (asset %d) FAILED to load: %s. Forge pieces will be plain blocks.", packId, tostring(result)))
        pending -= 1
        return
    end
    local found = 0
    local root = result:FindFirstChildWhichIsA("Model") or result
    for _, d in ipairs(root:GetChildren()) do
        if d:IsA("Model") then
            Sanitise(d)
            if CountParts(d) > 0 then
                local old = buildFolder:FindFirstChild(d.Name)
                if old then old:Destroy() end
                d.Parent = buildFolder
                found += 1
            end
        end
    end
    buildFolder:SetAttribute("Version", found)
    log(string.format("Build Pack (asset %d): %d forge piece(s) loaded", packId, found))
    pending -= 1
end

-- Quarry pieces: one asset holding every piece (children named after QuarryData ids) -> ReplicatedStorage.QuarryAssets
local function LoadQuarryPack(packId, folder)
    pending += 1
    local ok, result = pcall(function() return InsertService:LoadAsset(packId) end)
    if not ok or not result then
        warn(string.format("[GolemAssets] Quarry Pack (asset %d) FAILED to load: %s. Quarry pieces will be plain blocks.", packId, tostring(result)))
        pending -= 1
        return
    end
    local found = 0
    local root = result:FindFirstChildWhichIsA("Model") or result
    for _, d in ipairs(root:GetChildren()) do
        if d:IsA("Model") then
            Sanitise(d)
            if CountParts(d) > 0 then
                local old = folder:FindFirstChild(d.Name)
                if old then old:Destroy() end
                d.Parent = folder
                found += 1
            end
        end
    end
    folder:SetAttribute("Version", found)
    log(string.format("Quarry Pack (asset %d): %d piece(s) loaded", packId, found))
    pending -= 1
end
-- Material meshes: one small asset per material (AssetData.MaterialMeshes) -> ReplicatedStorage.MaterialAssets.<MaterialId>
local function LoadMaterialMeshes(list, folder)
    pending += 1
    local found, total = 0, 0
    local done = 0
    for matId, assetId in pairs(list) do
        total += 1
        task.spawn(function()
            local ok, result = pcall(function() return InsertService:LoadAsset(assetId) end)
            if ok and result then
                local model = Unwrap(result)
                Sanitise(model)
                if CountParts(model) > 0 then
                    model.Name = matId
                    local old = folder:FindFirstChild(matId)
                    if old then old:Destroy() end
                    model.Parent = folder
                    found += 1
                    folder:SetAttribute("Version", found)
                end
            else
                warn(string.format("[GolemAssets] Material mesh %s (asset %d) FAILED to load: %s", matId, assetId, tostring(result)))
            end
            done += 1
        end)
    end
    while done < total do task.wait(0.1) end
    log(string.format("Material meshes: %d of %d loaded", found, total))
    pending -= 1
end

function GolemAssetLoader.Init()
    local materialFolder = ReplicatedStorage:FindFirstChild("MaterialAssets")
    if not materialFolder then
        materialFolder = Instance.new("Folder")
        materialFolder.Name = "MaterialAssets"
        materialFolder.Parent = ReplicatedStorage
    end
    materialFolder:SetAttribute("Version", 0)
    if AssetData.MaterialMeshes and next(AssetData.MaterialMeshes) then task.spawn(LoadMaterialMeshes, AssetData.MaterialMeshes, materialFolder) end
    local quarryFolder = ReplicatedStorage:FindFirstChild("QuarryAssets")
    if not quarryFolder then
        quarryFolder = Instance.new("Folder")
        quarryFolder.Name = "QuarryAssets"
        quarryFolder.Parent = ReplicatedStorage
    end
    local quarryPackId = AssetData.QuarryPack and AssetData.QuarryPack.assetId or 0
    if quarryPackId > 0 then task.spawn(LoadQuarryPack, quarryPackId, quarryFolder) end
    local buildFolder = ReplicatedStorage:FindFirstChild("BuildAssets")
    if not buildFolder then
        buildFolder = Instance.new("Folder")
        buildFolder.Name = "BuildAssets"
        buildFolder.Parent = ReplicatedStorage
    end
    buildFolder:SetAttribute("Version", 0)
    local buildPackId = AssetData.BuildPack and AssetData.BuildPack.assetId or 0
    if buildPackId > 0 then task.spawn(LoadBuildPack, buildPackId, buildFolder) end

    local crownFolder = ReplicatedStorage:FindFirstChild("CrownAssets")
    if not crownFolder then
        crownFolder = Instance.new("Folder")
        crownFolder.Name = "CrownAssets"
        crownFolder.Parent = ReplicatedStorage
    end
    crownFolder:SetAttribute("Version", 0)
    local crownPackId = AssetData.CrownPack and AssetData.CrownPack.assetId or 0
    if crownPackId > 0 then task.spawn(LoadCrownPack, crownPackId, crownFolder) end

    folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = FOLDER_NAME
        folder.Parent = ReplicatedStorage
    end
    folder:SetAttribute("Version", 0)

    local petFolder = ReplicatedStorage:FindFirstChild("PetAssets")
    if not petFolder then
        petFolder = Instance.new("Folder")
        petFolder.Name = "PetAssets"
        petFolder.Parent = ReplicatedStorage
    end
    petFolder:SetAttribute("Version", 0)
    local petPackId = AssetData.PetPack and AssetData.PetPack.assetId or 0
    if petPackId > 0 then task.spawn(LoadPetPack, petPackId, petFolder) end

    local jobs = AssetData.All()
    local packId = AssetData.Pack and AssetData.Pack.assetId or 0
    if #jobs == 0 and packId <= 0 and petPackId <= 0 and crownPackId <= 0 then
        log("No Golem asset id is set in AssetData.lua: using the built-in block Golem.")
        return
    end
    log(string.format("Loading %d Golem asset(s)%s...", #jobs, packId > 0 and " and the Golem Pack" or ""))
    for _, job in ipairs(jobs) do
        task.spawn(LoadOne, job.key, job.config)
    end
    if packId > 0 then task.spawn(LoadPack, packId, AssetData.PackEntries()) end
    -- Not blocking: GolemVisuals rebuilds Golems when the version changes, so a slow asset just
    -- appears when it arrives. This only reports if it is taking long.
    task.delay(AssetData.LOAD_TIMEOUT, function()
        if pending > 0 then
            warn(string.format("[GolemAssets] %d asset(s) still loading after %ds; block Golems are shown until they arrive", pending, AssetData.LOAD_TIMEOUT))
        end
    end)
end

return GolemAssetLoader
