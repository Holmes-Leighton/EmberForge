-- Creates the Shop ScreenGui: convenience items and cosmetics.
-- Named elements expected by ShopController.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)

local gui = Instance.new("ScreenGui")
gui.Name = "ShopMenu"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local scrim = Instance.new("Frame")
scrim.Size = UDim2.new(1,0,1,0)
scrim.BackgroundColor3 = Color3.fromRGB(0,0,0)
scrim.BackgroundTransparency = 0.45
scrim.BorderSizePixel = 0
scrim.Parent = gui
scrim.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then gui.Enabled = false end
end)

-- ── Container ─────────────────────────────────────────────────────────────────
local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(0, 740, 0, 560)
ScaleUI.Apply(container, 740, 560)
container.BackgroundColor3 = Theme.Colors.Background
container.BorderSizePixel = 0
container.Parent = gui
Theme.AddCorner(container, Theme.Corner.Large)

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Theme.Colors.Panel
titleBar.BorderSizePixel = 0
titleBar.Parent = container
Theme.AddCorner(titleBar, Theme.Corner.Large)
local tf = Instance.new("Frame"); tf.Size=UDim2.new(1,0,0,12); tf.Position=UDim2.new(0,0,1,-12)
tf.BackgroundColor3=Theme.Colors.Panel; tf.BorderSizePixel=0; tf.Parent=titleBar

Theme.Label(titleBar, "💎  Shop", Theme.TextSize.Title,
    Theme.Colors.AccentBright, Theme.Fonts.Title).Size = UDim2.new(0.5, 0, 1, 0)

