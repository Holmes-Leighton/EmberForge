-- Builds a whole Sky Tower in the mock and checks the zone gates, boss banners and chests are there (a smoke test of TowerArt: the real look needs Studio).
QUIET = true
PhysicalProperties = { new = function() return {} end }          -- (the mock has no physics materials)
local TD  = load("game/ReplicatedStorage/Shared/Data/TowerData")
local TL  = load("game/ReplicatedStorage/Shared/Modules/TowerLayout")
local Art = load("SSS/EmberForge/Services/TowerArt")

local T = TL.Build({ levels = 30, seed = 21, base = TD.BASE })
local parent = Instance.new("Folder")
local ok, err = pcall(function() return Art.Build(parent, T) end)
expect(ok, "the tower builds without errors" .. (ok and "" or (": " .. tostring(err))))
if not ok then print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED") return end

local function count(name)
    local n = 0
    for _, d in ipairs(parent:GetDescendants()) do if d.Name == name then n += 1 end end
    return n
end
expect(count("GateLintel") == 5, "a gate at the start of the tower and of each of the next four zones (" .. count("GateLintel") .. ")")
expect(count("ChestBody") == 5, "a zone chest at the start of zones 2-5 and the summit chest (" .. count("ChestBody") .. ")")
expect(count("BossSign") == 5 and count("BossFlame") == 10, "a boss banner on each of the five bosses (" .. count("BossSign") .. " signs, " .. count("BossFlame") .. " flames)")
local levels = 0
for _, c in ipairs(parent:FindFirstChild("SkyTower"):GetChildren()) do if c.Name:find("^Level%d+$") then levels += 1 end end
expect(levels == 30, "30 level folders (" .. levels .. ")")

-- each level's sign carries its own zone colour, and the colours differ between zones
local colours = {}
for _, d in ipairs(parent:GetDescendants()) do
    if d.Name == "LevelBeam" then colours[#colours + 1] = d.Color end
end
expect(#colours == 30, "every level has a beam in its zone colour (" .. #colours .. ")")
local function key(c) return string.format("%.2f/%.2f/%.2f", c.R, c.G, c.B) end
local z1, z3 = key(colours[2]), key(colours[14])
expect(z1 ~= z3, "zone 1 and zone 3 look different (" .. z1 .. " vs " .. z3 .. ")")

-- the spiral ledges are drawn like any other platform
local ledgeParts = 0
for _, d in ipairs(parent:GetDescendants()) do if d:IsA("BasePart") and d.Name:lower():find("platform") then ledgeParts += 1 end end
expect(ledgeParts > 100, "platforms are drawn (" .. ledgeParts .. " parts named platform)")

print("== every level looks different")
local repeats, seenKinds = 0, {}
for seed = 1, 40 do
    for lvl = 2, 30 do
        local k = Art.EntranceKind(lvl, seed)
        seenKinds[k] = true
        if lvl > 2 and k == Art.EntranceKind(lvl - 1, seed) then repeats += 1 end
    end
end
local nKinds = 0 for _ in pairs(seenKinds) do nKinds += 1 end
expect(repeats == 0 and nKinds == #Art.ENTRANCES, "five kinds of doorway, never the same twice in a row (" .. nKinds .. " seen, " .. repeats .. " repeats)")
local entranceParts = { ArchLintel = 0, Lantern = 0, BannerCloth = 0, TorchFlame = 0 }
local rings = 0
for _, d in ipairs(parent:GetDescendants()) do
    if entranceParts[d.Name] then entranceParts[d.Name] += 1 end
    if d.Name == "RingBlock" then rings += 1 end
end
expect(entranceParts.ArchLintel > 0 and entranceParts.Lantern > 0 and entranceParts.BannerCloth > 0 and entranceParts.TorchFlame > 0 and rings > 0, "all five doorways turn up in one tower (arches " .. entranceParts.ArchLintel
    .. ", lanterns " .. entranceParts.Lantern .. ", banners " .. entranceParts.BannerCloth .. ", torches " .. entranceParts.TorchFlame .. ", ring blocks " .. rings .. ")")

local islands, solid, tooClose = 0, 0, 0
local zoneProps = { BackdropRock = 1, BackdropSpire = 2, BackdropIce = 3, BackdropOrb = 4, BackdropCube = 5 }
local zonesSeen = {}
for _, lvFolder in ipairs(parent:FindFirstChild("SkyTower"):GetChildren()) do
    if lvFolder.Name:find("^Level%d+$") then
        local level = tonumber(lvFolder.Name:match("%d+"))
        local zlo, zhi = 1e9, -1e9
        for _, p in ipairs(T.platforms) do
            if p.level == level then zlo, zhi = math.min(zlo, p.z - p.sz / 2), math.max(zhi, p.z + p.sz / 2) end
        end
        for _, d in ipairs(lvFolder:GetDescendants()) do
            if d.Name == "BackdropIsland" then
                islands += 1
                if d.CFrame.Position.Z - 22 < zhi and d.CFrame.Position.Z + 22 > zlo then tooClose += 1 end
            end
            if d.Name:find("^Backdrop") and d.CanCollide then solid += 1 end
            if zoneProps[d.Name] then zonesSeen[zoneProps[d.Name]] = true end
        end
    end
end
local nz = 0 for _ in pairs(zonesSeen) do nz += 1 end
expect(islands == 30, "every level has its own island beside the course (" .. islands .. ")")
expect(solid == 0, "and nothing on any of them is solid")
expect(tooClose == 0, "and none reaches over the climbing space (" .. tooClose .. " too close)")
expect(nz == 5, "each zone has its own scenery on the islands (" .. nz .. " of 5 kinds)")
local function islandPos(tw)
    local par = Instance.new("Folder")
    Art.Build(par, tw)
    local out = {}
    for _, d in ipairs(par:GetDescendants()) do if d.Name == "BackdropIsland" then out[#out + 1] = string.format("%.0f/%.0f/%.0f", d.CFrame.Position.X, d.CFrame.Position.Y, d.CFrame.Position.Z) end end
    return table.concat(out, ",")
end
expect(islandPos(T) == islandPos(T), "the scenery is the same every time for the same tower (every server sees the same one)")
local T2 = TL.Build({ levels = 30, seed = 22, base = TD.BASE })
expect(islandPos(T) ~= islandPos(T2), "and different from tower to tower")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
