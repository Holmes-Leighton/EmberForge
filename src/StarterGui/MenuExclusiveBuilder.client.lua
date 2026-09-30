-- Only one main menu may be open at a time: opening a menu closes the others.
-- (Dialogs such as SmeltDialog / GolemPickerDialog sit on top of a menu and are left alone.)
local Players = game:GetService("Players")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local MENUS = {
    InventoryMenu = true, ForgeMenu = true, MarketMenu = true, TradeMenu = true, ShopMenu = true,
    SeasonMenu = true, ChallengesMenu = true, StyleMenu = true, LeaderboardMenu = true, AnvilMenu = true,
}

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
    end)
end

for _, c in ipairs(playerGui:GetChildren()) do Watch(c) end
playerGui.ChildAdded:Connect(Watch)
