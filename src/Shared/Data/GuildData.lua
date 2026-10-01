-- Guilds (spec 7.3, Phase 2): groups of up to 20 players who work toward a weekly goal together and are
-- ranked on a weekly leaderboard by their combined production. This is the first slice: create / join /
-- leave, the weekly Guild Challenge and the Guild Leaderboard. (The shared Guild Forge space is not built yet.)
local GuildData = {}

GuildData.MAX_MEMBERS = 20
GuildData.NAME_MIN = 3
GuildData.NAME_MAX = 20
GuildData.CREATE_COST = 500          -- Ember Coins: keeps throwaway guilds from being spammed
GuildData.WEEK_SECONDS = 7 * 86400

-- The weekly Guild Challenge: everyone's mining adds up toward one target that grows with the guild.
GuildData.CHALLENGE_BASE = 20000
GuildData.CHALLENGE_PER_MEMBER = 6000
GuildData.REWARD = { coins = 300, speedUps = 1 }       -- each member who contributed claims this once a week
GuildData.MIN_CONTRIBUTION = 50                        -- resources a member must add to share in the reward

-- Guild battle prizes: when a week ends, the guilds on that week's leaderboard are paid by final rank. Every member
-- who added at least MIN_CONTRIBUTION that week claims it once (in the week that follows).
GuildData.Prizes = {
    { maxRank = 1,  coins = 3000, speedUps = 3, title = "Guild Champion", label = "1st" },
    { maxRank = 3,  coins = 1500, speedUps = 2, title = "Guild Elite",    label = "2nd - 3rd" },
    { maxRank = 10, coins = 600,  speedUps = 1, label = "4th - 10th" },
}

function GuildData.PrizeFor(rank)
    if type(rank) ~= "number" then return nil end
    for _, p in ipairs(GuildData.Prizes) do
        if rank <= p.maxRank then return p end
    end
    return nil
end

-- Guild level: everything the whole guild has ever mined. Each level gives every member a small permanent boost
-- to mining speed while they are in the guild (so a bigger, more active guild is worth belonging to).
GuildData.Levels = {
    { level = 1, total = 50000 },
    { level = 2, total = 250000 },
    { level = 3, total = 1000000 },
    { level = 4, total = 3000000 },
    { level = 5, total = 10000000 },
}
GuildData.LEVEL_BONUS = 0.02            -- mining speed per guild level (so +10% at level 5)

function GuildData.LevelOf(total)
    local level = 0
    for _, l in ipairs(GuildData.Levels) do
        if (total or 0) >= l.total then level = l.level end
    end
    return level
end

-- The next level's target: level, total needed (nil at the top)
function GuildData.NextLevel(total)
    local nextL = GuildData.Levels[GuildData.LevelOf(total) + 1]
    return nextL and nextL.level, nextL and nextL.total
end

function GuildData.LevelBonus(level)
    return GuildData.LEVEL_BONUS * math.clamp(level or 0, 0, #GuildData.Levels)
end

-- Guild chat and invites
GuildData.CHAT_KEEP = 30                -- messages kept per guild
GuildData.CHAT_MAX_LEN = 120
GuildData.CHAT_GAP = 1.5                -- seconds between a player's messages
GuildData.INVITE_SECONDS = 120          -- how long an invite stays open
GuildData.INVITE_GAP = 4                -- seconds between a player's invites

function GuildData.WeekId(unixTime)
    return math.floor((unixTime or os.time()) / GuildData.WEEK_SECONDS)
end

function GuildData.ChallengeTarget(memberCount)
    return GuildData.CHALLENGE_BASE + GuildData.CHALLENGE_PER_MEMBER * math.max(1, memberCount or 1)
end

-- Letters, digits and single spaces only; returns the cleaned name, or nil + why
function GuildData.CleanName(raw)
    if type(raw) ~= "string" then return nil, "Enter a guild name" end
    local name = raw:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    if #name < GuildData.NAME_MIN then return nil, "Guild names need at least " .. GuildData.NAME_MIN .. " characters" end
    if #name > GuildData.NAME_MAX then return nil, "Guild names can be at most " .. GuildData.NAME_MAX .. " characters" end
    if name:find("[^%w ]") then return nil, "Use letters, numbers and spaces only" end
    return name
end

function GuildData.NameKey(name) return name:lower() end

return GuildData
