-- Builds the Cart Run courses out of parts: the road, rails, rock tunnels, crusher gates, retracting bridges, checkpoints, a start sign and the depot.
-- Everything here is static. The moving pieces carry attributes and tags for the client (CartCourseController), which animates them on the shared clock:
--   "EFCourseCart"    the cart (CourseId, PathS, PathV, PathT, Jump) -- drawn smoothly by each client from the server's numbers
--   "EFCourseHazard"  a gate (Kind "Gate", a "Door" model that rises) or bridge (Kind "Bridge", a "Plate" model that sinks), with CourseId and HazardIndex
-- Every piece is a separate named part, so a mesh can replace any of them later without touching the rules.
local CollectionService = game:GetService("CollectionService")

local CartCourseData = require(game.ReplicatedStorage.Shared.Data.CartCourseData)
local CartPath       = require(game.ReplicatedStorage.Shared.Modules.CartPath)
local BiomeArt       = require(script.Parent.BiomeArt)
local SignArt        = require(script.Parent.SignArt)

local CartCourseArt = {}

local W        = CartCourseData.DECK_WIDTH
local RAIL_TOP = CartCourseData.RAIL_TOP
local DECK     = Color3.fromRGB(62, 50, 46)
local RAIL     = Color3.fromRGB(150, 148, 154)
local SLEEPER  = Color3.fromRGB(78, 54, 36)
local ROCK     = Color3.fromRGB(58, 42, 38)
local TIMBER   = Color3.fromRGB(100, 70, 44)
local IRON     = Color3.fromRGB(52, 52, 58)

local function P(props, parent)
    local p = Instance.new("Part")
    p.Anchored = true
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    for k, v in pairs(props) do p[k] = v end
    p.Parent = parent
    return p
end

-- horizontal "right" of a direction of travel
local function Right(tx, tz)
    local l = math.sqrt(tx * tx + tz * tz)
    if l < 1e-4 then return 1, 0 end
    return -tz / l, tx / l
end

local function Label(parent, adornee, text, size, offset, color, maxDistance)
    local gui = Instance.new("BillboardGui")
    gui.Name, gui.Adornee, gui.Size, gui.StudsOffset, gui.MaxDistance = "Sign", adornee, size, offset, maxDistance or 160
    gui.AlwaysOnTop = false
    gui.Parent = adornee                    -- (a billboard only draws from inside a part)
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Text"
    lbl.Size, lbl.BackgroundTransparency, lbl.Text = UDim2.new(1, 0, 1, 0), 1, text
    lbl.TextColor3, lbl.TextStrokeTransparency, lbl.Font = color or Color3.fromRGB(255, 220, 120), 0.3, Enum.Font.GothamBold
    lbl.TextScaled, lbl.TextWrapped = true, true
    lbl.Parent = gui
    return lbl
end

local function Lantern(parent, pos, color)
    local lamp = P({ Name = "TunnelLamp", Material = Enum.Material.Neon, Color = color or Color3.fromRGB(255, 190, 100), Size = Vector3.new(1.4, 2, 1.4),
        CFrame = CFrame.new(pos), CanCollide = false }, parent)
    local l = Instance.new("PointLight")
    l.Color, l.Range, l.Brightness = Color3.fromRGB(255, 190, 110), 40, 1.6
    l.Parent = lamp
end

local function InRange(s, ranges, pad)
    for _, r in ipairs(ranges) do
        if s >= r[1] - (pad or 0) and s <= r[2] + (pad or 0) then return true end
    end
    return false
end

local function GapRanges(r)
    local out = {}
    for _, h in ipairs(r.hazards) do
        if h.kind == "bridge" then table.insert(out, { h.s - h.length / 2, h.s + h.length / 2 }) end
    end
    return out
end

