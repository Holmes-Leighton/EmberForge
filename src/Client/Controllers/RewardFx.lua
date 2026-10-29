-- Reward feedback: coins that fly from your character to the purse (a pop that rises in pitch for each one), a count-up on the number, and a bump on the purse.
-- HUDController calls CoinBurst whenever your coins go up, so every source of coins (quests, selling, the Tower, the Maze, level-ups...) feels the same.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)
local Utils = require(game.ReplicatedStorage.Shared.Modules.Utils)

local RewardFx = {}

local LocalPlayer = Players.LocalPlayer
local rng = Random.new()
local fxGui
local flying = 0

RewardFx.MAX_COINS  = 14      -- never more coins in flight than this (a huge payout is still a handful of coins)
RewardFx.MAX_FLYING = 36
RewardFx.Sound      = nil     -- set by init.client.lua to SoundController (kept out of the require chain so this module stands alone in tests)
RewardFx.Flown      = 0       -- how many coins have landed in total (tests read this)

-- How many coins fly for a payout: 1 for a few coins, up to MAX_COINS for a big one (roughly three per power of ten).
function RewardFx.CoinCount(amount)
    if amount <= 0 then return 0 end
    return math.clamp(1 + math.floor(math.log(amount, 10) * 3 + 0.5), 1, RewardFx.MAX_COINS)
end

-- The pitch (playback speed) of the i-th pop of n: a little scale going up, so a stream of coins sounds like a rising run.
function RewardFx.PopPitch(i, n)
    return 1 + 0.5 * ((i - 1) / math.max(1, n - 1))
end

local function Gui()
    if fxGui and fxGui.Parent then return fxGui end
    fxGui = Instance.new("ScreenGui")
    fxGui.Name = "RewardFx"
    fxGui.ResetOnSpawn = false
    fxGui.IgnoreGuiInset = true
    fxGui.DisplayOrder = 60
    fxGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    return fxGui
end

local function Centre(obj)
    local p, s = obj.AbsolutePosition, obj.AbsoluteSize
    return Vector2.new(p.X + s.X / 2, p.Y + s.Y / 2)
end

-- where coins start: over the character if it is on screen, else the middle of the screen
local function Origin(gui)
    local origin = Vector2.new(gui.AbsoluteSize.X / 2, gui.AbsoluteSize.Y * 0.55)
    local cam = workspace.CurrentCamera
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root and cam and cam.WorldToViewportPoint then
        local v, onScreen = cam:WorldToViewportPoint(root.Position + Vector3.new(0, 2.5, 0))
        if onScreen then origin = Vector2.new(v.X, v.Y) end
    end
    return origin
end

-- A small bump on a gui object (scale up then settle).
function RewardFx.Bump(obj, size)
    if not obj then return end
    local base = obj.Size
    TweenService:Create(obj, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.new(base.X.Scale, base.X.Offset + (size or 6), base.Y.Scale, base.Y.Offset + (size or 6)) }):Play()
    task.delay(0.1, function()
        TweenService:Create(obj, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = base }):Play()
    end)
end

-- Count a label up from one number to another (formatted like the HUD's coins).
function RewardFx.CountUp(label, from, to, seconds)
    if not label then return end
    seconds = seconds or 0.7
    local steps = 14
    label.Text = Utils.FormatNumber(from)
    task.spawn(function()
        for i = 1, steps do
            task.wait(seconds / steps)
            label.Text = Utils.FormatNumber(math.floor(from + (to - from) * (i / steps) ^ 0.7 + 0.5))
        end
        label.Text = Utils.FormatNumber(to)
    end)
end

-- Fly coins to the purse. amount: what was gained; hud: the HUD ScreenGui (to find the purse); newTotal: for the count-up.
function RewardFx.CoinBurst(amount, hud, previous, newTotal)
    if amount <= 0 then return 0 end
    local gui = Gui()
    local target = hud and hud:FindFirstChild("CoinIcon", true)
    local label = hud and hud:FindFirstChild("CoinsLabel", true)
    local purse = hud and hud:FindFirstChild("Purse", true)
    if label and previous and newTotal then RewardFx.CountUp(label, previous, newTotal) end
    local to = target and Centre(target) or Vector2.new(70, 90)
    local from = Origin(gui)
    local n = RewardFx.CoinCount(amount)
    local sent = 0
    for i = 1, n do
        if flying >= RewardFx.MAX_FLYING then break end
        sent += 1
        flying += 1
        local delay = (i - 1) * 0.045
        local coin = Instance.new("Frame")
        coin.AnchorPoint = Vector2.new(0.5, 0.5)
        coin.Size = UDim2.new(0, 22, 0, 22)
        coin.BackgroundColor3 = Theme.Colors.Gold or Color3.fromRGB(255, 200, 60)
        coin.BorderSizePixel = 0
        local start = Vector2.new(from.X + rng:NextNumber(-34, 34), from.Y + rng:NextNumber(-22, 22))
        coin.Position = UDim2.new(0, start.X, 0, start.Y)
        coin.Visible = false
        coin.Parent = gui
        Theme.AddCorner(coin, UDim.new(1, 0))
        Theme.AddStroke(coin, Color3.fromRGB(255, 244, 190), 2, 0.1)
        local pitch = RewardFx.PopPitch(i, n)
        task.delay(delay, function()
            coin.Visible = true
            local hop = TweenService:Create(coin, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Position = UDim2.new(0, start.X + rng:NextNumber(-30, 30), 0, start.Y - rng:NextNumber(30, 70)) })
            local fly = TweenService:Create(coin, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In),
                { Position = UDim2.new(0, to.X, 0, to.Y), Size = UDim2.new(0, 14, 0, 14) })
            hop.Completed:Connect(function() fly:Play() end)
            fly.Completed:Connect(function()
                flying -= 1
                RewardFx.Flown += 1
                coin:Destroy()
                if RewardFx.Sound then RewardFx.Sound.Play("CoinPop", { pitch = pitch }) end
                if i % 3 == 1 then RewardFx.Bump(purse or target, 6) end
            end)
            hop:Play()
        end)
    end
    return sent
end

return RewardFx
