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

-- ── Moderation: kick, ban, mute ───────────────────────────────────────────────
-- Bans and mutes live in a DataStore of their own, so they hold across servers and rejoins (checked when a player joins). A mute stops guild
-- chat, trade requests and Market use; it is mirrored on the player as the attribute EFMutedUntil (unix time) for the server they are in.
local modStore
local function ModStore()
    modStore = modStore or require(script.Parent.SafeDataStore).GetDataStore("EmberForge_Moderation_v1")
    return modStore
end

local function DurationText(untilT)
    if not untilT or untilT == 0 then return "permanently" end
    return string.format("until %s UTC", os.date("!%Y-%m-%d %H:%M", untilT))
end

function AdminService.IsMuted(player)
    local untilT = player:GetAttribute("EFMutedUntil")
    return type(untilT) == "number" and (untilT == 0 or untilT > os.time())
end

-- Called when a player joins: kicks them if banned, restores a mute. Returns true if they were kicked.
function AdminService.CheckJoin(player)
    local ok, rec = pcall(function() return ModStore():GetAsync("u_" .. player.UserId) end)
    if not ok or type(rec) ~= "table" then return false end
    local ban = rec.ban
    if ban and (ban.untilT == 0 or ban.untilT > os.time()) then
        player:Kick(string.format("You are banned %s. Reason: %s", DurationText(ban.untilT), tostring(ban.reason ~= "" and ban.reason or "none given")))
        return true
    end
    local mute = rec.mute
    if mute and (mute.untilT == 0 or mute.untilT > os.time()) then player:SetAttribute("EFMutedUntil", mute.untilT) end
    return false
end

local function EditRecord(userId, edit)
    return pcall(function()
        ModStore():UpdateAsync("u_" .. userId, function(old)
            local rec = type(old) == "table" and old or {}
            edit(rec)
            return rec
        end)
    end)
end

-- a player's id from a name, an id or a player in this server (offline names are looked up through Roblox)
local function ResolveUserId(who)
    local id = tonumber(who)
    if id then return id end
    local p = FindPlayer(who)
    if p then return p.UserId end
    if type(who) == "string" and who ~= "" then
        local ok, uid = pcall(function() return Players:GetUserIdFromNameAsync(who) end)
        if ok then return uid end
    end
    return nil
end

local function ModerationAction(admin, action, args)
    local reason = type(args.reason) == "string" and args.reason:sub(1, 120) or ""
    local hours = tonumber(args.hours) or 0
    if hours < 0 or hours > 24 * 365 then return false, "Hours: 0 (permanent) to 8760" end
    local untilT = hours > 0 and os.time() + math.floor(hours * 3600) or 0
    local userId = ResolveUserId(args.target)
    if not userId then return false, "No such player" end
    if userId == admin.UserId then return false, "Not yourself" end
    local online = Players:GetPlayerByUserId(userId)
    if online and AdminService.IsAdmin(online) then return false, "That player is an admin" end

    if action == "kick" then
        if not online then return false, "Player not in this server" end
        online:Kick("You were removed from the game." .. (reason ~= "" and (" Reason: " .. reason) or ""))
        Audit(admin, action, { target = userId, reason = reason })
        return true, "Kicked " .. online.Name
    elseif action == "ban" then
        local ok = EditRecord(userId, function(rec) rec.ban = { untilT = untilT, reason = reason, by = admin.UserId, t = os.time() } end)
        if not ok then return false, "Couldn't save the ban, try again" end
        if online then online:Kick(string.format("You are banned %s. Reason: %s", DurationText(untilT), reason ~= "" and reason or "none given")) end
        Audit(admin, action, { target = userId, hours = hours, reason = reason })
        return true, string.format("Banned %d %s", userId, DurationText(untilT))
    elseif action == "unban" then
        local ok = EditRecord(userId, function(rec) rec.ban = nil end)
        Audit(admin, action, { target = userId })
        return ok, ok and ("Unbanned " .. userId) or "Couldn't save, try again"
    elseif action == "mute" then
        local ok = EditRecord(userId, function(rec) rec.mute = { untilT = untilT, reason = reason, by = admin.UserId, t = os.time() } end)
        if not ok then return false, "Couldn't save the mute, try again" end
        if online then online:SetAttribute("EFMutedUntil", untilT) end
        Audit(admin, action, { target = userId, hours = hours, reason = reason })
        return true, string.format("Muted %d %s", userId, DurationText(untilT))
    end
    local ok = EditRecord(userId, function(rec) rec.mute = nil end)      -- unmute
    if online then online:SetAttribute("EFMutedUntil", nil) end
    Audit(admin, action, { target = userId })
    return ok, ok and ("Unmuted " .. userId) or "Couldn't save, try again"