-- A timber frame across the road at distance s (tunnel mouths)
local function Frame(parent, r, s)
    local x, y, z, tx, ty, tz = CartPath.At(r.path, s)
    local rx, rz = Right(tx, tz)
    local dir = Vector3.new(tx, 0, tz)
    local H = CartCourseData.TUNNEL_HEIGHT
    for _, side in ipairs({ -1, 1 }) do
        local c = Vector3.new(x + rx * side * (W / 2 + 2), y + H / 2, z + rz * side * (W / 2 + 2))
        P({ Name = "FramePost", Material = Enum.Material.Wood, Color = TIMBER, Size = Vector3.new(3, H, 3), CFrame = CFrame.lookAt(c, c + dir) }, parent)
    end
    local c = Vector3.new(x, y + H + 1, z)
    P({ Name = "FrameBeam", Material = Enum.Material.Wood, Color = TIMBER, Size = Vector3.new(W + 10, 3, 3.4), CFrame = CFrame.lookAt(c, c + dir) }, parent)
end

-- ── Road, rails, tunnels ───────────────────────────────────────────────────────
local function BuildRoad(folder, r)
    -- Samples are closer together where the route bends (a 16-stud road cannot be drawn with 8-stud straight pieces round a 7-stud bend: the outside of every join
    -- would gape open), and every piece is lengthened by how far its outer edge swings away from the next piece.
    local samples = CartPath.AdaptiveSamples(r.path, 8, 1, 0.07)
    local gaps = GapRanges(r)
    local H = CartCourseData.TUNNEL_HEIGHT
    local deckFolder, railFolder, rockFolder = Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder")
    deckFolder.Name, railFolder.Name, rockFolder.Name = "Road", "Rails", "Tunnels"
    deckFolder.Parent, railFolder.Parent, rockFolder.Parent = folder, folder, folder
    local lastLampS, lastPillarS = -1e9, -1e9
    for i = 1, #samples - 1 do
        local a, b = samples[i], samples[i + 1]
        local va, vb = Vector3.new(a.x, a.y, a.z), Vector3.new(b.x, b.y, b.z)
        local mid, span = (va + vb) / 2, vb - va
        local chord = span.Magnitude
        local dir = span.Unit
        local midS = (a.s + b.s) / 2
        local cf = CFrame.lookAt(mid, mid + dir)
        -- how much the heading turns over this piece (radians): the outer edge of a piece W wide opens a gap of about W/2 * turn at each join
        local la, lb = math.sqrt(a.tx * a.tx + a.tz * a.tz), math.sqrt(b.tx * b.tx + b.tz * b.tz)
        local turn = 0
        if la > 1e-4 and lb > 1e-4 then turn = math.acos(math.clamp((a.tx * b.tx + a.tz * b.tz) / (la * lb), -1, 1)) end
        local function stretch(halfWidth) return chord + 0.5 + halfWidth * turn * 2 end
        if not InRange(midS, gaps) then
            P({ Name = "Deck", Material = Enum.Material.Slate, Color = DECK, Size = Vector3.new(W, 1, stretch(W / 2)), CFrame = cf * CFrame.new(0, -0.5, 0) }, deckFolder)
            if mid.Y > 3 and midS - lastPillarS >= 24 then                    -- a column holds up the raised road
                lastPillarS = midS
                P({ Name = "Pillar", Material = Enum.Material.Basalt, Color = ROCK, Size = Vector3.new(5, mid.Y - 1, 5),
                    CFrame = CFrame.new(mid.X, (mid.Y - 1) / 2, mid.Z) }, deckFolder)
            end
            -- each rail runs from where its own side of this sample is to where its side of the next one is (so it follows the bend instead of cutting across it)
            local rax, raz = Right(a.tx, a.tz)
            local rbx, rbz = Right(b.tx, b.tz)
            for _, off in ipairs({ -3, 3 }) do
                local pa = va + Vector3.new(rax * off, 0.4, raz * off)
                local pb = vb + Vector3.new(rbx * off, 0.4, rbz * off)
                local rmid = (pa + pb) / 2
                local rspan = pb - pa
                P({ Name = "Rail", Material = Enum.Material.Metal, Color = RAIL, Size = Vector3.new(0.5, 0.5, rspan.Magnitude + 0.3), CanCollide = false,
                    CFrame = CFrame.lookAt(rmid, rmid + rspan.Unit) }, railFolder)
            end
        end
        if InRange(midS, r.tunnels) then
            for _, side in ipairs({ -1, 1 }) do
                P({ Name = "TunnelWall", Material = Enum.Material.Basalt, Color = ROCK, Size = Vector3.new(3, H, stretch(W / 2 + 3)),
                    CFrame = cf * CFrame.new(side * (W / 2 + 1.5), H / 2, 0) }, rockFolder)
            end
            P({ Name = "TunnelRoof", Material = Enum.Material.Basalt, Color = ROCK, Size = Vector3.new(W + 8, 3, stretch(W / 2 + 4)),
                CFrame = cf * CFrame.new(0, H + 1.5, 0) }, rockFolder)
            if midS - lastLampS >= 32 then
                lastLampS = midS
                Lantern(rockFolder, (cf * CFrame.new(0, H - 2, 0)).Position, nil)
            end
        end
    end
    -- sleepers every few studs along the middle of the route (by distance, so a tight bend does not pile them up on its inside)
    local SLEEPER_EVERY = 4
    for s = SLEEPER_EVERY / 2, r.path.length, SLEEPER_EVERY do
        if not InRange(s, gaps) then
            local x, y, z, tx, ty, tz = CartPath.At(r.path, s)
            local pos = Vector3.new(x, y, z)
            local d = Vector3.new(tx, ty, tz)
            if d.Magnitude > 1e-4 then
                P({ Name = "Sleeper", Material = Enum.Material.Wood, Color = SLEEPER, Size = Vector3.new(10, 0.3, 1.2), CanCollide = false,
                    CFrame = CFrame.lookAt(pos + Vector3.new(0, 0.15, 0), pos + Vector3.new(0, 0.15, 0) + d.Unit) }, railFolder)
            end
        end
    end
    for _, t in ipairs(r.tunnels) do                                          -- timber frames at every tunnel mouth
        Frame(rockFolder, r, t[1])
        Frame(rockFolder, r, t[2])
    end
