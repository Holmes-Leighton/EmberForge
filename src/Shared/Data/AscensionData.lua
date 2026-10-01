-- Ascension: the endgame prestige. At Forge Level 10 you may spend coins to Ascend, up to MAX times. Each Ascension is
-- a permanent bonus on top of your Forge level perks and a title, and shows on your plot sign and the Ascensions
-- leaderboard. Nothing is reset: your Golems, pets, blueprints and forge stay yours, so Ascending is never a loss.
local AscensionData = {}

AscensionData.MAX = 10
AscensionData.FORGE_LEVEL = 10
AscensionData.BASE_COST = 25000          -- coins; Ascension n costs BASE_COST * n^2 (25k, 100k, 225k ... 2.5M)

-- what each Ascension adds (so 10 Ascensions: +20% mining, +20% carry, +10% luck, +30% daily coins)
AscensionData.PER = { mining = 0.02, carry = 0.02, luck = 0.01, coins = 0.03 }

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

function AscensionData.Roman(n) return ROMAN[n] or tostring(n) end

-- Cost of reaching Ascension `n` (the next one when you have n - 1)
function AscensionData.Cost(n) return AscensionData.BASE_COST * n * n end

function AscensionData.Title(n) return "Ascended " .. AscensionData.Roman(n) end

-- Total permanent bonuses at this many Ascensions: { mining, carry, luck, coins }
function AscensionData.Bonus(count)
    count = math.clamp(math.floor(tonumber(count) or 0), 0, AscensionData.MAX)
    local out = {}
    for stat, v in pairs(AscensionData.PER) do out[stat] = v * count end
    return out
end

return AscensionData