end

-- Returns ok (boolean), message or data
function AdminService.Action(admin, action, args, LiveOps)
    if not AdminService.IsAdmin(admin) then return false, "Not allowed" end
    if type(args) ~= "table" then args = {} end
    local PlayerDataService = require(script.Parent.PlayerDataService)

    if action == "kick" or action == "ban" or action == "unban" or action == "mute" or action == "unmute" then
        return ModerationAction(admin, action, args)
    elseif action == "grantCoins" or action == "grantMaterial" then
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

    elseif action == "grantBlueprint" or action == "grantCosmetic" then
        local target = FindPlayer(args.target)
        if not target then return false, "Player not in this server" end
        local data = PlayerDataService.Get(target)
        if not data then return false, "Their data isn't loaded" end
        if action == "grantBlueprint" then
            local bp = type(args.id) == "string" and require(game.ReplicatedStorage.Shared.Data.RecipeData).Get(args.id)
            if not bp then return false, "Unknown blueprint id" end
            if not PlayerDataService.UnlockBlueprint(target, args.id) then return false, "They already have it" end
            Audit(admin, action, { target = target.UserId, id = args.id })
            return true, string.format("Gave %s the %s tier %d blueprint", target.Name, bp.element, bp.tier)
        end
        -- cosmetic ids look like "<Type>_<Name>" (CosmeticData): the type must be a real one
        local CosmeticData = require(game.ReplicatedStorage.Shared.Data.CosmeticData)
        local kind = type(args.id) == "string" and args.id:match("^(%a+)_[%w_]+$")
        if not kind or not CosmeticData.Types[kind] then return false, "Cosmetic ids look like ForgeSkin_Molten, GolemAccessory_LavaCrown, TitleBadge_Veteran" end
        data.OwnedCosmetics = data.OwnedCosmetics or {}
        if table.find(data.OwnedCosmetics, args.id) then return false, "They already own it" end
        table.insert(data.OwnedCosmetics, args.id)
        PlayerDataService.MarkDirty(target)
        Audit(admin, action, { target = target.UserId, id = args.id })
        return true, string.format("Gave %s %s", target.Name, args.id)

    elseif action == "inspect" then
        local target = FindPlayer(args.target)
        if not target then return false, "Player not in this server" end
        local data = PlayerDataService.Get(target)
        if not data then return false, "Their data isn't loaded" end
        local mats, n = {}, 0
        for id, qty in pairs(data.Inventory or {}) do if qty > 0 then n += 1 table.insert(mats, { id = id, qty = qty }) end end
        table.sort(mats, function(a, b) return a.qty > b.qty end)
        local top = {}
        for i = 1, math.min(8, #mats) do top[i] = mats[i].id .. " x" .. mats[i].qty end
        local deployed = 0
        for _, g in ipairs(data.Golems or {}) do if g.deployed then deployed += 1 end end
        return true, {
            name = target.Name, userId = target.UserId, accountAge = target.AccountAge,
            summary = string.format("Player Lv %d, Forge Lv %d, Ascensions %d, %d coins", data.PlayerLevel or 1, data.ForgeLevel or 1, data.Ascensions or 0, data.EmberCoins or 0),
            lines = {
                string.format("Golems: %d (%d deployed)   Pets: %d   Blueprints: %d   Cosmetics: %d", #(data.Golems or {}), deployed, #(data.OwnedPets or {}), #(data.Blueprints or {}), #(data.OwnedCosmetics or {})),
                string.format("Materials: %d kinds. Most: %s", n, #top > 0 and table.concat(top, ", ") or "none"),
                "Guild: " .. tostring(data.GuildId or "none"),
                "Muted: " .. tostring(AdminService.IsMuted(target)),
            } }

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
            elseif kind == "deploygolem" then                                -- put a fresh Golem to work in zone `id` (trip-home test)
                table.insert(data.Golems, { id = "studio" .. (#data.Golems + 1), element = "Ember", tier = 2, deployed = true, zoneId = id or "EmberDepths" })
            elseif kind == "wear" then                                      -- set every Golem's durability to `qty` (0..1) of its maximum (tiredness test)
                for _, g in ipairs(data.Golems or {}) do
                    g._maxDurabilitySeconds = g._maxDurabilitySeconds or g._durabilitySeconds or 259200
                    g._durabilitySeconds = g._maxDurabilitySeconds * math.clamp(qty or 0, 0, 1)
                end
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
