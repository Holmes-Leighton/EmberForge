-- Builds a static, blocky Golem model (used for the Anvil preview).
-- Origin is at ground level, facing -Z.

local Theme = require(script.Parent.Theme)

local GolemModel = {}

function GolemModel.Build(element, tier)
    local color = Theme.Colors[element] or Color3.fromRGB(150, 150, 150)
    local dark  = color:Lerp(Color3.new(0, 0, 0), 0.35)
    local s     = 1 + ((tier or 1) - 1) * 0.18

    local model = Instance.new("Model")
    model.Name = "GolemPreview"

    local function part(name, size, c, material, cf)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size * s
        p.Color = c
        p.Material = material or Enum.Material.Slate
        p.Anchored = true
        p.CanCollide = false
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.CFrame = cf
        p.Parent = model
        return p
    end
    local function at(x, y, z) return CFrame.new(x * s, y * s, z * s) end

    local torso = part("Torso", Vector3.new(3.2, 4, 2), color, nil, at(0, 5, 0))
    part("Head", Vector3.new(2.4, 2.2, 2.4), dark, nil, at(0, 8.3, 0))
    for _, side in ipairs({ -0.6, 0.6 }) do
        part("Eye", Vector3.new(0.5, 0.4, 0.2), color:Lerp(Color3.new(1, 1, 1), 0.5),
            Enum.Material.Neon, at(side * 1.1, 8.5, -1.25))
    end
    for _, side in ipairs({ -0.85, 0.85 }) do
        part("Leg", Vector3.new(1.3, 3, 1.4), dark, nil, at(side * 1, 1.5, 0))
    end
    part("ArmL", Vector3.new(1.1, 3, 1.1), dark, nil,
        at(-2.2, 6.5, 0) * CFrame.Angles(-0.2, 0, 0) * CFrame.new(0, -1.5 * s, 0))
    local armR = part("ArmR", Vector3.new(1.1, 3, 1.1), dark, nil,
        at(2.2, 6.5, 0) * CFrame.Angles(-1.1, 0, 0) * CFrame.new(0, -1.5 * s, 0))

    local hand = armR.CFrame * CFrame.new(0, -1.4 * s, -1.4 * s)
    part("PickHandle", Vector3.new(0.4, 0.4, 3.4), Color3.fromRGB(110, 80, 50), Enum.Material.Wood, hand)
    part("PickHead", Vector3.new(2.8, 0.5, 0.5), Color3.fromRGB(190, 190, 200), Enum.Material.Metal,
        hand * CFrame.new(0, 0, -1.6 * s))

    model.PrimaryPart = torso
    return model
end

return GolemModel
