-- Names for Golems and pets. Every name is cleaned (Nicknames.Clean), checked with Roblox's text filter (other players read it, so it has to be filtered),
-- and only ever set on something the player owns. A blank name removes the nickname. Free to do, with a short cooldown so nobody spams the filter.
local TextService = game:GetService("TextService")

local Nicknames         = require(game.ReplicatedStorage.Shared.Modules.Nicknames)
local GolemNames        = require(game.ReplicatedStorage.Shared.Modules.GolemNames)
local PlayerDataService = require(script.Parent.PlayerDataService)

local NicknameService = {}

local COOLDOWN = 2          -- seconds between rename attempts per player
local lastTry = {}          -- userId -> os.clock()

-- Filtered text, or nil if the filter exists but failed (then the name is refused). Where there is no filter (tests / Studio mock) the text passes.
local function Filter(player, text)
    local ok, result = pcall(function()
        return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
    end)
    if ok and type(result) == "string" then return result end
    if ok == false and TextService.FilterStringAsync then return nil end
    return text
end

local function Find(list, id)
    for _, item in ipairs(list or {}) do
        if item.id == id then return item end
    end
end

-- A Golem standing at work wears its name over its head: update that too
local function RefreshGolemTag(golem)
    pcall(function()          -- a missing or unbuilt world must never stop a rename
        local world = workspace:FindFirstChild("EmberWorld")
        local folder = world and world:FindFirstChild("DeployedGolems")
        local model = folder and folder:FindFirstChild("Golem_" .. tostring(golem.id))
        local label = model and model:FindFirstChild("NameLabel", true)
        if label then label.Text = GolemNames.Describe(golem).shortName end
    end)
end

-- kind: "golem" or "pet". Returns true + the new name (nil if it was removed), or false + a reason.
function NicknameService.Rename(player, kind, id, text)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end
    if (kind ~= "golem" and kind ~= "pet") or type(id) ~= "string" then return false, "Bad request" end

    local now = os.clock()
    if lastTry[player.UserId] and now - lastTry[player.UserId] < COOLDOWN then return false, "Slow down a moment" end
    lastTry[player.UserId] = now

    local ok, clean = Nicknames.Clean(text)
    if not ok then return false, clean end

    local item = Find(kind == "golem" and data.Golems or data.OwnedPets, id)
    if not item then return false, kind == "golem" and "You don't have that Golem" or "You don't have that pet" end

    if clean == "" then
        item.nickname = nil
    else
        local filtered = Filter(player, clean)
        if not filtered then return false, "We couldn't check that name just now. Try again." end
        if filtered ~= clean then return false, "That name isn't allowed. Try another." end
        item.nickname = clean
    end
    PlayerDataService.MarkDirty(player)

    if kind == "pet" then
        require(script.Parent.PetService).Sync(player)
    else
        RefreshGolemTag(item)
    end
    return true, item.nickname
end

function NicknameService.OnPlayerLeave(player)
    lastTry[player.UserId] = nil
end

return NicknameService