end

-- ── Hazards ───────────────────────────────────────────────────────────────────
local function Tag(unit, r, h, kind)
    unit:SetAttribute("Kind", kind)
    unit:SetAttribute("CourseId", r.id)
    unit:SetAttribute("HazardIndex", h.index)
    CollectionService:AddTag(unit, "EFCourseHazard")
end

local function BuildGate(folder, r, h)
    local x, y, z, tx, _, tz = CartPath.At(r.path, h.s)
    local rx, rz = Right(tx, tz)
    local dir = Vector3.new(tx, 0, tz).Unit
    local unit = Instance.new("Model")
    unit.Name = "Gate" .. h.index
    local function at(side, up) return Vector3.new(x + rx * side, y + up, z + rz * side) end
    for _, side in ipairs({ -1, 1 }) do
        local c = at(side * (W / 2 + 1.5), 17)
        P({ Name = "GatePillar", Material = Enum.Material.Basalt, Color = ROCK, Size = Vector3.new(3, 34, 3.4), CFrame = CFrame.lookAt(c, c + dir) }, unit)
        local lamp = P({ Name = "Lamp", Material = Enum.Material.Neon, Color = Color3.fromRGB(80, 255, 120), Size = Vector3.new(2, 2, 2), CanCollide = false,
            CFrame = CFrame.lookAt(at(side * (W / 2 + 1.5), 27), at(side * (W / 2 + 1.5), 27) + dir) }, unit)
        local l = Instance.new("PointLight")
        l.Color, l.Range, l.Brightness = Color3.fromRGB(255, 255, 255), 24, 1.2
        l.Parent = lamp
    end
    local lintelC = at(0, 34)
    P({ Name = "GateLintel", Material = Enum.Material.Basalt, Color = IRON, Size = Vector3.new(W + 8, 4, 3.4), CFrame = CFrame.lookAt(lintelC, lintelC + dir) }, unit)
    -- the door: a heavy slab with warning stripes. Closed it stands on the road; open it is raised clear of the cart (CartCourseController moves it).
    local door = Instance.new("Model")
    door.Name = "Door"
    local doorC = at(0, 9)
    local slab = P({ Name = "DoorSlab", Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 66, 72), Size = Vector3.new(W, 18, 2.5), CFrame = CFrame.lookAt(doorC, doorC + dir) }, door)
    for k = 0, 2 do
        local c = at(0, 3 + k * 6)
        P({ Name = "DoorStripe", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 150, 40), Size = Vector3.new(W - 1, 1.2, 2.7), CanCollide = false,
            CFrame = CFrame.lookAt(c, c + dir) }, door)
    end
    door.PrimaryPart = slab
    door.Parent = unit
    unit:SetAttribute("Lift", CartCourseData.GATE_CLEARANCE)
    Tag(unit, r, h, "Gate")
    unit.Parent = folder
