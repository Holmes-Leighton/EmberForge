QUIET = true
-- Golem life stages in the model: size, head proportion, code-made details per stage, and the stage-mesh lookup.
local RemoteEvents = installFakeRemotes({})
local rs = Instance.new("Folder")                        -- a ReplicatedStorage we can put stage meshes in (set up before GolemModel reads it)
rs.Name = "ReplicatedStorage"
local prevGetService = game.GetService
rawset(game, "GetService", function(_, n) if n == "ReplicatedStorage" then return rs end return prevGetService(game, n) end)
local GolemModel = load("game/ReplicatedStorage/Shared/Modules/GolemModel")
local GD = load("game/ReplicatedStorage/Shared/Data/GolemData")
local AssetData = load("game/ReplicatedStorage/Shared/Data/AssetData")

local function has(m, name) return m:FindFirstChild(name) ~= nil end
local function build(stage, tier, element, opts)
    local o = opts or {}
    o.stage = stage
    return GolemModel.Build(element or "Ember", tier or 1, o)
end

print("== every element, tier, stage and variant builds")
local built = 0
for _, el in ipairs({ "Ember", "Stone", "Frost", "Storm", "Void", "All", "Coral", "Dragonbone" }) do
    for tier = 1, 5 do
        for _, st in ipairs(GD.Stages) do
            for _, variant in ipairs({ false, "Neon", "MegaNeon" }) do
                local ok, err = pcall(GolemModel.Build, el, tier, { stage = st.id, variant = variant or nil, accessory = "GolemAccessory_LavaCrown" })
                if not ok then print("  FAIL", el, tier, st.id, variant, err) FAILED = (FAILED or 0) + 1 else built += 1 end
            end
        end
    end
end
expect(built == 8 * 5 * 5 * 3, "all " .. built .. " stage models build")

print("== size and head grow with the stage")
local torso = {}
for _, st in ipairs(GD.Stages) do torso[st.id] = build(st.id):FindFirstChild("Torso").Size.X end
expect(torso.Infant < torso.Young and torso.Young < torso.Adult and torso.Adult < torso.Elder and torso.Elder < torso.Ancient, "bodies get bigger every stage")
local S = GD.Stages
expect(math.abs(torso.Infant / torso.Adult - S[1].scale * S[1].body) < 1e-6 and math.abs(torso.Ancient / torso.Adult - S[5].scale * S[5].body) < 1e-6, "by the stage's scale and body width")
local ratio = function(st) local m = build(st) return m:FindFirstChild("Head").Size.X / m:FindFirstChild("Torso").Size.X end
expect(ratio("Infant") > ratio("Young") and ratio("Young") > ratio("Adult"), "a young Golem's head is big for its body")
local limbX = {}
for _, st in ipairs(S) do limbX[st.id] = build(st.id):FindFirstChild("Leg").Size.X / st.scale end
expect(math.abs(limbX.Infant / limbX.Adult - S[1].limb) < 1e-6 and math.abs(limbX.Ancient / limbX.Adult - S[5].limb) < 1e-6, "limbs are thicker for their size when young, and again when ancient")
expect(S[1].body > S[2].body and S[2].body > S[3].body and S[3].body < S[4].body and S[4].body < S[5].body, "the body is chubby young, slim at Adult and broadens with age: every stage differs")
for i = 2, #S do
    local a, b = S[i - 1], S[i]
    expect(a.head ~= b.head or a.body ~= b.body or a.limb ~= b.limb, a.id .. " -> " .. b.id .. " changes the proportions of the mesh itself")
end

print("== Adult is the unchanged look")
local plain, adult = GolemModel.Build("Ember", 2, {}), build("Adult", 2)
local function count(m) return #m:GetDescendants() end
expect(count(plain) == count(adult), "no stage and Adult build the same model (" .. count(plain) .. " parts)")
for _, n in ipairs({ "BabyEye", "SproutStem", "BudCrystal", "Beard", "Brow", "ChestRune", "AncientCrest", "GroundRing", "OrbitStone" }) do
    expect(not has(adult, n), "Adult has no " .. n)
end

