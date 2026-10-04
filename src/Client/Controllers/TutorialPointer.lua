-- Shows a new player where to go: a bobbing arrow floating above the target in the world, and, when the target is off screen, a marker on the edge of the
-- screen pointing the way with the distance. Roblox only draws an object's "Press E" prompt while it is in view, so without a pointer a player standing
-- near the Anvil but facing away sees nothing to press.
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local TutorialPointer = {}

local ORANGE = Color3.fromRGB(255, 160, 50)
local target                       -- { name = "Golem Anvil", position = function() -> Vector3 or nil }
local arrowPart, arrowGui, diamond, nameLabel
local edgeGui, edgeFrame, edgeLabel

local function Build()
    if arrowPart then return end
    arrowPart = Instance.new("Part")
    arrowPart.Name = "TutorialArrow"
    arrowPart.Anchored, arrowPart.CanCollide, arrowPart.CanQuery, arrowPart.CanTouch = true, false, false, false
    arrowPart.Transparency = 1
    arrowPart.Size = Vector3.new(1, 1, 1)
    arrowPart.Parent = workspace

    arrowGui = Instance.new("BillboardGui")
    arrowGui.Size = UDim2.new(0, 150, 0, 120)
    arrowGui.AlwaysOnTop = true
    arrowGui.MaxDistance = 1e5
    arrowGui.Adornee = arrowPart
    arrowGui.Parent = arrowPart

    nameLabel = Instance.new("TextLabel")
    nameLabel.Size, nameLabel.Position = UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3, nameLabel.TextStrokeTransparency, nameLabel.Font = Color3.fromRGB(255, 255, 255), 0.2, Enum.Font.GothamBold
    nameLabel.TextScaled = true
    nameLabel.Parent = arrowGui

    diamond = Instance.new("Frame")                    -- a diamond (a rotated square) pointing down at the target
    diamond.AnchorPoint = Vector2.new(0.5, 0.5)
    diamond.Size, diamond.Position = UDim2.new(0, 34, 0, 34), UDim2.new(0.5, 0, 0, 68)
    diamond.Rotation = 45
    diamond.BackgroundColor3 = ORANGE
    diamond.BorderSizePixel = 0
    diamond.Parent = arrowGui
    local stroke = Instance.new("UIStroke")
    stroke.Color, stroke.Thickness = Color3.fromRGB(255, 255, 255), 3
    stroke.Parent = diamond

    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    edgeGui = Instance.new("ScreenGui")
    edgeGui.Name = "TutorialPointer"
    edgeGui.ResetOnSpawn = false
    edgeGui.IgnoreGuiInset = true
    edgeGui.DisplayOrder = 6
    edgeGui.Enabled = false
    edgeGui.Parent = playerGui

    edgeFrame = Instance.new("Frame")
    edgeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    edgeFrame.Size = UDim2.new(0, 92, 0, 46)
    edgeFrame.BackgroundColor3 = ORANGE
    edgeFrame.BorderSizePixel = 0
    edgeFrame.Parent = edgeGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = edgeFrame
    local es = Instance.new("UIStroke")
    es.Color, es.Thickness = Color3.fromRGB(255, 255, 255), 2
    es.Parent = edgeFrame

    edgeLabel = Instance.new("TextLabel")
    edgeLabel.Size = UDim2.new(1, -8, 1, -4)
    edgeLabel.Position = UDim2.new(0, 4, 0, 2)
    edgeLabel.BackgroundTransparency = 1
    edgeLabel.TextColor3, edgeLabel.TextStrokeTransparency, edgeLabel.Font = Color3.fromRGB(40, 20, 10), 1, Enum.Font.GothamBold
    edgeLabel.TextScaled = true
    edgeLabel.Parent = edgeFrame
end

local function Hide()
    if arrowGui then arrowGui.Enabled = false end
    if edgeGui then edgeGui.Enabled = false end
end

local function Update()
    if not target or not arrowPart then return end
    local pos = target.position()
    local cam = workspace.CurrentCamera
    local char = Players.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not pos or not cam or not root then Hide() return end

    local dist = (root.Position - pos).Magnitude
    if dist < 14 then Hide() return end                              -- you are there

    local t = os.clock()
    arrowPart.CFrame = CFrame.new(pos + Vector3.new(0, 3 + math.sin(t * 3) * 1.2, 0))
    nameLabel.Text = target.name
    arrowGui.Enabled = true

    local vp, onScreen = cam:WorldToViewportPoint(pos)
    if onScreen then
        edgeGui.Enabled = false
        return
    end
    local size = cam.ViewportSize
    local center = size / 2
    local dir = Vector2.new(vp.X, vp.Y) - center
    if vp.Z < 0 then dir = -dir end                                   -- behind the camera: the marker goes the other way
    if dir.Magnitude < 1 then dir = Vector2.new(0, -1) end
    local margin = 60
    local sx = (size.X / 2 - margin) / math.max(math.abs(dir.X), 1e-3)
    local sy = (size.Y / 2 - margin) / math.max(math.abs(dir.Y), 1e-3)
    local p = center + dir * math.min(sx, sy)
    edgeFrame.Position = UDim2.fromOffset(p.X, p.Y)
    edgeLabel.Text = string.format("%s\n%d studs", target.name, math.floor(dist))
    edgeGui.Enabled = true
end

-- target: { name, position = function() return Vector3 or nil end }
function TutorialPointer.Set(newTarget)
    target = newTarget
    if not newTarget then Hide() return end
    Build()
end

function TutorialPointer.Clear()
    target = nil
    Hide()
end

function TutorialPointer.Init()
    local ok = pcall(function() RunService.RenderStepped:Connect(function()
        local good, err = pcall(Update)
        if not good then target = nil Hide() warn("[TutorialPointer] " .. tostring(err)) end
    end) end)
    return ok
end

return TutorialPointer
