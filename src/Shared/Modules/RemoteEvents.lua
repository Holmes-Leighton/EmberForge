-- Centralised RemoteEvent / RemoteFunction references.
-- Both server and client require this module to get typed handles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "EmberForgeRemotes"

local RemoteEvents = {}

-- Event definitions: name → "event" or "function"
local DEFINITIONS = {
    -- Resource collection
    CollectResources    = "event",
    ResourcesCollected  = "event",   -- server → client confirmation

    -- Smelting
    StartSmelt          = "event",
    UseSpeedUp          = "event",   -- client → server (jobId)
    SmeltQueued         = "event",   -- server → client
    SmeltCompleted      = "event",   -- server → client

    -- Crafting
    PendingUpdate       = "event",   -- server → client (pending mined resources per type)
    Notify              = "event",   -- server → client (title, message)
    CraftGolem          = "event",
    GolemCrafted        = "event",   -- server → client

    -- Deployment
    DeployGolem         = "event",
    GolemDeployed       = "event",   -- server → client
    ReturnGolem         = "event",
    GolemReturned       = "event",   -- server → client

    -- Trading
    InitiateTrade       = "event",
    TradeRequest        = "event",   -- server → client (someone wants to trade: fromName, fromUserId, info)
    RespondTradeRequest = "event",   -- client → server (accept: boolean)
    TradeOffer          = "event",   -- server → client (a trade window opened: tradeId, err)
    AddTradeItem        = "event",   -- client → server (tradeId, item)
    RemoveTradeItem     = "event",   -- client → server (tradeId, index)
    TradeUpdated        = "event",   -- server → client (full view of the trade)
    TradeClosed         = "event",   -- server → client (tradeId, reason)
    AcceptTrade         = "event",   -- confirm my side
    DeclineTrade        = "event",   -- cancel the trade
    TradeCompleted      = "event",   -- server → client
    GetTradeHistory     = "function",
    BuyFromSupplier     = "event",   -- client → server (itemId, quantity)
    GetSupplierStock    = "function",
    MarkCosmeticsSeen   = "event",   -- client → server: opened the Style menu
    ListOnMarket        = "event",
    BuyFromMarket       = "event",
    CancelListing       = "event",
    GetMyListings       = "function",

    -- Purchases
    PurchaseItem        = "event",
    PurchaseResult      = "event",   -- server → client

    -- Forge crafting (non-golem)
    CraftStorageVault   = "event",
    StorageVaultCrafted = "event",   -- server → client
    RepairGolem         = "event",
    GolemRepaired       = "event",   -- server → client

    -- Golem fusion
    FuseGolems          = "event",
    GolemFused          = "event",   -- server → client

    NeonFuse            = "event",   -- client → server (element, tier, variant)
    GolemNeoned         = "event",   -- server → client (ok, golem or reason)

    -- Style & access
    EquipCosmetic       = "event",   -- client → server (slot, id or nil)
    SetForgeAccess      = "event",   -- client → server (friendsOnly: boolean)
    GoToMyForge         = "event",   -- client → server
    ShopOffer           = "event",   -- server → client: (kind, key, reason) a contextual purchase offer

    -- Pets
    HatchPet            = "event",   -- client → server (eggId)
    PetHatched          = "event",   -- server → client (ok, pet or reason)
    EquipPet            = "event",   -- client → server (petId, on)
    ReleasePet          = "event",   -- client → server (petId)
    MergePets           = "event",   -- client → server (petType, variant or nil): 4 identical -> 1 rarer
    PetsMerged          = "event",   -- server → client (ok, pet or reason)

    -- Guilds
    CreateGuild         = "event",   -- client → server (name)
    JoinGuild           = "event",   -- client → server (name)
    LeaveGuild          = "event",
    ClaimGuildReward    = "event",
    ClaimGuildPrize     = "event",   -- last week's battle prize
    InviteToGuild       = "event",   -- client → server (player name)
    RespondGuildInvite  = "event",   -- client → server (accept: boolean)
    GuildInvite         = "event",   -- server → client (guildName, fromName)
    SendGuildChat       = "event",   -- client → server (text)
    GetGuildChat        = "function", -- → list of { name, userId, text, t }
    GoToGuildHall       = "event",
    ManageGuild         = "event",   -- client → server (action: "kick" | "promote", userId) - leader only
    GuildResult         = "event",   -- server → client (action, ok, message)
    GetGuildInfo        = "function", -- → { mine = snapshot or nil, top = {...} }

    -- Rewards: login streak, codes, ranked ladder
    RedeemCode          = "event",   -- client → server (code)
    ClaimLadderPrize    = "event",
    RewardsResult       = "event",   -- server → client (action, ok, message)
    GetLadderInfo       = "function", -- → LadderService.GetInfo
    GetStreakInfo       = "function", -- → { count, best, lastDay, today }

    TeleportToGolem     = "event",   -- client → server (golemId): stand next to one of your deployed Golems

    -- Forge Builder
    BuildAction         = "event",   -- client → server (action: "buy" | "place" | "pickup" | "sell", id or index)
    BuildResult         = "event",   -- server → client (action, ok, message)
    GetBuildInfo        = "function", -- → ForgeBuildService.Snapshot

    -- Season Pass
    ClaimSeasonReward   = "event",

    -- Challenge reward claiming
    ClaimChallengeReward   = "event",
    ChallengeRewardClaimed = "event",  -- server → client

    -- UI data sync (RemoteFunctions — client requests, server responds)
    GetPlayerData       = "function",
    GetMarketListings   = "function",
    GetLeaderboard      = "function",

    -- Player progression events (server → client)
    LevelUp             = "event",
    MasteryLevelUp      = "event",
    ForgeUpgraded       = "event",
    ChallengeCompleted  = "event",
    AchievementUnlocked = "event",

    -- Challenge tracking
    UpdateChallengeProgress = "event",  -- server → client UI update

    -- Daily login reward
    DailyReward             = "event",  -- server → client (amount)

    -- Forge zone visiting (world-based, like Adopt Me / Grow a Garden)
    ForgeZoneEntered        = "event",  -- server → client (ownerUserId, ownerName, forgeData)
    ForgeZoneLeft           = "event",  -- server → client
    GetForgeZoneData        = "function",  -- client requests snapshot of a player's forge
}

-- On server: create all remotes in a folder
function RemoteEvents.CreateOnServer()
    local folder = Instance.new("Folder")
    folder.Name = FOLDER_NAME
    folder.Parent = ReplicatedStorage

    for name, remoteType in pairs(DEFINITIONS) do
        local remote
        if remoteType == "event" then
            remote = Instance.new("RemoteEvent")
        else
            remote = Instance.new("RemoteFunction")
        end
        remote.Name = name
        remote.Parent = folder
        RemoteEvents[name] = remote
    end

    return folder
end

-- On client (or server after creation): bind references
function RemoteEvents.Load()
    local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30)
    if not folder then
        error("[RemoteEvents] Remote folder not found within timeout")
    end

    for name, remoteType in pairs(DEFINITIONS) do
        local remote = folder:WaitForChild(name, 10)
        if not remote then
            warn("[RemoteEvents] Missing remote: " .. name)
        else
            RemoteEvents[name] = remote
        end
    end
end

return RemoteEvents
