-- The look of each place: ambient light, haze and colour grade. LookController blends to the mood of wherever the player is, so the hub is warm and bright,
-- every mining cave has its own colour, the Sky Tower is open sky that changes zone by zone, and the Hollow Maze gets darker and stranger section by section.
-- Pure data (colours are {r, g, b} 0-255) so a test can check every mood is complete.
local MoodData = {}

MoodData.SHADOWS = true            -- real shadows give the world depth; set false if low-end phones struggle
MoodData.BLEND_SECONDS = 1.6
MoodData.MAX_LIGHT = 2.6          -- the most any mood may light the world: brightness x 2^exposure (a test holds every mood to it; the old murky cavern was 1.0)       -- how long a change of mood takes to fade in

local function M(t) return t end

-- ambient / outdoor: fill light colour. brightness, exposure: overall light. haze: atmosphere density, offset, colour, decay.
-- tint / sat / contrast: the colour grade. bloom: glow on bright things (intensity, size, threshold).
MoodData.Moods = {
    -- the hub: a warm, bright cavern (was a murky brown)
    Hub = M{ ambient = { 150, 112, 96 }, outdoor = { 150, 112, 96 }, brightness = 2.0, exposure = 0.25,
        density = 0.28, offset = 0.1, haze = 1.2, atmColor = { 214, 150, 112 }, atmDecay = { 130, 66, 44 },
        tint = { 255, 238, 220 }, sat = 0.18, contrast = 0.12, bloomI = 0.55, bloomSize = 28, bloomThreshold = 1.0 },

    -- the six mining caves, one colour each
    Ember = M{ ambient = { 160, 96, 70 }, outdoor = { 160, 96, 70 }, brightness = 2.0, exposure = 0.25,
        density = 0.34, offset = 0.1, haze = 1.6, atmColor = { 230, 120, 70 }, atmDecay = { 150, 50, 30 },
        tint = { 255, 226, 205 }, sat = 0.24, contrast = 0.14, bloomI = 0.7, bloomSize = 30, bloomThreshold = 0.95 },
    Stone = M{ ambient = { 128, 124, 120 }, outdoor = { 128, 124, 120 }, brightness = 2.0, exposure = 0.2,
        density = 0.28, offset = 0.1, haze = 1.0, atmColor = { 170, 160, 150 }, atmDecay = { 100, 92, 86 },
        tint = { 250, 244, 236 }, sat = 0.12, contrast = 0.12, bloomI = 0.4, bloomSize = 24, bloomThreshold = 1.0 },
    Frost = M{ ambient = { 120, 150, 184 }, outdoor = { 120, 150, 184 }, brightness = 2.1, exposure = 0.2,
        density = 0.26, offset = 0.1, haze = 0.9, atmColor = { 170, 205, 240 }, atmDecay = { 100, 140, 190 },
        tint = { 232, 244, 255 }, sat = 0.2, contrast = 0.1, bloomI = 0.6, bloomSize = 30, bloomThreshold = 0.95 },
    Storm = M{ ambient = { 112, 108, 150 }, outdoor = { 112, 108, 150 }, brightness = 2.0, exposure = 0.25,
        density = 0.32, offset = 0.1, haze = 1.4, atmColor = { 150, 140, 210 }, atmDecay = { 80, 70, 140 },
        tint = { 240, 236, 255 }, sat = 0.22, contrast = 0.16, bloomI = 0.75, bloomSize = 32, bloomThreshold = 0.9 },
    Void = M{ ambient = { 96, 70, 130 }, outdoor = { 96, 70, 130 }, brightness = 1.8, exposure = 0.2,
        density = 0.4, offset = 0.1, haze = 1.8, atmColor = { 120, 70, 190 }, atmDecay = { 50, 24, 96 },
        tint = { 238, 228, 255 }, sat = 0.2, contrast = 0.18, bloomI = 0.85, bloomSize = 34, bloomThreshold = 0.9 },
    DeepForge = M{ ambient = { 150, 120, 80 }, outdoor = { 150, 120, 80 }, brightness = 2.0, exposure = 0.25,
        density = 0.3, offset = 0.1, haze = 1.2, atmColor = { 230, 190, 100 }, atmDecay = { 140, 96, 40 },
        tint = { 255, 240, 214 }, sat = 0.22, contrast = 0.14, bloomI = 0.7, bloomSize = 30, bloomThreshold = 0.95 },

    -- the Sky Tower: open sky, a colour per zone as you climb (the element of each zone). Kept well under MoodData.MAX_LIGHT: the first version was so bright the pale
    -- zones washed out and platforms could not be seen against the sky.
    TowerLobby = M{ ambient = { 170, 175, 190 }, outdoor = { 170, 175, 190 }, brightness = 2.1, exposure = 0.05,
        density = 0.2, offset = 0.0, haze = 0.5, atmColor = { 190, 215, 245 }, atmDecay = { 150, 170, 210 },
        tint = { 255, 252, 246 }, sat = 0.2, contrast = 0.14, bloomI = 0.3, bloomSize = 26, bloomThreshold = 1.1 },
    TowerStone = M{ ambient = { 170, 168, 160 }, outdoor = { 170, 168, 160 }, brightness = 2.0, exposure = 0.0,
        density = 0.22, offset = 0.0, haze = 0.6, atmColor = { 205, 200, 190 }, atmDecay = { 160, 150, 140 },
        tint = { 255, 250, 240 }, sat = 0.18, contrast = 0.16, bloomI = 0.25, bloomSize = 24, bloomThreshold = 1.1 },
    TowerEmber = M{ ambient = { 190, 150, 120 }, outdoor = { 190, 150, 120 }, brightness = 2.1, exposure = 0.05,
        density = 0.28, offset = 0.0, haze = 0.9, atmColor = { 250, 170, 110 }, atmDecay = { 200, 100, 60 },
        tint = { 255, 232, 210 }, sat = 0.26, contrast = 0.18, bloomI = 0.4, bloomSize = 30, bloomThreshold = 1.05 },
    TowerFrost = M{ ambient = { 160, 185, 215 }, outdoor = { 160, 185, 215 }, brightness = 2.1, exposure = 0.05,
        density = 0.24, offset = 0.0, haze = 0.7, atmColor = { 190, 225, 255 }, atmDecay = { 140, 180, 230 },
        tint = { 236, 246, 255 }, sat = 0.22, contrast = 0.14, bloomI = 0.35, bloomSize = 28, bloomThreshold = 1.1 },
    TowerStorm = M{ ambient = { 140, 135, 185 }, outdoor = { 140, 135, 185 }, brightness = 1.9, exposure = 0.05,
        density = 0.34, offset = 0.0, haze = 1.2, atmColor = { 170, 160, 235 }, atmDecay = { 100, 90, 170 },
        tint = { 238, 234, 255 }, sat = 0.26, contrast = 0.22, bloomI = 0.5, bloomSize = 32, bloomThreshold = 1.0 },
    TowerVoid = M{ ambient = { 110, 85, 150 }, outdoor = { 110, 85, 150 }, brightness = 1.7, exposure = 0.0,
        density = 0.42, offset = 0.0, haze = 1.6, atmColor = { 130, 85, 200 }, atmDecay = { 70, 40, 120 },
        tint = { 238, 226, 255 }, sat = 0.24, contrast = 0.26, bloomI = 0.55, bloomSize = 34, bloomThreshold = 0.95 },

    -- the Foggy Peaks mutator: the zone's sky is swallowed by thick fog (you can only see a short way ahead)
    TowerFog = M{ ambient = { 150, 154, 170 }, outdoor = { 150, 154, 170 }, brightness = 2.2, exposure = 0.2,
        density = 0.72, offset = 0.0, haze = 4.0, atmColor = { 205, 210, 226 }, atmDecay = { 170, 176, 200 },
        tint = { 244, 246, 255 }, sat = 0.04, contrast = 0.04, bloomI = 0.3, bloomSize = 22, bloomThreshold = 1.0 },

    -- the Hollow Maze: a roofed cave, darker the deeper you go
    MazeStone = M{ ambient = { 96, 92, 90 }, outdoor = { 96, 92, 90 }, brightness = 1.6, exposure = 0.1,
        density = 0.38, offset = 0.1, haze = 1.8, atmColor = { 120, 112, 104 }, atmDecay = { 60, 56, 52 },
        tint = { 245, 240, 232 }, sat = 0.08, contrast = 0.16, bloomI = 0.4, bloomSize = 24, bloomThreshold = 1.0 },
    MazeEmber = M{ ambient = { 120, 70, 50 }, outdoor = { 120, 70, 50 }, brightness = 1.5, exposure = 0.1,
        density = 0.4, offset = 0.1, haze = 2.0, atmColor = { 190, 90, 50 }, atmDecay = { 110, 36, 20 },
        tint = { 255, 222, 200 }, sat = 0.18, contrast = 0.18, bloomI = 0.7, bloomSize = 30, bloomThreshold = 0.95 },
    MazeFrost = M{ ambient = { 90, 115, 150 }, outdoor = { 90, 115, 150 }, brightness = 1.6, exposure = 0.15,
        density = 0.36, offset = 0.1, haze = 1.6, atmColor = { 140, 180, 225 }, atmDecay = { 70, 100, 150 },
        tint = { 228, 240, 255 }, sat = 0.14, contrast = 0.16, bloomI = 0.6, bloomSize = 28, bloomThreshold = 0.95 },
    MazeStorm = M{ ambient = { 80, 78, 120 }, outdoor = { 80, 78, 120 }, brightness = 1.4, exposure = 0.1,
        density = 0.42, offset = 0.1, haze = 2.0, atmColor = { 120, 110, 190 }, atmDecay = { 56, 48, 110 },
        tint = { 236, 232, 255 }, sat = 0.18, contrast = 0.2, bloomI = 0.8, bloomSize = 32, bloomThreshold = 0.9 },
    MazeVoid = M{ ambient = { 64, 44, 96 }, outdoor = { 64, 44, 96 }, brightness = 1.2, exposure = 0.0,
        density = 0.5, offset = 0.1, haze = 2.4, atmColor = { 90, 50, 150 }, atmDecay = { 36, 16, 70 },
        tint = { 232, 220, 255 }, sat = 0.16, contrast = 0.24, bloomI = 0.9, bloomSize = 34, bloomThreshold = 0.85 },
}