end

local function BuildBridge(folder, r, h)
    local x, y, z, tx, ty, tz = CartPath.At(r.path, h.s)
    local rx, rz = Right(tx, tz)
    local dir = Vector3.new(tx, 0, tz).Unit
    local mid = Vector3.new(x, y, z)
    local cf = CFrame.lookAt(mid, mid + dir)
    local unit = Instance.new("Model")
    unit.Name = "Bridge" .. h.index
    -- the pit: glowing lava just above the floor, so a missing bridge looks like a gap
    local lava = P({ Name = "Lava", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 110, 30), Size = Vector3.new(W + 2, 0.3, h.length), CanCollide = false,
        CFrame = CFrame.lookAt(Vector3.new(x, 0.2, z), Vector3.new(x, 0.2, z) + dir) }, unit)
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 130, 50), 36, 1.6
    light.Parent = lava
    -- the bridge itself: a plate with its rails, which sinks into the floor when it is out of the way (the client moves the whole "Plate" model)
    local plate = Instance.new("Model")
    plate.Name = "Plate"
    local deck = P({ Name = "PlateDeck", Material = Enum.Material.Slate, Color = DECK, Size = Vector3.new(W, 1, h.length), CFrame = cf * CFrame.new(0, -0.5, 0) }, plate)
    local rightV = Vector3.new(rx, 0, rz)
    for _, off in ipairs({ -3, 3 }) do
        P({ Name = "Rail", Material = Enum.Material.Metal, Color = RAIL, Size = Vector3.new(0.5, 0.5, h.length), CanCollide = false,
            CFrame = CFrame.lookAt(mid + rightV * off + Vector3.new(0, 0.4, 0), mid + rightV * off + Vector3.new(0, 0.4, 0) + dir) }, plate)
    end
    for k = 0, math.floor(h.length / 8) do
        local local_z = -h.length / 2 + 4 + k * 8
        if local_z < h.length / 2 then
            P({ Name = "Sleeper", Material = Enum.Material.Wood, Color = SLEEPER, Size = Vector3.new(10, 0.3, 1.2), CanCollide = false, CFrame = cf * CFrame.new(0, 0.15, local_z) }, plate)
        end
    end
    plate.PrimaryPart = deck
    plate.Parent = unit
    -- warning lamps at both ends
    for _, end_ in ipairs({ -1, 1 }) do
        local c = mid + dir * (end_ * (h.length / 2 + 2)) + rightV * (W / 2 + 1) + Vector3.new(0, 4, 0)
        P({ Name = "Post", Material = Enum.Material.Wood, Color = TIMBER, Size = Vector3.new(1.4, 8, 1.4), CFrame = CFrame.new(c - Vector3.new(0, 2, 0)) }, unit)
        P({ Name = "Lamp", Material = Enum.Material.Neon, Color = Color3.fromRGB(80, 255, 120), Size = Vector3.new(2, 2, 2), CanCollide = false, CFrame = CFrame.new(c + Vector3.new(0, 2.5, 0)) }, unit)
    end
    unit:SetAttribute("Sink", 3.5)
    Tag(unit, r, h, "Bridge")
    unit.Parent = folder
