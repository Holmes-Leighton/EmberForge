-- Loading screen (spec 10.2): shown while the game loads and the player's data arrives, then fades out.

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players         = game:GetService("Players")
local TweenService    = game:GetService("TweenService")
local RunService      = game:GetService("RunService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "EmberLoading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.Parent = playerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(18, 14, 12)
bg.BorderSizePixel = 0
bg.Parent = gui

local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(60, 24, 10), Color3.fromRGB(14, 11, 10))
grad.Rotation = 90
grad.Parent = bg

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.new(0.5, 0, 0.42, 0)
title.Size = UDim2.new(0.8, 0, 0, 80)
title.BackgroundTransparency = 1
title.Text = "EMBERFORGE"
title.TextColor3 = Color3.fromRGB(255, 160, 50)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.Parent = bg

local sub = Instance.new("TextLabel")
sub.AnchorPoint = Vector2.new(0.5, 0.5)
sub.Position = UDim2.new(0.5, 0, 0.42, 64)
sub.Size = UDim2.new(0.8, 0, 0, 26)
sub.BackgroundTransparency = 1
sub.Text = "Build your Golems. Keep the fire burning."
sub.TextColor3 = Color3.fromRGB(200, 185, 170)
sub.Font = Enum.Font.Gotham
sub.TextScaled = true
sub.Parent = bg

local barBg = Instance.new("Frame")
barBg.AnchorPoint = Vector2.new(0.5, 0)
barBg.Position = UDim2.new(0.5, 0, 0.62, 0)
barBg.Size = UDim2.new(0.4, 0, 0, 8)
barBg.BackgroundColor3 = Color3.fromRGB(40, 32, 26)
barBg.BorderSizePixel = 0
barBg.Parent = bg
Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
local bar = Instance.new("Frame")
bar.Size = UDim2.new(0, 0, 1, 0)
bar.BackgroundColor3 = Color3.fromRGB(255, 140, 40)
bar.BorderSizePixel = 0
bar.Parent = barBg
Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

local tips = {
    "Stand on a glowing pad to gather Ore and Coal.",
    "Fuse 4 identical Golems at the Neon Cave to make a Neon.",
    "Your Golems keep mining while you are away.",
    "Higher Forge levels unlock stronger Golem tiers.",
    "Visit other players' forges and trade with them.",
}
local tip = Instance.new("TextLabel")
tip.AnchorPoint = Vector2.new(0.5, 0)
tip.Position = UDim2.new(0.5, 0, 0.7, 0)
tip.Size = UDim2.new(0.7, 0, 0, 24)
tip.BackgroundTransparency = 1
tip.Text = "Tip: " .. tips[math.random(#tips)]
tip.TextColor3 = Color3.fromRGB(170, 155, 140)
tip.Font = Enum.Font.Gotham
tip.TextScaled = true
tip.Parent = bg

-- progress: game loaded (50%) -> our HUD exists (100%); never wait longer than 25 s
local started = os.clock()
local progress = 0
local conn = RunService.RenderStepped:Connect(function()
    bar.Size = UDim2.new(progress, 0, 1, 0)
end)

if not game:IsLoaded() then game.Loaded:Wait() end
progress = 0.5
while os.clock() - started < 25 and not playerGui:FindFirstChild("HUD") do
    progress = math.min(0.95, progress + 0.01)
    task.wait(0.1)
end
progress = 1
task.wait(0.4)

for _, obj in ipairs(bg:GetDescendants()) do
    if obj:IsA("TextLabel") then TweenService:Create(obj, TweenInfo.new(0.5), { TextTransparency = 1 }):Play() end
end
local fade = TweenService:Create(bg, TweenInfo.new(0.6), { BackgroundTransparency = 1 })
fade:Play()
fade.Completed:Wait()
conn:Disconnect()
gui:Destroy()
