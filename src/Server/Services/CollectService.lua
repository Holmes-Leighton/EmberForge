-- Banking what the Golems have mined: everything in the player's Pending pool goes into the inventory and the Golems' bags are emptied.
-- It happens by itself every few seconds (there is no Collect button any more), except while the player is in the Sky Tower or the Hollow Maze: what the Golems mine
-- then waits and is banked a moment after they are back. The Collect remote still works (the same rules) for anything that asks for it.
local Players = game:GetService("Players")

local RemoteEvents      = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ChallengeService  = require(script.Parent.ChallengeService)
local Analytics         = require(script.Parent.AnalyticsHelper)

local CollectService = {}

CollectService.EVERY         = 8      -- seconds between automatic collections
CollectService.CHALLENGE_GAP = 300    -- an automatic collection counts for the "collect" challenges at most this often (or "collect from 3 Golems" would be done in half a minute)
CollectService.MANUAL, CollectService.AUTO = -1, -2            -- the marker the client gets with the pickup (-1 asked for, -2 by itself)

local lastChallenge = {}              -- userId -> os.clock() of the last automatic collection that counted

-- Climbing the tower or running the maze: nothing is banked until they are out
function CollectService.Blocked(player)
    local services = script.Parent
    local tower, maze = services:FindFirstChild("TowerService"), services:FindFirstChild("MazeService")
    if tower and require(tower).InTower(player) then return "Sky Tower" end
    if maze and require(maze).InMaze(player) then return "Hollow Maze" end
    return nil
end

local function PendingTotal(data)
    local total = 0
    for _, qty in pairs(data.Pending or {}) do if qty > 0 then total += qty end end
    return total
end

-- Moves everything pending into the inventory. Returns the total banked and what it was (gains), or 0 when there was nothing.
function CollectService.Collect(player, marker)
    local data = PlayerDataService.Get(player)
    if not data then return 0, {} end
    local gains, total = {}, 0
    for matId, qty in pairs(data.Pending or {}) do
        if qty > 0 then
            PlayerDataService.AddMaterial(player, matId, qty)
            gains[matId] = qty
            total += qty
        end
    end
    data.Pending = {}
    for _, g in ipairs(data.Golems or {}) do
        g._carriedResources = 0   -- empty their bags (recalled Golems too)
    end
    PlayerDataService.MarkDirty(player)
    RemoteEvents.PendingUpdate:FireClient(player, data.Pending)
    if total == 0 then return 0, gains end

    local counts = true
    if marker == CollectService.AUTO then
        local now = os.clock()
        counts = (lastChallenge[player.UserId] or -1e9) + CollectService.CHALLENGE_GAP <= now
        if counts then lastChallenge[player.UserId] = now end
    end
    if counts then ChallengeService.TrackEvent(player, "GolemCollect", { count = 1 }) end
    Analytics.Funnel(player, data, "collect", 4, "FirstCollect")
    Analytics.TimeTo(player, data, "FirstCollect")
    RemoteEvents.ResourcesCollected:FireClient(player, gains, marker or CollectService.MANUAL)
    return total, gains
end

-- One automatic pass: bank for every player who has something pending and is not in the tower or the maze
function CollectService.Tick()
    for _, player in ipairs(Players:GetPlayers()) do
        local data = PlayerDataService.Get(player)
        if data and PendingTotal(data) > 0 and not CollectService.Blocked(player) then
            local ok, err = pcall(CollectService.Collect, player, CollectService.AUTO)
            if not ok then warn("[CollectService] " .. tostring(err)) end
        end
    end
end

function CollectService.Init()
    Players.PlayerRemoving:Connect(function(player) lastChallenge[player.UserId] = nil end)
    task.spawn(function()
        while true do
            task.wait(CollectService.EVERY)
            CollectService.Tick()
        end
    end)
end

return CollectService