local closeBtn = Theme.Button(titleBar, "X", Theme.Colors.Danger, Color3.fromRGB(255,255,255), "CloseButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 7)
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- ── Section: Convenience ─────────────────────────────────────────────────────
local function sectionLabel(text, y)
    local lbl = Theme.Label(container, text, Theme.TextSize.Heading,
        Theme.Colors.Gold, Theme.Fonts.Heading)
    lbl.Size = UDim2.new(1, -16, 0, 26)
    lbl.Position = UDim2.new(0, 8, 0, y)
    return lbl
end

sectionLabel("⚡ Convenience", 58)

-- Shop item grid
local convGrid = Instance.new("Frame")
convGrid.Name = "ConvenienceGrid"
convGrid.Size = UDim2.new(1, -16, 0, 160)
convGrid.Position = UDim2.new(0, 8, 0, 88)
convGrid.BackgroundTransparency = 1
convGrid.Parent = container

-- Item definitions: { btnName, emoji, title, subtitle, price, accentColor }
local convItems = {
    { name="SpeedUpx1Btn",        emoji="⚗",  title="Speed-Up",          sub="Instantly smelt 1 item",        price="25 R$",    color=Theme.Colors.Info    },
    { name="SpeedUpx10Btn",       emoji="⚗⚗", title="Speed-Up Pack",     sub="10 instant completions",        price="200 R$",   color=Theme.Colors.Info    },
    { name="StorageExpansionBtn", emoji="📦",  title="Storage Expansion", sub="Offline cap → 24 hrs",          price="299 R$",   color=Theme.Colors.Frost   },
    { name="SlotBoostBtn",        emoji="🔓",  title="Slot Boost",        sub="+1 deploy slot for 7 days",     price="149 R$/wk",color=Theme.Colors.Storm   },
    { name="MaterialMagnetBtn",   emoji="🧲",  title="Material Magnet",   sub="2× resource collection 24 hrs", price="199 R$",   color=Theme.Colors.Success },
    { name="EventCatalystBtn",    emoji="✨",  title="Event Catalyst",    sub="Skip the grind for 1 event mat",price="~400 R$",  color=Theme.Colors.Legendary },
}

local itemW = math.floor((740 - 16) / 3) - 6
local itemH = 70

for i, item in ipairs(convItems) do
    local col = (i - 1) % 3
    local row = math.floor((i - 1) / 3)
    local xOff = col * (itemW + 8)
    local yOff = row * (itemH + 8)

    local card = Instance.new("Frame")
    card.Name = item.name .. "Card"
    card.Size = UDim2.new(0, itemW, 0, itemH)
    card.Position = UDim2.new(0, xOff, 0, yOff)
    card.BackgroundColor3 = Theme.Colors.Panel
    card.BorderSizePixel = 0
    card.Parent = convGrid
    Theme.AddCorner(card, Theme.Corner.Small)

    -- Left colour stripe
    local stripe = Theme.Stripe(card, item.color)
    stripe.Size = UDim2.new(0, 4, 1, 0)

    local titleLbl = Theme.Label(card, item.emoji .. " " .. item.title,
        Theme.TextSize.Body, item.color, Theme.Fonts.Heading)
    titleLbl.Size = UDim2.new(0.65, 0, 0, 22)
    titleLbl.Position = UDim2.new(0, 12, 0, 6)

    local subLbl = Theme.Label(card, item.sub, Theme.TextSize.Small, Theme.Colors.TextDim)
    subLbl.Size = UDim2.new(0.65, 0, 0, 16)
    subLbl.Position = UDim2.new(0, 12, 0, 28)

    local buyBtn = Theme.Button(card, item.price, item.color, Color3.fromRGB(255,255,255), item.name)
    buyBtn.Size = UDim2.new(0, 86, 0, 28)
    buyBtn.Position = UDim2.new(1, -94, 0, (itemH - 28) / 2)
    buyBtn.TextSize = 11
end

-- ── Section: Season Passes ────────────────────────────────────────────────────
sectionLabel("🌟 Season Passes", 258)

local passGrid = Instance.new("Frame")
passGrid.Name = "PassGrid"
passGrid.Size = UDim2.new(1, -16, 0, 120)
passGrid.Position = UDim2.new(0, 8, 0, 288)
passGrid.BackgroundTransparency = 1
passGrid.Parent = container

local passItems = {
    {
        name = "StandardPassBtn", title = "Standard Season Pass",
        sub  = "All free rewards + 15 cosmetics + 1 storage slot + speed-up pack",
        price = "699 R$", color = Theme.Colors.Info,
        features = { "Seasonal cosmetics", "Storage expansion", "Speed-up pack" },
    },
    {
        name = "PremiumPassBtn", title = "Premium Season Pass",
        sub  = "All Standard rewards + exclusive Tier 5 skin + animated forge effect + early access",
        price = "1,299 R$", color = Theme.Colors.Legendary,
        features = { "Exclusive Golem skin", "Animated forge effect", "Season preview access" },
    },
}

local passW = math.floor((740 - 16) / 2) - 6

for i, pass in ipairs(passItems) do
    local xOff = (i - 1) * (passW + 8)

    local card = Instance.new("Frame")
    card.Name = pass.name .. "Card"
    card.Size = UDim2.new(0, passW, 1, 0)
    card.Position = UDim2.new(0, xOff, 0, 0)
    card.BackgroundColor3 = Theme.Colors.Panel
    card.BorderSizePixel = 0
    card.Parent = passGrid
    Theme.AddCorner(card, Theme.Corner.Medium)

    -- Top accent bar
    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(1, 0, 0, 4)
    accentBar.BackgroundColor3 = pass.color
    accentBar.BorderSizePixel = 0
    accentBar.Parent = card
    Theme.AddCorner(accentBar, Theme.Corner.Small)

    local titleLbl = Theme.Label(card, pass.title, Theme.TextSize.Heading, pass.color, Theme.Fonts.Heading)
    titleLbl.Size = UDim2.new(1, -12, 0, 22)
    titleLbl.Position = UDim2.new(0, 10, 0, 10)

    local subLbl = Theme.Label(card, pass.sub, Theme.TextSize.Small, Theme.Colors.TextSecondary)
    subLbl.Size = UDim2.new(1, -12, 0, 32)
    subLbl.Position = UDim2.new(0, 10, 0, 34)

    for fi, feat in ipairs(pass.features) do
        local fl = Theme.Label(card, "+ " .. feat, Theme.TextSize.Small, Theme.Colors.Success)
        fl.Size = UDim2.new(1, -12, 0, 16)
        fl.Position = UDim2.new(0, 10, 0, 68 + (fi - 1) * 18)
    end

    local buyBtn = Theme.Button(card, pass.price .. " — Buy", pass.color, Color3.fromRGB(255,255,255), pass.name)
    buyBtn.Size = UDim2.new(1, -16, 0, 30)
    buyBtn.Position = UDim2.new(0, 8, 1, -38)
    buyBtn.TextSize = 13
end

-- ── Section: Mining Pads (permanent game passes) ─────────────────────────────
sectionLabel("⛏ Mining Pads  -  unlock forever, no grinding", 414)

local padGrid = Instance.new("Frame")
padGrid.Name = "PadGrid"
padGrid.Size = UDim2.new(1, -16, 0, 86)
padGrid.Position = UDim2.new(0, 8, 0, 442)
padGrid.BackgroundTransparency = 1
padGrid.Parent = container

local padItems = {
    { name = "PadCopperBtn", key = "Pad_Copper", title = "Copper Pad", mult = "3x", sub = "or reach Level 5",  price = "149 R$", color = Color3.fromRGB(205, 127, 80)  },
    { name = "PadIronBtn",   key = "Pad_Iron",   title = "Iron Pad",   mult = "5x", sub = "or reach Level 10", price = "299 R$", color = Color3.fromRGB(160, 170, 185) },
    { name = "PadGoldBtn",   key = "Pad_Gold",   title = "Gold Pad",   mult = "10x", sub = "or reach Level 20", price = "599 R$", color = Color3.fromRGB(255, 200, 60) },
}
local padW = math.floor((740 - 16) / 3) - 6
for i, pad in ipairs(padItems) do
    local card = Instance.new("Frame")
    card.Name = pad.name .. "Card"
    card.Size = UDim2.new(0, padW, 1, 0)
    card.Position = UDim2.new(0, (i - 1) * (padW + 8), 0, 0)
    card.BackgroundColor3 = Theme.Colors.Panel
    card.BorderSizePixel = 0
    card.Parent = padGrid
    Theme.AddCorner(card, Theme.Corner.Medium)
    Theme.AddStroke(card, pad.color, 2, 0.3)

    local big = Theme.Label(card, pad.mult, 30, pad.color, Enum.Font.GothamBlack, "Multiplier")
    big.Size = UDim2.new(0, 70, 0, 40)
    big.Position = UDim2.new(0, 10, 0, 6)
    big.TextXAlignment = Enum.TextXAlignment.Left
    local t = Theme.Label(card, pad.title, Theme.TextSize.Heading, Theme.Colors.TextPrimary, Theme.Fonts.Heading)
    t.Size = UDim2.new(1, -90, 0, 22)
    t.Position = UDim2.new(0, 84, 0, 8)
    local sub = Theme.Label(card, pad.sub, Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Body, "Sub")
    sub.Size = UDim2.new(1, -90, 0, 16)
    sub.Position = UDim2.new(0, 84, 0, 30)

    local buy = Theme.Button(card, pad.price .. " - Unlock", pad.color, Color3.fromRGB(30, 20, 12), pad.name)
    buy.Size = UDim2.new(1, -16, 0, 28)
    buy.Position = UDim2.new(0, 8, 1, -34)
    buy.TextSize = 13
    buy:SetAttribute("PassKey", pad.key)
    buy:SetAttribute("Price", pad.price)
end

-- ── Footer note ───────────────────────────────────────────────────────────────
local footer = Theme.Label(container,
    "All purchases are cosmetic or convenience — core gameplay is always free.",
    Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Body, "FooterLabel")
footer.Size = UDim2.new(1, -16, 0, 20)
footer.Position = UDim2.new(0, 8, 1, -28)
footer.TextXAlignment = Enum.TextXAlignment.Center
