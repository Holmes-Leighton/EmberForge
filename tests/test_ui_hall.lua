-- The Hall of Legends: its own plaza east of the spawn, three statues that never touch, and nothing else built on top of it.
QUIET = true
local Hall = load("SSS/EmberForge/Services/HallOfLegends")
local Cart = load("game/ReplicatedStorage/Shared/Data/CartCourseData")

print("== the plaza")
local A = Hall.AREA
expect(A.x2 - A.x1 >= 100 and A.z2 - A.z1 >= 30, "a real area (" .. (A.x2 - A.x1) .. " x " .. (A.z2 - A.z1) .. " studs)")
-- the hub's own rules (WorldBuilder): forge plots lie where |z| < 62 east of x = -45, the pad plaza at z < -105 for |x| < 140, the spawn pad is 14 wide at (0, -60)
expect(A.z2 < -62, "clear of the forge plots (the area ends at z = " .. A.z2 .. ", plots begin at -62)")
expect(A.z1 > -105 or math.abs(A.x1) > 140, "clear of the pad plaza (it starts at z = " .. A.z1 .. ")")
expect(A.x1 > 7 + 20, "clear of the spawn pad (it starts at x = " .. A.x1 .. ")")
expect(A.x2 + 4 < 175, "short of the scatter region that starts at x = 175")

local blocked = 0
for x = A.x1 - 12, A.x2 + 12, 4 do
    for z = A.z1 - 12, A.z2 + 12, 4 do
        if Cart.NearRoute(x, z, 24) then blocked += 1 end
    end
end
expect(blocked == 0, "no Cart Run route passes within 24 studs of it (" .. blocked .. " grid points on a route)")

local scatter = SOURCES["src/Server/Services/BiomeArt.lua"]
local clashes, regions = 0, 0
for x1, x2, z1, z2 in scatter:gmatch("{ x1 = (-?%d+), x2 = (-?%d+), z1 = (-?%d+), z2 = (-?%d+) }") do
    regions += 1
    x1, x2, z1, z2 = tonumber(x1), tonumber(x2), tonumber(z1), tonumber(z2)
    if x1 < A.x2 + 4 and x2 > A.x1 - 4 and z1 < A.z2 + 4 and z2 > A.z1 - 4 then clashes += 1 end
end
expect(regions >= 4 and clashes == 0, "none of the hub's " .. regions .. " scenery regions (rocks, crystals, crates) reach the plaza (" .. clashes .. " do)")
expect(SOURCES["src/Server/Services/WorldBuilder.lua"]:find("inHall", 1, true) ~= nil, "and the world builder's own stalagmites skip it")

