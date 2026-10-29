-- Audio (spec 10.3). Every sound is an original made by tools/make_audio.py (files in audio/), uploaded with tools/upload_audio.py, which writes the Roblox asset ids to
-- AudioIds.lua. Until a sound has an id it is silent, except the few with a `builtin` fallback (a sound that ships inside the Roblox client, so it always exists).
--
-- IMPORTANT: use only audio you made, licensed for commercial use, or that Roblox provides for creators (see the 2022 audio-privacy change).
-- Fields: file = the name in audio/ (default: the key), volume, looped, pitch (playback speed), builtin (fallback asset path).
local AudioIds = require(script.Parent.AudioIds)

local AudioData = {}

AudioData.Sounds = {
    -- UI
    Click       = { volume = 0.35, builtin = "rbxasset://sounds/button.wav" },
    Notify      = { volume = 0.5,  builtin = "rbxasset://sounds/electronicpingshort.wav" },
    Error       = { volume = 0.4  },
    LevelUp     = { volume = 0.7  },
    Achievement = { volume = 0.7  },
    -- Gameplay
    Collect     = { volume = 0.5  },
    CoinPop     = { volume = 0.4  },           -- the little pop of a floating "+N" (played at a rising pitch for a run of them)
    RewardChest = { volume = 0.7  },
    Deploy      = { volume = 0.5  },
    Craft       = { volume = 0.6  },           -- tiers 1-2
    CraftRare   = { volume = 0.7  },           -- tiers 3+
    Neon        = { volume = 0.8  },
    Smelt       = { volume = 0.4  },
    TradeDone   = { volume = 0.6  },
    -- Sky Tower
    TowerStart  = { volume = 0.6  },
    TowerLevel  = { volume = 0.5  },           -- played at a pitch that rises with the level (see AudioData.LevelPitch)
    TowerFall   = { volume = 0.6  },
    TowerBounce = { volume = 0.45 },
    TowerSummit = { volume = 0.8  },
    -- Hollow Maze
    MazeRoar      = { volume = 0.9  },
    MazeFootstep  = { volume = 0.6  },         -- the Zombie's steps: louder and faster as it closes in
    MazeHeartbeat = { volume = 0.7  },         -- inside the warning radius
    MazeCaught    = { volume = 0.9  },
    MazeEscape    = { volume = 0.8  },
    MazePickup    = { volume = 0.5  },
    MazeHide      = { volume = 0.4  },
    MazeFreeze    = { volume = 0.6  },
    MazeStun      = { volume = 0.6  },
    MazeLight     = { volume = 0.5  },
    MazeThunder   = { volume = 0.6  },
    -- Ambience and music (looped, quiet)
    AmbientForge = { volume = 0.25, looped = true },
    Music        = { volume = 0.14, looped = true },
    MusicTower   = { volume = 0.16, looped = true },
    MusicMaze    = { volume = 0.2,  looped = true },
}

-- The asset path to play for a sound, or nil if it has no id yet and no built-in fallback.
function AudioData.Resolve(name)
    local def = AudioData.Sounds[name]
    if not def then return nil end
    local id = def.id or AudioIds[def.file or name] or 0
    if id ~= 0 then return "rbxassetid://" .. id end
    return def.builtin
end

-- A pitch (playback speed) that rises as the Tower climb goes up: a level-1 ding at 1.0, the top level a fifth higher (x1.5).
function AudioData.LevelPitch(level, total)
    return 1 + 0.5 * math.clamp((level - 1) / math.max(1, (total or 30) - 1), 0, 1)
end

return AudioData
