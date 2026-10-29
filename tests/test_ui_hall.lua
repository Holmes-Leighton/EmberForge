-- The Hall of Legends: three statues beside the spawn showing what to chase.
QUIET = true
local Hall = load("SSS/EmberForge/Services/HallOfLegends")

print("== the layout")
local c = Hall.CENTRE
expect(#Hall.Statues == 3, "three statues")
local pos = {}
for _, s in ipairs(Hall.Statues) do pos[#pos + 1] = { id = s.id, x = c.x + s.dx, z = c.z + s.dz } end
local inClear = true
for _, p in ipairs(pos) do
    -- WorldBuilder keeps scenery off |x| < 60 and -105 < z < -20 near the spawn; a plinth is 15 wide
    if math.abs(p.x) + 7.5 > 60 or p.z - 7.5 < -105 or p.z + 7.5 > -20 then inClear = false end
end
expect(inClear, "every plinth sits inside the patch of hub kept clear of scenery")
local apart = true
for a = 1, #pos do
    for b = a + 1, #pos do
        local d = math.sqrt((pos[a].x - pos[b].x) ^ 2 + (pos[a].z - pos[b].z) ^ 2)
        if d < 16 then apart = false end
    end
end
expect(apart, "no two plinths touch")
local spawnX, spawnZ = 0, -60
local clearOfSpawn = true
for _, p in ipairs(pos) do
    if p.x - 7.5 < spawnX + 7 + 1 and p.z - 7.5 < spawnZ + 7 and p.z + 7.5 > spawnZ - 7 then clearOfSpawn = false end
end
expect(clearOfSpawn, "none sits on the spawn pad")
local anvilClear = true
for _, p in ipairs(pos) do if math.abs(p.x - 0) < 16 and math.abs(p.z + 100) < 14 then anvilClear = false end end
expect(anvilClear, "or on the Golem Anvil")
local nearSpawn = true
for _, p in ipairs(pos) do if math.sqrt((p.x - spawnX) ^ 2 + (p.z - spawnZ) ^ 2) > 70 then nearSpawn = false end end
expect(nearSpawn, "all within 70 studs of the spawn, so a new player sees them straight away")

print("== every statue says what it is and how to get it")
for _, s in ipairs(Hall.Statues) do
    expect(s.title and s.title == s.title:upper() and #s.how > 20, s.id .. ": title and a plain-words way to get it")
    expect(s.scale >= 1.8, s.id .. " is big (x" .. s.scale .. ")")
end
local GD = load("game/ReplicatedStorage/Shared/Data/GolemData")
expect(GD.Specials and GD.Specials.Maze ~= nil, "the Maze Golem it shows exists")

print("== building it")
local parent = Instance.new("Folder")
local ok, err = pcall(function() return Hall.Build(parent) end)
expect(ok, "it builds without errors" .. (ok and "" or (": " .. tostring(err))))
local function count(name)
    local n = 0
    for _, d in ipairs(parent:GetDescendants()) do if d.Name == name then n += 1 end end
    return n
end
expect(count("Plinth") == 3 and count("StatueBeam") == 3 and count("StatueRing") == 3, "three plinths, beams and glowing rings")
expect(count("PlaqueAnchor") == 3 and count("HallBanner") == 1, "three plaques and a banner over the hall")
local again = Hall.Build(parent)
local folders = 0
for _, ch in ipairs(parent:GetChildren()) do if ch.Name == "HallOfLegends" then folders += 1 end end
expect(folders == 1, "building again replaces the hall rather than doubling it")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
