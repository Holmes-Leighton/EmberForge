-- Audio (spec 10.3). Every id is 0 = silent until you add audio.
--
-- IMPORTANT: use only audio you made, licensed for commercial use, or that Roblox provides for
-- creators (see the 2022 audio-privacy change). Upload your own in Creator Hub > Assets, then paste the
-- numeric asset id below (rbxassetid://<id>). Leave a sound at 0 to keep it silent.
local AudioData = {}

AudioData.Sounds = {
    -- UI
    Click       = { id = 0, volume = 0.35 },
    Notify      = { id = 0, volume = 0.5  },
    Error       = { id = 0, volume = 0.4  },
    LevelUp     = { id = 0, volume = 0.7  },
    Achievement = { id = 0, volume = 0.7  },
    -- Gameplay
    Collect     = { id = 0, volume = 0.5  },
    Deploy      = { id = 0, volume = 0.5  },
    Craft       = { id = 0, volume = 0.6  },   -- tiers 1-2
    CraftRare   = { id = 0, volume = 0.7  },   -- tiers 3+
    Neon        = { id = 0, volume = 0.8  },
    Smelt       = { id = 0, volume = 0.4  },
    TradeDone   = { id = 0, volume = 0.6  },
    -- Ambience (looped, quiet)
    AmbientForge = { id = 0, volume = 0.25, looped = true },
    Music        = { id = 0, volume = 0.12, looped = true },
}

return AudioData
