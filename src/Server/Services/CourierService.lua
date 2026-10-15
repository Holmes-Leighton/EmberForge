-- Courier Run: builds the courses in the hub and runs each player's attempt. The rules live in CourierRunner and the sums in CourierRewards (both pure and tested);
-- this picks up the crate, watches the player's position, sends them back to a checkpoint when they fall, pays them at the drop-off, and keeps the fastest-time boards.
local Players = game:GetService("Players")

local CourierData     = require(game.ReplicatedStorage.Shared.Data.CourierData)
local RemoteEvents    = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local LiveOpsService  = require(script.Parent.LiveOpsService)
local ProgressionService = require(script.Parent.ProgressionService)
local ChallengeService = require(script.Parent.ChallengeService)
local SafeDataStore   = require(script.Parent.SafeDataStore)
local CourierRunner   = require(script.Parent.CourierRunner)
local CourierRewards  = require(script.Parent.CourierRewards)
local CourierArt      = require(script.Parent.CourierArt)
local SignArt         = require(script.Parent.SignArt)

local CourierService = {}

local SAMPLE = 0.1                 -- seconds between position checks
local BOARD_SIZE = 5
local BOARD_REFRESH = 60

local runs = {}                    -- userId -> { player, run, course, crate, saved }
local boards = {}                  -- courseId -> { store, rows = { { name, seconds } }, part }
local nameCache = {}

local function ServerNow() return workspace:GetServerTimeNow() end

local function Fire(player, kind, payload)
    if player and player.Parent then RemoteEvents.CourierEvent:FireClient(player, kind, payload) end
end

local function Tell(player, title, message)
    if player and player.Parent then RemoteEvents.Notify:FireClient(player, title, message) end
end

local function Today() return CourierData.Today() end

-- ── The crate and the player's stats during a run ─────────────────────────────
local function AttachCrate(char)
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    if not torso then return nil end
    local crate = Instance.new("Part")
    crate.Name = "CourierCrate"
    crate.Size = Vector3.new(2.8, 2.8, 2.8)
    crate.Material, crate.Color = Enum.Material.Wood, Color3.fromRGB(150, 108, 64)
    crate.CanCollide, crate.Massless, crate.CanQuery = false, true, false
    crate.CFrame = torso.CFrame * CFrame.new(0, 0.4, 1.7)
    local weld = Instance.new("WeldConstraint")
    weld.Part0, weld.Part1 = torso, crate
    weld.Parent = crate
    local band = Instance.new("Part")
    band.Name = "CrateBand"
    band.Size = Vector3.new(2.9, 0.5, 2.9)
    band.Material, band.Color = Enum.Material.Neon, Color3.fromRGB(255, 190, 80)
    band.CanCollide, band.Massless, band.CanQuery = false, true, false
    band.CFrame = crate.CFrame
    local w2 = Instance.new("WeldConstraint")
    w2.Part0, w2.Part1 = crate, band
    w2.Parent = band
    crate.Parent = char
    band.Parent = char
    return { crate, band }
end

local function ApplyStats(rec, hum, perks)
    rec.saved = { walk = hum.WalkSpeed, useJumpPower = hum.UseJumpPower, jumpPower = hum.JumpPower, jumpHeight = hum.JumpHeight }
    hum.WalkSpeed = hum.WalkSpeed * CourierData.CRATE_SPEED_FACTOR + perks.walkBonus
    if hum.UseJumpPower then
        hum.JumpPower = hum.JumpPower * (1 + perks.jumpBonus / 7.2)
    else
        hum.JumpHeight = hum.JumpHeight + perks.jumpBonus
    end
end

local function EndRun(rec)
    runs[rec.player.UserId] = nil
    for _, part in ipairs(rec.crate or {}) do part:Destroy() end
    local player = rec.player
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum and rec.saved then
        hum.WalkSpeed = rec.saved.walk
        if rec.saved.useJumpPower then hum.JumpPower = rec.saved.jumpPower else hum.JumpHeight = rec.saved.jumpHeight end
    end
    for _, name in ipairs({ "CourierCourse", "CourierStart", "CourierRespawns", "CourierCP", "CourierLavaX0", "CourierLavaT0", "CourierLavaSpeed", "CourierLavaZ" }) do
        player:SetAttribute(name, nil)
    end
end

-- ── Boards ────────────────────────────────────────────────────────────────────
local function NameOf(userId)
    if nameCache[userId] then return nameCache[userId] end
    local ok, name = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
    nameCache[userId] = ok and name or ("Player" .. tostring(userId))
    return nameCache[userId]
