-- Cart Run: builds the courses in the hub and runs them. The rules live in CartRunner (pure); this finds who is pushing, pays the players, tells them what happened,
-- and publishes each cart's position as attributes (PathS / PathV / PathT = distance, speed and server time) that every client turns into smooth movement.
local Players = game:GetService("Players")

local CartCourseData  = require(game.ReplicatedStorage.Shared.Data.CartCourseData)
local CartBountyData  = require(game.ReplicatedStorage.Shared.Data.CartBountyData)
local CartPath        = require(game.ReplicatedStorage.Shared.Modules.CartPath)
local RemoteEvents    = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CartBountyService = require(script.Parent.CartBountyService)
local CartRunner      = require(script.Parent.CartRunner)
local CartCourseArt   = require(script.Parent.CartCourseArt)

local CartCourseService = {}

local PUSH_REACH_BEHIND, PUSH_REACH_AHEAD = 12, 4       -- studs behind / ahead of the cart's middle that still count as pushing
local PUSH_REACH_SIDE = 10
local PUSH_CONTACT, PUSH_CONTACT_SIDE = 8, 6                -- close enough behind the cart (studs) that walking into it counts as pushing
local MIN_PUSH_SPEED  = 5                                -- studs/s forward along the rail
local ACTIVE_RANGE    = 260                              -- carts with nobody this close (and parked at the start) are not simulated
local TICK            = 1 / 20

local courses = {}      -- { r, runner, model, folder, artFolder, lastPublish, lastStatus }

local function ServerNow() return workspace:GetServerTimeNow() end

local function CartPosition(c)
    local x, y, z, tx, ty, tz = CartPath.At(c.r.path, c.runner.st.s)
    return Vector3.new(x, y, z), tx, tz
end

-- The players pushing this cart right now: { { userId, speed, player } ... }
local function FindPushers(c)
    local pos, tx, tz = CartPosition(c)
    local hl = math.sqrt(tx * tx + tz * tz)
    if hl < 1e-4 then return {} end
    local hx, hz = tx / hl, tz / hl
    local out = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if root and hum and hum.Health > 0 then
            local rel = root.Position - pos
            local along = rel.X * hx + rel.Z * hz
            local side = math.abs(-rel.X * hz + rel.Z * hx)
            if along >= -PUSH_REACH_BEHIND and along <= PUSH_REACH_AHEAD and side <= PUSH_REACH_SIDE and math.abs(rel.Y) <= 16 then
                local vel = root.AssemblyLinearVelocity
                local speed = vel.X * hx + vel.Z * hz
                -- Leaning on the cart's back: the solid body stops the character, so its speed reads near zero. Walking forward into it still counts as pushing,
                -- at the pace the character is trying to walk (otherwise a parked cart can hardly be started on the flat).
                if along >= -PUSH_CONTACT and side <= PUSH_CONTACT_SIDE then
                    local intent = hum.MoveDirection.X * hx + hum.MoveDirection.Z * hz
                    if intent > 0.5 then speed = math.max(speed, hum.WalkSpeed * intent) end
                end
                -- forward = pushing; backward (walking against it) = braking
                if math.abs(speed) >= MIN_PUSH_SPEED then table.insert(out, { userId = player.UserId, speed = speed, player = player }) end
            end
        end
    end
    return out
end

local function Tell(player, title, message)
    if player and player.Parent then RemoteEvents.Notify:FireClient(player, title, message) end
end

local function SetSign(c, text)
    local body = c.model and c.model.PrimaryPart
    local sign = body and body:FindFirstChild("Sign")
    local label = sign and sign:FindFirstChild("Text")
    if label and label.Text ~= text then label.Text = text end
end

-- Pays one player an amount for this course, once their level is high enough. Returns coins paid (0 if none).
local function Pay(player, c, amount, finished, notePay)
    local data = PlayerDataService.Get(player)
    if not data then return 0 end
    if (data.PlayerLevel or 1) < c.r.def.minLevel then
        if notePay then Tell(player, c.r.name, string.format("%s pays from level %d. You're level %d.", c.r.name, c.r.def.minLevel, data.PlayerLevel or 1)) end
        return 0, "level"
    end
    local ok, coins, msg = CartBountyService.PayCourse(player, amount, finished)
    if not ok then
        Tell(player, "Cart Run limit", msg)
        return 0, "cap"
    end
    return coins
end

local function Publish(c, now, force)
    local st = c.runner.st
    if not (c.model and c.model.Parent) then return end
    if force or now - (c.lastPublish or 0) >= 0.1 then
        c.lastPublish = now
        c.model:SetAttribute("PathS", st.s)
        c.model:SetAttribute("PathV", st.v)
        c.model:SetAttribute("PathT", now)
    end
    if now - (c.lastStatus or 0) >= 0.25 then
        c.lastStatus = now
        SetSign(c, CartRunner.StatusText(c.runner, now))
    end
end

