-- Contextual purchase offers, the way Adopt Me / Grow a Garden do them: when something gets in your
-- way (storage too small, no free slot, smelter full) a small card slides in offering the fix.
-- One tap opens Roblox's own purchase prompt; "Later" (or 15 seconds) dismisses it.
-- The server decides *when* to offer (ShopService.Offer) and throttles it.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer  = Players.LocalPlayer

local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local ProductData  = require(game.ReplicatedStorage.Shared.Data.ProductData)
local Theme        = require(game.ReplicatedStorage.Shared.Modules.Theme)

local OfferController = {}

local card

local function Dismiss()
    if card then card:Destroy() card = nil end
end

function OfferController.Show(kind, key, reason)
    local item = (kind == "pass" and ProductData.GamePasses[key]) or (kind == "product" and ProductData.Products[key])
    if not item then return end
    Dismiss()

    local gui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("OfferGui")
    if not gui then
        gui = Instance.new("ScreenGui")
        gui.Name = "OfferGui"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 40
        gui.Parent = LocalPlayer.PlayerGui
    end

    card = Instance.new("Frame")
    card.Name = "OfferCard"
    card.AnchorPoint = Vector2.new(0, 1)
    card.Position = UDim2.new(0, 16, 1, -96)
    card.Size = UDim2.new(0, 300, 0, 132)
    card.BackgroundColor3 = Theme.Colors.Panel
    card.BorderSizePixel = 0
    card.Parent = gui
    Theme.AddCorner(card, Theme.Corner.Large)
    Theme.AddStroke(card, Theme.Colors.Gold, 3)

    local title = Theme.Label(card, item.displayName, Theme.TextSize.Heading, Theme.Colors.Gold, Theme.Fonts.Heading, "OfferTitle")
    title.Position = UDim2.new(0, 14, 0, 8)
    title.Size = UDim2.new(1, -28, 0, 22)
    local why = Theme.Label(card, reason or "", Theme.TextSize.Body, Theme.Colors.TextPrimary, Theme.Fonts.Body, "OfferReason")
    why.Position = UDim2.new(0, 14, 0, 32)
    why.Size = UDim2.new(1, -28, 0, 44)
    why.TextYAlignment = Enum.TextYAlignment.Top

    local buy = Theme.Button(card, item.robux .. " R$  -  Get it", Theme.Colors.Success, Color3.fromRGB(255, 255, 255), "OfferBuy")
    buy.Size = UDim2.new(0.6, -16, 0, 34)
    buy.Position = UDim2.new(0, 12, 1, -44)
    local later = Theme.Button(card, "Later", Theme.Colors.PanelAlt, Theme.Colors.TextSecondary, "OfferLater")
    later.Size = UDim2.new(0.4, -20, 0, 34)
    later.Position = UDim2.new(0.6, 8, 1, -44)

    buy.MouseButton1Click:Connect(function()
        local Shop = require(script.Parent.ShopController)
        if kind == "pass" then Shop._PromptPass(key) else Shop._Prompt(key) end
        Dismiss()
    end)
    later.MouseButton1Click:Connect(Dismiss)

    local mine = card
    pcall(function()
        card.Position = UDim2.new(0, -320, 1, -96)
        TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Position = UDim2.new(0, 16, 1, -96) }):Play()
    end)
    task.delay(15, function() if card == mine then Dismiss() end end)
end

function OfferController.Init()
    RemoteEvents.Load()
    RemoteEvents.ShopOffer.OnClientEvent:Connect(OfferController.Show)
end

return OfferController
