-- Builds the Hollow Maze out of parts from a layout (MazeLayout): a floor and walls for each of the five sections (plain parts that collide, with the section's generated meshes
-- drawn on top by MazeSkin), a roof with lamps, decorations in the dead ends and corners, a lobby with the Zombie Golem's coffin, and the victory room beyond the exit.
-- Everything is static; the lights are tagged with a "MazeFx" attribute (flicker, flash, ember) that MazeController animates. See MAZE_DESIGN.md.
local MazeData   = require(game.ReplicatedStorage.Shared.Data.MazeData)
local MazeLayout = require(game.ReplicatedStorage.Shared.Modules.MazeLayout)
local MazeSkin   = require(script.Parent.MazeSkin)
local CourierArt = require(script.Parent.CourierArt)

local MazeArt = {}

local P, Sign = CourierArt.P, CourierArt.Sign

-- Each section's look. `decor` lists the decoration meshes with the height each stands (studs).
MazeArt.Themes = {
    Stone = { material = Enum.Material.Slate,        floor = Color3.fromRGB(112, 114, 120), wall = Color3.fromRGB(100, 104, 112), accent = Color3.fromRGB(120, 230, 200),
              lamp = Color3.fromRGB(255, 196, 120), fx = nil, wallTint = Color3.fromRGB(80, 78, 74),      -- (the painted brick is pink and bright green: a grey wash makes it read as old stone)
              decor = { { "Stone_Pillar", 9 }, { "Stone_Crystals", 5 }, { "Stone_Lantern", 8 }, { "Stone_Rocks", 3 } } },
    Ember = { material = Enum.Material.Basalt,       floor = Color3.fromRGB(58, 44, 42),    wall = Color3.fromRGB(44, 34, 34),    accent = Color3.fromRGB(255, 120, 40),
              lamp = Color3.fromRGB(255, 130, 60),  fx = "ember",
              decor = { { "Ember_LavaPool", 2 }, { "Ember_Brazier", 6 }, { "Ember_Spikes", 6 }, { "Ember_Coals", 3 } } },
    Frost = { material = Enum.Material.Ice,          floor = Color3.fromRGB(175, 218, 245), wall = Color3.fromRGB(150, 200, 235), accent = Color3.fromRGB(190, 240, 255),
              lamp = Color3.fromRGB(170, 220, 255), fx = nil, slippery = true,
              decor = { { "Frost_Crystals", 8 }, { "Frost_Drift", 3 }, { "Frost_Torch", 7 }, { "Frost_Pillar", 10 } } },
    Storm = { material = Enum.Material.Metal,        floor = Color3.fromRGB(74, 78, 90),    wall = Color3.fromRGB(60, 64, 78),    accent = Color3.fromRGB(190, 150, 255),
              lamp = Color3.fromRGB(190, 160, 255), fx = "flash",
              decor = { { "Storm_Tesla", 9 }, { "Storm_Rod", 12 }, { "Storm_Cables", 3 }, { "Storm_Generator", 4 } } },
    Void  = { material = Enum.Material.SmoothPlastic, floor = Color3.fromRGB(36, 26, 56),   wall = Color3.fromRGB(30, 22, 48),    accent = Color3.fromRGB(170, 90, 255),
              lamp = Color3.fromRGB(170, 90, 255),  fx = "flicker",
              decor = { { "Void_Shards", 7 }, { "Void_Rift", 6 }, { "Void_Spire", 10 }, { "Void_Altar", 3 } } },
}

local LOBBY_DEPTH = 40
local VICTORY_DEPTH = 36

-- A mesh piece scaled by its height (so its proportions stay as the artist made them); falls back to `fallback` sized at the same height until the mesh has loaded
local function FitHeight(name, height, fallbackWidth)
    return function(template)
        if template then
            local n = template.MeshSize
            local k = height / math.max(n.Y, 0.01)
            return Vector3.new(n.X * k, height, n.Z * k)
        end
        return Vector3.new(fallbackWidth, height, fallbackWidth)
    end