end

local function DrawBoard(b)
    local part = b.part
    local gui = part and part:FindFirstChild("BoardGui")
    local label = gui and gui:FindFirstChild("Rows")
    if not label then return end
    local lines = { b.title }
    for i = 1, BOARD_SIZE do
        local row = b.rows[i]
        lines[#lines + 1] = row and string.format("%d.  %s   %s", i, row.name, string.format("%d:%04.1f", math.floor(row.seconds / 60), row.seconds % 60)) or string.format("%d.  -", i)
    end
    label.Text = table.concat(lines, "\n")
end

local function RefreshBoard(b)
    local ok, pages = pcall(function() return b.store:GetSortedAsync(true, BOARD_SIZE) end)
    if not ok or not pages then return end
    local ok2, entries = pcall(function() return pages:GetCurrentPageAsync() end)
    if not ok2 or type(entries) ~= "table" then return end
    local rows = {}
    for _, e in ipairs(entries) do
        local userId = tonumber(e.key)
        if userId then table.insert(rows, { name = NameOf(userId), seconds = e.value / 10 }) end
    end
    b.rows = rows
    DrawBoard(b)
end

local function SubmitBest(player, courseId, seconds)
    local b = boards[courseId]
    if not b or not b.store then return end
    task.spawn(function()
        pcall(function()
            b.store:UpdateAsync(tostring(player.UserId), function(old)
                local tenths = math.floor(seconds * 10 + 0.5)
                if type(old) ~= "number" or tenths < old then return tenths end
                return nil
            end)
        end)
        RefreshBoard(b)
    end)
end

-- ── A run ─────────────────────────────────────────────────────────────────────
local function Summary(course, result)
    local mats = {}
    for _, m in ipairs(result.materials or {}) do table.insert(mats, { id = m.id, qty = m.qty }) end
    return {
        course = course.name, tier = course.def.tier, medal = result.medal, seconds = result.seconds, respawns = result.respawns, coins = result.coins, xp = result.xp, playerXp = result.playerXp,
        level = result.level, levelUps = result.levelUps, xpInto = result.xpInto, xpNeeded = result.xpNeeded, materials = mats, rare = result.rare,
        personalBest = result.personalBest, previousBest = result.previousBest, daily = result.daily, cappedCoins = result.cappedCoins, bundleSkipped = result.bundleSkipped,
        par = course.par,
    }
end

local function StartRun(player, course)
    if runs[player.UserId] then
        Tell(player, "Already on a run", "Finish your delivery first, or fall far behind to drop it.")
        return
    end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local data = PlayerDataService.Get(player)
    if not (root and hum and hum.Health > 0 and data) then return end
    local ok, why = CourierRewards.CanStart(data, course.def, Today())
    if not ok then
        Tell(player, "Courier Run", why)
        return
    end
    local now = ServerNow()
    local state = CourierRewards.State(data, Today())
    local rec = { player = player, course = course }
    rec.run = CourierRunner.New(course, {
        onCheckpoint = function(index, seconds)
            player:SetAttribute("CourierCP", index)
            Fire(player, "checkpoint", { index = index - 1, total = #course.layout.checkpoints - 1, seconds = seconds })
        end,
        onRespawn = function(reason, cpIndex, cp)
            local target = Vector3.new(cp.x, cp.y + 2, cp.z)
            if root.Parent then
                root.CFrame = CFrame.lookAt(target, target + Vector3.new(1, 0, 0))
                root.AssemblyLinearVelocity = Vector3.zero
            end
            player:SetAttribute("CourierRespawns", rec.run.respawns)
            if rec.run.lavaX0 then
                player:SetAttribute("CourierLavaX0", rec.run.lavaX0)
                player:SetAttribute("CourierLavaT0", rec.run.lavaT0)
            end
            Fire(player, "respawn", { reason = reason, checkpoint = cpIndex - 1, respawns = rec.run.respawns, penalty = CourierData.RESPAWN_PENALTY })
        end,
        onFinish = function(seconds, respawns)
            local d = PlayerDataService.Get(player)
            if d then
                local result = CourierRewards.Settle(d, course, seconds, respawns, Today(), math.random, LiveOpsService.GetMultiplier("coins"))
                PlayerDataService.MarkDirty(player)
                if result.personalBest then SubmitBest(player, course.id, seconds) end
                -- the rest of the game: player XP (this is what levels you up), Quests and achievements
                result.playerXp = CourierData.PlayerXp(course.def, result.medal)
                ProgressionService.AddPlayerXP(player, result.playerXp)
                ChallengeService.TrackEvent(player, "CourierDelivery", { count = 1 })
                if result.medal == "Gold" then ChallengeService.TrackEvent(player, "CourierGold", { count = 1 }) end
                Fire(player, "finish", Summary(course, result))
            end
            EndRun(rec)
        end,
        onAbandon = function(reason)
            Fire(player, "abandon", { reason = reason })
            EndRun(rec)
        end,
    }, now)
    rec.crate = AttachCrate(char)
    ApplyStats(rec, hum, CourierData.Perks(state.level))
    runs[player.UserId] = rec

    player:SetAttribute("CourierCourse", course.id)
    player:SetAttribute("CourierStart", now)
    player:SetAttribute("CourierRespawns", 0)
    player:SetAttribute("CourierCP", 1)
    if course.def.lava then
        player:SetAttribute("CourierLavaX0", rec.run.lavaX0)
        player:SetAttribute("CourierLavaT0", rec.run.lavaT0)
        player:SetAttribute("CourierLavaSpeed", course.def.lava.speed)
        player:SetAttribute("CourierLavaZ", course.layout.base.z)
    end
    Fire(player, "start", { course = course.name, courseId = course.id, checkpoints = #course.layout.checkpoints - 1, par = course.par,
        best = state.best[course.id], lava = course.def.lava ~= nil, courierLevel = state.level })
end

local function Tick()
    local now = ServerNow()
    for _, rec in pairs(runs) do
        local player = rec.player
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (root and hum and hum.Health > 0) then
            Fire(player, "abandon", { reason = "died" })
            EndRun(rec)
        else
            local p = root.Position
            CourierRunner.Step(rec.run, now, p.X, p.Y, p.Z)
        end
    end
end

function CourierService.Init()
    local world = workspace:FindFirstChild("EmberWorld")
    if not world then
        warn("[CourierService] EmberWorld not found: build the world first")
        return
    end
    local root = Instance.new("Folder")
    root.Name = "CourierRuns"
    root.Parent = world
    for _, def in ipairs(CourierData.Courses) do
        local course = CourierData.Resolve(def.id)
        local folder = CourierArt.Build(root, course)
        local prompt = folder:FindFirstChild("CourierPickup", true)
        if prompt then prompt.Triggered:Connect(function(player) StartRun(player, course) end) end
        -- the fastest-times board beside the start
        local cp = course.layout.checkpoints[1]
        local part = Instance.new("Part")
        part.Name, part.Anchored, part.CanCollide = "Board", true, false
        part.Size = Vector3.new(0.5, 9, 14)
        part.Material, part.Color = Enum.Material.SmoothPlastic, Color3.fromRGB(34, 22, 18)
        part.CFrame = CFrame.new(cp.x - 12, cp.y - 3 + 6, cp.z - 4) * CFrame.Angles(0, math.rad(-90), 0)
        part.Parent = folder
        local gui = Instance.new("SurfaceGui")
        gui.Name, gui.Face, gui.SizingMode, gui.PixelsPerStud = "BoardGui", Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40
        gui.Parent = part
        SignArt.Frame("Notice", part)
        local label = Instance.new("TextLabel")
        label.Name = "Rows"
        label.Size, label.Position, label.BackgroundTransparency = UDim2.new(1, -30, 1, -30), UDim2.new(0, 15, 0, 15), 1
        label.TextColor3, label.Font, label.TextScaled, label.TextXAlignment = def.color or Color3.fromRGB(255, 232, 170), Enum.Font.GothamBold, true, Enum.TextXAlignment.Left
        label.Text = ""
        label.Parent = gui
        boards[def.id] = { store = SafeDataStore.GetOrderedDataStore("EF_Courier_" .. def.id .. "_v1"), rows = {}, part = part, title = def.name .. ": fastest" }
        DrawBoard(boards[def.id])
    end
    task.spawn(function()
        while true do
            task.wait(SAMPLE)
            local ok, err = pcall(Tick)
            if not ok then warn("[CourierService] " .. tostring(err)) end
        end
    end)
    task.spawn(function()
        while true do
            for _, b in pairs(boards) do RefreshBoard(b) end
            task.wait(BOARD_REFRESH)
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        local rec = runs[player.UserId]
        if rec then EndRun(rec) end
    end)
end

return CourierService
