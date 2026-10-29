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

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
