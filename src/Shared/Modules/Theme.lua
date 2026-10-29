-- Centralised design tokens for all EmberForge GUIs.
local Theme = {}

Theme.Colors = {
    Background      = Color3.fromRGB(52, 38, 104),   -- deep violet (fallback window body; windows pick a Palette)
    Panel           = Color3.fromRGB(32, 24, 62),    -- dark inset card: reads on every window colour
    PanelAlt        = Color3.fromRGB(64, 50, 112),   -- lighter inset (inactive tab / secondary button)
    Row             = Color3.fromRGB(42, 32, 80),    -- list row
    RowHover        = Color3.fromRGB(70, 56, 128),

    Accent          = Color3.fromRGB(245, 135, 25),  -- forge orange
    AccentBright    = Color3.fromRGB(255, 185, 70),  -- bright orange
    AccentDim       = Color3.fromRGB(140, 80, 20),   -- muted orange

    Gold            = Color3.fromRGB(255, 200, 60),  -- coins / XP
    TextPrimary     = Color3.fromRGB(250, 240, 228), -- main text
    TextSecondary   = Color3.fromRGB(226, 218, 240), -- secondary text
    TextDim         = Color3.fromRGB(182, 172, 208), -- dimmed/disabled (still readable on a bright window body)

    Success         = Color3.fromRGB(70, 200, 100),
    Danger          = Color3.fromRGB(225, 70, 60),
    Info            = Color3.fromRGB(80, 165, 240),

    -- Element colours
    Ember   = Color3.fromRGB(220, 80, 30),
    Stone   = Color3.fromRGB(120, 100, 70),
    Frost   = Color3.fromRGB(100, 170, 230),
    Storm   = Color3.fromRGB(140, 100, 220),
    Void    = Color3.fromRGB(100, 60, 160),
    -- Special Golems (GolemData.Specials)
    Patchwork  = Color3.fromRGB(200, 150, 120),
    Woven      = Color3.fromRGB(200, 160, 100),
    Coral      = Color3.fromRGB(240, 120, 130),
    Clockwork  = Color3.fromRGB(200, 150, 70),
    Alchemist  = Color3.fromRGB(110, 210, 140),
    Gargoyle   = Color3.fromRGB(130, 136, 150),
    StormJar   = Color3.fromRGB(170, 150, 240),
    Dragonbone = Color3.fromRGB(225, 215, 185),

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
    Body     = Enum.Font.GothamBold,   -- (GothamMedium was too thin to read on a bright window)
    Mono     = Enum.Font.RobotoMono,   -- (Code is too thin to read either)
}

Theme.TextSize = {
    Title   = 24,
    Heading = 17,
    Body    = 14,
    Small   = 13,
}

Theme.Corner = {
    Large  = UDim.new(0, 16),
    Medium = UDim.new(0, 10),
    Small  = UDim.new(0, 8),
}

-- Near-black outline used on every window, button and tile.
Theme.Outline = Color3.fromRGB(14, 9, 24)

