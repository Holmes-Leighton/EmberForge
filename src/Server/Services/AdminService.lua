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

-- ── Admin panel actions ───────────────────────────────────────────────────────
-- The in-game admin panel (AdminPanelBuilder) calls AdminAction(action, args). Every call is checked against IsAdmin on the server, args are
-- treated as hostile, and every action that changes something is written to a permanent admin log (who, what, when) in a DataStore of its own.
local MAX_GRANT_COINS, MAX_GRANT_QTY = 1000000, 100000
local auditStore

local function Audit(admin, action, detail)
    task.spawn(function()
        pcall(function()
            auditStore = auditStore or require(script.Parent.SafeDataStore).GetDataStore("EmberForge_AdminLog_v1")
            auditStore:UpdateAsync("log", function(old)
                local list = type(old) == "table" and old or {}
                table.insert(list, { t = os.time(), admin = admin.UserId, adminName = admin.Name, action = action, detail = detail })
                while #list > 500 do table.remove(list, 1) end
                return list
            end)
        end)
    end)
end

function AdminService.GetAuditLog(limit)
    local ok, list = pcall(function()
        auditStore = auditStore or require(script.Parent.SafeDataStore).GetDataStore("EmberForge_AdminLog_v1")
        return auditStore:GetAsync("log")
    end)
    local out = {}
    if ok and type(list) == "table" then
        for i = #list, math.max(1, #list - (limit or 30) + 1), -1 do table.insert(out, list[i]) end
    end
    return out
end

-- A player in this server, by exact name / display name (any case) or UserId
local function FindPlayer(who)
    if type(who) == "number" then return Players:GetPlayerByUserId(who) end
    if type(who) ~= "string" or who == "" then return nil end
    local lower = who:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == lower or p.DisplayName:lower() == lower or tostring(p.UserId) == who then return p end
    end
    return nil
end

local function WholeNumber(n, max)
    n = tonumber(n)
    return n and n == n and n >= 1 and n <= max and math.floor(n) == n and n or nil
end

