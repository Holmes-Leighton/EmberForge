-- Ascension (see AscensionData): spend coins at Forge Level 10 for a permanent bonus. PlayerData.Ascensions counts them.

local AscensionData     = require(game.ReplicatedStorage.Shared.Data.AscensionData)
local Utils             = require(game.ReplicatedStorage.Shared.Modules.Utils)
local PlayerDataService = require(script.Parent.PlayerDataService)

local AscensionService = {}

-- What the menu shows
function AscensionService.Info(player)
    local data = PlayerDataService.Get(player)
    if not data then return nil end
    local count = data.Ascensions or 0
    local nextN = count + 1
    return {
        count = count, max = AscensionData.MAX, maxed = count >= AscensionData.MAX,
        nextCost = nextN <= AscensionData.MAX and AscensionData.Cost(nextN) or nil,
        forgeLevel = data.ForgeLevel or 1, needLevel = AscensionData.FORGE_LEVEL,
        coins = data.EmberCoins or 0,
        bonus = AscensionData.Bonus(count),
        nextBonus = AscensionData.Bonus(math.min(nextN, AscensionData.MAX)),
    }
end

-- Returns the new count, or nil + a reason
function AscensionService.Ascend(player)
    local data = PlayerDataService.Get(player)
    if not data then return nil, "No player data" end
    local count = data.Ascensions or 0
    if count >= AscensionData.MAX then return nil, "You have reached the highest Ascension" end
    if (data.ForgeLevel or 1) < AscensionData.FORGE_LEVEL then
        return nil, string.format("Reach Forge Level %d to Ascend (you are Level %d)", AscensionData.FORGE_LEVEL, data.ForgeLevel or 1)
    end
    local cost = AscensionData.Cost(count + 1)
    if (data.EmberCoins or 0) < cost then
        return nil, string.format("Ascending costs %s coins (you have %s)", Utils.FormatNumber(cost), Utils.FormatNumber(data.EmberCoins or 0))
    end
    data.EmberCoins -= cost
    data.Ascensions = count + 1
    data.Titles = data.Titles or {}
    local title = AscensionData.Title(data.Ascensions)
    if not Utils.TableContains(data.Titles, title) then table.insert(data.Titles, title) end
    PlayerDataService.MarkDirty(player)
    return data.Ascensions
end

return AscensionService
