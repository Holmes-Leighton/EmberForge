-- The Sky Tower: builds the current round's tower far above the world, links the portals, and runs the round clock (a new tower every round, the same on every server).
-- Each climber's run (levels reached, falls, rewards) is added in the next step; this part makes the tower exist and lets players go up and come back.
local Players = game:GetService("Players")

local TowerData   = require(game.ReplicatedStorage.Shared.Data.TowerData)
local TowerLayout = require(game.ReplicatedStorage.Shared.Modules.TowerLayout)
local TowerRound  = require(script.Parent.TowerRound)
local TowerArt    = require(script.Parent.TowerArt)
local CourierArt  = require(script.Parent.CourierArt)

local TowerService = {}

local SPAWN_HOME = Vector3.new(0, 6, -60)          -- where the way back leaves you (the hub spawn)
local state = { round = nil, layout = nil, folder = nil, lobby = nil }

local function WallClock() return os.time() end

local function InTower(player)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    return root ~= nil and root.Position.Y > TowerData.BASE.y - 200
end

local function SendHome(player)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = CFrame.new(SPAWN_HOME)
        root.AssemblyLinearVelocity = Vector3.zero
    end
end

local function LobbyPoint()
    local b = TowerData.BASE
    return CFrame.lookAt(Vector3.new(b.x - 17, b.y + 4, b.z), Vector3.new(b.x + 20, b.y + 4, b.z))
end

local function SendUp(player)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = LobbyPoint()
        root.AssemblyLinearVelocity = Vector3.zero
    end
end

-- The tower for a round: the layout, the parts, the lobby and the return portals
local function BuildTower(world, round)
    if state.folder then state.folder:Destroy() end
    local T = TowerLayout.Build({ levels = TowerData.LEVELS, seed = round.seed, base = TowerData.BASE })
    state.layout = T
    local root = Instance.new("Folder")
    root.Name = "SkyTowerRoot"
    root.Parent = world
    state.folder = root
    TowerArt.Build(root, T)

    -- a lobby platform to arrive on, beside the first level
    local b = TowerData.BASE
    CourierArt.P({ Name = "TowerLobby", Material = Enum.Material.Slate, Color = Color3.fromRGB(110, 76, 66), Size = Vector3.new(34, 2, 30), CFrame = CFrame.new(b.x - 17, b.y - 1, b.z) }, root)
    local _, backPrompt = TowerArt.Portal(root, Vector3.new(b.x - 30, b.y, b.z - 6), Vector3.new(1, 0, 0), "Back to the cavern", Color3.fromRGB(120, 210, 255))
    backPrompt.ActionText = "Leave the tower"
    backPrompt.Triggered:Connect(SendHome)
    -- and one at the summit
    local f = T.finish
    local dir = T.levels[T.total].dir
    local _, topPrompt = TowerArt.Portal(root, Vector3.new(f.x + dir * 12, f.y - 3, f.z), Vector3.new(-dir, 0, 0), "Home", Color3.fromRGB(255, 215, 90))
    topPrompt.ActionText = "Go home"
    topPrompt.Triggered:Connect(SendHome)
    return T
end

function TowerService.Init()
    local world = workspace:FindFirstChild("EmberWorld")
    if not world then
        warn("[TowerService] EmberWorld not found: build the world first")
        return
    end
    state.round = TowerRound.New(WallClock())
    BuildTower(world, state.round)

    -- the hub portal, near the spawn
    local p = TowerData.PORTAL
    local _, prompt = TowerArt.Portal(world, Vector3.new(p.x, 0, p.z), Vector3.new(0.92, 0, -0.38), "SKY TOWER", Color3.fromRGB(190, 120, 255))
    prompt.ActionText = "Climb the Sky Tower"
    prompt.Triggered:Connect(SendUp)

    task.spawn(function()
        while true do
            task.wait(1)
            local events, round = TowerRound.Step(state.round, WallClock())
            state.round = round
            for _, e in ipairs(events) do
                if e.kind == "new" then
                    for _, player in ipairs(Players:GetPlayers()) do
                        if InTower(player) then SendHome(player) end          -- (a new tower is being built: everyone up there comes down)
                    end
                    BuildTower(world, e.round)
                end
            end
        end
    end)
end

function TowerService.Layout() return state.layout end
function TowerService.Round() return state.round end

return TowerService