print("== the statues")
local c = Hall.CENTRE
expect(#Hall.Statues == 3, "three statues")
local pos = {}
for _, s in ipairs(Hall.Statues) do pos[#pos + 1] = { id = s.id, x = c.x + s.dx, z = c.z + s.dz, scale = s.scale } end
local inside = true
for _, p in ipairs(pos) do
    local r = 10.5                                                          -- the glowing ring under each statue is 21 wide (and its plinth 15)
    if p.x - r < A.x1 or p.x + r > A.x2 or p.z - r < A.z1 or p.z + r > A.z2 then inside = false end
end
expect(inside, "every statue and its ring sits inside the plaza")
local gap = math.huge
for a = 1, #pos do
    for b = a + 1, #pos do
        gap = math.min(gap, math.sqrt((pos[a].x - pos[b].x) ^ 2 + (pos[a].z - pos[b].z) ^ 2) - 21)
    end
end
expect(gap >= 12, "their rings are at least 12 studs apart (" .. string.format("%.0f", gap) .. ") so no two statues overlap")
-- a statue at scale s stands about 9 * s studs wide at the shoulders: neighbours must not reach each other
local wide = true
for a = 1, #pos do
    for b = a + 1, #pos do
        local d = math.sqrt((pos[a].x - pos[b].x) ^ 2 + (pos[a].z - pos[b].z) ^ 2)
        if d < (pos[a].scale + pos[b].scale) * 4.5 + 6 then wide = false end
    end
end
expect(wide, "even the Golems themselves, at their full size, keep clear of each other")
local seen = 0
for _, p in ipairs(pos) do if math.sqrt((p.x - 0) ^ 2 + (p.z + 60) ^ 2) < 175 then seen += 1 end end
expect(seen == 3, "all three are within 175 studs of the spawn: the 70-stud beams are in view from it")
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
expect(count("HallFloor") == 1 and count("HallPost") == 4 and count("HallLamp") == 4, "a paved floor with four lit corner posts marks the area")
expect(count("HallEdge") >= 12, "and a dashed light along its edges (" .. count("HallEdge") .. ")")
expect(count("Plinth") == 3 and count("StatueBeam") == 3 and count("StatueRing") == 3, "three plinths, beams and glowing rings")
expect(count("PlaqueAnchor") == 3 and count("HallBanner") == 1, "three plaques and a banner over the hall")
-- the labels: sized in studs (so they shrink with distance instead of piling up on screen), one per statue, inside the statue's own width, and the banner clear above them
local guis, pixelSized, widest, plaqueTop = 0, 0, 0, 0
for _, d in ipairs(parent:GetDescendants()) do
    if d:IsA("BillboardGui") then
        guis += 1
        if d.Size.X.Offset ~= 0 or d.Size.Y.Offset ~= 0 then pixelSized += 1 end
        if d.Adornee and d.Adornee.Name == "PlaqueAnchor" then
            widest = math.max(widest, d.Size.X.Scale)
            plaqueTop = math.max(plaqueTop, d.Adornee.CFrame.Position.Y + d.Size.Y.Scale / 2)
        end
    end
end
expect(guis == 4 and pixelSized == 0, "four labels in all (a plaque per statue and the banner), every one sized in studs (" .. guis .. ", " .. pixelSized .. " in pixels)")
expect(widest <= Hall.SPACING - 3, "a plaque is " .. widest .. " studs wide, inside the " .. Hall.SPACING .. " between statues: neighbours never touch")
local bannerAnchor
for _, d in ipairs(parent:GetDescendants()) do if d.Name == "HallBanner" then bannerAnchor = d end end
expect(bannerAnchor and bannerAnchor.CFrame.Position.Y - 6.5 >= plaqueTop + 6, "the banner floats above the highest plaque (" .. tostring(bannerAnchor and bannerAnchor.CFrame.Position.Y) .. " vs plaque top " .. plaqueTop .. ")")
local plaqueRange, bannerRange = 0, 0
for _, d in ipairs(parent:GetDescendants()) do
    if d:IsA("BillboardGui") and d.Adornee then
        if d.Adornee.Name == "PlaqueAnchor" then plaqueRange = math.max(plaqueRange, d.MaxDistance) else bannerRange = d.MaxDistance end
    end
end
expect(plaqueRange <= 80 and bannerRange >= 200, "the plaques only show up close (" .. plaqueRange .. " studs: from the spawn the row of statues points at you and they would overlap), the banner from far off (" .. bannerRange .. ")")
expect(count("HowAnchor") == 0, "and the how-to-get-it text is part of the plaque, not a second label down among the Golem's legs")
Hall.Build(parent)
local folders = 0
for _, ch in ipairs(parent:GetChildren()) do if ch.Name == "HallOfLegends" then folders += 1 end end
expect(folders == 1, "building again replaces the hall rather than doubling it")

print("== nothing else stands in the plaza")
local CartArt = load("SSS/EmberForge/Services/CartCourseArt")
local sp = CartArt.SIGNPOST
local margin = 6
expect(sp.x + sp.depth + margin <= A.x1 or sp.x - sp.depth - margin >= A.x2 or sp.z + sp.halfWidth + margin <= A.z1 or sp.z - sp.halfWidth - margin >= A.z2,
    "the Cart Runs signpost (x " .. sp.x .. ", z " .. sp.z .. ", " .. sp.halfWidth * 2 .. " studs wide) stands clear of the hall (x " .. A.x1 .. " to " .. A.x2 .. ", z " .. A.z1 .. " to " .. A.z2 .. ") by at least " .. margin .. " studs")
local up = Instance.new("Folder")
local okSign = pcall(function() return CartArt.BuildSignpost(up) end)
expect(okSign, "and it still builds")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
