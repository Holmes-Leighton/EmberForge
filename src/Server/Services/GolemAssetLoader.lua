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

local function LoadOne(key, cfg)
    pending += 1
    local ok, result = pcall(function() return InsertService:LoadAsset(cfg.assetId) end)
    if not ok or not result then
        warn(string.format("[GolemAssets] '%s' (asset %d) FAILED to load: %s. Using the block Golem instead. "
            .. "Check the id, and that the asset is owned by this game's creator or group.", key, cfg.assetId, tostring(result)))
        pending -= 1
        return
    end

    local model = Unwrap(result)
    local removed = Sanitise(model)
    local parts = CountParts(model)
    if parts == 0 then
        warn(string.format("[GolemAssets] '%s' (asset %d) loaded but contains no parts. Using the block Golem instead.", key, cfg.assetId))
        pending -= 1
        return
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
    model:SetAttribute("AssetId", cfg.assetId)
    model:SetAttribute("RigMode", mode)
    model:SetAttribute("ElementTint", cfg.elementTint or 0)
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
    log(string.format("LOADED '%s' (asset %d): %s", key, cfg.assetId, Describe(model, mode, cfg)))
    pending -= 1
end

function GolemAssetLoader.Init()
    folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = FOLDER_NAME
        folder.Parent = ReplicatedStorage
    end
    folder:SetAttribute("Version", 0)

    local jobs = AssetData.All()
    if #jobs == 0 then
        log("No Golem asset id is set in AssetData.lua: using the built-in block Golem.")
        return
    end
    log(string.format("Loading %d Golem asset(s)...", #jobs))
    for _, job in ipairs(jobs) do
        task.spawn(LoadOne, job.key, job.config)
    end
    -- Not blocking: GolemVisuals rebuilds Golems when the version changes, so a slow asset just
    -- appears when it arrives. This only reports if it is taking long.
    task.delay(AssetData.LOAD_TIMEOUT, function()
        if pending > 0 then
            warn(string.format("[GolemAssets] %d asset(s) still loading after %ds; block Golems are shown until they arrive", pending, AssetData.LOAD_TIMEOUT))
        end
    end)
end

return GolemAssetLoader