end

-- A mesh piece whose size depends on the loaded mesh (resolved by MazeSkin once it is in)
local function PieceFit(name, fit, cf, parent, hide, tint)
    return MazeSkin.Piece(name, fit, cf, parent, hide, tint)
end

local function Lamp(parent, pos, theme, fxKind)
    local lamp = P({ Name = "MazeLamp", Material = Enum.Material.Neon, Color = theme.lamp, Size = Vector3.new(2.4, 0.6, 2.4), CanCollide = false, CanQuery = false,
        CFrame = CFrame.new(pos) }, parent)
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness, light.Shadows = theme.lamp, 30, 1.3, false
    light.Parent = lamp
    if fxKind then lamp:SetAttribute("MazeFx", fxKind) end
    return lamp
end

-- Builds the maze under `parent`. Returns { folder, door, lobbySpawn, zombieHome, exitX, victorySpawn, base }.
function MazeArt.Build(parent, M)
    MazeSkin.Clear()
    local root = Instance.new("Folder")
    root.Name = "MazeRoot"
    local floors, walls, decor, lights, extras = Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder")
    floors.Name, walls.Name, decor.Name, lights.Name, extras.Name = "Floors", "Walls", "Decor", "Lights", "Extras"
    for _, f in ipairs({ floors, walls, decor, lights, extras }) do f.Parent = root end

    local base = M.base
    local cell, H, T = M.cell, MazeData.WALL_H, MazeData.WALL_T
    local zTop = base.z - M.height * cell / 2
    local mazeW, mazeD = M.width * cell, M.height * cell
    local rng = Random.new(M.seed)

    -- ── floors and roofs, one plain part per section (the collision) with a mesh tile over every cell ──
    for s = 1, M.sections do
        local theme = MazeArt.Themes[MazeData.SECTIONS[s]]
        local x0 = base.x + (s - 1) * M.cols * cell
        local w = M.cols * cell
        local floor = P({ Name = "Floor_" .. MazeData.SECTIONS[s], Material = theme.material, Color = theme.floor, Size = Vector3.new(w, 1, mazeD),
            CFrame = CFrame.new(x0 + w / 2, base.y - 0.5, base.z) }, floors)
        if theme.slippery then floor.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.03, 0, 1, 1) end      -- ice: you slide
        local tiles = {}
        for cx = (s - 1) * M.cols + 1, s * M.cols do
            for cy = 1, M.height do
                local wx, wy, wz = MazeLayout.CellCenter(M, cx, cy)
                MazeSkin.Piece("Floor_" .. MazeData.SECTIONS[s], Vector3.new(cell, 1, cell), CFrame.new(wx, base.y - 0.5, wz) * CFrame.Angles(0, math.rad(90 * ((cx + cy) % 4)), 0), floors, { floor })
            end
        end
        local roof = P({ Name = "Roof_" .. MazeData.SECTIONS[s], Material = Enum.Material.Slate, Color = Color3.fromRGB(34, 32, 40), Size = Vector3.new(w + T, 2, mazeD + T),
            CFrame = CFrame.new(x0 + w / 2, base.y + MazeData.ROOF_H + 1, base.z) }, floors)
        -- lamps on the roof every three cells
        for cx = (s - 1) * M.cols + 2, s * M.cols, 3 do
            for cy = 2, M.height, 3 do
                local wx, _, wz = MazeLayout.CellCenter(M, cx, cy)
                Lamp(lights, Vector3.new(wx, base.y + MazeData.ROOF_H - 0.2, wz), theme, theme.fx)
            end
        end
    end

    -- ── walls: a collision part for each straight run, and mesh pieces (two courses, one per cell) over it ──
    local wallRng = Random.new(M.seed + 17)
    for _, w in ipairs(MazeLayout.Walls(M)) do
        local theme = MazeArt.Themes[MazeData.SECTIONS[w.section]]
        local sx, sz = (w.along == "x") and (w.length + T) or T, (w.along == "x") and T or (w.length + T)
        local wall = P({ Name = "Wall_" .. MazeData.SECTIONS[w.section], Material = theme.material, Color = theme.wall, Size = Vector3.new(sx, H, sz), CFrame = CFrame.new(w.x, base.y + H / 2, w.z) }, walls)
        local units = math.floor(w.length / cell + 0.5)
        local rot = (w.along == "x") and 0 or math.pi / 2
        for k = 1, units do
            local along = -w.length / 2 + (k - 0.5) * cell
            local ox, oz = (w.along == "x") and along or 0, (w.along == "x") and 0 or along
            for course = 0, 1 do
                local flip = (wallRng:NextInteger(0, 1) == 1) and math.pi or 0
                MazeSkin.Piece("Wall_" .. MazeData.SECTIONS[w.section], Vector3.new(cell, H / 2, T), CFrame.new(w.x + ox, base.y + H / 4 + course * H / 2, w.z + oz) * CFrame.Angles(0, rot + flip, 0), walls, { wall }, theme.wallTint)
            end
        end
    end

    -- ── decorations: in dead ends and a few corners, never in the middle of a corridor (they do not collide, so they can never block one) ──
    local function Place(cx, cy, theme)
        local pick = theme.decor[rng:NextInteger(1, #theme.decor)]
        local wx, wy, wz = MazeLayout.CellCenter(M, cx, cy)
        local c = M.cells[cx][cy]
        -- tuck it into a corner of the cell: against a wall on each axis if there is one
        local off = cell / 2 - 3.2
        local dx = (c.W and -off) or (c.E and off) or (rng:NextInteger(0, 1) == 0 and -off or off)
        local dz = (c.N and -off) or (c.S and off) or (rng:NextInteger(0, 1) == 0 and -off or off)
        local yaw = math.atan2(-dx, -dz) + rng:NextNumber(-0.4, 0.4)
        local name, height = pick[1], pick[2]
        PieceFit(name, FitHeight(name, height, 3), CFrame.new(wx + dx, base.y + height / 2 - (name == "Ember_LavaPool" and 0.5 or 0), wz + dz) * CFrame.Angles(0, yaw, 0), decor, nil, nil)
        local theme = MazeArt.Themes[MazeData.SECTIONS[MazeLayout.SectionOf(M, cx)]]
        if name == "Ember_Brazier" or name == "Frost_Torch" or name == "Stone_Lantern" then      -- the ones that give light
            local lamp = Instance.new("PointLight")
            local holder = P({ Name = "DecorLight", Transparency = 1, CanCollide = false, CanQuery = false, Size = Vector3.new(0.5, 0.5, 0.5),
                CFrame = CFrame.new(wx + dx, base.y + height * 0.8, wz + dz) }, decor)
            lamp.Color, lamp.Range, lamp.Brightness, lamp.Shadows = theme.lamp, 22, 1.1, false
            lamp.Parent = holder
            if theme.fx == "ember" then holder:SetAttribute("MazeFx", "ember") end
        end
    end
    for _, e in ipairs(MazeLayout.DeadEnds(M)) do
        if not (e.x == M.start.x and e.y == M.start.y) and not (e.x == M.exit.x and e.y == M.exit.y) then
            Place(e.x, e.y, MazeArt.Themes[MazeData.SECTIONS[MazeLayout.SectionOf(M, e.x)]])
        end
    end
    for cx = 1, M.width do
        for cy = 1, M.height do
            if rng:NextNumber() < 0.12 and not (cx == M.start.x and cy == M.start.y) and not (cx == M.exit.x and cy == M.exit.y) then
                Place(cx, cy, MazeArt.Themes[MazeData.SECTIONS[MazeLayout.SectionOf(M, cx)]])
            end
        end
    end

    -- ── section signs: a glowing banner over the first doorway of each section ──
    for s = 1, M.sections do
        local theme = MazeArt.Themes[MazeData.SECTIONS[s]]
        local row = (s == 1) and M.start.y or M.gates[s - 1]
        local wx, _, wz = MazeLayout.CellCenter(M, (s - 1) * M.cols + 1, row)
        local board = P({ Name = "SectionSign", Transparency = 1, CanCollide = false, CanQuery = false, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(wx - cell / 2, base.y + H - 3, wz) }, extras)
        Sign(extras, board, string.upper(MazeData.SECTIONS[s]) .. (s == 1 and "" or ("  -  SECTION " .. s)), UDim2.new(0, 260, 0, 60), Vector3.new(0, 0, 0), theme.accent, 90)
    end

    -- ── the lobby (west of the entrance) and the victory room (east of the exit) ──
    local lobbyX = base.x - LOBBY_DEPTH / 2
    local lobbyTheme = MazeArt.Themes.Stone
    P({ Name = "LobbyFloor", Material = Enum.Material.Slate, Color = Color3.fromRGB(86, 90, 98), Size = Vector3.new(LOBBY_DEPTH, 1, mazeD), CFrame = CFrame.new(lobbyX, base.y - 0.5, base.z) }, extras)
    -- (the lobby and the victory room have no roof: the portals' pillars are taller than the maze's roof)
    for _, sz in ipairs({ -1, 1 }) do
        P({ Name = "LobbyWall", Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 74, 82), Size = Vector3.new(LOBBY_DEPTH + T, H, T), CFrame = CFrame.new(lobbyX, base.y + H / 2, base.z + sz * (mazeD / 2)) }, extras)
    end
    P({ Name = "LobbyWall", Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 74, 82), Size = Vector3.new(T, H, mazeD + T), CFrame = CFrame.new(base.x - LOBBY_DEPTH, base.y + H / 2, base.z) }, extras)
    for _, sz in ipairs({ -1, 1 }) do
        for i = 1, 3 do Lamp(lights, Vector3.new(lobbyX + (i - 2) * 11, base.y + 13, base.z + sz * (mazeD / 2 - 2)), lobbyTheme, nil) end
    end
    -- the gate: an energy barrier across the entrance that holds everyone in until the gate opens
    local _, _, startZ = MazeLayout.CellCenter(M, 1, M.start.y)
    local door = P({ Name = "MazeGate", Material = Enum.Material.Neon, Color = Color3.fromRGB(120, 255, 170), Transparency = 0.45, Size = Vector3.new(T, H, cell), CFrame = CFrame.new(base.x, base.y + H / 2, startZ) }, extras)
    -- the Zombie Golem's coffin, in the lobby corner on the other side from the entrance (the Zombie stands in front of the entrance, so it must not hide inside the coffin)
    local coffinSide = (startZ < base.z) and 1 or -1
    local coffinCF = CFrame.new(base.x - 8, base.y, base.z + coffinSide * (mazeD / 2 - 8)) * CFrame.Angles(0, math.rad(-90), 0)
    PieceFit("Coffin", FitHeight("Coffin", 14, 5), coffinCF * CFrame.new(0, 7, 0), extras, nil, nil)
    local zombieHome = Vector3.new(base.x - 8, base.y, startZ)

    local victoryX = base.x + mazeW + VICTORY_DEPTH / 2
    local _, _, exitZ = MazeLayout.CellCenter(M, M.width, M.exit.y)
    P({ Name = "VictoryFloor", Material = Enum.Material.Marble, Color = Color3.fromRGB(235, 228, 205), Size = Vector3.new(VICTORY_DEPTH, 1, mazeD), CFrame = CFrame.new(victoryX, base.y - 0.5, base.z) }, extras)
    for _, sz in ipairs({ -1, 1 }) do
        P({ Name = "VictoryWall", Material = Enum.Material.Marble, Color = Color3.fromRGB(205, 198, 175), Size = Vector3.new(VICTORY_DEPTH + T, H, T), CFrame = CFrame.new(victoryX, base.y + H / 2, base.z + sz * (mazeD / 2)) }, extras)
    end
    P({ Name = "VictoryWall", Material = Enum.Material.Marble, Color = Color3.fromRGB(205, 198, 175), Size = Vector3.new(T, H, mazeD + T), CFrame = CFrame.new(base.x + mazeW + VICTORY_DEPTH, base.y + H / 2, base.z) }, extras)
    for _, sz in ipairs({ -1, 1 }) do
        for i = 1, 3 do Lamp(lights, Vector3.new(victoryX + (i - 2) * 10, base.y + 13, base.z + sz * (mazeD / 2 - 2)), { lamp = Color3.fromRGB(255, 225, 140) }, nil) end
    end
    PieceFit("ExitArch", FitHeight("ExitArch", H, 14), CFrame.new(base.x + mazeW, base.y + H / 2, exitZ) * CFrame.Angles(0, math.pi / 2, 0), extras, nil, nil)

    root.Parent = parent
    return {
        folder = root, door = door, base = base,
        lobbySpawn = CFrame.lookAt(Vector3.new(base.x - LOBBY_DEPTH * 0.6, base.y + 4, startZ), Vector3.new(base.x, base.y + 4, startZ)),
        zombieHome = zombieHome, exitX = base.x + mazeW, victorySpawn = Vector3.new(victoryX, base.y + 4, base.z), victoryX = victoryX, lobbyDepth = LOBBY_DEPTH,
        victoryDepth = VICTORY_DEPTH,
    }
