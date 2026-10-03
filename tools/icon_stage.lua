-- Icon capture stage. Run in the CLIENT command bar while the game is playing (Golem assets must be loaded).
-- Builds all 13 Golems with the game's own GolemModel on a green screen 3000 studs above the world,
-- pins the camera, and hides GUIs. Stop play to reset everything.
local GM = require(game.ReplicatedStorage.Shared.Modules.GolemModel)
local RS = game:GetService("RunService")
local old = workspace:FindFirstChild("IconStage"); if old then old:Destroy() end
local f = Instance.new("Folder"); f.Name = "IconStage"; f.Parent = workspace

local function Block(n, size, pos)
    local p = Instance.new("Part"); p.Name = n; p.Anchored = true; p.Size = size; p.Position = pos
    p.Color = Color3.fromRGB(0, 255, 0); p.Material = Enum.Material.SmoothPlastic; p.CastShadow = false; p.Parent = f
end
Block("GreenFloor", Vector3.new(400, 1, 300), Vector3.new(0, 2999.5, -20))
Block("GreenWall", Vector3.new(400, 200, 2), Vector3.new(0, 3100, -80))

local L = game.Lighting
L.Ambient = Color3.fromRGB(150, 150, 150); L.OutdoorAmbient = L.Ambient; L.Brightness = 2.5; L.ClockTime = 14
L.GlobalShadows = false; L.FogEnd = 1e6; L.FogStart = 1e6
for _, e in ipairs(L:GetChildren()) do
    if e:IsA("PostEffect") then e.Enabled = false elseif e:IsA("Atmosphere") then e.Density = 0 end
end

-- V formation: Gargoyle at the point nearest the camera, two arms stepping back and outward.
local STEP_X, STEP_Z = 17, 11
local left  = { { "Clockwork", 3 }, { "Frost", 4 }, { "Coral", 3 }, { "Void", 4 }, { "StormJar", 4 }, { "Dragonbone", 4 } }
local right = { { "Patchwork", 2 }, { "Stone", 4 }, { "Woven", 2 }, { "Alchemist", 3 }, { "Storm", 4 }, { "Ember", 5 } }
-- { element, tier, x, z }
local spec = { { "Gargoyle", 3, 0, 26 } }
for i = 1, 6 do
    table.insert(spec, { left[i][1],  left[i][2],  -STEP_X * i, 26 - STEP_Z * i })
    table.insert(spec, { right[i][1], right[i][2],  STEP_X * i, 26 - STEP_Z * i })
end
for _, s in ipairs(spec) do
    local ok, m = pcall(GM.Build, s[1], s[2], {})
    if ok then
        m.Name = s[1]; m.Parent = f
        m:PivotTo(CFrame.new(s[3], 3010, s[4]) * CFrame.Angles(0, math.rad(180 - s[3] * 0.45), 0))
        local cf, size = m:GetBoundingBox()
        m:PivotTo(m:GetPivot() + Vector3.new(0, 3000 - (cf.Position.Y - size.Y / 2), 0))
    end
end

local cam = CFrame.lookAt(Vector3.new(0, 3030, 78), Vector3.new(0, 3010, -14))
pcall(function() RS:UnbindFromRenderStep("IconCam") end)
RS:BindToRenderStep("IconCam", Enum.RenderPriority.Last.Value + 10, function()
    local c = workspace.CurrentCamera
    c.CameraType = Enum.CameraType.Scriptable; c.FieldOfView = 50; c.CFrame = cam
end)
local plr = game.Players.LocalPlayer
for _, g in ipairs(plr.PlayerGui:GetChildren()) do if g:IsA("ScreenGui") then g.Enabled = false end end
if plr.Character then plr.Character:PivotTo(CFrame.new(0, 6000, 0)) end
