-- The seasonal ranked ladder: every SEASON_SECONDS (4 weeks) a new ranked season begins. Everything you mine earns
-- Ladder Points; your points place you in a tier, and the top players are ranked on a global board. When a season ends,
-- last season's rank/tier pays a reward you claim once during the next season.
local LadderData = {}

LadderData.SEASON_SECONDS = 28 * 86400

function LadderData.SeasonOf(now) return math.floor((now or os.time()) / LadderData.SEASON_SECONDS) end

function LadderData.SeasonEnds(now) return (LadderData.SeasonOf(now) + 1) * LadderData.SEASON_SECONDS end

-- Tiers by points, lowest first
LadderData.Tiers = {
    { name = "Bronze",   points = 0,        color = Color3.fromRGB(190, 130, 80),  coins = 0    },
    { name = "Silver",   points = 20000,    color = Color3.fromRGB(200, 205, 215), coins = 300  },
    { name = "Gold",     points = 100000,   color = Color3.fromRGB(255, 205, 70),  coins = 800  },
    { name = "Platinum", points = 400000,   color = Color3.fromRGB(120, 220, 230), coins = 1800 },
    { name = "Diamond",  points = 1500000,  color = Color3.fromRGB(120, 170, 255), coins = 3500 },
    { name = "Champion", points = 5000000,  color = Color3.fromRGB(255, 120, 200), coins = 6000 },
}

function LadderData.TierOf(points)
    local tier = LadderData.Tiers[1]
    local index = 1
    for i, t in ipairs(LadderData.Tiers) do
        if (points or 0) >= t.points then tier, index = t, i end
    end
    return tier, index
end

-- The tier after this one: tier, pointsStillNeeded (nil at the top)
function LadderData.NextTier(points)
    local _, index = LadderData.TierOf(points)
    local nextTier = LadderData.Tiers[index + 1]
    if not nextTier then return nil end
    return nextTier, nextTier.points - (points or 0)
end

-- What last season pays: the better of a rank prize (top 100) and the tier prize
LadderData.RankPrizes = {
    { maxRank = 1,   coins = 10000, speedUps = 5, title = "Season Champion"   },
    { maxRank = 10,  coins = 5000,  speedUps = 3, title = "Season Elite"      },
    { maxRank = 100, coins = 2000,  speedUps = 1, title = "Season Contender"  },
}

function LadderData.PrizeFor(rank, points)
    local tier = LadderData.TierOf(points)
    local prize = { coins = tier.coins, speedUps = 0, tierName = tier.name }
    if type(rank) == "number" then
        for _, p in ipairs(LadderData.RankPrizes) do
            if rank <= p.maxRank then
                prize = { coins = math.max(p.coins, tier.coins), speedUps = p.speedUps, title = p.title, tierName = tier.name, rank = rank }
                break
            end
        end
    end
    if prize.coins <= 0 and (prize.speedUps or 0) <= 0 then return nil end
    return prize
end

return LadderData
