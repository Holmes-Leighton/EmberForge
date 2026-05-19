-- Manages the persistent heads-up display: resource counters, level, notifications.

local Players     = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local Utils      = require(game.ReplicatedStorage.Shared.Modules.Utils)
local GameConfig = require(game.ReplicatedStorage.Shared.Data.GameConfig)

local HUDController = {}

local hudGui     -- main ScreenGui reference
local notifQueue = {}
local showingNotif = false

-- ── Init ──────────────────────────────────────────────────────────────────────
function HUDController.Init(playerData)
    HUDController._data = playerData

    -- The HUD ScreenGui is created in StarterGui
    -- We reference it here once the player's GUI loads
    task.spawn(function()
        hudGui = PlayerGui:WaitForChild("HUD", 10)
        if not hudGui then
            warn("[HUDController] HUD ScreenGui not found")
            return
        end
        HUDController._SetupElements()
        HUDController.Refresh(playerData)
        StartBoostCountdowns(playerData)
    end)
end

function HUDController._SetupElements()
    if not hudGui then return end

    local mainFrame = hudGui:FindFirstChild("MainFrame")
    if not mainFrame then return end

    -- Wire collect button
    local collectBtn = mainFrame:FindFirstChild("CollectButton")
    if collectBtn and collectBtn:IsA("TextButton") then
        collectBtn.MouseButton1Click:Connect(function()
            local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
            RemoteEvents.CollectResources:FireServer()
        end)
    end
end

-- ── Data Refresh ──────────────────────────────────────────────────────────────
local function XPForLevel(level)
    return math.floor(100 * level ^ 1.8)
end

function HUDController.Refresh(data)
    if not hudGui then return end
    local mainFrame = hudGui:FindFirstChild("MainFrame")
    if not mainFrame then return end

    local function setLabel(name, text)
        local lbl = mainFrame:FindFirstChild(name, true)
        if lbl and lbl:IsA("TextLabel") then
            lbl.Text = text
        end
    end

    setLabel("PlayerLevelLabel", "Level " .. (data.PlayerLevel or 1))
    setLabel("ForgeLevelLabel",  "Forge " .. (data.ForgeLevel or 1))
    setLabel("CoinsLabel",       Utils.FormatNumber(data.EmberCoins or 0) .. " ⚡")
    setLabel("GolemSlotsLabel",  (data.GolemSlots or 3) .. " Slots")

    -- Mastery: find highest mastery level across all elements
    local thresholds = GameConfig.MASTERY_XP_THRESHOLDS
    local maxLevel = data.MasteryLevels and (function()
        local best = 0
        for _, xp in pairs(data.MasteryLevels) do
            for lvl = #thresholds, 1, -1 do
                if xp >= (thresholds[lvl] or 0) then
                    if lvl > best then best = lvl end
                    break
                end
            end
        end
        return best
    end)() or 0
    setLabel("MasteryLabel", "M: Lv " .. maxLevel)

    -- Animate XP bar
    local xpBarBg = hudGui:FindFirstChild("XPBarBg", true)
    if xpBarBg then
        local fill = xpBarBg:FindFirstChild("XPBarFill")
        if fill then
            local level     = data.PlayerLevel or 1
            local xp        = data.PlayerXP or 0
            local prevXP    = XPForLevel(level)
            local nextXP    = XPForLevel(level + 1)
            local ratio     = math.clamp((xp - prevXP) / math.max(nextXP - prevXP, 1), 0, 1)
            TweenService:Create(fill,
                TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Size = UDim2.new(ratio, 0, 1, 0) }
            ):Play()
        end
    end
end

-- ── Active boost countdowns ───────────────────────────────────────────────────
local function StartBoostCountdowns(data)
    task.spawn(function()
        while hudGui and hudGui.Parent do
            task.wait(5)
            local now = tick()

            local magnetLbl  = hudGui:FindFirstChild("MagnetBoostLabel", true)
            local slotLbl    = hudGui:FindFirstChild("SlotBoostLabel", true)

            if magnetLbl then
                local expiry  = data.MaterialMagnetExpiry or 0
                local remaining = math.max(0, expiry - now)
                magnetLbl.Visible = remaining > 0
                if remaining > 0 then
                    magnetLbl.Text = "🧲 Magnet " .. Utils.FormatTime(remaining)
                end
            end

            if slotLbl then
                local expiry  = data.TempSlotBoostExpiry or 0
                local remaining = math.max(0, expiry - now)
                slotLbl.Visible = remaining > 0
                if remaining > 0 then
                    slotLbl.Text = "⬆ +Slot " .. Utils.FormatTime(remaining)
                end
            end
        end
    end)
