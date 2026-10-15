-- Every forge decoration the game can give has a generated mesh and an animation spec, and the animation builder produces what it promises.
QUIET = true
-- the UI mock has no particle value types: tiny stand-ins so the effect builders can run
NumberRange = NumberRange or { new = function(a, b) return { Min = a, Max = b or a } end }
NumberSequence = NumberSequence or { new = function(a, b) return { a, b } end }
NumberSequenceKeypoint = NumberSequenceKeypoint or { new = function(t, v) return { t, v } end }
ColorSequence = ColorSequence or { new = function(a, b) return { a, b } end }
ColorSequenceKeypoint = ColorSequenceKeypoint or { new = function(t, c) return { t, c } end }
local CD = load("game/ReplicatedStorage/Shared/Data/CosmeticData")
local AD = load("game/ReplicatedStorage/Shared/Data/AssetData")
local Fx = load("SSS/EmberForge/Services/ForgeDecorFx")

local ids = {}
for _, file in ipairs({ "src/Shared/Data/CosmeticData.lua", "src/Shared/Data/SeasonData.lua" }) do
    for id in SOURCES[file]:gmatch('"(ForgeDecoration_[%w_]+)"') do ids[id] = true end
end
local list = {}
for id in pairs(ids) do table.insert(list, id) end
table.sort(list)

print("== every decoration is covered")
expect(#list >= 10, "the game has " .. #list .. " forge decorations")
for _, id in ipairs(list) do
    local mesh = AD.ForgeDecorationMeshes and AD.ForgeDecorationMeshes[id]
    expect(type(mesh) == "number" and mesh > 0, id .. " has a mesh (" .. tostring(mesh) .. ")")
    local spec = Fx.Specs[id]
    expect(spec and type(spec.height) == "number" and type(spec.fx) == "function", id .. " has an animation spec")
end

print("== every Forge Builder piece has a mesh")
local BD = SOURCES["src/Shared/Data/ForgeBuildData.lua"]
local pieces = {}
for id in BD:gmatch('id%s*=%s*"([%w]+)"') do pieces[id] = true end
local pack = {}
for _, name in ipairs({ "Workbench","OrePile","PickaxeRack","TrophyStatue","Throne","StorageShed","Signpost","QuenchBarrel","Waterwheel","Well","OreCrates","MoltenForge","MineEntrance","Fence",
    "BannerFlag","IronFurnace","Bellows","BarrelStack","ChimneyStack","Campfire","CrystalPedestal","CrystalCluster","Hearth","DisplayStand","MineCart","LanternPost","HammerRack","Grindstone","GemLamp","Fountain" }) do pack[name] = true end
for name, id in pairs(AD.BuildExtras or {}) do if id > 0 then pack[name] = true end end
local missing = {}
for id in pairs(pieces) do if not pack[id] then table.insert(missing, id) end end
table.sort(missing)
expect(#missing == 0, "no Forge Builder piece lacks a mesh (" .. table.concat(missing, ", ") .. ")")

print("== every skin family has its own house for every Forge level tier")
local houseIds, dupes = {}, {}
for _, fam in ipairs({ "default", "ember", "frost", "storm", "void", "ancient", "bronze" }) do
    local m = AD.ForgeSkinMeshes[fam]
    for tier = 1, 4 do
        local id = m and m["House" .. tier]
        expect(type(id) == "number" and id > 0, fam .. " has a House" .. tier .. " mesh (" .. tostring(id) .. ")")
        if id then
            if houseIds[id] then table.insert(dupes, fam .. " House" .. tier .. " = " .. houseIds[id]) end
            houseIds[id] = fam .. " House" .. tier
        end
    end
end
expect(#dupes == 0, "no two houses share a mesh, so skins differ in design and not only colour (" .. table.concat(dupes, ", ") .. ")")

print("== the animation builder")
-- a fake decoration stood in the test environment: Place is nil there (no ServerStorage assets), and every spec's fx must not error when given a context
local made = 0
for id, spec in pairs(Fx.Specs) do
    local parent = Instance.new("Model")
    local ctx = { parent = parent, h = spec.height, w = 4, d = 4, base = Vector3.new(0, 0, 0), top = Vector3.new(0, spec.height, 0) }
    function ctx.at(rx, ry, rz) return CFrame.new(rx * 2, ry * spec.height, rz * 2) end
    parent.FindFirstChildWhichIsA = function() return Instance.new("Part") end
    local ok, err = pcall(spec.fx, ctx)
    expect(ok, id .. " animation builds (" .. tostring(err) .. ")")
    if ok then made += 1 end
end
expect(made == #list, "all " .. #list .. " animations build")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
