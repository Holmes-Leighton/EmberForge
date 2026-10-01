-- Draws every player's Golem pets trotting along behind them. The server only publishes *which* pets a
-- player is wearing (the "EFPets" attribute, comma-separated types); everything you see here is built and
-- moved on this client, so the motion is smooth and costs the server nothing.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local GolemModel = require(game.ReplicatedStorage.Shared.Modules.GolemModel)
local PetModel   = require(game.ReplicatedStorage.Shared.Modules.PetModel)
local PetRig     = require(game.ReplicatedStorage.Shared.Modules.PetRig)
local PetData    = require(game.ReplicatedStorage.Shared.Data.PetData)

local PetController = {}

local FOLLOW_GAP  = 4.5          -- studs behind the owner
local SPACING     = 3.4          -- studs between pets worn side by side
local SNAP_DIST   = 45           -- farther than this (a teleport) and the pet jumps to its owner
local DRAW_DIST   = 140          -- farther than this from the camera and a pet is not drawn at all
local ANIMATE_DIST  = 70           -- farther than this and its limbs rest instead of swinging (nobody can see the detail)

local folder
local states = {}                -- Player -> { key, assetVersion, pets = { { model, feet, pos, yaw, phase } } }

local function Destroy(state)
    for _, pet in ipairs(state.pets) do pet.model:Destroy() end
    state.pets = {}
end

-- Builds one pet (its own model, or a mini Golem until one is uploaded; see PetModel)
local function MakePet(entry)
    local petType, variant = entry:match("^([^:]+):?(.*)$")
    variant = variant ~= "" and variant or nil
    local model, feet, hover, rig = PetModel.Build(petType, variant)
    if not model then return nil end
    model.Parent = folder
    local pet = { model = model, feet = feet, hover = hover, rig = rig, variant = variant, pos = nil, yaw = nil, phase = math.random() * 6.28 }
    if variant == "MegaNeon" then                    -- Mega Neon cycles through the rainbow
        pet.tinted = {}
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") and d:GetAttribute("Tint") then table.insert(pet.tinted, d) end
        end
    end
    return pet
end

local function Rebuild(player, state, types)
    Destroy(state)
    for _, t in ipairs(types) do
        local pet = MakePet(t)
        if pet then table.insert(state.pets, pet) end
    end
    state.key = table.concat(types, ",")
    state.assetVersion = GolemModel.AssetVersion() + PetModel.AssetVersion() * 1000
end

local function Parse(value)
    local types = {}
    for t in tostring(value or ""):gmatch("[^,]+") do          -- "Ember" or "Ember:Neon"
        local petType, variant = t:match("^([^:]+):?(.*)$")
        if PetData.Get(petType) and (variant == "" or PetData.Variants[variant]) then table.insert(types, t) end
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
        if key ~= state.key or (#types > 0 and state.assetVersion ~= GolemModel.AssetVersion() + PetModel.AssetVersion() * 1000) then
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

            -- Animation. A segmented pet (pet.rig) swings its limbs about their joints (see PetRig); the whole body adds a hop on
            -- each footfall and a lean into the walk. A standing pet breathes, looks about and now and then cheers with a hop.
            local walking = moving and not atHome
            pet.walk = (pet.walk or 0) + ((walking and 1 or 0) - (pet.walk or 0)) * (1 - math.exp(-dt * 8))      -- eases between standing and walking
            pet.gait = (pet.gait or pet.phase) + dt * 4.5 * pet.walk                                              -- two footfalls per cycle
            local bob = math.abs(math.sin(pet.gait * 2)) * 0.45 * pet.walk + math.sin(t * 2 + pet.phase) * 0.05 * (1 - pet.walk)
            local pitch = -0.1 * pet.walk + math.sin(t * 0.9 + pet.phase * 2) * 0.025 * (1 - pet.walk)
            if not walking then
                pet.nextCheer = pet.nextCheer or (t + 4 + math.random() * 8)
                if not pet.cheerAt and t >= pet.nextCheer then pet.cheerAt = t end
            end
            local happy = 0
            if pet.cheerAt then
                local k = (t - pet.cheerAt) / 0.8
                if k >= 1 or walking then
                    pet.cheerAt, pet.nextCheer = nil, t + 6 + math.random() * 10
                else
                    happy = math.sin(k * math.pi)
                    bob += happy * 1.1                                                     -- a hop
                end
            end
            -- floating pets (sprites, ghosts) hover and drift a little higher than walkers bob
            local p = Vector3.new(pet.pos.X, pet.pos.Y + pet.feet + pet.hover + bob + (pet.hover > 0 and math.sin(t * 2.5 + pet.phase) * 0.15 or 0), pet.pos.Z)
            local modelCF = CFrame.new(p) * CFrame.Angles(0, pet.yaw or 0, 0) * CFrame.Angles(pitch, 0, 0)
            pet.model:PivotTo(modelCF)
            if pet.rig then
                if not cam or (p - cam.CFrame.Position).Magnitude <= ANIMATE_DIST then
                    PetRig.Apply(pet.rig, modelCF, { t = t + pet.phase, walk = pet.walk, gait = pet.gait, happy = happy, fly = pet.hover > 0 })
                    pet.limbsRest = false
                elseif not pet.limbsRest then
                    PetRig.Rest(pet.rig, modelCF)                                          -- too far to see the detail: stand it at rest
                    pet.limbsRest = true
                end
            end            if pet.tinted then
                local c = Color3.fromHSV((t * 0.25 + pet.phase) % 1, 0.65, 1)
                for _, part in ipairs(pet.tinted) do part.Color = c end
            end
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
