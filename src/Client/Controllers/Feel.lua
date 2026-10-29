-- Small helpers the challenge controllers (Sky Tower, Hollow Maze) share for how the game feels: play a sound, change the music scene, set the lighting mood and shake the camera.
-- Each is optional: if the sound or look controller is missing nothing breaks.
local Players = game:GetService("Players")

local Feel = {}

local function Safe(name)
    local ok, mod = pcall(require, script.Parent[name])
    return ok and mod or nil
end

function Feel.Snd(name, opts)
    local S = Safe("SoundController")
    if S and S.Play then return S.Play(name, opts) end
end

function Feel.Scene(name)
    local S = Safe("SoundController")
    if S and S.SetScene then S.SetScene(name) end
end

function Feel.Mood(name)
    local L = Safe("LookController")
    if L and L.SetMood then L.SetMood(name) end
end

-- A short camera shake: the humanoid's camera offset jitters and settles
function Feel.Shake(strength, seconds)
    local char = Players.LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    task.spawn(function()
        local steps = math.max(1, math.floor((seconds or 0.4) / 0.03))
        for i = 1, steps do
            local f = (1 - i / steps) * (strength or 1)
            hum.CameraOffset = Vector3.new((math.random() - 0.5) * f, (math.random() - 0.5) * f, 0)
            task.wait(0.03)
        end
        hum.CameraOffset = Vector3.new(0, 0, 0)
    end)
end

return Feel
