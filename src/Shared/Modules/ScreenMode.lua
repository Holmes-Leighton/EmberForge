-- One answer to "is this a phone-sized screen?", so every HUD piece makes the same call. Compact = a touch-only device or a short window.
-- Compact screens get slimmer HUD pieces that leave the view clear.
local UserInputService = game:GetService("UserInputService")

local ScreenMode = {}

function ScreenMode.Compact()
    local cam = workspace.CurrentCamera
    local short = cam and cam.ViewportSize.Y < 520
    local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    return (short or touchOnly) and true or false
end

-- Calls fn(compact) now and again whenever the window size changes
function ScreenMode.Watch(fn)
    fn(ScreenMode.Compact())
    local cam = workspace.CurrentCamera
    if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() fn(ScreenMode.Compact()) end) end
end

return ScreenMode
