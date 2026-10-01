-- Small face portraits for list rows: a ViewportFrame showing a pet's or Golem's head, close up.
--   Portrait.Pet(parent, pet, size)      pet = { type, variant, grown }   (its current stage is drawn)
--   Portrait.Golem(parent, golem, size)  golem = { element, tier, variant }
-- Both return the ViewportFrame (a round, framed picture). The model is built once, posed at rest and never animated, so a
-- long list of portraits costs very little. Models that cannot be built give a plain coloured disc with the first letter.

local PetData    = require(script.Parent.Parent.Data.PetData)
local Theme      = require(script.Parent.Theme)
local PetModel   = require(script.Parent.PetModel)
local GolemModel = require(script.Parent.GolemModel)

local Portrait = {}

local function Frame(parent, size, ringColor)
    local vp = Instance.new("ViewportFrame")
    vp.Name = "Portrait"
    vp.Size = UDim2.new(0, size, 0, size)
    vp.BackgroundColor3 = Color3.fromRGB(58, 48, 44)
    vp.BorderSizePixel = 0
    vp.LightColor = Color3.fromRGB(255, 244, 230)
    vp.Ambient = Color3.fromRGB(150, 140, 135)
    vp.Parent = parent
    Theme.AddCorner(vp, UDim.new(0.5, 0))
    Theme.AddStroke(vp, ringColor or Color3.fromRGB(255, 190, 90), 2, 0.2)
    return vp
end

local function Fallback(vp, letter)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Text = string.upper(string.sub(tostring(letter or "?"), 1, 1))
    l.Font = Enum.Font.GothamBlack
    l.TextScaled = true
    l.TextColor3 = Color3.fromRGB(255, 220, 160)
    l.Parent = vp
end

-- Points a camera at the head: the "Head" part when the model has one, otherwise the upper part of the whole model
local function Aim(vp, model)
    local cam = Instance.new("Camera")
    cam.FieldOfView = 36
    cam.Parent = vp
    vp.CurrentCamera = cam
    local head = model:FindFirstChild("Head", true)
    local focus, reach
    local face = Vector3.new(0, 0, -1)
    if head and head:IsA("BasePart") then
        focus = head.Position
        reach = math.max(head.Size.X, head.Size.Y, head.Size.Z) * 0.75
        -- the face is on the side of the head that points away from the body's centre
        local away = head.Position - model:GetBoundingBox().Position
        away = Vector3.new(away.X, 0, away.Z)
        if away.Magnitude > 0.05 then face = away.Unit end
    else
        local cf, size = model:GetBoundingBox()
        focus = cf.Position + Vector3.new(0, size.Y * 0.28, 0)
        reach = math.max(size.X, size.Y) * 0.34
    end
    local dist = math.max(reach, 0.5) / math.tan(math.rad(cam.FieldOfView / 2)) * 1.05
    cam.CFrame = CFrame.lookAt(focus + face * dist + Vector3.new(0, reach * 0.12, 0), focus)
end

local function Finish(vp, model, fallbackLetter)
    if not model then Fallback(vp, fallbackLetter) return vp end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("ParticleEmitter") or d:IsA("PointLight") then d.Enabled = false end
    end
    model.Parent = vp
    Aim(vp, model)
    return vp
end

function Portrait.Pet(parent, pet, size)
    local def = PetData.Get(pet.type)
    local colour = def and ({ Common = Color3.fromRGB(190, 190, 190), Uncommon = Color3.fromRGB(110, 210, 120), Rare = Color3.fromRGB(100, 170, 255),
        Epic = Color3.fromRGB(200, 120, 255), Legendary = Color3.fromRGB(255, 190, 70) })[def.rarity]
    local vp = Frame(parent, size or 52, colour)
    local ok, model = pcall(function() return (PetModel.Build(pet.type, pet.variant, PetData.StageOf(pet).id)) end)
    return Finish(vp, ok and model or nil, def and def.displayName or pet.type)
end

function Portrait.Golem(parent, golem, size)
    local vp = Frame(parent, size or 52)
    local ok, model = pcall(function() return GolemModel.Build(golem.element, golem.tier or 1, { variant = golem.variant }) end)
    return Finish(vp, ok and model or nil, golem.element)
end

return Portrait
