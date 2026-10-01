-- Labels the HUD buttons that are not open yet. A locked button keeps its colour and its spinning icon, but its caption
-- says what is needed ("Level 4") and a small lock sits on the corner; pressing it explains why instead of opening.
-- The rules live in FeatureGates (shared with the server, which refuses the actions too).

local Players = game:GetService("Players")

local FeatureGates = require(game.ReplicatedStorage.Shared.Data.FeatureGates)

local GateController = {}

local lastData
local wired = {}        -- button -> true once its click handler is connected

local LOCK_COLOUR = Color3.fromRGB(255, 214, 120)

local function Toast(title, message)
    local ok, HUD = pcall(function() return require(script.Parent.HUDController) end)
    if ok and HUD and HUD.ShowNotification then HUD.ShowNotification(title, message) end
end

local function Lock(button, label, reason)
    button:SetAttribute("GateReason", reason)
    local cap = button:FindFirstChild("Caption")
    if cap then
        if not button:GetAttribute("BaseCaption") then button:SetAttribute("BaseCaption", cap.Text) end
        cap.Text = label
        cap.TextColor3 = LOCK_COLOUR
    end
    if not button:FindFirstChild("LockTag") then
        local tag = Instance.new("TextLabel")
        tag.Name = "LockTag"
        tag.AnchorPoint = Vector2.new(1, 0)
        tag.Position = UDim2.new(1, -3, 0, 3)
        tag.Size = UDim2.new(0, 18, 0, 18)
        tag.BackgroundColor3 = Color3.fromRGB(20, 14, 12)
        tag.BackgroundTransparency = 0.25
        tag.BorderSizePixel = 0
        tag.Text = "🔒"
        tag.TextSize = 11
        tag.ZIndex = 5
        tag.Parent = button
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 5)
        corner.Parent = tag
    end
end

local function Unlock(button)
    if button:GetAttribute("GateReason") == nil then return end
    button:SetAttribute("GateReason", nil)
    local cap = button:FindFirstChild("Caption")
    local base = button:GetAttribute("BaseCaption")
    if cap and base then
        cap.Text = base
        cap.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
    local tag = button:FindFirstChild("LockTag")
    if tag then tag:Destroy() end
end

local function Apply()
    local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
    local hud = pg and pg:FindFirstChild("HUD")
    if not hud or not lastData then return end
    for id, def in pairs(FeatureGates.List) do
        local button = hud:FindFirstChild(def.nav, true)
        if button then
            if not wired[button] then
                wired[button] = true
                button.MouseButton1Click:Connect(function()
                    local reason = button:GetAttribute("GateReason")
                    if reason then Toast("Not yet", reason) end
                end)
            end
            local ok, reason, label = FeatureGates.Check(id, lastData)
            if ok then Unlock(button) else Lock(button, label, reason) end
        end
    end
end

function GateController.Update(data)
    lastData = data
    Apply()
end

return GateController
