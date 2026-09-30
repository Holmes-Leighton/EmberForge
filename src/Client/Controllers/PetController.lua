-- Draws every player's Golem pets trotting along behind them. The server only publishes *which* pets a
-- player is wearing (the "EFPets" attribute, comma-separated types); everything you see here is built and
-- moved on this client, so the motion is smooth and costs the server nothing.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local GolemModel = require(game.ReplicatedStorage.Shared.Modules.GolemModel)
local PetData    = require(game.ReplicatedStorage.Shared.Data.PetData)

local PetController = {}

local PET_SCALE   = 0.2          -- a pet is about a fifth of a Golem (roughly knee height on a player)
local FOLLOW_GAP  = 4.5          -- studs behind the owner
local SPACING     = 3.4          -- studs between pets worn side by side
local SNAP_DIST   = 45           -- farther than this (a teleport) and the pet jumps to its owner
local DRAW_DIST   = 140          -- don't bother animating pets farther than this from the camera

local folder
local states = {}                -- Player -> { key, assetVersion, pets = { { model, feet, pos, yaw, phase } } }

local function Destroy(state)
    for _, pet in ipairs(state.pets) do pet.model:Destroy() end
    state.pets = {}
end

-- Builds one pet model and works out how far its pivot sits above the floor
local function MakePet(petType)
    local ok, model = pcall(GolemModel.Build, petType, 1, {})
    if not ok or not model then return nil end
    model.Name = "Pet_" .. petType
    model:ScaleTo(model:GetScale() * PET_SCALE)
    local box, size = model:GetBoundingBox()
    local feet = model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
        elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") or d:IsA("SpotLight") then
            d.Enabled = false                       -- keep a crowd of pets cheap
        end
    end
    model.Parent = folder
    return { model = model, feet = feet, pos = nil, yaw = nil, phase = math.random() * 6.28 }
end

local function Rebuild(player, state, types)
    Destroy(state)
    for _, t in ipairs(types) do
        local pet = MakePet(t)
        if pet then table.insert(state.pets, pet) end
    end
    state.key = table.concat(types, ",")
    state.assetVersion = GolemModel.AssetVersion()
end

local function Parse(value)
    local types = {}
    for t in tostring(value or ""):gmatch("[^,]+") do
        if PetData.Get(t) then table.insert(types, t) end
    end
    return types
end

local function Track(player)
    if states[player] then return end
    states[player] = { key = "", assetVersion = -1, pets = {} }
end

local function Untrack(player)
    local state = states[player]
    if state then Destroy(state) states[player] = nil end
end

local function Step(dt)
    local cam = workspace.CurrentCamera
    local t = os.clock()
    for player, state in pairs(states) do
        local types = Parse(player:GetAttribute("EFPets"))
        local key = table.concat(types, ",")
        if key ~= state.key or (#types > 0 and state.assetVersion ~= GolemModel.AssetVersion()) then
            Rebuild(player, state, types)
        end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (root and hum) or #state.pets == 0 then continue end
        if cam and (root.Position - cam.CFrame.Position).Magnitude > DRAW_DIST then
            for _, pet in ipairs(state.pets) do pet.model.Parent = nil end
            continue
        end

        local ground = root.Position.Y - hum.HipHeight - root.Size.Y / 2
        local moving = root.AssemblyLinearVelocity.Magnitude > 2
        local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
        local yawTarget = look.Magnitude > 0.01 and math.atan2(-look.X, -look.Z) or nil
        local n = #state.pets
        for i, pet in ipairs(state.pets) do
            if pet.model.Parent ~= folder then pet.model.Parent = folder end
            local side = (i - (n + 1) / 2) * SPACING
            local target = (root.CFrame * CFrame.new(side, 0, FOLLOW_GAP)).Position
            target = Vector3.new(target.X, ground, target.Z)

            if not pet.pos or (pet.pos - target).Magnitude > SNAP_DIST then pet.pos = target end
            pet.pos = pet.pos:Lerp(target, 1 - math.exp(-dt * (moving and 7 or 4)))
            local atHome = (pet.pos - target).Magnitude < 0.25
            if yawTarget then
                pet.yaw = pet.yaw and (pet.yaw + ((yawTarget - pet.yaw + math.pi) % (2 * math.pi) - math.pi) * (1 - math.exp(-dt * 6))) or yawTarget
            end

            local bob = (moving and not atHome) and math.abs(math.sin(t * 9 + pet.phase)) * 0.5 or math.sin(t * 2 + pet.phase) * 0.06
            local p = Vector3.new(pet.pos.X, pet.pos.Y + pet.feet + bob, pet.pos.Z)
            pet.model:PivotTo(CFrame.new(p) * CFrame.Angles(0, pet.yaw or 0, 0))
        end
    end
end

function PetController.Init()
    folder = Instance.new("Folder")
    folder.Name = "Pets"
    folder.Parent = workspace

    for _, p in ipairs(Players:GetPlayers()) do Track(p) end
    Players.PlayerAdded:Connect(Track)
    Players.PlayerRemoving:Connect(Untrack)
    RunService.RenderStepped:Connect(Step)
end

return PetController
