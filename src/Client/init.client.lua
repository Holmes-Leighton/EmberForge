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
local TradingController      = require(script.Controllers.TradingController)
local ShopController         = require(script.Controllers.ShopController)
local ChallengesController   = require(script.Controllers.ChallengesController)
local LeaderboardController  = require(script.Controllers.LeaderboardController)
local ForgeZoneController    = require(script.Controllers.ForgeZoneController)
local TutorialController     = require(script.Controllers.TutorialController)

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
TradingController.Init(playerData)
ShopController.Init(playerData)
ChallengesController.Init(playerData)
LeaderboardController.Init(playerData)
ForgeZoneController.Init(playerData)
TutorialController.Init(playerData)

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
    HUDController.ShowNotification("Forge Upgraded!", "Now Level " .. newForgeLevel)
end)

RemoteEvents.TradeOffer.OnClientEvent:Connect(function(tradeId, err)
    TradingController.OnTradeOffer(tradeId, err)
end)

RemoteEvents.TradeCompleted.OnClientEvent:Connect(function(result)
    TradingController.OnTradeCompleted(result)
    HUDController.ShowNotification("Trade Complete!", "Items exchanged successfully.")
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

print("[EmberForge Client] Initialised for " .. LocalPlayer.Name)
