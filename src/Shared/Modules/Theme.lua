-- Centralised design tokens for all EmberForge GUIs.
local Theme = {}

Theme.Colors = {
    Background      = Color3.fromRGB(34, 26, 24),    -- warm dark brown
    Panel           = Color3.fromRGB(52, 41, 36),    -- warm panel
    PanelAlt        = Color3.fromRGB(70, 56, 48),    -- lighter panel
    Row             = Color3.fromRGB(58, 46, 40),    -- list row
    RowHover        = Color3.fromRGB(78, 62, 52),

    Accent          = Color3.fromRGB(245, 135, 25),  -- forge orange
    AccentBright    = Color3.fromRGB(255, 185, 70),  -- bright orange
    AccentDim       = Color3.fromRGB(140, 80, 20),   -- muted orange

    Gold            = Color3.fromRGB(255, 200, 60),  -- coins / XP
    TextPrimary     = Color3.fromRGB(250, 240, 228), -- main text
    TextSecondary   = Color3.fromRGB(205, 192, 178), -- secondary text
    TextDim         = Color3.fromRGB(140, 128, 116),   -- dimmed/disabled

    Success         = Color3.fromRGB(70, 200, 100),
    Danger          = Color3.fromRGB(225, 70, 60),
    Info            = Color3.fromRGB(80, 165, 240),

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
    Heading  = Enum.Font.GothamBlack,
    Body     = Enum.Font.GothamMedium,
    Mono     = Enum.Font.Code,
}

Theme.TextSize = {
    Title   = 24,
    Heading = 17,
    Body    = 14,
    Small   = 12,
}

Theme.Corner = {
    Large  = UDim.new(0, 16),
    Medium = UDim.new(0, 10),
    Small  = UDim.new(0, 8),
}

-- ── Factory helpers ────────────────────────────────────────────────────────────

function Theme.AddCorner(parent, size)
    local c = Instance.new("UICorner")
    c.CornerRadius = size or Theme.Corner.Medium
    c.Parent = parent
    return c
end

function Theme.AddStroke(parent, color, thickness, transparency)
    local st = Instance.new("UIStroke")
    st.Color = color or Color3.fromRGB(20, 14, 12)
    st.Thickness = thickness or 2
    st.Transparency = transparency or 0
    st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    st.Parent = parent
    return st
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

-- Chunky cartoon button: dark outline, top-lit gradient, outlined text, springy hover / press.
function Theme.Button(parent, text, bgColor, textColor, name)
    local btn = Instance.new("TextButton")
    btn.Name = name or "Button"
    btn.BackgroundColor3 = bgColor or Theme.Colors.Accent
    btn.BorderSizePixel = 0
    btn.Text = text or ""
    btn.TextSize = Theme.TextSize.Body
    btn.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
    btn.TextStrokeColor3 = Color3.fromRGB(20, 12, 8)
    btn.TextStrokeTransparency = 0.55
    btn.Font = Theme.Fonts.Heading
    btn.AutoButtonColor = false
    btn.Parent = parent
    Theme.AddCorner(btn, Theme.Corner.Small)
    Theme.AddStroke(btn, Color3.fromRGB(20, 14, 12), 2)

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190))
    grad.Rotation = 90
    grad.Parent = btn

    local scale = Instance.new("UIScale")
    scale.Parent = btn
    local function to(target, t)
        pcall(function()
            game:GetService("TweenService"):Create(scale, TweenInfo.new(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
        end)
    end
    btn.MouseEnter:Connect(function() if btn.Active then to(1.05, 0.12) end end)
    btn.MouseLeave:Connect(function() to(1, 0.12) end)
    btn.MouseButton1Down:Connect(function() to(0.94, 0.06) end)
    btn.MouseButton1Up:Connect(function() to(1.05, 0.12) end)
    return btn
end

function Theme.Panel(parent, name, bgColor)
    local f = Instance.new("Frame")
    f.Name = name or "Panel"
    f.BackgroundColor3 = bgColor or Theme.Colors.Panel
    f.BorderSizePixel = 0
    f.Parent = parent
    Theme.AddCorner(f, Theme.Corner.Medium)
    Theme.AddStroke(f, Color3.fromRGB(24, 17, 14), 2, 0.35)
    return f
end

function Theme.ScrollFrame(parent, name)
    local sf = Instance.new("ScrollingFrame")
    sf.Name = name or "Scroll"
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 6
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