-- Window body colours (Top fades to Bottom; Rim is the light inner edge; TitleStroke outlines the ~Title~ text).
Theme.Palettes = {
    Purple = { Top = Color3.fromRGB(150, 84, 224), Bottom = Color3.fromRGB(84, 36, 160),  Rim = Color3.fromRGB(214, 170, 255), TitleStroke = Color3.fromRGB(52, 20, 104) },
    Blue   = { Top = Color3.fromRGB(70, 152, 255), Bottom = Color3.fromRGB(28, 84, 196),  Rim = Color3.fromRGB(160, 214, 255), TitleStroke = Color3.fromRGB(12, 42, 116) },
    Navy   = { Top = Color3.fromRGB(58, 72, 112),  Bottom = Color3.fromRGB(26, 34, 64),   Rim = Color3.fromRGB(130, 150, 205), TitleStroke = Color3.fromRGB(8, 12, 28) },
    Pink   = { Top = Color3.fromRGB(232, 84, 138), Bottom = Color3.fromRGB(150, 30, 90),  Rim = Color3.fromRGB(255, 178, 212), TitleStroke = Color3.fromRGB(90, 12, 52) },
    Teal   = { Top = Color3.fromRGB(62, 204, 176), Bottom = Color3.fromRGB(20, 120, 124), Rim = Color3.fromRGB(160, 244, 220), TitleStroke = Color3.fromRGB(6, 62, 70) },
    Orange = { Top = Color3.fromRGB(255, 160, 52), Bottom = Color3.fromRGB(200, 82, 22),  Rim = Color3.fromRGB(255, 220, 150), TitleStroke = Color3.fromRGB(104, 40, 8) },
    Tan    = { Top = Color3.fromRGB(222, 178, 128), Bottom = Color3.fromRGB(160, 114, 74), Rim = Color3.fromRGB(246, 218, 170), TitleStroke = Color3.fromRGB(74, 44, 20) },
    Green  = { Top = Color3.fromRGB(96, 208, 84),  Bottom = Color3.fromRGB(38, 134, 52),  Rim = Color3.fromRGB(186, 242, 164), TitleStroke = Color3.fromRGB(14, 66, 24) },
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
    lbl.TextStrokeColor3 = Theme.Outline             -- dark outline keeps text readable on any window colour
    lbl.TextStrokeTransparency = (size or Theme.TextSize.Body) >= 14 and 0.3 or 0.45
    lbl.Font = font or Theme.Fonts.Body
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.Parent = parent
    return lbl
end

-- Chunky cartoon button: thick dark outline, top-lit gradient, outlined text, springy hover / press.
function Theme.Button(parent, text, bgColor, textColor, name)
    local btn = Instance.new("TextButton")
    btn.Name = name or "Button"
    btn.BackgroundColor3 = bgColor or Theme.Colors.Accent
    btn.BorderSizePixel = 0
    btn.Text = text or ""
    btn.TextSize = Theme.TextSize.Body
    btn.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
    btn.TextStrokeColor3 = Theme.Outline
    btn.TextStrokeTransparency = 0.25
    btn.Font = Theme.Fonts.Heading
    btn.AutoButtonColor = false
    btn.Parent = parent
    Theme.AddCorner(btn, Theme.Corner.Small)
    Theme.AddStroke(btn, Theme.Outline, 3)

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

-- Inset card with a light rim, like the lighter panels inside the reference windows.
function Theme.Panel(parent, name, bgColor)
    local f = Instance.new("Frame")
    f.Name = name or "Panel"
    f.BackgroundColor3 = bgColor or Theme.Colors.Panel
    f.BorderSizePixel = 0
    f.Parent = parent
    Theme.AddCorner(f, Theme.Corner.Medium)
    Theme.AddStroke(f, Color3.fromRGB(190, 160, 255), 2, 0.55)
    return f
end

function Theme.ScrollFrame(parent, name)
    local sf = Instance.new("ScrollingFrame")
    sf.Name = name or "Scroll"
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 6
    sf.ScrollBarImageColor3 = Color3.fromRGB(255, 205, 80)
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

-- ── Windows (the look of the reference screenshots) ───────────────────────────
-- Dresses a window frame: thick dark outline, gradient body in the palette's colour, light inner rim.
-- Any UICorner / UIGradient the builder already added is replaced.
function Theme.StyleWindow(container, paletteName)
    local pal = Theme.Palettes[paletteName] or Theme.Palettes.Purple
    for _, c in ipairs(container:GetChildren()) do
        if c:IsA("UICorner") or c:IsA("UIGradient") or c:IsA("UIStroke") then c:Destroy() end
    end
    container.BackgroundColor3 = Color3.fromRGB(255, 255, 255)      -- the gradient supplies the colour
    container.BackgroundTransparency = 0
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new(pal.Top, pal.Bottom)
    grad.Rotation = 90
    grad.Parent = container
    Theme.AddCorner(container, UDim.new(0, 20))
    Theme.AddStroke(container, Theme.Outline, 5)

    local rim = Instance.new("Frame")
    rim.Name = "Rim"
    rim.Size = UDim2.new(1, -12, 1, -12)
    rim.Position = UDim2.new(0, 6, 0, 6)
    rim.BackgroundTransparency = 1
    rim.BorderSizePixel = 0
    rim.Parent = container
    Theme.AddCorner(rim, UDim.new(0, 15))
    Theme.AddStroke(rim, pal.Rim, 2, 0.6)
    return pal
end

-- The red X, top right of a window.
function Theme.CloseButton(parent, onClick)
    local btn = Theme.Button(parent, "X", Color3.fromRGB(214, 36, 44), Color3.fromRGB(255, 255, 255), "CloseButton")
    btn.AnchorPoint = Vector2.new(1, 0)
    btn.Size = UDim2.new(0, 40, 0, 40)
    btn.Position = UDim2.new(1, -10, 0, 8)
    btn.TextSize = 24
    btn.Font = Enum.Font.GothamBlack
    btn.ZIndex = 5
    if onClick then btn.MouseButton1Click:Connect(onClick) end
    return btn
end

-- Dresses a window and gives it a "~Title~" and the red X in one go. Returns titleBar (a transparent
-- 50px strip, so content laid out below it stays where it was), the title label and the close button.
-- `gui` is the ScreenGui the X switches off; pass `onClose` instead for a window that closes differently.
function Theme.WindowHeader(container, gui, title, paletteName, labelName, onClose)
    local pal = Theme.StyleWindow(container, paletteName)

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundTransparency = 1
    titleBar.BorderSizePixel = 0
    titleBar.Parent = container

    local lbl = Instance.new("TextLabel")
    lbl.Name = labelName or "Title"
    lbl.BackgroundTransparency = 1
    lbl.Text = "~" .. title .. "~"
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextSize = 30
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeColor3 = pal.TitleStroke
    lbl.TextStrokeTransparency = 0
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.TextScaled = true                                   -- long titles shrink to fit instead of running under the X
    lbl.Size = UDim2.new(1, -140, 1, -6)
    lbl.Position = UDim2.new(0, 70, 0, 3)
    lbl.Parent = titleBar
    local fit = Instance.new("UITextSizeConstraint")
    fit.MinTextSize = 14
    fit.MaxTextSize = 30
    fit.Parent = lbl

    local close = Theme.CloseButton(container, onClose or function() gui.Enabled = false end)
    return titleBar, lbl, close
end

-- Chunky progress bar with its text INSIDE it (outlined white, readable on any fill).
-- opts (all optional): height (default 24), color (fill), name / fillName / labelName, position.
-- Returns bar (the track), fill, label.
function Theme.ProgressBar(parent, fraction, text, opts)
    opts = opts or {}
    local height = opts.height or 24
    local frac = math.clamp(fraction or 0, 0, 1)
    local radius = UDim.new(0, math.floor(height / 2))

    local bar = Instance.new("Frame")
    bar.Name = opts.name or "ProgressBar"
    bar.Size = opts.size or UDim2.new(1, 0, 0, height)
    if opts.position then bar.Position = opts.position end
    bar.BackgroundColor3 = Color3.fromRGB(20, 14, 38)
    bar.BorderSizePixel = 0
    bar.Parent = parent
    Theme.AddCorner(bar, radius)
    Theme.AddStroke(bar, Theme.Outline, 2)

    local fill = Instance.new("Frame")
    fill.Name = opts.fillName or "Fill"
    fill.Size = UDim2.new(frac, 0, 1, 0)
    fill.BackgroundColor3 = opts.color or Theme.Colors.Accent
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Theme.AddCorner(fill, radius)
    local grad = Instance.new("UIGradient")                       -- top-lit, like the buttons
    grad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 180, 180))
    grad.Rotation = 90
    grad.Parent = fill

    local lbl = Instance.new("TextLabel")
    lbl.Name = opts.labelName or "BarLabel"
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -12, 1, 0)
    lbl.Position = UDim2.new(0, 6, 0, 0)
    lbl.Text = text or ""
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextSize = math.clamp(math.floor(height * 0.6), 12, 18)
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeColor3 = Theme.Outline
    lbl.TextStrokeTransparency = 0.15
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.ZIndex = 3
    lbl.Parent = bar
    return bar, fill, lbl
end

-- Screen-covering dark scrim
function Theme.Scrim(parent, transparency)
    local s = Instance.new("Frame")
    s.Name = "Scrim"
    s.Size = UDim2.new(1, 0, 1, 0)
    s.BackgroundColor3 = Theme.Colors.Scrim
    s.BackgroundTransparency = transparency or 0.5
    s.BorderSizePixel = 0
    s.ZIndex = 0              -- behind the window it dims (a higher layer would dim the window itself)
    s.Parent = parent
    return s
end

return Theme
