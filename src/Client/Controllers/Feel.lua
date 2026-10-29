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

-- Where the hub spawn is, and which way you face leaving a portal back to it (toward the Golem Anvil and the mining pads, where the game starts)
Feel.HOME = Vector3.new(0, 6, -60)
Feel.HOME_DIR = { 0, -1 }

-- Face the direction (dx, dz): after a respawn on a course, or stepping out of a portal. Three things can turn you the wrong way, so all three are set, now and again just
-- after the teleport lands: the camera (it stays pointing wherever it was, and a player still holding "forward" is turned to match it), the character itself, and any spin it
-- carried. `at` is the exact arrival point if the server sent it. With `onlyThere` nothing is touched until the character is actually standing at `at` (used for "back home",
-- where the player may have gone somewhere else entirely). A camera some other script is driving is left alone.
function Feel.FaceDirection(dx, dz, at, onlyThere)
    local m = math.sqrt(dx * dx + dz * dz)
    if m < 1e-6 then return end
    dx, dz = dx / m, dz / m
    local cam = workspace.CurrentCamera
    local function apply()
        local char = Players.LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local there = root and at and (root.Position - at).Magnitude < 8
        if onlyThere and not there then return end
        local pos = at or (root and root.Position)
        if cam and pos and cam.CameraType == Enum.CameraType.Custom then
            cam.CFrame = CFrame.lookAt(pos + Vector3.new(-dx * 14, 7, -dz * 14), pos + Vector3.new(dx * 10, 2, dz * 10))
        end
        if there then                                                          -- (only once it has actually arrived)
            root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(dx, 0, dz))
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end
    apply()
    task.delay(0.12, apply)
    task.delay(0.4, apply)
end

-- A course that runs east (+1) or west (-1): the Sky Tower's levels and the Courier Run
function Feel.FaceCourse(dir, at)
    Feel.FaceDirection((dir or 1) >= 0 and 1 or -1, 0, at)
end

-- Stepped out of a portal into the hub: face the way the game starts
function Feel.FaceHome()
    Feel.FaceDirection(Feel.HOME_DIR[1], Feel.HOME_DIR[2], Feel.HOME, true)
end

return Feel
