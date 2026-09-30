-- First-run onboarding: a "How to Play" pop-up, a step-by-step objective tracker
-- that advances as the player does each thing, and a Help button to reopen it.
-- Players who already own a Golem skip the tracker automatically.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local Theme        = require(game.ReplicatedStorage.Shared.Modules.Theme)

local TutorialController = {}

local STEPS = {
    { title = "Open the Forge",       hint = "Click the 🔥 Forge button on the right sidebar." },
    { title = "Craft your first Golem", hint = "Pick a Tier 1 blueprint in the Forge menu and press Craft." },
    { title = "Deploy it to a zone",   hint = "Select your Golem in the Forge menu and send it to its mining zone." },
    { title = "Collect resources",     hint = "Golems mine on their own. Wait a few seconds, then press ⛏ Collect Resources." },
}

local HOW_TO_PLAY = table.concat({
    "EmberForge is an idle crafting game. Your Golems mine while you play, and while you're away.",
    "",
    "1.  Open the 🔥 Forge and craft a Golem from a Tier 1 blueprint (you start with the materials).",
    "2.  Deploy the Golem to its mining zone so it can gather materials for you.",
    "3.  Press ⛏ Collect Resources to bank what your Golems mined.",
    "4.  Smelt raw materials in the Forge, then craft stronger Golems and level up your Forge.",
    "5.  Finish 📋 Challenges for rewards, trade in the 🏪 Market, and check 🏆 Leaders.",
    "",
    "Tip: walk north to see the six mining zones. Visit other players' forges to trade.",
}, "\n")

local gui, tracker, trackerTitle, trackerHint, howTo
local stepIndex = 1
local active = false

-- ── UI ────────────────────────────────────────────────────────────────────────
local function Build()
    gui = Instance.new("ScreenGui")
    gui.Name = "TutorialGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 30
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = PlayerGui

    -- Objective tracker (top centre, under the HUD bar)
    tracker = Instance.new("Frame")
    tracker.Name = "Tracker"
    tracker.AnchorPoint = Vector2.new(0.5, 0)
    tracker.Size = UDim2.new(0, 400, 0, 70)
    tracker.Position = UDim2.new(0.5, 0, 0, 96)
    tracker.BackgroundColor3 = Theme.Colors.Panel
    tracker.BackgroundTransparency = 0.05
    tracker.BorderSizePixel = 0
    tracker.Visible = false
    tracker.Parent = gui
    Theme.AddCorner(tracker, Theme.Corner.Large)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Colors.Accent
    stroke.Thickness = 2
    stroke.Parent = tracker

    trackerTitle = Theme.Label(tracker, "", 16, Theme.Colors.AccentBright, Theme.Fonts.Heading, "Title")
    trackerTitle.Position = UDim2.new(0, 12, 0, 6)
    trackerTitle.Size = UDim2.new(1, -70, 0, 22)

    trackerHint = Theme.Label(tracker, "", 13, Theme.Colors.TextPrimary, Theme.Fonts.Body, "Hint")
    trackerHint.Position = UDim2.new(0, 12, 0, 30)
    trackerHint.Size = UDim2.new(1, -24, 0, 36)
    trackerHint.TextYAlignment = Enum.TextYAlignment.Top

    local skip = Theme.Button(tracker, "Skip", Theme.Colors.PanelAlt, Theme.Colors.TextSecondary, "Skip")
    skip.Size = UDim2.new(0, 48, 0, 22)
    skip.Position = UDim2.new(1, -56, 0, 6)
    skip.TextSize = 12
    skip.MouseButton1Click:Connect(function()
        active = false
        tracker.Visible = false
    end)

    -- Help button (bottom left)
    local help = Theme.Button(gui, "?  Help", Theme.Colors.Accent, Color3.fromRGB(255, 255, 255), "HelpButton")
    help.Size = UDim2.new(0, 86, 0, 34)
    help.Position = UDim2.new(0, 12, 1, -52)
    help.TextSize = 14
    help.MouseButton1Click:Connect(function() howTo.Visible = true end)

    -- How to Play pop-up
    howTo = Instance.new("Frame")
    howTo.Name = "HowToPlay"
    howTo.Size = UDim2.new(1, 0, 1, 0)
    howTo.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    howTo.BackgroundTransparency = 0.45
    howTo.BorderSizePixel = 0
    howTo.Active = true
    howTo.Visible = false
    howTo.Parent = gui

    local box = Instance.new("Frame")
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.Size = UDim2.new(0, 560, 0, 400)
    box.Position = UDim2.new(0.5, 0, 0.5, 0)
    box.BackgroundColor3 = Theme.Colors.Background
    box.BorderSizePixel = 0
    box.Parent = howTo
    Theme.AddCorner(box, Theme.Corner.Large)

    local title = Theme.Label(box, "🔥  Welcome to EmberForge", Theme.TextSize.Title,
        Theme.Colors.AccentBright, Theme.Fonts.Title, "Title")
    title.Position = UDim2.new(0, 20, 0, 14)
    title.Size = UDim2.new(1, -40, 0, 32)

    local body = Theme.Label(box, HOW_TO_PLAY, 15, Theme.Colors.TextPrimary, Theme.Fonts.Body, "Body")
    body.Position = UDim2.new(0, 20, 0, 58)
    body.Size = UDim2.new(1, -40, 1, -130)
    body.TextYAlignment = Enum.TextYAlignment.Top

    local go = Theme.Button(box, "Let's go!", Theme.Colors.Accent, Color3.fromRGB(255, 255, 255), "StartButton")
    go.Size = UDim2.new(0, 160, 0, 40)
    go.Position = UDim2.new(0.5, -80, 1, -56)
    go.TextSize = 16
    go.MouseButton1Click:Connect(function() howTo.Visible = false end)
end

-- ── Steps ─────────────────────────────────────────────────────────────────────
local function ShowStep()
    local step = STEPS[stepIndex]
    if not step then
        active = false
        tracker.Visible = false
        return
    end
    trackerTitle.Text = string.format("Step %d/%d:  %s", stepIndex, #STEPS, step.title)
    trackerHint.Text = step.hint
    tracker.Visible = true
end

local function Advance(fromStep)
    if not active or stepIndex ~= fromStep then return end
    stepIndex += 1
    if stepIndex > #STEPS then
        active = false
        tracker.Visible = false
        local HUDController = require(script.Parent.HUDController)
        HUDController.ShowNotification("Tutorial complete!", "You're up and running. Keep crafting and exploring.")
    else
        ShowStep()
    end
end

-- ── Init ──────────────────────────────────────────────────────────────────────
function TutorialController.Init(playerData)
    Build()

    local returning = playerData and playerData.Golems and #playerData.Golems > 0
    if returning then return end   -- already played: no forced tutorial, Help button still works

    active = true
    howTo.Visible = true
    ShowStep()

    -- Step 1: Forge menu opened
    task.spawn(function()
        local forgeGui = PlayerGui:WaitForChild("ForgeMenu", 15)
        if forgeGui then
            forgeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
                if forgeGui.Enabled then Advance(1) end
            end)
        end
    end)

    -- Steps 2-4 follow the server's events
    RemoteEvents.GolemCrafted.OnClientEvent:Connect(function(golem)
        if golem then Advance(2) end
    end)
    RemoteEvents.GolemDeployed.OnClientEvent:Connect(function(ok)
        if ok then Advance(3) end
    end)
    RemoteEvents.ResourcesCollected.OnClientEvent:Connect(function(gains)
        if gains and next(gains) ~= nil then Advance(4) end
    end)
end

return TutorialController