end

-- ── Checkpoints, start, depot ─────────────────────────────────────────────────
local function BuildCheckpoint(folder, r, index, s)
    local x, y, z, tx, _, tz = CartPath.At(r.path, s)
    local rx, rz = Right(tx, tz)
    local dir = Vector3.new(tx, 0, tz).Unit
    local color = r.def.color or Color3.fromRGB(255, 220, 120)
    local unit = Instance.new("Model")
    unit.Name = "Checkpoint" .. index
    for _, side in ipairs({ -1, 1 }) do
        local c = Vector3.new(x + rx * side * (W / 2 + 1), y + 10, z + rz * side * (W / 2 + 1))
        P({ Name = "CheckpointPost", Material = Enum.Material.Wood, Color = TIMBER, Size = Vector3.new(1.6, 20, 1.6), CanCollide = false, CFrame = CFrame.lookAt(c, c + dir) }, unit)
    end
    local top = Vector3.new(x, y + 20, z)
    local banner = P({ Name = "CheckpointBanner", Material = Enum.Material.Neon, Color = color, Transparency = 0.15, Size = Vector3.new(W + 2, 3.2, 0.5), CanCollide = false,
        CFrame = CFrame.lookAt(top, top + dir) }, unit)
    Label(unit, banner, string.format("Checkpoint %d", index), UDim2.new(0, 170, 0, 34), Vector3.new(0, 3, 0), Color3.fromRGB(255, 255, 255), 140)
    unit.Parent = folder
end

local function Stars(tier)
    return string.rep("*", tier) .. string.rep("-", 3 - tier)
end