-- Returns ok (boolean), message or data
function AdminService.Action(admin, action, args, LiveOps)
    if not AdminService.IsAdmin(admin) then return false, "Not allowed" end
    if type(args) ~= "table" then args = {} end
    local PlayerDataService = require(script.Parent.PlayerDataService)

    if action == "grantCoins" or action == "grantMaterial" then
        local target = FindPlayer(args.target)
        if not target then return false, "Player not in this server" end
        local data = PlayerDataService.Get(target)
        if not data then return false, "Their data isn't loaded" end
        if action == "grantCoins" then
            local n = WholeNumber(args.amount, MAX_GRANT_COINS)
            if not n then return false, "Coins: a whole number from 1 to " .. MAX_GRANT_COINS end
            data.EmberCoins = (data.EmberCoins or 0) + n
            PlayerDataService.MarkDirty(target)
            Audit(admin, action, { target = target.UserId, amount = n })
            return true, string.format("Gave %s %d coins", target.Name, n)
        end
        local MaterialData = require(game.ReplicatedStorage.Shared.Data.MaterialData)
        local def = type(args.id) == "string" and MaterialData.Get(args.id)
        local n = WholeNumber(args.qty, MAX_GRANT_QTY)
        if not def then return false, "Unknown material id" end
        if not n then return false, "Quantity: a whole number from 1 to " .. MAX_GRANT_QTY end
        PlayerDataService.AddMaterial(target, args.id, n)
        Audit(admin, action, { target = target.UserId, id = args.id, qty = n })
        return true, string.format("Gave %s %d x %s", target.Name, n, def.displayName or args.id)

    elseif action == "grantEgg" then
        local target = FindPlayer(args.target)
        if not target then return false, "Player not in this server" end
        local data = PlayerDataService.Get(target)
        if not data then return false, "Their data isn't loaded" end
        local PetData = require(game.ReplicatedStorage.Shared.Data.PetData)
        if type(args.id) ~= "string" or not PetData.Eggs[args.id] then return false, "Unknown egg id" end
        local n = WholeNumber(args.qty, 10)
        if not n then return false, "Eggs: a whole number from 1 to 10" end
        if #(data.OwnedPets or {}) + n > PetData.MAX_OWNED then return false, "Their pet box doesn't have room" end
        local pets = require(script.Parent.PetService).HatchPaid(target, args.id, n)     -- hatches for free and plays the reveal for them
        Audit(admin, action, { target = target.UserId, egg = args.id, qty = n })
        return true, string.format("Hatched %d x %s for %s", #pets, args.id, target.Name)

    elseif action == "grantPet" or action == "grantGolem" then
        local target = FindPlayer(args.target)
        if not target then return false, "Player not in this server" end
        local data = PlayerDataService.Get(target)
        if not data then return false, "Their data isn't loaded" end
        local Utils = require(game.ReplicatedStorage.Shared.Modules.Utils)
        local variant = args.variant
        if variant == "" or variant == "none" then variant = nil end
        if variant ~= nil and variant ~= "Neon" and variant ~= "MegaNeon" then return false, "Variant: blank, Neon or MegaNeon" end
        if action == "grantPet" then
            local PetData = require(game.ReplicatedStorage.Shared.Data.PetData)
            if type(args.id) ~= "string" or not PetData.Get(args.id) then return false, "Unknown pet id" end
            data.OwnedPets = data.OwnedPets or {}
            if #data.OwnedPets >= PetData.MAX_OWNED then return false, "Their pet box is full" end
            local pet = { id = Utils.GenerateId(), type = args.id, variant = variant, hatchedAt = Utils.UnixTimestamp(), grown = 0 }
            table.insert(data.OwnedPets, pet)
            PetData.NoteSeen(data, pet)
            PlayerDataService.MarkDirty(target)
            require(script.Parent.PetService).Sync(target)
            Audit(admin, action, { target = target.UserId, id = args.id, variant = variant })
            return true, string.format("Gave %s a %s", target.Name, PetData.DisplayName(pet))
        end
        local bp = type(args.id) == "string" and require(game.ReplicatedStorage.Shared.Data.RecipeData).Get(args.id)
        if not bp then return false, "Unknown blueprint id" end
        local GolemData = require(game.ReplicatedStorage.Shared.Data.GolemData)
        local seconds = ((GolemData.Tiers[bp.tier] or {}).durabilityHours or 72) * 3600
        table.insert(data.Golems, {
            id = Utils.GenerateId(), blueprintId = args.id, element = bp.element, tier = bp.tier, skinId = "default", deployed = false,
            variant = variant, quality = require(game.ReplicatedStorage.Shared.Modules.CraftRules).QualityFor(bp), rarity = GolemData.RarityForTier(bp.tier), _carriedResources = 0, _accumulatedResources = 0,
            _durabilitySeconds = seconds, _maxDurabilitySeconds = seconds, craftedAt = Utils.UnixTimestamp(),
        })
        PlayerDataService.MarkDirty(target)
        Audit(admin, action, { target = target.UserId, id = args.id, variant = variant })
        return true, string.format("Gave %s a %s tier %d Golem", target.Name, bp.element, bp.tier)

    elseif action == "event" then
        local kind, multiplier, hours = args.kind, tonumber(args.multiplier), tonumber(args.hours)
        if kind ~= "xp" and kind ~= "drops" then return false, "Kind must be xp or drops" end
        if not multiplier or not hours or multiplier <= 1 or multiplier > 10 or hours <= 0 or hours > 24 * 14 then
            return false, "Multiplier 1-10 (above 1), hours 1-336"
        end
        LiveOps.AddEvent(kind, multiplier, hours, kind == "xp" and "Bonus XP" or "Bonus Drops")
        for _, p in ipairs(Players:GetPlayers()) do
            require(game.ReplicatedStorage.Shared.Modules.RemoteEvents).Notify:FireClient(p, "Event started!",
                string.format("%s x%g for %g hours", kind == "xp" and "XP" or "Resource drops", multiplier, hours))
        end
        Audit(admin, action, { kind = kind, multiplier = multiplier, hours = hours })
        return true, string.format("Started %s x%g for %g hours", kind, multiplier, hours)

    elseif action == "clearEvents" then
        LiveOps.ClearEvents()
        Audit(admin, action, {})
        return true, "All admin events cleared"

    elseif action == "announce" then
        local text = type(args.text) == "string" and args.text:sub(1, 140) or ""
        if text:match("^%s*$") then return false, "Write a message first" end
        local ok, filtered = pcall(function()
            return game:GetService("TextService"):FilterStringAsync(text, admin.UserId):GetNonChatStringForBroadcastAsync()
        end)
        if not ok then filtered = RunService:IsStudio() and text or nil end
        if not filtered then return false, "Couldn't filter that message, try again" end
        for _, p in ipairs(Players:GetPlayers()) do
            require(game.ReplicatedStorage.Shared.Modules.RemoteEvents).Notify:FireClient(p, "Announcement", filtered)
        end
        Audit(admin, action, { text = filtered })
        return true, "Sent to this server"

    elseif action == "lookup" then
        local id = tonumber(args.target)
        if not id then
            local p = FindPlayer(args.target)
            id = p and p.UserId
            if not id and type(args.target) == "string" then
                local ok, uid = pcall(function() return Players:GetUserIdFromNameAsync(args.target) end)
                id = ok and uid or nil
            end
        end
        if not id then return false, "No such player" end
        local Trading = require(script.Parent.TradingService)
        return true, { userId = id, online = Players:GetPlayerByUserId(id) ~= nil,
                       log = Trading.GetLog(id, 25), reports = Trading.GetReports(id), admin = AdminService.GetAuditLog(15) }

    elseif action == "events" then
        local t = {}
        for _, e in ipairs(LiveOps.ActiveEvents()) do table.insert(t, string.format("%s x%g", e.name or e.kind, e.multiplier)) end
        return true, #t == 0 and "None running" or table.concat(t, ", ")
    end
    return false, "Unknown action"
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

    local remote = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents).AdminAction
    if remote then
        remote.OnServerInvoke = function(player, action, args)
            if type(action) ~= "string" then return false, "Bad request" end
            local ok, a, b = pcall(AdminService.Action, player, action, args, LiveOps)
            if not ok then warn("[Admin] " .. tostring(a)) return false, "Something went wrong" end
            return a, b
        end
    end

    local function hook(player)
        player:SetAttribute("EFAdmin", AdminService.IsAdmin(player))     -- the client shows the Admin button only when this is true
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
            elseif kind == "growpets" then require(script.Parent.PetService).Grow(player, qty or 0)      -- fast-forward worn time (seconds)
            elseif kind == "coins" then data.EmberCoins = (data.EmberCoins or 0) + (qty or 0)
            elseif kind == "quarryage" and data.Quarry then                  -- age every Quarry node by `qty` hours (maturity test)
                for _, p in ipairs(data.Quarry.placed or {}) do if p.born then p.born -= (qty or 0) * 3600 end end
            elseif kind == "playerlevel" then data.PlayerLevel = tonumber(id) or data.PlayerLevel
            elseif kind == "forgelevel" then data.ForgeLevel = math.max(data.ForgeLevel or 1, tonumber(id) or 1) end
            PlayerDataService.MarkDirty(player)
        end)
    end
    Players.PlayerAdded:Connect(hook)
    for _, p in ipairs(Players:GetPlayers()) do hook(p) end
end

return AdminService
