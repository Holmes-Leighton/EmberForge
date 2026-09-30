-- Plays the sounds listed in AudioData for UI clicks and game events. Silent until real asset ids
-- are added there; safe to run without any.

local Players      = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local AudioData    = require(game.ReplicatedStorage.Shared.Data.AudioData)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)

local SoundController = {}

local cache = {}   -- name -> Sound

local function GetSound(name)
    local def = AudioData.Sounds[name]
    if not def or def.id == 0 then return nil end
    if cache[name] and cache[name].Parent then return cache[name] end
    local s = Instance.new("Sound")
    s.Name = name
    s.SoundId = "rbxassetid://" .. def.id
    s.Volume = def.volume or 0.5
    s.Looped = def.looped or false
    s.Parent = SoundService
    cache[name] = s
    return s
end

function SoundController.Play(name)
    local s = GetSound(name)
    if s then
        if s.Looped then
            if not s.IsPlaying then s:Play() end
        else
            s:Play()
        end
    end
end

function SoundController.Init()
    -- ambience
    SoundController.Play("AmbientForge")
    SoundController.Play("Music")

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
