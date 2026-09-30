-- "What should I do next?" A bobbing arrow and speech bubble above the HUD button that needs the
-- player right now: deploy an idle Golem, claim a quest or a season reward.
-- Driven by the same counts as the red badges (BadgeController), so the two never disagree.
-- Stays out of the way during the first-run tutorial (which has its own tracker).

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local GuideController = {}

local PRIORITY = {
    { button = "ForgeButton",      badge = "ForgeButton",      text = "Your Golems need you" },
    { button = "ChallengesButton", badge = "ChallengesButton", text = "Claim your reward!" },
    { button = "SeasonButton",     badge = "SeasonButton",     text = "Season reward ready!" },
}

-- Returns { button, text } or nil. `counts` is BadgeController.Compute(...).
function GuideController.Pick(counts, hasGolem)
    if not hasGolem then return nil end
    for _, step in ipairs(PRIORITY) do
        local c = counts[step.badge]
        if c and c.count > 0 then return step end
    end
    return nil
end

local marker, currentTarget

local function ClearMarker()
    if marker then marker:Destroy() marker = nil end
    currentTarget = nil
end

local function MakeMarker(parent, text)
    local m = Instance.new("Frame")
    m.Name = "GuideMarker"
    m.AnchorPoint = Vector2.new(0.5, 1)
    m.Position = UDim2.new(0.5, 0, 0, -8)
    m.Size = UDim2.new(0, 170, 0, 40)
    m.BackgroundColor3 = Color3.fromRGB(255, 226, 120)
    m.BorderSizePixel = 0
    m.ZIndex = 20
    m.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = m

    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -8, 1, -12)
    label.Position = UDim2.new(0, 4, 0, 2)
    label.Text = text
    label.TextColor3 = Color3.fromRGB(60, 36, 12)
    label.Font = Enum.Font.GothamBlack
    label.TextSize = 14
    label.TextWrapped = true
    label.ZIndex = 21
    label.Parent = m

    local arrow = Instance.new("TextLabel")
    arrow.Name = "Arrow"
    arrow.BackgroundTransparency = 1
    arrow.AnchorPoint = Vector2.new(0.5, 0)
    arrow.Position = UDim2.new(0.5, 0, 1, -8)
    arrow.Size = UDim2.new(0, 30, 0, 22)
    arrow.Text = "▼"
    arrow.TextColor3 = Color3.fromRGB(255, 226, 120)
    arrow.Font = Enum.Font.GothamBlack
    arrow.TextSize = 22
    arrow.ZIndex = 21
    arrow.Parent = m

    pcall(function()
        TweenService:Create(m, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Position = UDim2.new(0.5, 0, 0, -18) }):Play()
    end)
    return m
end

-- counts: BadgeController.Compute result; hasGolem: whether the tutorial phase is over
function GuideController.Show(counts, hasGolem)
    local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
    local hud = pg and pg:FindFirstChild("HUD")
    if not hud then return end
    local step = GuideController.Pick(counts or {}, hasGolem)
    if not step then ClearMarker() return end
    local button = hud:FindFirstChild(step.button, true)
    if not button then ClearMarker() return end
    if button == currentTarget and marker and marker.Parent then
        local t = marker:FindFirstChild("Text") if t then t.Text = step.text end
        return
    end
    ClearMarker()
    currentTarget = button
    marker = MakeMarker(button, step.text)
end

return GuideController
