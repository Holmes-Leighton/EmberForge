-- Draws every player's Golem pets trotting along behind them. The server only publishes *which* pets a
-- player is wearing (the "EFPets" attribute, comma-separated types); everything you see here is built and
-- moved on this client, so the motion is smooth and costs the server nothing.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local GolemModel = require(game.ReplicatedStorage.Shared.Modules.GolemModel)
local PetModel   = require(game.ReplicatedStorage.Shared.Modules.PetModel)
local PetData    = require(game.ReplicatedStorage.Shared.Data.PetData)

local PetController = {}

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

-- Builds one pet (its own model, or a mini Golem until one is uploaded; see PetModel)
local function MakePet(entry)
    local petType, variant = entry:match("^([^:]+):?(.*)$")
    variant = variant ~= "" and variant or nil
    local model, feet, hover = PetModel.Build(petType, variant)
    if not model then return nil end
    model.Parent = folder
    local pet = { model = model, feet = feet, hover = hover, variant = variant, pos = nil, yaw = nil, phase = math.random() * 6.28 }
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

            -- Movement animation. Every pet is one solid mesh (no legs to bend), so the life comes from the whole body:
            --   walking: a hop on each step, leaning into the direction of travel, and a side-to-side waddle
            --   standing: a slow breathing sway, looking about, and now and then a happy hop with a spin
            local walking = moving and not atHome
            local bob = walking and math.abs(math.sin(t * 9 + pet.phase)) * 0.5 or math.sin(t * 2 + pet.phase) * 0.06
            local pitch, roll, spin = 0, 0, 0
            if walking then
                pitch = -0.16                                              -- nose down: leaning forward
                roll = math.sin(t * 9 + pet.phase) * 0.13                  -- waddle in time with the hops
            else
                roll = math.sin(t * 1.4 + pet.phase) * 0.04                -- breathing sway
                pitch = math.sin(t * 0.9 + pet.phase * 2) * 0.03
                -- an idle pet looks around a little...
                spin = math.sin(t * 0.55 + pet.phase) * 0.35
                -- ...and every so often does a happy hop with a full spin
                pet.nextHappy = pet.nextHappy or (t + 4 + math.random() * 8)
                if not pet.happyAt and t >= pet.nextHappy then pet.happyAt = t end
            end
            if pet.happyAt then
                local k = (t - pet.happyAt) / 0.7
                if k >= 1 or walking then
                    pet.happyAt, pet.nextHappy = nil, t + 6 + math.random() * 10
                else
                    bob += math.sin(k * math.pi) * 1.3                     -- up and back down
                    spin += k * math.pi * 2                                -- one full turn
                    pitch += math.sin(k * math.pi) * 0.25                  -- lean back at the top, like a cheer
                end
            end
            -- floating pets (sprites, ghosts) hover and drift a little higher than walkers bob
            local p = Vector3.new(pet.pos.X, pet.pos.Y + pet.feet + pet.hover + bob + (pet.hover > 0 and math.sin(t * 2.5 + pet.phase) * 0.15 or 0), pet.pos.Z)
            pet.model:PivotTo(CFrame.new(p) * CFrame.Angles(0, (pet.yaw or 0) + spin, 0) * CFrame.Angles(pitch, 0, roll))
            if pet.tinted then
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
