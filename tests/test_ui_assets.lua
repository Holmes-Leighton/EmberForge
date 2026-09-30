QUIET = true
-- ── fakes for the parts of Roblox the asset path needs ───────────────────────────────
local CFmeta = getmetatable(CFrame.new(0, 0, 0))
CFmeta.__index.ToObjectSpace = function(self) return setmetatable({ Position = self.Position }, CFmeta) end
CFmeta.__index.Inverse = function(self) return self end
getmetatable(Vector3.new(0, 0, 0)).__index = function(_, k)
    if k == "Magnitude" then return 0 end
end

local logs, warns = {}, {}
local realPrint = print
print = function(...) local t = {} for i, v in ipairs({ ... }) do t[i] = tostring(v) end table.insert(logs, table.concat(t, " ")) end
warn = function(...) local t = {} for i, v in ipairs({ ... }) do t[i] = tostring(v) end table.insert(warns, table.concat(t, " ")) end
function expect(cond, msg) if cond then realPrint("  ok   " .. msg) else realPrint("  FAIL " .. msg); FAILED = (FAILED or 0) + 1 end end
local function saw(list, needle) for _, l in ipairs(list) do if l:find(needle, 1, true) then return true end end return false end
local function reset() logs, warns = {}, {} end

local rs = Instance.new("Folder")
rs.Name = "ReplicatedStorage"
local insertResults = {}
local fakeInsert = { LoadAsset = function(_, id)
    local r = insertResults[id]
    if type(r) == "string" then error(r) end
    if type(r) == "function" then return r() end     -- a fresh container each time: loading moves the model out of it
    return r
end }
local prevGetService = game.GetService
rawset(game, "GetService", function(_, n)
    if n == "ReplicatedStorage" then return rs end
    if n == "InsertService" then return fakeInsert end
    return prevGetService(game, n)
end)

local function props(o) return rawget(o, "_props") end
local function deepClone(o)
    local c = Instance.new(o.ClassName)
    c.Name = o.Name
    for k, v in pairs(props(o)) do rawset(props(c), k, v) end
    for k, v in pairs(rawget(o, "_attrs")) do c:SetAttribute(k, v) end
    for _, ch in ipairs(o:GetChildren()) do deepClone(ch).Parent = c end
    return c
end
local scaleCalls
local function newPart(parent, name, cls)
    local p = Instance.new(cls or "Part")
    p.Name = name
    p.Size = Vector3.new(1, 2, 1)
    p.Material = Enum.Material.Slate
    p.Color = Color3.new(1, 1, 1)
    p.Anchored = false
    p.CFrame = CFrame.new(0, 3, 0)
    p.PivotOffset = CFrame.new(0, 0, 0)
    p.Parent = parent
    return p