local function BuildStart(folder, r)
    local x, y, z, tx, _, tz = CartPath.At(r.path, 0)
    local rx, rz = Right(tx, tz)
    local color = r.def.color or Color3.fromRGB(255, 220, 120)
    local dir = Vector3.new(tx, 0, tz).Unit
    local unit = Instance.new("Model")
    unit.Name = "Start"
    -- a signpost beside the road and a tall beam so the start can be seen from across the cavern
    local post = Vector3.new(x + rx * (W / 2 + 6) - tx * 8, y + 9, z + rz * (W / 2 + 6) - tz * 8)
    P({ Name = "SignPost", Material = Enum.Material.Wood, Color = TIMBER, Size = Vector3.new(2, 18, 2), CFrame = CFrame.new(post) }, unit)
    local anchor = P({ Name = "SignAnchor", Transparency = 1, CanCollide = false, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(post + Vector3.new(0, 12, 0)) }, unit)
    local text = string.format("CART RUN: %s\n%s  Level %d+  Par %s", r.name, Stars(r.def.tier), r.def.minLevel,
        string.format("%d:%02d", math.floor(r.par) // 60, math.floor(r.par) % 60))
    Label(unit, anchor, text, UDim2.new(0, 300, 0, 64), Vector3.new(0, 0, 0), color, 90)
    P({ Name = "StartBeam", Material = Enum.Material.Neon, Color = color, Transparency = 0.65, Size = Vector3.new(3, 90, 3), CanCollide = false,
        CFrame = CFrame.new(post + Vector3.new(0, 36, 0)) }, unit)
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = color, 50, 1.5
    light.Parent = anchor
    unit.Parent = folder
end

-- The depot: a stone hall over the last stretch of rail. The cart is pushed inside and stops against the buffer at the far wall (the course ends at the
-- buffer, so it can't roll through). Hall length is DEPOT_LENGTH studs before the end of the rail, plus the buffer bay behind it.
CartCourseArt.DEPOT_LENGTH = 36

local function BuildDepot(folder, r)
    local x, y, z, tx, _, tz = CartPath.At(r.path, r.length)
    local color = r.def.color or Color3.fromRGB(255, 220, 120)
    local dir = Vector3.new(tx, 0, tz).Unit
    local f = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x, y, z) + dir)       -- local -Z is forward (towards the buffer), +X is to the right
    local unit = Instance.new("Model")
    unit.Name = "Depot"
    local H = 24
    local L = CartCourseArt.DEPOT_LENGTH
    local cz = (L - 6) / 2                                                           -- the hall runs from z = +L (entrance) to z = -6 (back wall)
    local len = L + 6

    local function block(name, size, offset, props)
        local part = P({ Name = name, Material = Enum.Material.Basalt, Color = ROCK, Size = size, CFrame = f * offset }, unit)
        if props then for k, v in pairs(props) do part[k] = v end end
        return part
    end
    -- floor that carries on to the back wall, walls, roof and back wall (all solid)
    block("DepotFloor", Vector3.new(W, 1, 6), CFrame.new(0, -0.5, -3), { Material = Enum.Material.Slate, Color = DECK })
    for _, side in ipairs({ -1, 1 }) do
        block("DepotWall", Vector3.new(3, H, len), CFrame.new(side * (W / 2 + 1.5), H / 2, cz))
    end
    block("DepotRoof", Vector3.new(W + 8, 3, len), CFrame.new(0, H + 1.5, cz))
    block("DepotBackWall", Vector3.new(W + 8, H + 3, 3), CFrame.new(0, (H + 3) / 2, -7.5))
    -- the entrance: timber frame and a big sign over it
    for _, side in ipairs({ -1, 1 }) do
        P({ Name = "DepotPost", Material = Enum.Material.Wood, Color = TIMBER, Size = Vector3.new(3.4, H + 2, 3.4), CFrame = f * CFrame.new(side * (W / 2 + 2.2), (H + 2) / 2, L + 1) }, unit)
    end
    local lintel = P({ Name = "DepotLintel", Material = Enum.Material.Wood, Color = TIMBER, Size = Vector3.new(W + 10, 5, 3.6), CFrame = f * CFrame.new(0, H + 2.5, L + 1) }, unit)
    local signPanel = P({ Name = "DepotSignPanel", Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(34, 22, 18), Size = Vector3.new(W, 4, 0.3), CanCollide = false,
        CFrame = f * CFrame.new(0, H + 2.5, L + 2.9) }, unit)
    local gui = Instance.new("SurfaceGui")
    gui.Name, gui.Face, gui.SizingMode, gui.PixelsPerStud = "Lettering", Enum.NormalId.Back, Enum.SurfaceGuiSizingMode.PixelsPerStud, 50
    gui.Parent = signPanel
    local word = Instance.new("TextLabel")
    word.Size, word.BackgroundTransparency, word.Text = UDim2.new(1, 0, 1, 0), 1, "DEPOT"
    word.TextColor3, word.Font, word.TextScaled = color, Enum.Font.GothamBlack, true
    word.Parent = gui
    -- the hall is a carved mesh (AssetData.SignMeshes.Depot); the plain walls, roof, back wall, posts and lintel go invisible but stay as the solid collision
    local hide = {}
    for _, c in ipairs(unit:GetChildren()) do
        if c.Name == "DepotWall" or c.Name == "DepotRoof" or c.Name == "DepotBackWall" or c.Name == "DepotPost" or c.Name == "DepotLintel" then table.insert(hide, c) end
    end
    SignArt.Piece("Depot", Vector3.new(W + 8, H + 5, len), f * CFrame.new(0, (H + 5) / 2 - 0.5, cz) * CFrame.Angles(0, math.pi, 0), unit, hide)
    -- the buffer stop at the end of the rail, where the cart's front comes to rest
    block("DepotBuffer", Vector3.new(W - 3, 4, 2), CFrame.new(0, 2, -5.4), { Material = Enum.Material.Metal, Color = IRON })
    for _, off in ipairs({ -5, 0, 5 }) do
        P({ Name = "BufferStripe", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 150, 40), Size = Vector3.new(2.4, 0.8, 2.2), CanCollide = false,
            CFrame = f * CFrame.new(off, 3.2, -5.4) }, unit)
    end
    -- the glowing floor marker where the cart parks, and warm light along the hall
    local disc = P({ Name = "DepotDisc", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = color, Transparency = 0.35, Size = Vector3.new(0.3, 12, 12), CanCollide = false,
        CFrame = f * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2) }, unit)
    local glow = Instance.new("PointLight")
    glow.Color, glow.Range, glow.Brightness = color, 40, 1.8
    glow.Parent = disc
    for k = 0, 2 do
        Lantern(unit, (f * CFrame.new(0, H - 3, L - 6 - k * 12)).Position, color)
    end
    unit.Parent = folder
