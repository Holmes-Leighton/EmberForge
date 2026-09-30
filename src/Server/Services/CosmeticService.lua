-- What a player owns and what they are wearing/using. Cosmetics never change stats (spec 3.3).
local CosmeticData      = require(game.ReplicatedStorage.Shared.Data.CosmeticData)
local Utils             = require(game.ReplicatedStorage.Shared.Modules.Utils)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CosmeticService = {}

local SLOTS = { ForgeSkin = true, ForgeDecoration = true, GolemAccessory = true, ParticleEffect = true, ForgeEffect = true, Title = true }

-- Every title the player can wear: plain-text titles earned from achievements/mastery,
-- plus TitleBadge cosmetics. Returns array of { key, text }.
function CosmeticService.OwnedTitles(data)
    local list, seen = {}, {}
    for _, t in ipairs(data.Titles or {}) do
        if not seen[t] then seen[t] = true table.insert(list, { key = "T:" .. t, text = t }) end
    end
    for _, id in ipairs(data.OwnedCosmetics or {}) do
        local d = CosmeticData.Describe(id)
        if d.slot == "Title" and not seen[d.name] then
            seen[d.name] = true
            table.insert(list, { key = id, text = d.name })
        end
    end
    return list
end

-- Equip (or clear, with id = nil) something in a slot. Returns ok, reason.
function CosmeticService.Equip(player, slot, id)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end
    if type(slot) ~= "string" or not SLOTS[slot] then return false, "Unknown slot" end
    data.Equipped = data.Equipped or {}

    if id == nil then
        data.Equipped[slot] = nil
        PlayerDataService.MarkDirty(player)
        return true
    end
    if type(id) ~= "string" then return false, "Bad item" end

    if slot == "Title" then
        for _, t in ipairs(CosmeticService.OwnedTitles(data)) do
            if t.key == id then
                data.Equipped.Title = t.text
                PlayerDataService.MarkDirty(player)
                return true
            end
        end
        return false, "You don't own that title"
    end

    if not Utils.TableContains(data.OwnedCosmetics or {}, id) then return false, "You don't own that" end
    if CosmeticData.Describe(id).slot ~= slot then return false, "That doesn't go there" end
    data.Equipped[slot] = id
    PlayerDataService.MarkDirty(player)
    return true
end

-- Forge access: false = anyone may visit, true = friends only (spec 7.2)
function CosmeticService.SetFriendsOnly(player, on)
    local data = PlayerDataService.Get(player)
    if not data or type(on) ~= "boolean" then return false end
    data.Settings = data.Settings or {}
    data.Settings.ForgeFriendsOnly = on
    PlayerDataService.MarkDirty(player)
    return true
end

return CosmeticService
