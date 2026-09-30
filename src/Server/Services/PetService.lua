-- Golem pets: hatch them from eggs, wear up to PetData.SLOTS, and they give small boosts (IdleEngine reads
-- PetData.Boosts). What you are wearing is published as the player attribute "EFPets" (pet types, comma
-- separated) so every client can draw your pets following you; nothing else about them is sent.

local PetData           = require(game.ReplicatedStorage.Shared.Data.PetData)
local Utils             = require(game.ReplicatedStorage.Shared.Modules.Utils)
local PlayerDataService = require(script.Parent.PlayerDataService)

local PetService = {}

local function FindPet(data, petId)
    for _, pet in ipairs(data.OwnedPets or {}) do
        if pet.id == petId then return pet end
    end
    return nil
end

-- Publishes the worn pets to every client
function PetService.Sync(player)
    local data = PlayerDataService.Get(player)
    if not data then return end
    local types = {}
    for _, id in ipairs(data.EquippedPets or {}) do
        local pet = FindPet(data, id)
        if pet then table.insert(types, pet.type) end
    end
    player:SetAttribute("EFPets", table.concat(types, ","))
end

-- Pay for an egg and get a random pet. Returns the new pet, or nil + a reason.
function PetService.Hatch(player, eggId)
    local data = PlayerDataService.Get(player)
    if not data then return nil, "No player data" end
    local egg = PetData.Eggs[eggId]
    if not egg then return nil, "Unknown egg" end
    data.OwnedPets = data.OwnedPets or {}
    if #data.OwnedPets >= PetData.MAX_OWNED then return nil, "Your pet box is full" end
    if (data.EmberCoins or 0) < egg.cost then
        return nil, string.format("You need %d coins (you have %d)", egg.cost, data.EmberCoins or 0)
    end

    data.EmberCoins -= egg.cost
    local pet = { id = Utils.GenerateId(), type = Utils.WeightedRandom(egg.pool), hatchedAt = Utils.UnixTimestamp() }
    table.insert(data.OwnedPets, pet)
    -- a first pet goes straight onto your side so the egg pays off at once
    data.EquippedPets = data.EquippedPets or {}
    if #data.EquippedPets < PetData.SLOTS then table.insert(data.EquippedPets, pet.id) end
    PlayerDataService.MarkDirty(player)
    PetService.Sync(player)
    return pet, nil
end

-- Wear or put away a pet. Returns true, or false + a reason.
function PetService.Equip(player, petId, on)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end
    if not FindPet(data, petId) then return false, "You don't have that pet" end
    data.EquippedPets = data.EquippedPets or {}

    local index = table.find(data.EquippedPets, petId)
    if on then
        if index then return true end
        if #data.EquippedPets >= PetData.SLOTS then
            return false, string.format("You can only wear %d pets. Put one away first.", PetData.SLOTS)
        end
        table.insert(data.EquippedPets, petId)
    else
        if not index then return true end
        table.remove(data.EquippedPets, index)
    end
    PlayerDataService.MarkDirty(player)
    PetService.Sync(player)
    return true
end

-- Say goodbye to a pet you no longer want
function PetService.Release(player, petId)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end
    for i, pet in ipairs(data.OwnedPets or {}) do
        if pet.id == petId then
            table.remove(data.OwnedPets, i)
            local e = table.find(data.EquippedPets or {}, petId)
            if e then table.remove(data.EquippedPets, e) end
            PlayerDataService.MarkDirty(player)
            PetService.Sync(player)
            return true
        end
    end
    return false, "You don't have that pet"
end

return PetService
