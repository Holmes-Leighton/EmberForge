-- A burst of confetti for the good moments (level-up, a rare craft, an achievement). Client only; costs nothing when it is not called.
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Celebrate = {}

local GOLD = { Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 232, 130), Color3.fromRGB(245, 135, 25), Color3.fromRGB(255, 255, 255) }
local rng = Random.new()
local gui
local live = 0
local MAX_LIVE = 80                      -- never pile up when several things happen at once

local function Holder()
    if gui and gui.Parent then return gui end
    local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    gui = Instance.new("ScreenGui")
    gui.Name = "Celebrate"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 40
    gui.Parent = pg
    return gui
end

-- opts: count (default 24), colors (list of Color3), origin (UDim2, default upper middle), spread (pixels, default 260)
function Celebrate.Burst(opts)
    opts = opts or {}
    local holder = Holder()
    if not holder then return end
    local colors = opts.colors or GOLD
    local origin = opts.origin or UDim2.new(0.5, 0, 0.35, 0)
    local spread = opts.spread or 260
    local count = math.min(opts.count or 24, MAX_LIVE - live)
    for _ = 1, count do
        live += 1
        local p = Instance.new("Frame")
        local size = rng:NextInteger(6, 12)
        p.Size = UDim2.new(0, size, 0, size)
        p.AnchorPoint = Vector2.new(0.5, 0.5)
        p.Position = origin
        p.BackgroundColor3 = colors[rng:NextInteger(1, #colors)]
        p.BorderSizePixel = 0
        p.Rotation = rng:NextInteger(0, 180)
        p.Parent = holder
        local angle = rng:NextNumber(0, math.pi * 2)
        local dist = rng:NextNumber(spread * 0.35, spread)
        local rise = math.sin(angle) * dist - rng:NextNumber(30, 90)          -- pieces fly up and out, then fall as they fade
        local goal = {
            Position = UDim2.new(origin.X.Scale, origin.X.Offset + math.cos(angle) * dist, origin.Y.Scale, origin.Y.Offset + rise + dist * 0.5),
            Rotation = p.Rotation + rng:NextInteger(-260, 260),
            BackgroundTransparency = 1,
        }
        local t = TweenService:Create(p, TweenInfo.new(rng:NextNumber(0.9, 1.5), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
        t:Play()
        task.delay(1.6, function()
            live = math.max(0, live - 1)
            p:Destroy()
        end)
    end
end

-- Colours by Golem tier: a plain craft gets a small burst, a rare one a big shower
function Celebrate.Craft(tier)
    tier = tier or 1
    if tier >= 3 then
        Celebrate.Burst({ count = 20 + tier * 8, spread = 300 })
    else
        Celebrate.Burst({ count = 10, spread = 180 })
    end
end

return Celebrate
