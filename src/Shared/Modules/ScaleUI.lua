-- Keeps fixed-size windows usable on small screens (phones, small Studio windows).
local ScaleUI = {}

local function Viewport()
    local cam = workspace.CurrentCamera
    return cam, (cam and cam.ViewportSize or Vector2.new(1280, 720))
end

-- Centre `frame` and shrink it (never enlarge) so a w x h window fits with a margin.
function ScaleUI.Apply(frame, w, h, margin)
    margin = margin or 24
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)

    local scale = Instance.new("UIScale")
    scale.Parent = frame
    local function update()
        local _, vp = Viewport()
        scale.Scale = math.clamp(math.min((vp.X - margin) / w, (vp.Y - margin) / h), 0.4, 1)
    end
    update()
    local cam = Viewport()
    if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(update) end
    return scale
end

-- Shrinks always-visible HUD panels on short screens (landscape phones).
function ScaleUI.ApplyHud(frame, referenceHeight)
    referenceHeight = referenceHeight or 720
    local scale = Instance.new("UIScale")
    scale.Parent = frame
    local function update()
        local _, vp = Viewport()
        scale.Scale = math.clamp(vp.Y / referenceHeight, 0.6, 1)
    end
    update()
    local cam = Viewport()
    if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(update) end
    return scale
end

return ScaleUI
