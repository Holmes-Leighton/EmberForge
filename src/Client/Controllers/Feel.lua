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

-- After a respawn on a course (Sky Tower, Courier Run): face the way the course runs. `dir` is +1 (east) or -1 (west); `at` is the exact respawn point if the server sent it.
-- Three things can turn you the wrong way, so all three are set, now and again just after the teleport lands: the camera (it stays pointing wherever it was, often back at the fall,
-- and a player still holding "forward" is turned to match it), the character itself, and any spin it carried. A camera some other script is driving is left alone.
function Feel.FaceCourse(dir, at)
    local cam = workspace.CurrentCamera
    local d = (dir or 1) >= 0 and 1 or -1
    local function apply()
        local char = Players.LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local pos = at or (root and root.Position)
        if cam and pos and cam.CameraType == Enum.CameraType.Custom then
            cam.CFrame = CFrame.lookAt(pos + Vector3.new(-d * 14, 7, 0), pos + Vector3.new(d * 10, 2, 0))
        end
        if root and at and (root.Position - at).Magnitude < 8 then              -- (only once it has actually arrived at the respawn point)
            root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(d, 0, 0))
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end
    apply()
    task.delay(0.12, apply)
    task.delay(0.4, apply)
end

return Feel
