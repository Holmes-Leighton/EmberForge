-- The trade request popup: when another player asks to trade, this shows who it is (avatar, name, @username, forge
-- level, Ascension and title) with Accept / Decline and a countdown. The trade window opens only after you accept.

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Theme        = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI      = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local AscensionData = require(game.ReplicatedStorage.Shared.Data.AscensionData)

RemoteEvents.Load()

local gui = Instance.new("ScreenGui")
gui.Name = "TradeRequestPopup"
gui.ResetOnSpawn = false
gui.DisplayOrder = 41
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.new(0.5, 0, 0, 80)
card.Size = UDim2.new(0, 420, 0, 184)
card.BackgroundColor3 = Theme.Colors.Panel
card.BorderSizePixel = 0
card.Parent = gui
Theme.AddCorner(card, Theme.Corner.Large)
Theme.AddStroke(card, Theme.Colors.Success, 2, 0.1)
ScaleUI.ApplyHud(card)

local header = Theme.Label(card, "Trade request", Theme.TextSize.Heading, Theme.Colors.Success, Theme.Fonts.Heading, "Header")
header.Position = UDim2.new(0, 16, 0, 8)
header.Size = UDim2.new(1, -140, 0, 22)

local avatar = Instance.new("ImageLabel")
avatar.Name = "Avatar"
avatar.Size = UDim2.new(0, 84, 0, 84)
avatar.Position = UDim2.new(0, 16, 0, 38)
avatar.BackgroundColor3 = Theme.Colors.PanelAlt
avatar.BorderSizePixel = 0
avatar.Parent = card
Theme.AddCorner(avatar, UDim.new(0, 42))
Theme.AddStroke(avatar, Theme.Colors.Gold, 2, 0.2)

local nameLbl = Theme.Label(card, "", Theme.TextSize.Title, Theme.Colors.TextPrimary, Theme.Fonts.Heading, "PlayerName")
nameLbl.Position = UDim2.new(0, 114, 0, 36)
nameLbl.Size = UDim2.new(1, -126, 0, 28)
local userLbl = Theme.Label(card, "", Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Body, "Username")
userLbl.Position = UDim2.new(0, 114, 0, 64)
userLbl.Size = UDim2.new(1, -126, 0, 18)
local detailLbl = Theme.Label(card, "", Theme.TextSize.Body, Theme.Colors.AccentBright, Theme.Fonts.Body, "Details")
detailLbl.Position = UDim2.new(0, 114, 0, 84)
detailLbl.Size = UDim2.new(1, -126, 0, 40)
detailLbl.TextWrapped = true
detailLbl.TextYAlignment = Enum.TextYAlignment.Top

local timerLbl = Theme.Label(card, "", Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Body, "Countdown")
timerLbl.AnchorPoint = Vector2.new(1, 0)
timerLbl.Position = UDim2.new(1, -16, 0, 10)
timerLbl.Size = UDim2.new(0, 90, 0, 20)
timerLbl.TextXAlignment = Enum.TextXAlignment.Right

local acceptBtn = Theme.Button(card, "Accept", Theme.Colors.Success, Color3.fromRGB(255, 255, 255), "Accept")
acceptBtn.Size = UDim2.new(0.5, -22, 0, 28)             -- 16px left, 12px between the buttons, 16px right
acceptBtn.Position = UDim2.new(0, 16, 1, -44)          -- 16px from the bottom (card is 192 high)
acceptBtn.TextSize = 14
local declineBtn = Theme.Button(card, "Decline", Theme.Colors.Danger, Color3.fromRGB(255, 255, 255), "Decline")
declineBtn.Size = UDim2.new(0.5, -22, 0, 28)
declineBtn.Position = UDim2.new(0.5, 6, 1, -44)
declineBtn.TextSize = 14

local token = 0
local expiresAt = 0
local totalSeconds = 60

local function Close()
    token += 1
    gui.Enabled = false
end

acceptBtn.MouseButton1Click:Connect(function() Close() RemoteEvents.RespondTradeRequest:FireServer(true) end)
declineBtn.MouseButton1Click:Connect(function() Close() RemoteEvents.RespondTradeRequest:FireServer(false) end)

RunService.Heartbeat:Connect(function()
    if not gui.Enabled then return end
    local left = expiresAt - os.clock()
    timerLbl.Text = string.format("closes in %ds", math.max(0, math.ceil(left)))
    if left <= 0 then Close() end
end)

RemoteEvents.TradeRequest.OnClientEvent:Connect(function(fromName, fromUserId, info)
    info = type(info) == "table" and info or {}
    token += 1
    local mine = token
    header.Text = "Wants to trade with you"
    nameLbl.Text = tostring(fromName)
    userLbl.Text = info.username and ("@" .. info.username) or ""
    local bits = { string.format("Forge Level %d", info.forgeLevel or 1), string.format("Player Level %d", info.playerLevel or 1) }
    if (info.ascensions or 0) > 0 then table.insert(bits, AscensionData.Title(info.ascensions)) end
    if info.title then table.insert(bits, tostring(info.title)) end
    detailLbl.Text = table.concat(bits, "   -   ")
    avatar.Image = ""
    if type(fromUserId) == "number" then
        task.spawn(function()
            local ok, img = pcall(function()
                return Players:GetUserThumbnailAsync(fromUserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
            end)
            if ok and mine == token then avatar.Image = img end
        end)
    end
    totalSeconds = info.seconds or 60
    expiresAt = os.clock() + totalSeconds
    gui.Enabled = true
end)