local function MakeHooks(c)
    return {
        onCheckpoint = function(index, pushers)
            for _, p in ipairs(pushers) do
                local player = Players:GetPlayerByUserId(p.userId)
                local data = player and PlayerDataService.Get(player)
                if player and data then
                    local share = math.floor(CartBountyData.CourseReward(data, c.r.def) * CartBountyData.COURSE_CHECKPOINT_SHARE)
                    local coins = Pay(player, c, share, false, false)
                    Tell(player, string.format("%s: checkpoint %d/%d", c.r.name, index, #c.r.checkpoints), coins > 0 and string.format("+%d coins", coins) or "Checkpoint reached")
                end
            end
        end,
        onFinish = function(seconds, contributors)
            local medal, bonus = CartBountyData.Medal(seconds, c.r.par)
            for _, userId in ipairs(contributors) do
                local player = Players:GetPlayerByUserId(userId)
                local data = player and PlayerDataService.Get(player)
                if player and data then
                    local coins, why = Pay(player, c, math.floor(CartBountyData.CourseReward(data, c.r.def) * bonus), true, true)
                    local line = string.format("%s in %s", medal and (medal .. " time") or "Delivered", CartRunner.FormatTime(seconds))
                    if coins > 0 then line ..= string.format("  +%d coins", coins) end
                    local isBest, old = CartBountyService.RecordBest(player, c.r.id, seconds)
                    if isBest and old then line ..= string.format("  New best! (was %s)", CartRunner.FormatTime(old))
                    elseif isBest then line ..= "  First time on the board!" end
                    if why ~= "level" then Tell(player, c.r.name .. " complete!", line) end
                end
            end
        end,
        onDerail = function(reason, checkpointIndex)
            local text = reason == "crushed" and "The gate crushed the cart!" or reason == "toppled" and "Too fast round the bend - it tipped over! Slow down (walk against the cart to brake)." or "The cart fell into the pit!"
            local pos = CartPosition(c)
            for _, player in ipairs(Players:GetPlayers()) do
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if root and (root.Position - pos).Magnitude < 60 then
                    Tell(player, "Derailed!", text .. (checkpointIndex > 0 and " Back to checkpoint " .. checkpointIndex .. "." or " Back to the start."))
                end
            end
        end,
        onReset = function(reason)
            c.model:SetAttribute("Jump", (c.model:GetAttribute("Jump") or 0) + 1)         -- clients snap instead of gliding back
        end,
    }
end

local function BuildCourse(world, root, id, index)
    local r = CartCourseData.Resolve(id)
    local c = { r = r }
    c.artFolder = CartCourseArt.Build(root, r)
    c.model = CartCourseArt.BuildCart(root, r, index)
    c.runner = CartRunner.New(r, MakeHooks(c))
    c.lastPublish, c.lastStatus = 0, 0
    c.model:SetAttribute("PathT", ServerNow())
    return c
end

local function BuildAll()
    local world = workspace:FindFirstChild("EmberWorld")
    if not world then
        warn("[CartCourseService] EmberWorld not found: build the world first")
        return
    end
    local old = world:FindFirstChild("CartRuns")
    local saved = {}
    if old then                                                                -- a rebuild (mesh pack loaded) keeps each cart where it was
        for _, c in ipairs(courses) do saved[c.r.id] = { st = c.runner.st, phase = c.runner.phase, phaseAt = c.runner.phaseAt, runner = c.runner } end
        old:Destroy()
    end
    local root = Instance.new("Folder")
    root.Name = "CartRuns"
    root.Parent = world
    courses = {}
    CartCourseArt.BuildSignpost(root)
    for i, def in ipairs(CartCourseData.Courses) do
        local c = BuildCourse(world, root, def.id, i)
        local s = saved[def.id]
        if s then                                                              -- carry the run state over to the rebuilt cart
            c.runner = s.runner
            c.runner.hooks = MakeHooks(c)
            c.model:PivotTo(CartCourseArt.CartCFrame(c.r, s.st.s))
            c.model:SetAttribute("PathS", s.st.s)
        end
        table.insert(courses, c)
    end
end

local function Tick(now)
    for _, c in ipairs(courses) do
        local runner = c.runner
        local pushers
        local pos = CartPosition(c)
        local idleAtStart = runner.phase == "idle" and runner.st.s == 0
        local anyoneNear = false
        if idleAtStart then
            for _, player in ipairs(Players:GetPlayers()) do
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if root and (root.Position - pos).Magnitude < ACTIVE_RANGE then anyoneNear = true break end
            end
        end
        if not idleAtStart or anyoneNear then
            pushers = (runner.phase == "idle" or runner.phase == "running") and FindPushers(c) or {}
            CartRunner.Step(runner, TICK, now, pushers)
        end
        Publish(c, now, runner.st.v ~= 0 or (c.lastV or 0) ~= 0)
        c.lastV = runner.st.v
    end
end

function CartCourseService.Init()
    BuildAll()
    require(script.Parent.BiomeArt).OnWorldRefresh(BuildAll)                   -- redraw the carts and road art with meshes once the World pack loads
    task.spawn(function()
        while true do
            task.wait(TICK)
            local ok, err = pcall(Tick, ServerNow())
            if not ok then warn("[CartCourseService] " .. tostring(err)) end
        end
    end)
end

-- For tests and the admin tools
function CartCourseService.Courses() return courses end

return CartCourseService