end

-- Builds a course's whole static scenery under `parent`. Returns the folder.
function CartCourseArt.Build(parent, r)
    local folder = Instance.new("Folder")
    folder.Name = "CartRun_" .. r.id
    BuildRoad(folder, r)
    for _, h in ipairs(r.hazards) do
        if h.kind == "gate" then BuildGate(folder, r, h) else BuildBridge(folder, r, h) end
    end
    for i, s in ipairs(r.checkpoints) do BuildCheckpoint(folder, r, i, s) end
    BuildStart(folder, r)
    BuildDepot(folder, r)
    folder.Parent = parent
    return folder
end

-- A signpost near the spawn pointing east to the courses, which start 180 studs and more away along the south wall. A tall beam over the first course's start
-- (see BuildStart) can be seen from here, and the sign names the three courses with the level each needs.
-- Where it stands, and how far its board reaches along z (12) and its posts back from the board (3). It was at x = 48 until the Hall of Legends got its plaza (x 40 to 146), which it
-- stood in, a few studs from the Maze statue, hiding its plaque from the spawn: it now stands west of the plaza (a test keeps it clear).
CartCourseArt.SIGNPOST = { x = 26, z = -74, halfWidth = 12, depth = 3 }
function CartCourseArt.BuildSignpost(parent)
    local unit = Instance.new("Model")
    unit.Name = "CartRunSignpost"
    local base = Vector3.new(CartCourseArt.SIGNPOST.x, 0, CartCourseArt.SIGNPOST.z)
    -- the board faces west, towards the spawn; the posts stand BEHIND it (so nothing covers the lettering) and the words sit on a dark panel
    local boardPos = base + Vector3.new(0, 16, 0)
    local face = CFrame.lookAt(boardPos, boardPos + Vector3.new(-1, 0, 0))
    for _, dz in ipairs({ -8, 8 }) do
        SignArt.Post(P({ Name = "SignPost", Material = Enum.Material.Wood, Color = TIMBER, Size = Vector3.new(2, 15, 2), CFrame = CFrame.new(base + Vector3.new(2.2, 7.5, dz)) }, unit))
    end
    local board = P({ Name = "SignBoard", Material = Enum.Material.Wood, Color = Color3.fromRGB(120, 84, 52), Size = Vector3.new(24, 10.5, 1), CFrame = face }, unit)
    local stripe = P({ Name = "SignStripe", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 190, 80), Size = Vector3.new(24.4, 0.6, 1.1), CanCollide = false,
        CFrame = face * CFrame.new(0, 5.6, 0) }, unit)
    local panel = P({ Name = "SignPanel", Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(34, 22, 18), Size = Vector3.new(23, 9.5, 0.2), CanCollide = false,
        CFrame = face * CFrame.new(0, 0, -0.6) }, unit)
    local lines = { "CART RUNS  >>>" }
    for _, c in ipairs(CartCourseData.Courses) do
        table.insert(lines, string.format("%s   level %d+", c.name, c.minLevel))
    end
    local gui = Instance.new("SurfaceGui")
    gui.Name, gui.Face, gui.SizingMode, gui.PixelsPerStud = "Lettering", Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 50
    gui.Parent = panel
    if SignArt.Frame("Plank", panel).art then board.Transparency = 1 end      -- a plank-sign frame mesh replaces the plain board
    local text = Instance.new("TextLabel")
    text.Size, text.Position, text.BackgroundTransparency = UDim2.new(1, -40, 1, -30), UDim2.new(0, 20, 0, 15), 1
    text.Text = table.concat(lines, "\n")
    text.TextColor3, text.Font, text.TextScaled, text.TextXAlignment = Color3.fromRGB(255, 236, 180), Enum.Font.GothamBold, true, Enum.TextXAlignment.Left
    text.Parent = gui
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 200, 120), 40, 1.4
    light.Parent = stripe
    unit.Parent = parent
    return unit
