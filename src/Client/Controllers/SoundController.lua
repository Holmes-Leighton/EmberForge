-- Plays the sounds listed in AudioData: UI clicks, game events, the Sky Tower and Hollow Maze, plus looping music and ambience that cross-fade by scene
-- (Hub, Tower, Maze). A sound with no asset id yet (see AudioData.Resolve) is skipped without any error.

local Players      = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local AudioData    = require(game.ReplicatedStorage.Shared.Data.AudioData)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)

local SoundController = {}

local MIN_GAP      = 0.04     -- the same sound is not started twice within this many seconds (a run of clicks or pops must not stack into a buzz)
local FADE_SECONDS = 1.5
local LOG_SIZE     = 64

-- The looping sounds each scene plays; anything not listed is faded out.
SoundController.Scenes = {
    Hub   = { "Music", "AmbientForge" },
    Tower = { "MusicTower" },
    Maze  = { "MusicMaze" },
}

local loops = {}        -- name -> Sound (looped sounds, made once)
local lastPlayed = {}   -- name -> os.clock()
local scene = nil
SoundController.Log = {}   -- the most recent plays { name, pitch, volume }, for tests

local function Record(name, pitch, volume)
    local log = SoundController.Log
    log[#log + 1] = { name = name, pitch = pitch, volume = volume }
    if #log > LOG_SIZE then table.remove(log, 1) end
end

local function Make(name, parent)
    local def = AudioData.Sounds[name]
    local id = AudioData.Resolve(name)
    if not def or not id then return nil end
    local s = Instance.new("Sound")
    s.Name = name
    s.SoundId = id
    s.Volume = def.volume or 0.5
    s.Looped = def.looped or false
    s.Parent = parent or SoundService
    return s
end

-- One-shot sound. opts: pitch (playback speed), volume (a multiplier), at (a BasePart: the sound comes from there and fades with distance)
function SoundController.Play(name, opts)
    opts = opts or {}
    local def = AudioData.Sounds[name]
    if not def then return nil end
    if def.looped then
        -- (kept for old callers: a looping sound started by name just starts its loop)
        local s = loops[name] or Make(name)
        if s then
            loops[name] = s
            if not s.IsPlaying then s:Play() end
        end
        return s
    end
    local now = os.clock()
    if lastPlayed[name] and now - lastPlayed[name] < MIN_GAP and not opts.at then return nil end
    lastPlayed[name] = now
    local pitch, volume = opts.pitch or def.pitch or 1, (def.volume or 0.5) * (opts.volume or 1)
    Record(name, pitch, volume)
    local s = Make(name, opts.at)
    if not s then return nil end
    s.Volume = volume
    s.PlaybackSpeed = pitch
    if opts.at then
        s.RollOffMode = Enum.RollOffMode.InverseTapered
        s.RollOffMinDistance = opts.minDistance or 12
        s.RollOffMaxDistance = opts.maxDistance or 90
    end
    s:Play()
    task.delay(8, function() s:Destroy() end)
    return s
end

-- Fade the looping music and ambience to a scene's set ("Hub", "Tower" or "Maze").
function SoundController.SetScene(name)
    if name == scene then return end
    scene = name
    local want = {}
    for _, n in ipairs(SoundController.Scenes[name] or {}) do want[n] = true end
    for n, def in pairs(AudioData.Sounds) do
        if def.looped then
            local s = loops[n]
            if want[n] then
                if not s then s = Make(n); loops[n] = s end
                if s then
                    s.Volume = s.IsPlaying and s.Volume or 0
                    if not s.IsPlaying then s:Play() end
                    TweenService:Create(s, TweenInfo.new(FADE_SECONDS), { Volume = def.volume or 0.2 }):Play()
                end
            elseif s and s.IsPlaying then
                TweenService:Create(s, TweenInfo.new(FADE_SECONDS), { Volume = 0 }):Play()
                task.delay(FADE_SECONDS + 0.1, function() if scene ~= name then s:Stop() end end)
            end
        end
    end
end

function SoundController.Scene() return scene end
function SoundController.ResetThrottle() lastPlayed = {} end      -- (for the tests, which fire events microseconds apart)

function SoundController.Init()
    SoundController.SetScene("Hub")

    -- every button click in the player's GUI
    local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
    local function Hook(inst)
        if inst:IsA("GuiButton") then
            inst.MouseButton1Click:Connect(function() SoundController.Play("Click") end)
        end
    end
    for _, d in ipairs(pg:GetDescendants()) do Hook(d) end
    pg.DescendantAdded:Connect(Hook)

    -- game events
    RemoteEvents.GolemCrafted.OnClientEvent:Connect(function(golem)
        if golem then SoundController.Play((golem.tier or 1) >= 3 and "CraftRare" or "Craft") else SoundController.Play("Error") end
    end)
    RemoteEvents.GolemDeployed.OnClientEvent:Connect(function(ok) SoundController.Play(ok and "Deploy" or "Error") end)
    RemoteEvents.ResourcesCollected.OnClientEvent:Connect(function(_, elapsed)
        if elapsed == -1 then SoundController.Play("Collect") end
    end)
    RemoteEvents.LevelUp.OnClientEvent:Connect(function() SoundController.Play("LevelUp") end)
    RemoteEvents.AchievementUnlocked.OnClientEvent:Connect(function() SoundController.Play("Achievement") end)
    RemoteEvents.SmeltCompleted.OnClientEvent:Connect(function() SoundController.Play("Smelt") end)
    RemoteEvents.TradeCompleted.OnClientEvent:Connect(function() SoundController.Play("TradeDone") end)
    RemoteEvents.GolemNeoned.OnClientEvent:Connect(function(ok) SoundController.Play(ok and "Neon" or "Error") end)
    RemoteEvents.Notify.OnClientEvent:Connect(function() SoundController.Play("Notify") end)
end

return SoundController