-- the cave you are standing in, from where you stand: the six caves are in a row along the north side of the hub
MoodData.CAVE_ORDER   = { "Ember", "Stone", "Frost", "Storm", "Void", "DeepForge" }
MoodData.CAVE_SPACING = 140
MoodData.CAVE_Z       = 195        -- north of this is cave country (the hub's north wall, which the tunnels pierce, is at z = 190)
MoodData.TOWER_X      = 4000       -- beyond this east you are in the Sky Tower
MoodData.MAZE_X       = -4000      -- beyond this west you are in the Hollow Maze

-- the mood for a position: { x, y, z }; also returns the zone index (1-6) if it is a cave. Pure maths, tested.
function MoodData.CaveIndexAt(x)
    local n = #MoodData.CAVE_ORDER
    local i = math.floor((x + (n / 2) * MoodData.CAVE_SPACING) / MoodData.CAVE_SPACING) + 1
    return math.clamp(i, 1, n)
end

function MoodData.MoodAt(x, z)
    if x >= MoodData.TOWER_X then return "TowerLobby" end
    if x <= MoodData.MAZE_X then return "MazeStone" end
    if z >= MoodData.CAVE_Z then return MoodData.CAVE_ORDER[MoodData.CaveIndexAt(x)] end
    return "Hub"
end

-- Tower zones: five zones up the tower, one per element. The mood name for a level.
MoodData.TOWER_ZONES = { "Stone", "Ember", "Frost", "Storm", "Void" }
function MoodData.TowerMood(level, total)
    local n = #MoodData.TOWER_ZONES
    local zone = math.clamp(math.ceil((level / math.max(1, total)) * n), 1, n)
    return "Tower" .. MoodData.TOWER_ZONES[zone], zone
end

function MoodData.MazeMood(section)
    return "Maze" .. (({ "Stone", "Ember", "Frost", "Storm", "Void" })[math.clamp(section or 1, 1, 5)])
end

return MoodData