end

-- ── The cart ──────────────────────────────────────────────────────────────────
-- Where the cart's body sits (and how it is turned) at distance s along the course
function CartCourseArt.CartCFrame(r, s)
    local x, y, z, fx, fy, fz, ux, uy, uz = CartPath.Frame(r.path, s)
    return CFrame.fromMatrix(Vector3.new(x, y + RAIL_TOP, z), Vector3.new(fx, fy, fz), Vector3.new(ux, uy, uz))
end

-- The cart for a course: its art plus an invisible solid body the size of the cart (so a player pushing it feels it, can't walk through it, and can't hop on:
-- the body is taller than a jump). There is no physics: every client moves the whole model from PathS / PathV / PathT, and each client's own character
-- collides with the body where that client draws it. Returns the model.
function CartCourseArt.BuildCart(parent, r, index)
    local model = Instance.new("Model")
    model.Name = "CartRunCart_" .. r.id
    local body = P({ Name = "Body", Transparency = 1, CanCollide = true, CanQuery = false, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 0.5, 0) }, model)
    model.PrimaryPart = body
    BiomeArt.MakeCartArt(model, { x = 0, z = 0, ore = r.def.color }, index)
    local art = model:FindFirstChild("CartArt")
    local center, size = CFrame.new(0, 0.5 + 3.5, 0), Vector3.new(8.6, 7, 6.6)
    if art then center, size = art:GetBoundingBox() end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and d ~= body then d.Anchored, d.CanCollide, d.CanQuery = true, false, false end
    end
    -- the solid body: as wide and as tall as the cart you see, resting where its wheels do; the model's pivot stays at the middle of the cart's base
    local solid = Vector3.new(math.max(size.X * 0.92, 6), math.max(size.Y, 6), math.max(size.Z * 0.92, 5))
    body.Size = solid
    body.CFrame = CFrame.new(center.Position.X, 0.5 + solid.Y / 2, center.Position.Z)
    body.PivotOffset = CFrame.new(-center.Position.X, -solid.Y / 2, -center.Position.Z)
    Label(model, body, string.format("%s  (level %d+)  Push me to the depot!", r.name, r.def.minLevel), UDim2.new(0, 280, 0, 44), Vector3.new(0, solid.Y / 2 + 2, 0), nil, 32)        -- (only close up: from a distance it printed over the start sign, which says the same)
    model:SetAttribute("CourseId", r.id)
    model:SetAttribute("PathS", 0)
    model:SetAttribute("PathV", 0)
    model:SetAttribute("PathT", 0)
    model:SetAttribute("Jump", 0)
    CollectionService:AddTag(model, "EFCourseCart")
    model:PivotTo(CartCourseArt.CartCFrame(r, 0))
    model.Parent = parent
    return model
end

return CartCourseArt
