-- Wires the leaderboard nav button and handles server-push leaderboard updates.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)

local LeaderboardController = {}

function LeaderboardController.Init(_playerData)
    -- Nothing to wire: the HUD's Leaders tile already toggles the LeaderboardMenu (HUDBuilder's OpenNav), and the menu loads its
    -- own data when it is enabled. This controller used to add a second click handler that toggled it again, so the two cancelled
    -- out and the Leaders button never opened the menu.
end

return LeaderboardController
