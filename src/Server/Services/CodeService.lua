-- Redeem codes (see CodeData). PlayerData.RedeemedCodes = { [CODE] = true }.

local CodeData          = require(game.ReplicatedStorage.Shared.Data.CodeData)
local Utils             = require(game.ReplicatedStorage.Shared.Modules.Utils)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CodeService = {}

local lastTry = {}                  -- userId -> os.clock() of the last attempt (stops code guessing)
CodeService.ThrottleSeconds = 3

-- Returns true + a message, or false + a reason
function CodeService.Redeem(player, raw)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end
    local now = os.clock()
    if now - (lastTry[player.UserId] or -1e9) < CodeService.ThrottleSeconds then return false, "Slow down a little" end
    lastTry[player.UserId] = now

    local def, code = CodeData.Get(raw)
    if not code then return false, "Enter a code" end
    if not def then return false, "That code isn't valid" end
    if def.expires and Utils.UnixTimestamp() > def.expires then return false, "That code has expired" end
    data.RedeemedCodes = type(data.RedeemedCodes) == "table" and data.RedeemedCodes or {}
    if data.RedeemedCodes[code] then return false, "You already used that code" end

    data.RedeemedCodes[code] = true
    local bits = {}
    if def.coins then data.EmberCoins = (data.EmberCoins or 0) + def.coins table.insert(bits, def.coins .. " coins") end
    if def.speedUps then data.SpeedUps = (data.SpeedUps or 0) + def.speedUps table.insert(bits, def.speedUps .. " Speed-Up" .. (def.speedUps > 1 and "s" or "")) end
    if def.luckBoostSeconds then
        data.LuckBoostExpiry = math.max(data.LuckBoostExpiry or 0, Utils.UnixTimestamp()) + def.luckBoostSeconds
        table.insert(bits, "a Lucky Boost")
    end
    PlayerDataService.MarkDirty(player)
    return true, "Code redeemed! You got " .. table.concat(bits, " + ") .. "."
end

function CodeService.OnPlayerLeave(player) lastTry[player.UserId] = nil end

return CodeService
