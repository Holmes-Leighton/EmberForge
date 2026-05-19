-- Centralised design tokens for all EmberForge GUIs.
local Theme = {}

Theme.Colors = {
    Background      = Color3.fromRGB(18, 14, 12),    -- very dark charcoal
    Panel           = Color3.fromRGB(30, 24, 20),    -- dark panel
    PanelAlt        = Color3.fromRGB(40, 32, 26),    -- slightly lighter panel
    Row             = Color3.fromRGB(35, 28, 23),    -- list row
    RowHover        = Color3.fromRGB(50, 40, 32),

    Accent          = Color3.fromRGB(220, 120, 30),  -- forge orange
    AccentBright    = Color3.fromRGB(255, 160, 50),  -- bright orange
    AccentDim       = Color3.fromRGB(140, 80, 20),   -- muted orange

    Gold            = Color3.fromRGB(255, 200, 60),  -- coins / XP
    TextPrimary     = Color3.fromRGB(230, 215, 200), -- main text
    TextSecondary   = Color3.fromRGB(160, 148, 136), -- secondary text
    TextDim         = Color3.fromRGB(100, 92, 84),   -- dimmed/disabled

    Success         = Color3.fromRGB(60, 180, 90),
    Danger          = Color3.fromRGB(200, 60, 50),
    Info            = Color3.fromRGB(70, 150, 220),

    -- Element colours
    Ember   = Color3.fromRGB(220, 80, 30),
    Stone   = Color3.fromRGB(120, 100, 70),
    Frost   = Color3.fromRGB(100, 170, 230),
    Storm   = Color3.fromRGB(140, 100, 220),
    Void    = Color3.fromRGB(100, 60, 160),

    -- Rarity colours
    Common    = Color3.fromRGB(180, 180, 180),
    Uncommon  = Color3.fromRGB(80, 200, 100),
    Rare      = Color3.fromRGB(80, 130, 230),
    Epic      = Color3.fromRGB(160, 70, 230),
    Legendary = Color3.fromRGB(255, 180, 30),

    -- Overlay
    Scrim   = Color3.fromRGB(0, 0, 0),
}

Theme.Fonts = {
    Title    = Enum.Font.GothamBlack,
    Heading  = Enum.Font.GothamBold,
    Body     = Enum.Font.Gotham,
    Mono     = Enum.Font.Code,
}

Theme.TextSize = {
    Title   = 22,
    Heading = 16,
    Body    = 13,
    Small   = 11,
}

Theme.Corner = {
    Large  = UDim.new(0, 10),
    Medium = UDim.new(0, 6),
    Small  = UDim.new(0, 4),
}

-- ── Factory helpers ────────────────────────────────────────────────────────────

function Theme.AddCorner(parent, size)
    local c = Instance.new("UICorner")
    c.CornerRadius = size or Theme.Corner.Medium
    c.Parent = parent
    return c
end

function Theme.AddPadding(parent, top, right, bottom, left)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, top    or 8)
    p.PaddingRight  = UDim.new(0, right  or 8)
    p.PaddingBottom = UDim.new(0, bottom or 8)
    p.PaddingLeft   = UDim.new(0, left   or 8)
    p.Parent = parent
    return p
end

function Theme.AddListLayout(parent, dir, padding, halign)
    local l = Instance.new("UIListLayout")
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.Padding = UDim.new(0, padding or 4)
    l.HorizontalAlignment = halign or Enum.HorizontalAlignment.Left
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = parent
    return l
end

function Theme.Label(parent, text, size, color, font, name)
    local lbl = Instance.new("TextLabel")
    lbl.Name = name or "Label"
    lbl.BackgroundTransparency = 1
    lbl.Text = text or ""
    lbl.TextSize = size or Theme.TextSize.Body
    lbl.TextColor3 = color or Theme.Colors.TextPrimary
    lbl.Font = font or Theme.Fonts.Body
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.Parent = parent
    return lbl
end

function Theme.Button(parent, text, bgColor, textColor, name)
    local btn = Instance.new("TextButton")
    btn.Name = name or "Button"
    btn.BackgroundColor3 = bgColor or Theme.Colors.Accent
    btn.BorderSizePixel = 0
    btn.Text = text or ""
    btn.TextSize = Theme.TextSize.Body
    btn.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
    btn.Font = Theme.Fonts.Heading
    btn.AutoButtonColor = true
    btn.Parent = parent
    Theme.AddCorner(btn, Theme.Corner.Small)
    return btn
end

function Theme.Panel(parent, name, bgColor)
    local f = Instance.new("Frame")
    f.Name = name or "Panel"
    f.BackgroundColor3 = bgColor or Theme.Colors.Panel
    f.BorderSizePixel = 0
    f.Parent = parent
    Theme.AddCorner(f, Theme.Corner.Medium)
    return f
end

function Theme.ScrollFrame(parent, name)
    local sf = Instance.new("ScrollingFrame")
    sf.Name = name or "Scroll"
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 4
    sf.ScrollBarImageColor3 = Theme.Colors.Accent
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.Parent = parent
    return sf
end

function Theme.Divider(parent, color)
    local d = Instance.new("Frame")
    d.Name = "Divider"
    d.Size = UDim2.new(1, 0, 0, 1)
    d.BackgroundColor3 = color or Theme.Colors.PanelAlt
    d.BorderSizePixel = 0
    d.Parent = parent
    return d
end

-- Thin coloured stripe on left edge (rarity / element indicator)
function Theme.Stripe(parent, color)
    local s = Instance.new("Frame")
    s.Name = "Stripe"
    s.Size = UDim2.new(0, 3, 1, 0)
    s.Position = UDim2.new(0, 0, 0, 0)
    s.BackgroundColor3 = color or Theme.Colors.Accent
    s.BorderSizePixel = 0
    s.Parent = parent
    Theme.AddCorner(s, Theme.Corner.Small)
    return s
end

-- Screen-covering dark scrim
function Theme.Scrim(parent, transparency)
    local s = Instance.new("Frame")
    s.Name = "Scrim"
    s.Size = UDim2.new(1, 0, 1, 0)
    s.BackgroundColor3 = Theme.Colors.Scrim
    s.BackgroundTransparency = transparency or 0.5
    s.BorderSizePixel = 0
    s.ZIndex = 5
    s.Parent = parent
    return s
end

return Theme