print("== stage details")
local infant = build("Infant")
expect(has(infant, "BabyEye") and has(infant, "BabyPupil") and has(infant, "SproutStem") and has(infant, "SproutLeaf"), "Infant: big eyes and a sprout")
expect(not has(infant, "Beard") and not has(infant, "BudCrystal"), "Infant has nothing from the older stages")
local young = build("Young")
expect(has(young, "BudCrystal") and has(young, "YoungCrack") and not has(young, "SproutStem"), "Young: budding crystals, no sprout")
local elder = build("Elder")
expect(has(elder, "Beard") and has(elder, "Brow") and has(elder, "ChestRune") and has(elder, "ShoulderMoss"), "Elder: beard, brow, chest runes and moss")
expect(not has(elder, "AncientCrest") and not has(elder, "OrbitStone"), "Elder has no crest or orbiting stones yet")
expect(has(elder, "GroundRing"), "but an Elder has a glowing ring on the ground")
local ancient = build("Ancient")
expect(has(ancient, "Beard") and has(ancient, "ChestRune") and has(ancient, "AncientCrest") and has(ancient, "OrbitStone") and has(ancient, "OrbitRune") and has(ancient, "GroundRing"), "Ancient: all of Elder, plus a crest up the back and rune stones")
expect(count(infant) ~= count(elder) and count(elder) < count(ancient), "each stage is its own model (" .. count(infant) .. " / " .. count(elder) .. " / " .. count(ancient) .. " parts)")

print("== each element's stage dressing follows its colours")
local ember, frost = build("Elder", 1, "Ember"), build("Elder", 1, "Frost")
expect(ember:FindFirstChild("ChestRune").Color ~= frost:FindFirstChild("ChestRune").Color, "Ember and Frost runes glow differently")

print("== a mesh made for a stage wins, and skips the code dressing")
local gaFolder = Instance.new("Folder")
gaFolder.Name = "GolemAssets"
gaFolder.Parent = rs
local function addModel(name) local m = Instance.new("Model") m.Name = name m.Parent = gaFolder return m end
local defaultAdult, emberAdult = addModel("Default"), addModel("Ember")
local tpl, isStage = GolemModel.FindAsset("Frost", "Infant")
expect(tpl == defaultAdult and isStage == false, "with no stage mesh a type falls back to its Adult mesh (the shared body)")
tpl, isStage = GolemModel.FindAsset("Ember", "Elder")
expect(tpl == emberAdult and isStage == false, "a type with its own Adult mesh falls back to that")
local defaultInfant = addModel("Default_Infant")
tpl, isStage = GolemModel.FindAsset("Frost", "Infant")
expect(tpl == defaultInfant and isStage == true, "the shared Infant body is used by a type with no model of its own")
tpl, isStage = GolemModel.FindAsset("Ember", "Infant")
expect(tpl == emberAdult and isStage == false, "but a type with its own Adult model does not borrow the shared Infant body")
local emberInfant = addModel("Ember_Infant")
tpl, isStage = GolemModel.FindAsset("Ember", "Infant")
expect(tpl == emberInfant and isStage == true, "Ember's own Infant mesh is preferred")
tpl, isStage = GolemModel.FindAsset("Ember", "Adult")
expect(tpl == emberAdult and isStage == false, "Adult always uses the standard mesh")
tpl, isStage = GolemModel.FindAsset("Ember")
expect(tpl == emberAdult and isStage == false, "no stage = the standard mesh")
gaFolder:Destroy()

print("== the asset settings for stage packs")
for _, st in ipairs({ "Infant", "Young", "Elder", "Ancient" }) do
    expect(AssetData.StagePacks[st] and AssetData.StagePacks[st].assetId ~= nil, st .. " has a pack slot")
end
expect(AssetData.StagePacks.Adult == nil, "Adult needs no pack (it is the standard mesh)")
local entries = AssetData.StageEntries()
expect(entries.Default and entries.Ember and entries.Dragonbone and entries.Default.elementTint == AssetData.Golem.Default.elementTint, "stage entries cover Default and every type")
expect(entries.Ember.elementTint == 0, "a type's own stage mesh is not element-tinted")