end
local function newModel(names, extraFn)
    local m = Instance.new("Model")
    m.Name = "Art"
    for _, n in ipairs(names) do newPart(m, n) end
    m.Clone = function(self) return deepClone(self) end
    m.GetExtentsSize = function() return Vector3.new(3, 10, 2) end
    m.GetScale = function() return 1 end
    m.ScaleTo = function(self, k) scaleCalls[#scaleCalls + 1] = k end
    m.GetBoundingBox = function() return CFrame.new(0, 5, 0), Vector3.new(3, 10, 2) end
    if extraFn then extraFn(m) end
    return m
end
local function container(inner)
    local c = Instance.new("Model")
    inner.Parent = c
    return c
end

local AssetData = load("game/ReplicatedStorage/Shared/Data/AssetData")
local Loader = load("SSS/EmberForge/Services/GolemAssetLoader")
local GolemModel = load("game/ReplicatedStorage/Shared/Modules/GolemModel")
local D = AssetData.Golem.Default

print("== no asset ids: block Golem, clear log")
Loader.Init()
local m = GolemModel.Build("Frost", 2, {})
expect(m:FindFirstChild("Torso") ~= nil and m:GetAttribute("RigMode") == nil, "block Golem is used")
expect(saw(logs, "No Golem asset id"), "log says no asset id is set")
expect(GolemModel.AssetVersion() == 0, "asset version is 0")

print("== Parts model loads, is cleaned, scaled, tinted, dressed")
D.assetId = 111
insertResults[111] = function() return container(newModel({ "Torso", "Head", "ArmL", "ArmR", "PickHandle", "PickHead" }, function(x)
    local s = Instance.new("Script"); s.Parent = x
    newPart(x, "Eye").Material = Enum.Material.Neon
end)) end
reset()
Loader.Init()
local tpl = rs:FindFirstChild("GolemAssets"):FindFirstChild("Default")
expect(tpl ~= nil, "asset placed in ReplicatedStorage.GolemAssets")
expect(tpl:GetAttribute("RigMode") == "Parts", "Auto detects Parts from ArmR")
expect(tpl:FindFirstChildOfClass("Script") == nil, "scripts are stripped from the asset")
expect(saw(warns, "removed 1 script"), "removing scripts is logged")
expect(saw(logs, "LOADED 'Default' (asset 111): mode=Parts"), "Output says the asset LOADED")
expect(GolemModel.AssetVersion() == 1, "version bumped")
scaleCalls = {}
local g = GolemModel.Build("Frost", 3, { variant = "Neon", accessory = "GolemAccessory_LavaCrown", particle = "ParticleEffect_Sparks" })
expect(g:GetAttribute("RigMode") == "Parts" and g.Name == "GolemPreview", "Build returns the uploaded model")
expect(g:FindFirstChild("Torso") ~= nil and g:FindFirstChild("Torso").Material == Enum.Material.Neon, "Neon variant makes body parts Neon")
expect(g:FindFirstChild("Eye").Material == Enum.Material.Neon and g:FindFirstChild("Eye"):GetAttribute("Tint") == nil, "glowing eyes keep their own look and are not tinted")
expect(g:FindFirstChild("Torso"):GetAttribute("Tint") == true, "body parts are tagged for the Neon / Mega Neon colour animation")
expect(math.abs(scaleCalls[1] - 9.5 / 10 * 1.36) < 1e-6, "tier 3 scale = target height x 1.36")
expect(g.PrimaryPart ~= nil, "PrimaryPart set so callers can PivotTo")
expect(g:FindFirstChild("CrownBand") ~= nil, "accessory is added")
expect(g:FindFirstChild("Core") ~= nil, "tier 3 core is added on top")
expect(g:FindFirstChild("Torso"):FindFirstChild("PointLight") ~= nil, "Neon adds a light")
expect(g:FindFirstChild("PickHead"):FindFirstChild("ParticleEmitter") ~= nil, "particle effect attaches to the pickaxe head")
local plain = GolemModel.Build("Frost", 1, {})
expect(plain:FindFirstChild("Torso").Color ~= tpl:FindFirstChild("Torso").Color, "element tint recolours the model")
expect(plain:FindFirstChild("Torso").Anchored == true, "non-skinned models stay anchored (client moves them)")
expect(plain:FindFirstChild("Shoulder") == nil, "block-only shoulders are not added")

print("== elements with their own model win; tier add-ons can be turned off")
AssetData.Golem.Elements.Ember.assetId = 333
insertResults[333] = function() return container(newModel({ "Torso" })) end
D.tierAddOns = false
reset()
Loader.Init()
expect(GolemModel.Build("Ember", 1, {}):GetAttribute("AssetId") == 333, "Ember uses its own model")
expect(GolemModel.Build("Stone", 1, {}):GetAttribute("AssetId") == 111, "other elements use Default")
expect(GolemModel.Build("Stone", 5, {}):FindFirstChild("Halo") == nil and GolemModel.Build("Stone", 5, {}):FindFirstChild("Halo") == nil, "tierAddOns=false skips the halo")
AssetData.Golem.Elements.Ember.assetId = 0

print("== single mesh becomes Static (bob and sway)")
insertResults[111] = function() return container(newModel({ "Body" })) end
D.tierAddOns = true
reset()
Loader.Init()
expect(rs:FindFirstChild("GolemAssets"):FindFirstChild("Default"):GetAttribute("RigMode") == "Static", "no arms -> Static")

print("== rigged model with animations becomes Skinned")
D.animations = { Idle = 0, Mine = 222, Walk = 333 }
local tracks = {}
insertResults[111] = function() return container(newModel({ "Root", "Torso", "ArmR" }, function(x)
    Instance.new("Motor6D").Parent = x
    local ctl = Instance.new("AnimationController"); ctl.Parent = x
    local an = Instance.new("Animator"); an.Parent = ctl
    an.LoadAnimation = function(_, anim)
        local t = { id = anim.AnimationId, speed = 1, Play = function(self) self.playing = true end,
            AdjustSpeed = function(self, v) self.speed = v end }
        table.insert(tracks, t)
        return t
    end
end)) end
reset()
Loader.Init()
tpl = rs:FindFirstChild("GolemAssets"):FindFirstChild("Default")
expect(tpl:GetAttribute("RigMode") == "Skinned", "rig + animation ids -> Skinned")
expect(tpl:GetAttribute("AnimMine") == "rbxassetid://222" and tpl:GetAttribute("AnimWalk") == "rbxassetid://333" and tpl:GetAttribute("AnimIdle") == nil, "animation ids stored as attributes")
local sk = GolemModel.Build("Storm", 2, { accessory = "GolemAccessory_MinerHelm" })
expect(sk:FindFirstChild("Root").Anchored == false and sk:FindFirstChild("ArmR").Anchored == false, "skinned parts are free to move")
expect(sk.PrimaryPart.Anchored == true, "the root is anchored")
expect(sk:FindFirstChild("Helm") ~= nil and sk:FindFirstChild("Helm"):FindFirstChildOfClass("WeldConstraint") ~= nil, "accessory is welded to the skeleton")

print("== failures fall back to the block Golem, loudly")
tpl:Destroy()
insertResults[111] = "HTTP 403 forbidden"
reset()
Loader.Init()
expect(saw(warns, "FAILED to load") and saw(warns, "block Golem"), "load failure is warned")
expect(rs:FindFirstChild("GolemAssets"):FindFirstChild("Default") == nil, "nothing placed")
expect(GolemModel.Build("Ember", 1, {}):FindFirstChild("Torso") ~= nil, "falls back to blocks")

insertResults[111] = function() return container(Instance.new("Folder")) end
reset()
Loader.Init()
expect(saw(warns, "contains no parts"), "empty asset is rejected")

local bad = newModel({ "Torso" }, function(x) x.GetExtentsSize = function() return Vector3.new(0, 0, 0) end end)
insertResults[111] = function() return container(bad) end
reset()
Loader.Init()
expect(rs:FindFirstChild("GolemAssets"):FindFirstChild("Default") ~= nil, "zero-height asset still loads")
local fb = GolemModel.Build("Stone", 1, {})
expect(fb:FindFirstChild("Torso") ~= nil and fb:GetAttribute("RigMode") == nil, "unusable asset falls back to blocks")
expect(saw(warns, "could not use the loaded"), "and says why")

print("== GolemAnimator moves each mode")
D.tierAddOns = true
local Animator = load("SPS/EmberForge/Controllers/GolemAnimator")
local world = Instance.new("Folder"); world.Name = "EmberWorld"; world.Parent = workspace
local dep = Instance.new("Folder"); dep.Name = "DeployedGolems"; dep.Parent = world
Animator.Init()
local function deploy(mode, arms)
    local mdl = Instance.new("Model")
    mdl:SetAttribute("Base", CFrame.new(0, 0, 0)); mdl:SetAttribute("Scale", 1); mdl:SetAttribute("Phase", 0.5)
    if mode then mdl:SetAttribute("RigMode", mode) end
    for _, n in ipairs(arms or {}) do newPart(mdl, n) end
    return mdl
end
local function add(m) m.Parent = dep; dep.ChildAdded:Fire(m) end
local runStep = game:GetService("RunService").RenderStepped

local blockM = deploy(nil, { "ArmL", "ArmR", "PickHandle", "PickHead" })
add(blockM)
local partsM = deploy("Parts", { "ArmL", "ArmR", "PickHandle", "PickHead" })
add(partsM)
local staticM = deploy("Static", { "Body" })
add(staticM)
local skinM = deploy("Skinned", {})
skinM:SetAttribute("AnimMine", "rbxassetid://222")
local an = Instance.new("Animator"); local ctl = Instance.new("AnimationController"); an.Parent = ctl; ctl.Parent = skinM
local played
skinM.FindFirstChildWhichIsA = function(_, c) if c == "Animator" then return an end end
an.LoadAnimation = function(_, a) played = { id = a.AnimationId, speed = 1, Play = function(self) self.on = true end, AdjustSpeed = function(self, v) self.speed = v end } return played end
add(skinM)
runStep:Fire()
expect(blockM:FindFirstChild("ArmR").CFrame ~= nil, "block Golem arms still swing")
expect(partsM:FindFirstChild("ArmR").CFrame ~= nil and partsM:FindFirstChild("PickHead").CFrame ~= nil, "Parts model swings arm and pickaxe")
expect(staticM._pivot ~= nil, "Static model bobs (PivotTo called)")
expect(played ~= nil and played.id == "rbxassetid://222" and played.on and played.Looped == true, "Skinned model plays its Mine animation, looped")
expect(played.speed > 0, "animation runs while near")

print = realPrint
if FAILED then print("FAILED: " .. FAILED) os.exit(1) end
print("ALL PASSED")
