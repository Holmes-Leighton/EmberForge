-- Movement speed levels: trained by standing on mining pads, so a pad pays materials AND speed. Level 0 is Roblox's normal walk (16); each level adds a little.
-- Each pad only trains speed up to its own cap (PadData speedCap), so climbing the levels means moving up to the higher pads. The Sky Tower is built for the
-- normal pace (no bonus there); the Hollow Maze keeps the Zombie Golem in step (MazeData.ZombieScale).
local SpeedData = {}

SpeedData.BASE_WALK  = 16
SpeedData.MAX_LEVEL  = 200
SpeedData.PER_LEVEL  = 0.1        -- studs/s per level: level 200 walks at 36
SpeedData.NOTICE_EVERY = 5        -- a level-up message every this many levels (the HUD row shows every level)

-- Speed XP per pad tick (once a second): the pad's multiplier to the power 0.6, so the Starter pad gives 1, Copper 1.9, Iron 3.7, Gold 6.9, Legend 15.8
function SpeedData.XpPerTick(multiplier)
    return math.max(1, multiplier) ^ 0.6
end

-- XP needed to go from `level` to `level + 1` (nil at the top). Each pad covers 40 levels: about 6 h on the Starter pad (1-40), 12 h on Copper (41-80),
-- 12 h on Iron (81-120), 10 h on Gold (121-160) and 6 h on Legend (161-200), some 45 hours of standing on pads for the whole ladder.
-- (XP_SCALE is the one number to change to make the whole ladder longer or shorter.)
SpeedData.XP_SCALE = 10
function SpeedData.XpToNext(level)
    if level >= SpeedData.MAX_LEVEL then return nil end
    return math.floor(SpeedData.XP_SCALE * (level + 1) ^ 1.3)
end

function SpeedData.WalkSpeed(level)
    return SpeedData.BASE_WALK + SpeedData.PER_LEVEL * math.clamp(level or 0, 0, SpeedData.MAX_LEVEL)
end

return SpeedData