print("== colours: duller when young, brighter glow when old, family kept")
local function lum(c) return c.R * 0.3 + c.G * 0.59 + c.B * 0.11 end
local body = {}
for _, st in ipairs(S) do body[st.id] = lum(build(st.id, 1, "Frost"):FindFirstChild("Torso").Color) end
expect(body.Infant < body.Young and body.Young < body.Adult, "the body colour deepens Infant -> Young -> Adult (" .. string.format("%.2f / %.2f / %.2f", body.Infant, body.Young, body.Adult) .. ")")
expect(math.abs(body.Elder - body.Adult) < 1e-9 and math.abs(body.Ancient - body.Adult) < 1e-9, "Elder and Ancient keep the full colour")
local accentOf = function(st) return build(st, 1, "Ember"):FindFirstChild("Crack") end
expect(build("Infant", 1, "Ember"):FindFirstChild("Crack").Color == build("Ancient", 1, "Ember"):FindFirstChild("Crack").Color, "the element's accent colour is the same at every stage (the family cue)")
local function lightRange(m) local t = m:FindFirstChild("Torso") local l = t and t:FindFirstChild("PointLight") return l and l.Range or 0 end
expect(lightRange(build("Adult")) == 0 and lightRange(build("Elder")) > 0 and lightRange(build("Ancient")) > lightRange(build("Elder")), "glow: none until Elder, stronger at Ancient")
local function moteRate(m) local t = m:FindFirstChild("Torso") local e = t and t:FindFirstChildOfClass("ParticleEmitter") return e and e.Rate or 0 end
expect(moteRate(build("Elder", 1, "Frost")) > 0 and moteRate(build("Ancient", 1, "Frost")) > moteRate(build("Elder", 1, "Frost")), "motes drift off an Elder and more off an Ancient")
expect(build("Ancient", 1, "Ember"):FindFirstChild("OrbitStone").Material ~= build("Ancient", 1, "Frost"):FindFirstChild("OrbitStone").Material, "orbiting stones are made of each element's own material")
local seen = {}
for _, st in ipairs(S) do local key = string.format("%.3f,%.3f,%.3f", st.color.R, st.color.G, st.color.B)
    expect(not seen[key], st.id .. " has its own badge colour")
    seen[key] = true
end

print("== nothing of age sits on the head, and slots do not clash")
local function headTopParts(m) local n = 0 for _, d in ipairs(m:GetChildren()) do if d.Name == "AncientCrystal" or d.Name == "AncientCrown" then n += 1 end end return n end
expect(headTopParts(build("Ancient")) == 0, "an Ancient wears no crown of its own on the head")
local crestY = build("Ancient", 1, "Ember"):FindFirstChild("AncientCrest")
local headY = build("Ancient", 1, "Ember"):FindFirstChild("Head")
expect(crestY.CFrame.Position.Z > 0 and crestY.CFrame.Position.Z > headY.CFrame.Position.Z - 0.001, "the crest is behind the Golem, up the back")
local elderElite = build("Elder", 1, "Ember", { variant = "Neon" })
local ancientHat = build("Ancient", 1, "Ember", { accessory = "GolemAccessory_LavaCrown" })
expect(has(ancientHat, "AncientCrest") and has(ancientHat, "GroundRing"), "an Ancient wearing a hat keeps its crest and ring (the head is the hat's)")
expect(has(elderElite, "GroundRing") and has(elderElite, "Beard"), "an Elite Elder still shows its age")
local ancientCrests = {}
for _, el in ipairs({ "Ember", "Frost", "Stone", "Storm", "Void" }) do
    local c = build("Ancient", 1, el):FindFirstChild("AncientCrest")
    ancientCrests[el] = tostring(c.Material) .. "/" .. string.format("%.2f", c.Size.X)
end
local distinct = {}
local n = 0
for _, v in pairs(ancientCrests) do if not distinct[v] then distinct[v] = true n += 1 end end
expect(n >= 4, "the crest differs by element family (" .. n .. " distinct looks among 5)")

