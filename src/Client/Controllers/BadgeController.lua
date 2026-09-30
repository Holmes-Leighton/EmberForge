-- Red notification badges on the sidebar buttons: how many things are waiting for the player.
--   Inventory  uncollected resources mined by Golems
--   Forge      Golems that could be deployed (free slots) + broken Golems + Neon fusions ready
--   Challenges completed challenges whose reward hasn't been claimed
--   Season     season rewards that can be claimed right now
--   Style      cosmetics/titles you haven't looked at yet
-- Everything is worked out from the server's data, so the badges can't drift from the truth.

local Players = game:GetService("Players")

local ChallengeData = require(game.ReplicatedStorage.Shared.Data.ChallengeData)
local SeasonData    = require(game.ReplicatedStorage.Shared.Data.SeasonData)
local GolemData     = require(game.ReplicatedStorage.Shared.Data.GolemData)
local Utils         = require(game.ReplicatedStorage.Shared.Modules.Utils)

local BadgeController = {}

local lastData
local lastPending = {}
local locallySeen = {}      -- keys of cosmetics the player opened the Style menu for (until the server confirms)

-- ── Counting ──────────────────────────────────────────────────────────────────
local function ClaimableChallenges(data)
    local n = 0
    local function scan(map, defs)
        for _, def in ipairs(defs) do
            local entry = map and map[def.id]
            if entry and not entry.claimed and (entry.progress or 0) >= def.target then n += 1 end
        end
    end
    scan(data.DailyChallenges, ChallengeData.Daily)
    scan(data.WeeklyChallenges, ChallengeData.Weekly)
    return n
end

local TRACKS = {
    { key = "freeTrackRewards", name = "free", tier = 0 },
    { key = "standardTrackRewards", name = "standard", tier = 1 },
    { key = "premiumTrackRewards", name = "premium", tier = 2 },
}

local function ClaimableSeasonRewards(data)
    local status = data.SeasonStatus
    local season = SeasonData.GetCurrentSeason()
    if not status or not season then return 0 end
    local n = 0
    local passTier = data.SeasonPassTier or 0
    for _, track in ipairs(TRACKS) do
        if passTier >= track.tier then
            for _, entry in ipairs(season[track.key] or {}) do
                if entry.week <= (status.currentWeek or 1)
                    and not (status.claimedWeeks and status.claimedWeeks[track.name .. "_" .. entry.week]) then
                    n += 1
                end
            end
        end
    end
    return n
end

local function ForgeAttention(data)
    local deployed, idle, broken = 0, 0, 0
    local groups = {}
    for _, g in ipairs(data.Golems or {}) do
        if g.deployed then
            deployed += 1
            if g._durabilitySeconds ~= nil and g._durabilitySeconds <= 0 then broken += 1 end
        else
            idle += 1
            if g.variant ~= "MegaNeon" then
                local key = g.element .. "|" .. g.tier .. "|" .. (g.variant or "")
                groups[key] = (groups[key] or 0) + 1
            end
        end
    end
    local freeSlots = math.max(0, (data.EffectiveGolemSlots or data.GolemSlots or 3) - deployed)
    local ready = math.min(idle, freeSlots)                 -- Golems you could put to work right now
    local fusions = 0
    for _, count in pairs(groups) do
        if count >= GolemData.NEON_FUSION_COUNT then fusions += 1 end
    end
    return ready + broken + fusions
end

local function UnseenCosmetics(data)
    local seen = {}
    for _, k in ipairs(data.SeenCosmetics or {}) do seen[k] = true end
    for k in pairs(locallySeen) do seen[k] = true end
    local n = 0
    for _, id in ipairs(data.OwnedCosmetics or {}) do if not seen[id] then n += 1 end end
    for _, t in ipairs(data.Titles or {}) do if not seen["T:" .. t] then n += 1 end end
    return n
end

function BadgeController.Compute(data, pending)
    local pendingTotal = 0
    for _, qty in pairs(pending or {}) do
        if type(qty) == "number" and qty > 0 then pendingTotal += qty end
    end
    return {
        InventoryButton  = { count = pendingTotal, text = pendingTotal > 0 and Utils.FormatNumber(pendingTotal) or nil },
        ForgeButton      = { count = data and ForgeAttention(data) or 0 },
        ChallengesButton = { count = data and ClaimableChallenges(data) or 0 },
        SeasonButton     = { count = data and ClaimableSeasonRewards(data) or 0 },
        StyleButton      = { count = data and UnseenCosmetics(data) or 0 },
    }
end

-- ── Showing ───────────────────────────────────────────────────────────────────
local function Apply()
    local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
    local hud = pg and pg:FindFirstChild("HUD")
    if not hud then return end
    local counts = BadgeController.Compute(lastData, lastPending)
    pcall(function()
        require(script.Parent.GuideController).Show(counts, lastData ~= nil and #(lastData.Golems or {}) > 0)
    end)
    for name, info in pairs(counts) do
        local button = hud:FindFirstChild(name, true)
        local badge = button and button:FindFirstChild("Badge")
        if badge then
            badge.Visible = info.count > 0
            badge.Text = info.text or tostring(math.min(info.count, 99))
        end
    end
end

function BadgeController.Update(data)
    lastData = data
    Apply()
end

function BadgeController.SetPending(pending)
    lastPending = pending or {}
    Apply()
end

-- Opening the Style menu counts everything in it as seen (the server is told separately)
function BadgeController.Init()
    task.spawn(function()
        local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
        local style = pg:WaitForChild("StyleMenu", 15)
        if not style then return end
        style:GetPropertyChangedSignal("Enabled"):Connect(function()
            if style.Enabled and lastData then
                for _, id in ipairs(lastData.OwnedCosmetics or {}) do locallySeen[id] = true end
                for _, t in ipairs(lastData.Titles or {}) do locallySeen["T:" .. t] = true end
                Apply()
            end
        end)
    end)
end

return BadgeController
