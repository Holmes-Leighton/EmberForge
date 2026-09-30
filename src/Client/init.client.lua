-- Client entry point. Loads all controllers and fetches initial player data.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Wait for remotes to be ready
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
RemoteEvents.Load()

-- Load controllers
local HUDController          = require(script.Controllers.HUDController)
local ForgeController        = require(script.Controllers.ForgeController)
local InventoryController    = require(script.Controllers.InventoryController)
local ShopController         = require(script.Controllers.ShopController)
local ChallengesController   = require(script.Controllers.ChallengesController)
local LeaderboardController  = require(script.Controllers.LeaderboardController)
local ForgeZoneController    = require(script.Controllers.ForgeZoneController)
local TutorialController     = require(script.Controllers.TutorialController)
local GolemAnimator          = require(script.Controllers.GolemAnimator)
local SoundController        = require(script.Controllers.SoundController)
local BadgeController        = require(script.Controllers.BadgeController)
local OfferController        = require(script.Controllers.OfferController)
local PetController          = require(script.Controllers.PetController)

-- Fetch initial data from server
-- The server may still be loading our save when we arrive: keep asking for a while
local playerData
for attempt = 1, 30 do
    local ok, result = pcall(function() return RemoteEvents.GetPlayerData:InvokeServer() end)
    if ok and result then
        playerData = result
        break
    end
    task.wait(1)
end
if not playerData then
    warn("[Client] Failed to get player data on init")
    return
end

-- Boot controllers with initial data
HUDController.Init(playerData)
ForgeController.Init(playerData)
InventoryController.Init(playerData)
ShopController.Init(playerData)
ChallengesController.Init(playerData)
LeaderboardController.Init(playerData)
ForgeZoneController.Init(playerData)
TutorialController.Init(playerData)
GolemAnimator.Init()
SoundController.Init()
BadgeController.Init()
OfferController.Init()
PetController.Init()

-- ── Global event listeners ────────────────────────────────────────────────────

RemoteEvents.ResourcesCollected.OnClientEvent:Connect(function(gains, elapsed)
    InventoryController.OnResourcesCollected(gains)
    ForgeController.OnResourcesCollected(gains)
    HUDController.OnResourceUpdate(gains)

end)

RemoteEvents.PendingUpdate.OnClientEvent:Connect(function(pending)
    HUDController.SetPending(pending)
    InventoryController.OnPendingUpdate(pending)
end)

RemoteEvents.Notify.OnClientEvent:Connect(function(title, message)
    HUDController.ShowNotification(tostring(title), tostring(message))
end)

RemoteEvents.GolemCrafted.OnClientEvent:Connect(function(golem, newLevel)
    if golem then
        ForgeController.OnGolemCrafted(golem)
        InventoryController.OnGolemAdded(golem)
        HUDController.ShowNotification("Golem Crafted!", tostring(golem.element) .. " Golem (Tier " .. tostring(golem.tier) .. ")")
        if newLevel then
            HUDController.ShowLevelUp(newLevel)
        end
    else
        HUDController.ShowNotification("Can't forge yet", tostring(newLevel or "Not enough materials"))
    end
end)

RemoteEvents.GolemDeployed.OnClientEvent:Connect(function(ok, golemId, zoneId, err)
    ForgeController.OnGolemDeployed(ok, golemId, zoneId, err)
    if ok then
        HUDController.ShowNotification("Golem Deployed", "Mining in " .. zoneId)
    else
        HUDController.ShowNotification("Can't deploy", tostring(err))
    end
end)

RemoteEvents.GolemReturned.OnClientEvent:Connect(function(result, golemId, err)
    ForgeController.OnGolemReturned(result, golemId, err)
    if result then
        HUDController.ShowNotification("Golem Returned", "Resources collected!")
    end
end)

RemoteEvents.SmeltQueued.OnClientEvent:Connect(function(job, err)
    ForgeController.OnSmeltQueued(job, err)
end)

RemoteEvents.SmeltCompleted.OnClientEvent:Connect(function(job)
    ForgeController.OnSmeltCompleted(job)
    HUDController.ShowNotification("Smelt Complete!", job.outputId .. " x" .. job.outputQty)
end)

RemoteEvents.LevelUp.OnClientEvent:Connect(function(newLevel)
    HUDController.ShowLevelUp(newLevel)
end)

