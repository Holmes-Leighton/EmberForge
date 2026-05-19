-- Handles player XP, player leveling, and elemental mastery.

local GameConfig        = require(game.ReplicatedStorage.Shared.Data.GameConfig)
local Utils             = require(game.ReplicatedStorage.Shared.Modules.Utils)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ProgressionService = {}

-- XP required to reach a given player level (quadratic curve)
local function XPForLevel(level)
    return math.floor(100 * level ^ 1.8)
end

-- ── Player XP & Level ────────────────────────────────────────────────────────
function ProgressionService.AddPlayerXP(player, xp)
    local data = PlayerDataService.Get(player)
    if not data then return false end

    data.PlayerXP = (data.PlayerXP or 0) + xp
    PlayerDataService.MarkDirty(player)

    local leveledUp = false
    while true do
        local needed = XPForLevel(data.PlayerLevel + 1)
        if data.PlayerXP >= needed then
            data.PlayerLevel = data.PlayerLevel + 1
            leveledUp = true
        else
            break
        end
    end

    return leveledUp, data.PlayerLevel
end

function ProgressionService.GetPlayerLevelProgress(player)
    local data = PlayerDataService.Get(player)
    if not data then return nil end
    local currentNeeded = XPForLevel(data.PlayerLevel)
    local nextNeeded    = XPForLevel(data.PlayerLevel + 1)
    local progress      = (data.PlayerXP - currentNeeded) / (nextNeeded - currentNeeded)
    return {
        level    = data.PlayerLevel,
        xp       = data.PlayerXP,
        toNext   = nextNeeded - data.PlayerXP,
        progress = Utils.Clamp(progress, 0, 1),
    }
end

-- ── Mastery ───────────────────────────────────────────────────────────────────
function ProgressionService.AddMasteryXP(player, elementId, xp)
    local data = PlayerDataService.Get(player)
    if not data or not data.MasteryLevels then return false end
    if not data.MasteryLevels[elementId] then
        data.MasteryLevels[elementId] = 0
    end

    data.MasteryLevels[elementId] = data.MasteryLevels[elementId] + xp
    PlayerDataService.MarkDirty(player)

    -- Determine new mastery level
    local currentXP  = data.MasteryLevels[elementId]
    local masteryLvl = ProgressionService.GetMasteryLevel(currentXP)

    return masteryLvl
end

function ProgressionService.GetMasteryLevel(xp)
    local thresholds = GameConfig.MASTERY_XP_THRESHOLDS
    for level = GameConfig.MASTERY_MAX_LEVEL, 1, -1 do
        if xp >= (thresholds[level] or 0) then
            return level
        end
    end
    return 1
end

-- Returns stat multipliers for a given element based on mastery level
function ProgressionService.GetMasteryBonuses(player, elementId)
    local data = PlayerDataService.Get(player)
    if not data then return {} end

    local xp  = (data.MasteryLevels or {})[elementId] or 0
    local lvl = ProgressionService.GetMasteryLevel(xp)

    local bonuses = {}
    if lvl >= 5  then bonuses.miningRateBonus   = 0.05 end
    if lvl >= 10 then bonuses.luckBonus          = 0.10 end
    if lvl >= 15 then bonuses.smeltSpeedBonus    = 0.15 end
    if lvl >= 20 then
        bonuses.allStatsBonus = 0.20
        bonuses.exclusiveTitle = elementId .. "_Sage"
    end

    return bonuses, lvl
end

-- ── Reward dispatchers (called by other services) ────────────────────────────
function ProgressionService.OnGolemCrafted(player, golem)
    local xpReward = GameConfig.XP_PER_CRAFT_TIER[golem.tier] or 50
    local leveled, newLevel = ProgressionService.AddPlayerXP(player, xpReward)
    return leveled, newLevel
end

function ProgressionService.OnTradeCompleted(player)
    ProgressionService.AddPlayerXP(player, GameConfig.XP_PER_TRADE)
end

function ProgressionService.OnGolemMined(player, elementId, resourcesThisTick)
    -- Award mastery XP proportional to resources mined
    local masteryXP = math.floor(resourcesThisTick * GameConfig.MASTERY_XP_PER_HOUR_MINED)
    if masteryXP > 0 then
        local newMasteryLevel = ProgressionService.AddMasteryXP(player, elementId, masteryXP)
        return newMasteryLevel
    end
end

return ProgressionService
