-- Window behaviour shared by every main menu:
--   * only one main menu may be open at a time (opening one closes the others)
--   * menus pop in: the backdrop fades up and the window springs in from slightly below
-- (Dialogs such as SmeltDialog / GolemPickerDialog sit on top of a menu and are left alone.)
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local MENUS = {
    InventoryMenu = true, ForgeMenu = true, MarketMenu = true, TradeMenu = true, ShopMenu = true,
    SeasonMenu = true, ChallengesMenu = true, StyleMenu = true, LeaderboardMenu = true, AnvilMenu = true, PetsMenu = true, GuildMenu = true, BuildMenu = true, QuarryMenu = true, RewardsMenu = true,
}

local function PopIn(gui)
    pcall(function()
        local box = gui:FindFirstChild("Container")
        if box then
            local home = box.Position
            box.Position = home + UDim2.new(0, 0, 0, 36)
            TweenService:Create(box, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = home }):Play()
        end
        local scrim = gui:FindFirstChild("Scrim") or gui:FindFirstChildWhichIsA("GuiObject")
        if scrim and scrim ~= box and scrim.BackgroundTransparency < 1 then
            local target = scrim.BackgroundTransparency
            scrim.BackgroundTransparency = 1
            TweenService:Create(scrim, TweenInfo.new(0.2), { BackgroundTransparency = target }):Play()
        end
    end)
end

local watched = {}
local function Watch(gui)
    if watched[gui] or not gui:IsA("ScreenGui") or not MENUS[gui.Name] then return end
    watched[gui] = true
    gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if not gui.Enabled then return end
        for _, other in ipairs(playerGui:GetChildren()) do
            if other ~= gui and MENUS[other.Name] and other:IsA("ScreenGui") and other.Enabled then
                other.Enabled = false
            end
        end
        PopIn(gui)
    end)
end

for _, c in ipairs(playerGui:GetChildren()) do Watch(c) end
playerGui.ChildAdded:Connect(Watch)
