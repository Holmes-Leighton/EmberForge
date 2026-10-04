-- The small "name your Golem / pet" window, and the pencil button menus put next to a name. Client only.
local Players = game:GetService("Players")

local Theme     = require(script.Parent.Theme)
local ScaleUI   = require(script.Parent.ScaleUI)
local Nicknames = require(script.Parent.Nicknames)

local RenameDialog = {}

local open          -- the ScreenGui of the window that is up, if any

function RenameDialog.Close()
    if open then open:Destroy() open = nil end
end

-- opts.kind      "Golem" or "pet" (for the wording)
-- opts.current   the name it has now, or nil
-- opts.baseName  what it is called without a nickname ("Frost Core Golem")
-- opts.onSubmit  function(text): called with the typed name; "" removes the name
function RenameDialog.Open(opts)
    RenameDialog.Close()
    local W, H = 360, opts.current and 232 or 196

    local gui = Instance.new("ScreenGui")
    gui.Name = "RenameDialog"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 300
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    open = gui

    local scrim = Instance.new("TextButton")           -- tapping outside closes it
    scrim.Size = UDim2.new(1, 0, 1, 0)
    scrim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    scrim.BackgroundTransparency = 0.45
    scrim.BorderSizePixel = 0
    scrim.Text = ""
    scrim.AutoButtonColor = false
    scrim.Parent = gui
    scrim.MouseButton1Click:Connect(RenameDialog.Close)

    local panel = Theme.Panel(gui, "Panel", Theme.Colors.Background)
    panel.Size = UDim2.new(0, W, 0, H)
    ScaleUI.Apply(panel, W, H)

    local title = Theme.Label(panel, "Name your " .. (opts.kind or "Golem"), Theme.TextSize.Heading + 2, Theme.Colors.AccentBright, Theme.Fonts.Title)
    title.Position, title.Size = UDim2.new(0, 18, 0, 12), UDim2.new(1, -36, 0, 26)
    local sub = Theme.Label(panel, opts.baseName or "", Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Body)
    sub.Position, sub.Size = UDim2.new(0, 18, 0, 40), UDim2.new(1, -36, 0, 18)

    local box = Instance.new("TextBox")
    box.Name = "NameBox"
    box.Position, box.Size = UDim2.new(0, 18, 0, 66), UDim2.new(1, -36, 0, 40)
    box.BackgroundColor3 = Theme.Colors.Panel
    box.TextColor3 = Theme.Colors.TextPrimary
    box.PlaceholderText = string.format("Type a name (up to %d letters)", Nicknames.MAX_LENGTH)
    box.PlaceholderColor3 = Theme.Colors.TextDim
    box.Font = Theme.Fonts.Heading
    box.TextSize = 18
    box.Text = opts.current or ""
    box.ClearTextOnFocus = false
    box.BorderSizePixel = 0
    box.Parent = panel
    Theme.AddCorner(box, Theme.Corner.Small)
    box:GetPropertyChangedSignal("Text"):Connect(function()
        local trimmed = Nicknames.Trim(box.Text)
        if trimmed ~= box.Text then box.Text = trimmed end
    end)

    local hint = Theme.Label(panel, "Everyone who sees it reads the name, and Roblox checks it first.", Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Body)
    hint.Position, hint.Size = UDim2.new(0, 18, 0, 110), UDim2.new(1, -36, 0, 30)

    local function submit(text)
        RenameDialog.Close()
        if opts.onSubmit then opts.onSubmit(text) end
    end

    local y = H - 52
    local save = Theme.Button(panel, "Save", Theme.Colors.Accent, Color3.fromRGB(255, 255, 255), "Save")
    save.Size, save.Position = UDim2.new(0.5, -24, 0, 38), UDim2.new(0, 18, 0, y)
    save.MouseButton1Click:Connect(function() submit(box.Text) end)
    local cancel = Theme.Button(panel, "Cancel", Theme.Colors.PanelAlt, Theme.Colors.AccentBright, "Cancel")
    cancel.Size, cancel.Position = UDim2.new(0.5, -24, 0, 38), UDim2.new(0.5, 6, 0, y)
    cancel.MouseButton1Click:Connect(RenameDialog.Close)
    if opts.current then
        local clear = Theme.Button(panel, "Remove name", Theme.Colors.PanelAlt, Theme.Colors.TextSecondary, "Remove")
        clear.Size, clear.Position = UDim2.new(1, -36, 0, 30), UDim2.new(0, 18, 0, y - 40)
        clear.TextSize = 13
        clear.MouseButton1Click:Connect(function() submit("") end)
    end
    box.FocusLost:Connect(function(enterPressed) if enterPressed then submit(box.Text) end end)
    return gui
end

-- A small "Name" button right after a name label: tapping it runs onClick. `title` is the name's TextLabel.
function RenameDialog.AddPencil(parent, title, onClick)
    local width = 220
    pcall(function()
        local size = game:GetService("TextService"):GetTextSize(title.Text, title.TextSize, title.Font, Vector2.new(10000, 40))
        local boxW = title.AbsoluteSize.X > 0 and title.AbsoluteSize.X or 260
        width = math.min(size.X, math.max(boxW - 48, 40))
    end)
    local btn = Theme.Button(parent, "Name", Theme.Colors.PanelAlt, Theme.Colors.AccentBright, "RenameButton")     -- (the game font has no pencil glyph)
    btn.Size = UDim2.new(0, 42, 0, 20)
    local p = title.Position
    btn.Position = UDim2.new(p.X.Scale, p.X.Offset + width + 6, p.Y.Scale, p.Y.Offset)
    btn.TextSize = 11
    btn.MouseButton1Click:Connect(onClick)
    return btn
end

return RenameDialog