end

-- The Zombie Golem: the generated model if it has loaded, otherwise a plain block zombie. Returns the model, parented under `parent`, standing at `home`.
function MazeArt.Zombie(parent, home)
    local RS = game:GetService("ReplicatedStorage")
    local assets = RS:FindFirstChild("GolemAssets")
    local template = assets and assets:FindFirstChild("Zombie_Maze")
    local model
    if template then
        model = template:Clone()
        model.Name = "MazeZombie"
        local height = template:GetAttribute("Height") or 11
        local _, size = model:GetBoundingBox()
        if size.Y > 0.05 then model:ScaleTo(model:GetScale() * (height / size.Y)) end
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false end
        end
    else
        model = Instance.new("Model")
        model.Name = "MazeZombie"
        local green, dark = Color3.fromRGB(96, 140, 110), Color3.fromRGB(60, 90, 72)
        local function B(name, size, c, pos) return P({ Name = name, Material = Enum.Material.Slate, Color = c, Size = size, CanCollide = false, CanQuery = false, CFrame = CFrame.new(pos) }, model) end
        B("Torso", Vector3.new(4, 5, 2.4), green, Vector3.new(0, 6, 0))
        B("Head", Vector3.new(2.4, 2.2, 2.4), dark, Vector3.new(0, 9.4, 0))
        B("ArmL", Vector3.new(1.4, 5.5, 1.4), dark, Vector3.new(-3, 5.6, 0))
        B("ArmR", Vector3.new(1.4, 5.5, 1.4), dark, Vector3.new(3, 5.6, 0))
        B("Leg", Vector3.new(1.6, 3.4, 1.6), dark, Vector3.new(-1.1, 1.7, 0))
        B("Leg", Vector3.new(1.6, 3.4, 1.6), dark, Vector3.new(1.1, 1.7, 0))
        for _, side in ipairs({ -0.6, 0.6 }) do B("Eye", Vector3.new(0.5, 0.4, 0.2), Color3.fromRGB(120, 255, 120), Vector3.new(side, 9.5, -1.25)).Material = Enum.Material.Neon end
    end
    -- stand on the ground at `home`, facing east (into the maze)
    local box, size = model:GetBoundingBox()
    model:PivotTo(CFrame.new(home.X - box.Position.X, 0, home.Z - box.Position.Z) * CFrame.new(0, home.Y - (box.Position.Y - size.Y / 2), 0) * model:GetPivot())
    model:SetAttribute("Home", home)
    model.Parent = parent
    return model
end

return MazeArt
