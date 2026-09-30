QUIET = true
local RemoteEvents = installFakeRemotes({})
RemoteEvents.Notify.FireClient = function() end

print("== every Golem model builds (5 elements + All, 5 tiers, variants, cosmetics)")
local GolemModel = load("game/ReplicatedStorage/Shared/Modules/GolemModel")
local built = 0
for _, el in ipairs({ "Ember", "Stone", "Frost", "Storm", "Void", "All" }) do
    for tier = 1, 5 do
        for _, variant in ipairs({ false, "Neon", "MegaNeon" }) do
            local ok, err = pcall(GolemModel.Build, el, tier, { variant = variant or nil, accessory = "GolemAccessory_LavaCrown", particle = "ParticleEffect_Sparks" })
            if not ok then print("  FAIL", el, tier, variant, err) FAILED = (FAILED or 0) + 1 else built += 1 end
        end
    end
end
expect(built == 6 * 5 * 3, "all " .. built .. " model variants build")
for _, acc in ipairs({ "GolemAccessory_MinerHelm", "GolemAccessory_FrostHat", "GolemAccessory_VoidOrb" }) do
    local ok = pcall(GolemModel.Build, "Ember", 3, { accessory = acc })
    expect(ok, "accessory style " .. acc)
end

print("== forge builds at every level with skins and decorations")
local ForgeBuilder = load("SSS/EmberForge/Services/ForgeBuilder")
local folder = Instance.new("Folder")
for level = 1, 10 do
    local ok, err = pcall(ForgeBuilder.Build, folder, Vector3.new(0, 10, 0), level, { ForgeSkin = "ForgeSkin_Ember_Basic", ForgeDecoration = "ForgeDecoration_Anvil" })
    if not ok then print("  FAIL level", level, err) FAILED = (FAILED or 0) + 1 end
end
local forge10 = ForgeBuilder.Build(folder, Vector3.new(0, 10, 0), 10, {})
expect(forge10:FindFirstChild("KilnDome") ~= nil and forge10:FindFirstChild("AuraRing") ~= nil, "level 10 has the kiln dome and aura ring")
local forge1 = ForgeBuilder.Build(folder, Vector3.new(0, 10, 0), 1, {})
expect(forge1:FindFirstChild("Furnace") ~= nil and forge1:FindFirstChild("Roof") == nil and forge1:FindFirstChild("ShedRoof") ~= nil, "level 1 is an open lean-to with no workshop roof")
local forge3 = ForgeBuilder.Build(folder, Vector3.new(0, 10, 0), 3, {})
expect(forge3:FindFirstChild("Roof") ~= nil and forge3:FindFirstChild("ShedRoof") == nil, "level 3 is an enclosed workshop")
local function count(m) return #m:GetDescendants() end
local prev = 0
local grows = true
for level = 1, 10 do
    local n = count(ForgeBuilder.Build(folder, Vector3.new(0, 10, 0), level, {}))
    if n < prev then grows = false end
    prev = n
end
expect(grows, "the forge never loses detail as it levels")
expect(count(ForgeBuilder.Build(folder, Vector3.new(0, 10, 0), 10, {})) > count(ForgeBuilder.Build(folder, Vector3.new(0, 10, 0), 1, {})) * 1.5, "level 10 is much bigger than level 1")
local withVault = ForgeBuilder.Build(folder, Vector3.new(0, 10, 0), 4, {}, { storageTier = 1 })
expect(withVault:FindFirstChild("VaultBody") ~= nil and ForgeBuilder.Build(folder, Vector3.new(0, 10, 0), 4, {}):FindFirstChild("VaultBody") == nil, "vault building only after the Storage Vault is built")
local gallery = ForgeBuilder.Build(folder, Vector3.new(0, 10, 0), 2, {}, { playerLevel = 30,
    golems = { { element = "Ember", tier = 1 }, { element = "Frost", tier = 3, variant = "Neon" } } })
local pedestals = 0
for _, c in ipairs(gallery:GetChildren()) do if c.Name == "Pedestal" then pedestals += 1 end end
expect(pedestals == 2 and gallery:FindFirstChild("Banner") ~= nil and gallery:FindFirstChild("Trophy") ~= nil, "gallery pedestals, banners and trophy follow Golems and player level")
expect(pcall(ForgeBuilder.Celebrate, forge10), "celebrate burst runs")
local forge8 = ForgeBuilder.Build(folder, Vector3.new(0, 10, 0), 8, {})
expect(forge8:FindFirstChild("Gear") ~= nil, "level 8 has machinery")

print("== the world builds")
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local WorldBuilder = load("SSS/EmberForge/Services/WorldBuilder")
local ok, err = pcall(WorldBuilder.Build)
expect(ok, "WorldBuilder.Build runs" .. (ok and "" or (": " .. tostring(err))))
local world = workspace:FindFirstChild("EmberWorld")
expect(world ~= nil and world:FindFirstChild("Ground") ~= nil, "ground exists")
for _, id in ipairs({ "EmberDepths", "GraniteCaverns", "GlacialPeaks", "StormriftCliffs", "TheHollow", "TheDeepForge" }) do
    expect(world:FindFirstChild("Zone_" .. id) ~= nil, "zone landmark " .. id)
end
expect(world:FindFirstChild("GolemAnvil") ~= nil, "golem anvil")
expect(world:FindFirstChild("DiscoveryBoard") ~= nil, "top forges board")
expect(WorldBuilder.GetZoneCenter("GlacialPeaks") ~= nil and WorldBuilder.GetZoneCenter("Nope") == nil, "zone centres resolve")

print("== pads and deployed golems")
local PadService = load("SSS/EmberForge/Services/PadService")
PadService.Init()
local pads = 0
for _, c in ipairs(world:GetChildren()) do if c.Name:find("^Pad_") then pads += 1 end end
expect(pads == 5, "five mining pads (" .. pads .. ")")

local GolemVisuals = load("SSS/EmberForge/Services/GolemVisuals")
GolemVisuals.Init()
local p = newPlayer(1, "Tester"); local data = PDS.Load(p)
data.Golems = { { id = "a1", element = "Frost", tier = 2, deployed = true, zoneId = "GlacialPeaks", variant = "Neon" },
                { id = "a2", element = "Ember", tier = 1, deployed = true, zoneId = "EmberDepths" } }
data.Equipped = { GolemAccessory = "GolemAccessory_LavaCrown" }
-- reconcile runs inside the module's loop; call it via the public loop by advancing one iteration manually
local visuals = world:FindFirstChild("DeployedGolems")
expect(visuals ~= nil, "DeployedGolems folder created")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