end

-- ── Resource update (called on tick) ──────────────────────────────────────────
function HUDController.OnResourceUpdate(gains)
    if not hudGui then return end
    -- Animate +N resource counters floating up (visual only)
    for matId, qty in pairs(gains) do
        if qty >= 1 then
            HUDController._FloatText("+" .. Utils.FormatNumber(qty) .. " " .. matId)
        end
    end
end

function HUDController._FloatText(text)
    -- Creates a brief floating text label on screen
    local screenGui = Instance.new("ScreenGui")
    screenGui.ResetOnSpawn = false
    screenGui.Name = "FloatText_" .. tick()
    screenGui.Parent = PlayerGui

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 200, 0, 40)
    lbl.Position = UDim2.new(0.5, -100, 0.6, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(255, 220, 60)
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 18
    lbl.Parent = screenGui

    local tween = TweenService:Create(lbl,
        TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, -100, 0.45, 0), TextTransparency = 1, TextStrokeTransparency = 1 }
    )
    tween:Play()
    tween.Completed:Connect(function()
        screenGui:Destroy()
    end)
end

-- ── Notifications ─────────────────────────────────────────────────────────────
function HUDController.ShowNotification(title, message)
    table.insert(notifQueue, { title = title, message = message })
    if not showingNotif then
        HUDController._ProcessNotifQueue()
    end
end

function HUDController._ProcessNotifQueue()
    if #notifQueue == 0 then
        showingNotif = false
        return
    end
    showingNotif = true

    local notif = table.remove(notifQueue, 1)

    local screenGui = Instance.new("ScreenGui")
    screenGui.ResetOnSpawn = false
    screenGui.Name = "Notification"
    screenGui.Parent = PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 280, 0, 70)
    frame.Position = UDim2.new(1, -300, 0, 20)
    frame.BackgroundColor3 = Color3.fromRGB(30, 25, 20)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -10, 0, 28)
    titleLbl.Position = UDim2.new(0, 10, 0, 5)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = notif.title
    titleLbl.TextColor3 = Color3.fromRGB(255, 180, 50)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 16
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = frame

    local msgLbl = Instance.new("TextLabel")
    msgLbl.Size = UDim2.new(1, -10, 0, 24)
    msgLbl.Position = UDim2.new(0, 10, 0, 36)
    msgLbl.BackgroundTransparency = 1
    msgLbl.Text = notif.message
    msgLbl.TextColor3 = Color3.fromRGB(220, 200, 180)
    msgLbl.Font = Enum.Font.Gotham
    msgLbl.TextSize = 13
    msgLbl.TextXAlignment = Enum.TextXAlignment.Left
    msgLbl.Parent = frame

    -- Slide in
    local slideIn = TweenService:Create(frame,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(1, -300, 0, 20) }
    )
    slideIn:Play()

    task.wait(3)

    -- Slide out
    local slideOut = TweenService:Create(frame,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.new(1, 10, 0, 20) }
    )
    slideOut:Play()
    slideOut.Completed:Connect(function()
        screenGui:Destroy()
        task.wait(0.1)
        HUDController._ProcessNotifQueue()
    end)
end

-- ── Level up banner ───────────────────────────────────────────────────────────
function HUDController.ShowLevelUp(newLevel)
    HUDController.ShowNotification("Level Up!", "You are now Player Level " .. newLevel)
end

-- ── Achievement toast ─────────────────────────────────────────────────────────
function HUDController.ShowAchievement(achievementId)
    local ChallengeData = require(game.ReplicatedStorage.Shared.Data.ChallengeData)
    local ach = ChallengeData.Get(achievementId)
    local name = ach and ach.displayName or achievementId
    HUDController.ShowNotification("Achievement Unlocked!", name)
end

return HUDController