RemoteEvents.ForgeUpgraded.OnClientEvent:Connect(function(newForgeLevel)
    ForgeController.OnForgeUpgraded(newForgeLevel)
    local ForgeDataC = require(game.ReplicatedStorage.Shared.Data.ForgeData)
    local fdC = ForgeDataC.Get(newForgeLevel)
    local perkText = ForgeDataC.PerkText(ForgeDataC.PerkAt(newForgeLevel))
    HUDController.ShowNotification("Forge Level " .. newForgeLevel .. ": " .. (fdC and fdC.displayName or ""),
        perkText ~= "" and ("New boost: " .. perkText) or "Your forge grows.")
end)

RemoteEvents.TradeClosed.OnClientEvent:Connect(function(tradeId, reason)
    if reason and reason ~= "" then
        HUDController.ShowNotification("Trade closed", tostring(reason))
    end
end)

RemoteEvents.TradeCompleted.OnClientEvent:Connect(function(result)
    HUDController.ShowNotification("Trade Complete!", "Items exchanged successfully.")
    InventoryController.Resync()
    ForgeController.Resync()
end)

RemoteEvents.MasteryLevelUp.OnClientEvent:Connect(function(element, level)
    HUDController.ShowNotification("Mastery up!", tostring(element) .. " Mastery is now level " .. tostring(level))
end)

RemoteEvents.StorageVaultCrafted.OnClientEvent:Connect(function(ok, err)
    HUDController.ShowNotification(ok and "Storage Vault built" or "Can't build Storage Vault",
        ok and "Offline storage is now 8 hours." or tostring(err))
    ForgeController.Resync()
end)

RemoteEvents.GolemRepaired.OnClientEvent:Connect(function(ok, golemId, err)
    HUDController.ShowNotification(ok and "Golem repaired" or "Can't repair", ok and "Good as new." or tostring(err))
    ForgeController.Resync()
    InventoryController.Resync()
end)

RemoteEvents.GolemNeoned.OnClientEvent:Connect(function(ok)
    ForgeController.Resync()
    InventoryController.Resync()
    HUDController.QueueResync()
end)

RemoteEvents.PurchaseResult.OnClientEvent:Connect(function(ok, payload, err)
    ShopController.OnResult(ok, payload, err)
end)

RemoteEvents.ChallengeCompleted.OnClientEvent:Connect(function(challengeId)
    HUDController.ShowNotification("Challenge Complete!", challengeId)
    ChallengesController.OnChallengeCompleted(challengeId)
end)

RemoteEvents.AchievementUnlocked.OnClientEvent:Connect(function(achievementId)
    HUDController.ShowAchievement(achievementId)
end)

RemoteEvents.GolemFused.OnClientEvent:Connect(function(ok, golem1Id, err)
    ForgeController.OnGolemFused(ok, golem1Id, err)
    if ok then
        HUDController.ShowNotification("Golems Fused!", "Fusion bonus applied.")
    else
        HUDController.ShowNotification("Fusion Failed", tostring(err))
    end
end)

RemoteEvents.ChallengeRewardClaimed.OnClientEvent:Connect(function(ok, challengeId, result)
    ChallengesController.OnChallengeRewardClaimed(ok, challengeId, result)
end)

RemoteEvents.DailyReward.OnClientEvent:Connect(function(amount)
    HUDController.ShowNotification("Daily Reward!", "+" .. tostring(amount) .. " Ember Coins  ⚡")
    HUDController.OnResourceUpdate({})   -- refresh coin display
end)

RemoteEvents.ForgeZoneEntered.OnClientEvent:Connect(function(ownerUserId, ownerName, forgeData)
    ForgeZoneController.OnZoneEntered(ownerUserId, ownerName, forgeData)
end)

RemoteEvents.ForgeZoneLeft.OnClientEvent:Connect(function()
    ForgeZoneController.OnZoneLeft()
end)

-- Anything that changes slots, durability, smelting or levels refreshes the HUD from the server
for _, name in ipairs({ "GolemCrafted", "GolemDeployed", "GolemReturned", "GolemFused", "GolemRepaired", "SmeltQueued",
    "SmeltCompleted", "ForgeUpgraded", "LevelUp", "TradeCompleted", "PurchaseResult", "StorageVaultCrafted",
    "DailyReward", "ChallengeRewardClaimed", "ChallengeCompleted", "AchievementUnlocked" }) do
    RemoteEvents[name].OnClientEvent:Connect(function() HUDController.QueueResync() end)
end

print("[EmberForge Client] Initialised for " .. LocalPlayer.Name)
