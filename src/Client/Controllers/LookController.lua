-- Blends the world's lighting to the mood of wherever you are (MoodData): warm hub, a colour for each mining cave, open sky up the Sky Tower, a darkening Hollow Maze.
-- The Tower and Maze controllers call SetMood to say which zone or section you are in; anywhere else the mood comes from where you stand.
local Lighting     = game:GetService("Lighting")
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MoodData = require(game.ReplicatedStorage.Shared.Data.MoodData)

local LookController = {}

local atmosphere, grade, bloom
local current, override
local lastCheck = 0

local function C(t) return Color3.fromRGB(t[1], t[2], t[3]) end

local function Ensure(class)
    local inst = Lighting:FindFirstChildOfClass(class)
    if not inst then
        inst = Instance.new(class)
        inst.Parent = Lighting
    end
    return inst
end

local function Tween(inst, props, seconds)
    TweenService:Create(inst, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props):Play()
end

-- Fade to a named mood (instantly when seconds is 0, e.g. on the first frame).
function LookController.Apply(name, seconds)
    local m = MoodData.Moods[name]
    if not m or name == current then return end
    current = name
    local s = seconds or MoodData.BLEND_SECONDS
    Tween(Lighting, { Ambient = C(m.ambient), OutdoorAmbient = C(m.outdoor), Brightness = m.brightness, ExposureCompensation = m.exposure }, s)
    Tween(atmosphere, { Density = m.density, Offset = m.offset, Haze = m.haze, Color = C(m.atmColor), Decay = C(m.atmDecay) }, s)
    Tween(grade, { TintColor = C(m.tint), Saturation = m.sat, Contrast = m.contrast }, s)
    Tween(bloom, { Intensity = m.bloomI, Size = m.bloomSize, Threshold = m.bloomThreshold }, s)
end

-- A controller that knows better than the position (the Tower's zone, the Maze's section) sets this; SetMood(nil) hands control back to the position.
function LookController.SetMood(name)
    override = name
    if name then LookController.Apply(name) end
end

function LookController.Current() return current end

local function Update()
    if override then return end
    local char = Players.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local p = root.Position
    LookController.Apply(MoodData.MoodAt(p.X, p.Z))
end

function LookController.Init()
    Lighting.GlobalShadows = MoodData.SHADOWS
    atmosphere = Ensure("Atmosphere")
    grade = Ensure("ColorCorrectionEffect")
    bloom = Ensure("BloomEffect")
    LookController.Apply("Hub", 0)
    RunService.Heartbeat:Connect(function(dt)
        lastCheck += dt
        if lastCheck < 0.5 then return end
        lastCheck = 0
        Update()
    end)
end

return LookController
