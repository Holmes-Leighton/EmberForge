-- Client-side handler for forge zone enter / exit events.
-- Shows/hides the ForgeVisitOverlay and manages the "visiting" state.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local ForgeZoneController = {}

local overlay         -- ForgeVisitOverlay ScreenGui, found lazily
local playerData

local function GetOverlay()
    if not overlay or not overlay.Parent then
        overlay = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("ForgeVisitOverlay")
    end
    return overlay
end

function ForgeZoneController.Init(data)
    playerData = data
end

function ForgeZoneController.OnZoneEntered(ownerUserId, ownerName, forgeData)
    local gui = GetOverlay()
    if not gui then return end

    -- Populate the overlay
    local fn = gui:FindFirstChild("Show")
    if fn then
        fn:Invoke(ownerName, forgeData)
    end
    gui.Enabled = true
end

function ForgeZoneController.OnZoneLeft()
    local gui = GetOverlay()
    if not gui then return end
    gui.Enabled = false
end

return ForgeZoneController