print("== footprints")
local Animator = load("SPS/EmberForge/Controllers/GolemAnimator")
local P = Animator._Prints
expect(P ~= nil and P.cap > 0, "the animator exposes its footprint pool")
local function info(stage) return { stage = stage, dustColor = Color3.fromRGB(150, 140, 125), accent = Color3.fromRGB(255, 120, 40) } end
local function put(stage, t) P.Spawn(Vector3.new(1, 5, 2), 0, Vector3.new(0, 0, -1), 2, info(stage), t or 100) return P.list[#P.list] end
local infantPrint, adultPrint, elderPrint, ancientPrint = put("Infant"), put("Adult"), put("Elder"), put("Ancient")
expect(infantPrint.part.Size.X < adultPrint.part.Size.X and adultPrint.part.Size.X < ancientPrint.part.Size.X, "bigger Golems leave bigger prints")
expect(infantPrint.part.Material ~= Enum.Material.Neon and adultPrint.part.Material ~= Enum.Material.Neon, "young and Adult prints are plain dust")
expect(elderPrint.part.Material == Enum.Material.Neon and ancientPrint.part.Material == Enum.Material.Neon, "Elder and Ancient prints glow")
local want = info("Elder").accent
expect(math.abs(elderPrint.part.Color.R - want.R) < 1e-6 and math.abs(elderPrint.part.Color.G - want.G) < 1e-6 and math.abs(elderPrint.part.Color.B - want.B) < 1e-6, "in the Golem's own element colour")
expect(infantPrint.part.Color ~= info("Infant").accent, "while a young Golem's are dust coloured")
expect(infantPrint.life < adultPrint.life and adultPrint.life < elderPrint.life and elderPrint.life < ancientPrint.life, "the older the Golem, the longer its prints last")
expect(ancientPrint.alpha < elderPrint.alpha and elderPrint.alpha < adultPrint.alpha, "and the brighter they are")
expect(elderPrint.part.Parent ~= nil and elderPrint.part.Parent.Name == "Footprints", "prints are kept in one folder")
expect(ancientPrint.part.Size.Y < 0.1 and ancientPrint.part.CFrame.Position.Y < 0.2, "flat on the ground")
P.Fade(100 + 2.5)
expect(infantPrint.part.Parent == nil and adultPrint.part.Parent == nil and elderPrint.part.Parent ~= nil, "short-lived prints are gone after 2.5 s, the Elder's is still there")
expect(elderPrint.part.Transparency > elderPrint.alpha and elderPrint.part.Transparency < 1, "and fading")
P.Fade(100 + 8)
expect(#P.list == 0, "every print is gone after 8 s")
expect(#P.pool >= 4, "their parts go back to the pool (" .. #P.pool .. ")")
for i = 1, P.cap + 25 do put("Ancient", 200) end
expect(#P.list == P.cap, "never more than " .. P.cap .. " prints at once (" .. #P.list .. ")")
P.Fade(200 + 20)

print("== the inventory card shows the stage and a growth bar")
local Inv = load("SPS/EmberForge/Controllers/InventoryController")
local function card(g) return Inv._CreateGolemCard(g, 0) end
local infantCard = card({ id = "a", element = "Ember", tier = 1, grown = 1800 })
local lbl = infantCard:FindFirstChild("StageLabel")
expect(lbl and lbl.Text:find("Infant") and lbl.Text:find("50%% to Young"), "Infant card: " .. tostring(lbl and lbl.Text))
expect(math.abs(infantCard:FindFirstChild("GrowthBar"):GetChildren()[1].Size.X.Scale - 0.5) < 1e-6, "the growth bar is half full")
expect(card({ id = "b", element = "Stone", tier = 2 }):FindFirstChild("StageLabel").Text:find("Adult"), "an old Golem's card says Adult")
local ancientCard = card({ id = "c", element = "Frost", tier = 3, grown = 999 * 3600 })
expect(ancientCard:FindFirstChild("StageLabel").Text:find("fully grown") and ancientCard:FindFirstChild("GrowthBar"):GetChildren()[1].Size.X.Scale == 1, "an Ancient's card is fully grown")

print("== the collection card")
local seenData = { Golems = { { element = "Ember", tier = 1, grown = 60 * 3600 } }, GolemsSeen = { ["Frost:Infant"] = true } }
local lines = Inv._CollectionLines(seenData)
expect(lines.found == 5 and lines.total == 75 and lines.title:find("5 / 75"), "title counts the forms seen: " .. lines.title)
expect(#lines.rows == #GD.CollectionOrder, "one row per Golem type")
local emberRow
for _, r in ipairs(lines.rows) do if r.name == "Ember" then emberRow = r.text end end
local _, filled = emberRow:gsub("●", "")
local _, empty = emberRow:gsub("○", "")
expect(filled == 4 and empty == 1, "Ember shows 4 stages seen and 1 to find (" .. filled .. " / " .. empty .. ")")
local card = Inv._CreateCollectionCard(seenData, 0)
expect(card.Name == "CollectionCard" and card:FindFirstChild("Row_Ember") ~= nil and card:FindFirstChild("Row_Ember").RichText == true and card:FindFirstChild("Title") ~= nil, "the card builds with a title and a row per type")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
