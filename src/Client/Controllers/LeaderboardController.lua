-- Wires the leaderboard nav button and handles server-push leaderboard updates.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)

local LeaderboardController = {}

function LeaderboardController.Init(_playerData)
    -- Nav button toggle is handled directly in LeaderboardMenu.client.lua.
    -- This controller wires the HUD nav button to that Toggle function.
    task.spawn(function()
        local pg   = LocalPlayer:WaitForChild("PlayerGui")
        local hud  = pg:WaitForChild("HUD", 10)
        if not hud then return end

        local lbBtn = hud:FindFirstChild("LeaderboardBtn", true)
        if lbBtn then
            lbBtn.MouseButton1Click:Connect(function()
                local lbGui  = pg:FindFirstChild("LeaderboardMenu")
                local toggle = lbGui and lbGui:FindFirstChild("Toggle")
                if toggle then toggle:Invoke() end
            end)
        end
    end)
end

return LeaderboardController
