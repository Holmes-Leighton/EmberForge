-- Who counts as an admin, and the chat commands they can use to run live events.
-- Admins: the place owner (or a group rank 250+ owner), UserIds listed in GameConfig.ADMIN_USER_IDS,
-- and everyone while testing in Studio.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameConfig = require(game.ReplicatedStorage.Shared.Data.GameConfig)

local AdminService = {}

function AdminService.IsAdmin(player)
    if RunService:IsStudio() then return true end
    for _, id in ipairs(GameConfig.ADMIN_USER_IDS or {}) do
        if id == player.UserId then return true end
    end
    if game.CreatorType == Enum.CreatorType.User then
        return game.CreatorId == player.UserId
    end
    local ok, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
    return ok and rank >= 250
end

-- /event xp 2 24        double XP for 24 hours
-- /event drops 3 12     triple drops for 12 hours
-- /event list | /event clear
function AdminService.Init(LiveOps, Notify)
    local function handle(player, message)
        local args = {}
        for word in message:gmatch("%S+") do table.insert(args, word) end
        if args[1] ~= "/event" then return end
        if not AdminService.IsAdmin(player) then return end

        local cmd = args[2]
        if cmd == "list" then
            local list = LiveOps.ActiveEvents()
            Notify(player, "Live events", #list == 0 and "None running." or table.concat((function()
                local t = {}
                for _, e in ipairs(list) do table.insert(t, string.format("%s x%g", e.name or e.kind, e.multiplier)) end
                return t
            end)(), ", "))
        elseif cmd == "clear" then
            LiveOps.ClearEvents()
            Notify(player, "Live events", "All events cleared.")
        elseif cmd == "xp" or cmd == "drops" then
            local multiplier, hours = tonumber(args[3]), tonumber(args[4])
            if not multiplier or not hours or multiplier <= 0 or multiplier > 10 or hours <= 0 or hours > 24 * 14 then
                Notify(player, "Usage", "/event xp|drops <multiplier 1-10> <hours 1-336>")
                return
            end
            LiveOps.AddEvent(cmd, multiplier, hours, cmd == "xp" and "Bonus XP" or "Bonus Drops")
            for _, p in ipairs(Players:GetPlayers()) do
                Notify(p, "Event started!", string.format("%s x%g for %g hours", cmd == "xp" and "XP" or "Resource drops", multiplier, hours))
            end
        else
            Notify(player, "Usage", "/event xp|drops <multiplier> <hours>, /event list, /event clear")
        end
    end

    local function hook(player)
        player.Chatted:Connect(function(msg) handle(player, msg) end)
    end
    -- Studio-only test hook (never exists in a published game): ServerStorage.StudioGrant:Fire(player, "blueprint"|"material"|"forgelevel", id, qty)
    if RunService:IsStudio() then
        local PlayerDataService = require(script.Parent.PlayerDataService)
        local bindable = Instance.new("BindableEvent")
        bindable.Name = "StudioGrant"
        bindable.Parent = game:GetService("ServerStorage")
        bindable.Event:Connect(function(player, kind, id, qty)
            local data = PlayerDataService.Get(player)
            if not data then return end
            if kind == "blueprint" and not table.find(data.Blueprints, id) then table.insert(data.Blueprints, id)
            elseif kind == "material" then data.Inventory[id] = (data.Inventory[id] or 0) + (qty or 1)
            elseif kind == "forgelevel" then data.ForgeLevel = math.max(data.ForgeLevel or 1, tonumber(id) or 1) end
            PlayerDataService.MarkDirty(player)
        end)
    end
    Players.PlayerAdded:Connect(hook)
    for _, p in ipairs(Players:GetPlayers()) do hook(p) end
end

return AdminService
