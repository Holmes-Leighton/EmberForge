-- Keeps fixed-size windows usable on small screens (phones, small Studio windows).
local ScaleUI = {}

local function Viewport()
    local cam = workspace.CurrentCamera
    return cam, (cam and cam.ViewportSize or Vector2.new(1280, 720))
end

-- ── Readable text on small screens ────────────────────────────────────────────
-- A window designed for 1280x720 and scaled down to fit a phone makes its text tiny (14 px at scale 0.6 is 8 px). So text inside a
-- scaled window may grow, up to the size that would make it READABLE_PX on screen, but it is fitted to its own box (TextScaled) and never
-- smaller than the size it was designed at, so it cannot overflow any more than it did before. Labels that size themselves
-- (AutomaticSize) are left alone, as TextScaled would collapse them.
local READABLE_PX = 11
local SCALE_OFF   = 0.85            -- at or above this scale the designed sizes are readable already

local function IsText(obj)
    return obj:IsA("TextLabel") or obj:IsA("TextButton")
end

local function Refresh(obj, scaleValue)
    local base = obj:GetAttribute("EFBaseTextSize")
    if not base then return end
    local wanted = scaleValue < SCALE_OFF and math.min(100, math.ceil(READABLE_PX / math.max(scaleValue, 0.1))) or base
    local constraint = obj:FindFirstChild("EFTextBoost")
    if wanted > base then
        if not constraint then
            constraint = Instance.new("UITextSizeConstraint")
            constraint.Name = "EFTextBoost"
            constraint.Parent = obj
        end
        constraint.MinTextSize = base
        constraint.MaxTextSize = wanted
        obj.TextScaled = true
    else
        if constraint then constraint:Destroy() end
        obj.TextScaled = false
        obj.TextSize = base
    end
end

local function Track(root, scale)
    local tracked = setmetatable({}, { __mode = "k" })      -- rows that get destroyed drop out by themselves
    local function consider(obj)
        if tracked[obj] or not IsText(obj) or obj:GetAttribute("EFNoBoost") then return end
        local auto = obj.AutomaticSize
        if auto ~= nil and auto ~= Enum.AutomaticSize.None then return end
        if obj.TextScaled then return end                      -- already fits itself
        tracked[obj] = true
        obj:SetAttribute("EFBaseTextSize", obj.TextSize)
        Refresh(obj, scale.Scale)
    end
    for _, d in ipairs(root:GetDescendants()) do consider(d) end
    root.DescendantAdded:Connect(function(d) task.defer(consider, d) end)
    scale:GetPropertyChangedSignal("Scale"):Connect(function()
        for obj in pairs(tracked) do
            if obj.Parent then Refresh(obj, scale.Scale) else tracked[obj] = nil end
        end
    end)
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
        local margin = vp.Y < 600 and math.min(margin, 8) or margin     -- every pixel counts on a phone: bigger window, bigger text
        -- the ScreenGui starts below Roblox's top bar, so that strip isn't available to the window
        local okInset, inset = pcall(function() return game:GetService("GuiService"):GetGuiInset() end)
        local topBar = okInset and inset and inset.Y or 0
        scale.Scale = math.clamp(math.min((vp.X - margin) / w, (vp.Y - topBar - margin) / h), 0.35, 1)
    end
    update()
    local cam = Viewport()
    if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(update) end
    Track(frame, scale)
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
    Track(frame, scale)
    return scale
end

return ScaleUI
