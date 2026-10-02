-- The pad unlock dialog. Walk up to a mining pad you cannot use yet and this opens: what the pad gives, the level that unlocks it for free, and an "Unlock
-- forever" button that opens Roblox's own Robux purchase. The server decides when to show it (PadService); this only displays and asks.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer

local Theme        = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI      = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local PadData      = require(game.ReplicatedStorage.Shared.Data.PadData)

RemoteEvents.Load()

local gui = Instance.new("ScreenGui")
gui.Name = "PadOffer"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 20
gui.Enabled = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.new(0.5, 0, 0.42, 0)
card.Size = UDim2.new(0, 400, 0, 258)
card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
card.BorderSizePixel = 0
card.Parent = gui
Theme.AddCorner(card, UDim.new(0, 18))
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(68, 52, 44), Color3.fromRGB(36, 28, 25))
grad.Rotation = 90
grad.Parent = card
local stroke = Theme.AddStroke(card, Theme.Colors.Gold, 3, 0.15)
ScaleUI.ApplyHud(card)

-- a coloured banner across the top, in the pad's own colour
local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.Size = UDim2.new(1, 0, 0, 62)
banner.BackgroundColor3 = Theme.Colors.Gold
banner.BorderSizePixel = 0
banner.Parent = card
Theme.AddCorner(banner, UDim.new(0, 18))
local bannerFill = Instance.new("Frame")           -- squares off the banner's bottom corners
bannerFill.Position = UDim2.new(0, 0, 1, -18)
bannerFill.Size = UDim2.new(1, 0, 0, 18)
bannerFill.BackgroundColor3 = Theme.Colors.Gold
bannerFill.BorderSizePixel = 0
bannerFill.Parent = banner
local bannerGrad = Instance.new("UIGradient")
bannerGrad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190))
bannerGrad.Rotation = 90
bannerGrad.Parent = banner
local title = Theme.Label(banner, "", 26, Color3.fromRGB(30, 20, 12), Enum.Font.GothamBlack, "Title")
title.Position = UDim2.new(0, 18, 0, 6)
title.Size = UDim2.new(1, -36, 0, 32)
local locked = Theme.Label(banner, "LOCKED", 12, Color3.fromRGB(70, 40, 20), Enum.Font.GothamBold, "LockedTag")
locked.Position = UDim2.new(0, 18, 0, 38)
locked.Size = UDim2.new(1, -36, 0, 16)

local gives = Theme.Label(card, "", 18, Color3.fromRGB(255, 244, 228), Enum.Font.GothamBold, "Gives")
gives.Position = UDim2.new(0, 18, 0, 72)
gives.Size = UDim2.new(1, -36, 0, 26)
gives.TextXAlignment = Enum.TextXAlignment.Left

local free = Theme.Label(card, "", 15, Theme.Colors.TextSecondary, Enum.Font.Gotham, "Free")
free.Position = UDim2.new(0, 18, 0, 100)
free.Size = UDim2.new(1, -36, 0, 22)
free.TextXAlignment = Enum.TextXAlignment.Left

local buy = Theme.Button(card, "", Theme.Colors.Success, Color3.fromRGB(255, 255, 255), "BuyButton")
buy.Position = UDim2.new(0, 18, 0, 134)
buy.Size = UDim2.new(1, -36, 0, 50)
buy.Font = Enum.Font.GothamBlack
buy.TextSize = 20

local later = Theme.Button(card, "Maybe later", Theme.Colors.PanelAlt, Theme.Colors.TextSecondary, "LaterButton")
later.Position = UDim2.new(0, 18, 0, 196)
later.Size = UDim2.new(1, -36, 0, 40)
later.TextSize = 16

local note = Theme.Label(card, "", 12, Theme.Colors.TextDim, Enum.Font.Gotham, "Note")
note.Position = UDim2.new(0, 18, 1, -18)
note.Size = UDim2.new(1, -36, 0, 14)

local current
local shownAt = 0
local function Hide()
    gui.Enabled = false
    current = nil
end

local function Show(offer)
    current = offer
    shownAt = os.clock()
    local def
    for _, d in ipairs(PadData.Pads) do if d.id == offer.padId then def = d end end
    local colour = def and def.color or Theme.Colors.Gold
    banner.BackgroundColor3, bannerFill.BackgroundColor3, stroke.Color = colour, colour, colour
    title.Text = string.format("%s   x%d", offer.name, offer.multiplier)
    gives.Text = string.format("Mine %dx more materials every second", offer.multiplier)
    free.Text = string.format("Free at level %d   (you are level %d)", offer.minLevel, offer.level)
    if offer.available then
        buy.Text = string.format("Unlock forever   -   R$ %d", offer.robux)
        buy.BackgroundColor3 = Theme.Colors.Success
        buy.AutoButtonColor = true
        note.Text = "One-time purchase. Yours on every character, forever."
    else
        buy.Text = "Not for sale yet"
        buy.BackgroundColor3 = Theme.Colors.PanelAlt
        buy.AutoButtonColor = false
        note.Text = "Reach the level above to use it for free."
    end
    gui.Enabled = true
end

buy.MouseButton1Click:Connect(function()
    if not (current and current.available) then return end
    RemoteEvents.PadBuy:FireServer(current.padId)
    Hide()                                          -- Roblox's purchase window takes over
end)
later.MouseButton1Click:Connect(Hide)

RemoteEvents.PadOffer.OnClientEvent:Connect(function(offer)
    if type(offer) == "table" and offer.padId then Show(offer) end
end)

-- a pass bought on this prompt (or on the game page) unlocks the pad: close the dialog
if MarketplaceService.PromptGamePassPurchaseFinished then
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(_, _, purchased)
        if purchased then Hide() end
    end)
end

-- it never stays up for long: walking on closes it
task.spawn(function()
    while true do
        task.wait(1)
        if gui.Enabled and os.clock() - shownAt > 25 then Hide() end
    end
end)
