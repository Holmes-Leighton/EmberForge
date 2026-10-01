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
