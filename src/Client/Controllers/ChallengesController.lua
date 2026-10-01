-- Populates the ChallengesMenu with live challenge data and wires claim buttons.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local RemoteEvents    = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local ChallengeData   = require(game.ReplicatedStorage.Shared.Data.ChallengeData)
local Utils           = require(game.ReplicatedStorage.Shared.Modules.Utils)

local ChallengesController = {}

local challengesGui
local playerData

-- Seconds until midnight UTC (approximate daily reset)
local function SecondsUntilDailyReset()
    local now = os.time()
    if playerData and (playerData.LastDailyReset or 0) > 0 then
        return math.max(0, playerData.LastDailyReset + 86400 - now)   -- the server resets 24h after the last reset
    end
    return math.ceil(now / 86400) * 86400 - now
end

-- Seconds until next Monday midnight UTC (weekly reset)
local function SecondsUntilWeeklyReset()
    local now      = os.time()
    if playerData and (playerData.LastWeeklyReset or 0) > 0 then
        return math.max(0, playerData.LastWeeklyReset + 604800 - now)
    end
    local dayOfWeek = tonumber(os.date("*t", now).wday)  -- 1=Sun … 7=Sat
    local daysUntilMonday = (9 - dayOfWeek) % 7
    if daysUntilMonday == 0 then daysUntilMonday = 7 end
    return daysUntilMonday * 86400 - (now % 86400)
end

-- ── Init ──────────────────────────────────────────────────────────────────────
function ChallengesController.Init(data)
    playerData = data

    task.spawn(function()
        challengesGui = PlayerGui:WaitForChild("ChallengesMenu", 10)
        if not challengesGui then return end

        -- Wait until the GUI script has finished building
        if not challengesGui:GetAttribute("ready") then
            challengesGui:GetAttributeChangedSignal("ready"):Wait()
        end

        ChallengesController.Refresh()
        ChallengesController._StartResetCountdowns()

        -- The progress shown must be the server's, not the snapshot taken at login: re-read it every time the menu opens
        challengesGui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if challengesGui.Enabled then ChallengesController.SyncFromServer() end
        end)
    end)
end

-- Pulls the player's current challenge progress from the server, updating the shared data table in place
-- (other controllers hold the same table) and redrawing the cards.
function ChallengesController.SyncFromServer()
    if not playerData then return end
    local ok, fresh = pcall(function() return RemoteEvents.GetPlayerData:InvokeServer() end)
    if not ok or type(fresh) ~= "table" then return end
    for _, key in ipairs({ "DailyChallenges", "WeeklyChallenges", "Achievements", "ClaimedAchievements", "_achievementProgress",
        "LastDailyReset", "LastWeeklyReset" }) do
        playerData[key] = fresh[key]
    end
    ChallengesController.Refresh()
end

-- ── Populate challenge cards ───────────────────────────────────────────────────
function ChallengesController.Refresh()
    if not challengesGui or not playerData then return end

    local buildFn      = challengesGui:FindFirstChild("BuildChallengeCard")
    local dailyScrollV = challengesGui:FindFirstChild("DailyScroll")
    local weeklyScrollV= challengesGui:FindFirstChild("WeeklyScroll")
    local lifetimeScrollV = challengesGui:FindFirstChild("LifetimeScroll")

    if not buildFn or not dailyScrollV then return end

    local dailyScroll    = dailyScrollV.Value
    local weeklyScroll   = weeklyScrollV.Value
    local lifetimeScroll = lifetimeScrollV.Value

    -- Clear previous cards
    for _, scroll in ipairs({ dailyScroll, weeklyScroll, lifetimeScroll }) do
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
    end

    -- ── Daily ────────────────────────────────────────────────────────────────
    local order = 0
    for challengeId, entry in pairs(playerData.DailyChallenges or {}) do
        local def = ChallengeData.Get(challengeId)
        if def then
            order = order + 1
            local card, claimBtn = buildFn:Invoke(dailyScroll, def, entry.progress or 0, entry.claimed, order)
            if claimBtn then
                claimBtn.MouseButton1Click:Connect(function()
                    ChallengesController._Claim(challengeId, claimBtn)
                end)
            end
        end
    end

    if order == 0 then
        ChallengesController._AddEmptyState(dailyScroll, "No daily challenges active.\nCheck back after midnight.")
    end

    -- ── Weekly ───────────────────────────────────────────────────────────────
    order = 0
    for challengeId, entry in pairs(playerData.WeeklyChallenges or {}) do
        local def = ChallengeData.Get(challengeId)
        if def then
            order = order + 1
            local card, claimBtn = buildFn:Invoke(weeklyScroll, def, entry.progress or 0, entry.claimed, order)
            if claimBtn then
                claimBtn.MouseButton1Click:Connect(function()
                    ChallengesController._Claim(challengeId, claimBtn)
                end)
            end
        end
    end

    if order == 0 then
        ChallengesController._AddEmptyState(weeklyScroll, "No weekly challenges active.\nCheck back after Monday midnight.")
    end

    -- ── Lifetime ─────────────────────────────────────────────────────────────
    order = 0
    local achSet = {}
    for _, id in ipairs(playerData.Achievements or {}) do achSet[id] = true end
    local achProgress = playerData._achievementProgress or {}

    -- Sort: incomplete first, then completed
    local sorted = {}
    for _, ach in ipairs(ChallengeData.Lifetime) do
        table.insert(sorted, ach)
    end
    table.sort(sorted, function(a, b)
        local aComp = achSet[a.id] and 1 or 0
        local bComp = achSet[b.id] and 1 or 0
        return aComp < bComp
    end)

    for _, def in ipairs(sorted) do
        order = order + 1
        local prog    = achSet[def.id] and def.target or (achProgress[def.id] or 0)
        local claimed = achSet[def.id]  -- lifetime achievements auto-claim on unlock
        local card, claimBtn = buildFn:Invoke(lifetimeScroll, def, prog, claimed, order)
        -- No claim button for lifetime (auto-awarded)
        if claimBtn then claimBtn.Visible = false end
    end
end

-- ── Claim handler ─────────────────────────────────────────────────────────────
function ChallengesController._Claim(challengeId, btn)
    btn.Active = false
    btn.Text = "..."
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

    -- Fire server via a RemoteEvent (ChallengeService.ClaimReward)
    -- We reuse PurchaseResult as the generic response channel here
    -- (In a larger build this would have its own RemoteEvent)
    local def = ChallengeData.Get(challengeId)
    if not def then return end

    -- Optimistic update of local data
    local challengeType = def.type
    local map
    if challengeType == ChallengeData.Type.Daily then
        map = playerData.DailyChallenges
    elseif challengeType == ChallengeData.Type.Weekly then
        map = playerData.WeeklyChallenges
    end

    if map and map[challengeId] then
        map[challengeId].claimed = true
    end

    -- Apply local reward mirrors
    local rewards = def.rewards or {}
    if rewards.coins then
        playerData.EmberCoins = (playerData.EmberCoins or 0) + rewards.coins
    end
    if rewards.materials then
        for _, m in ipairs(rewards.materials) do
            playerData.Inventory[m.id] = (playerData.Inventory[m.id] or 0) + m.qty
        end
    end

    -- Notify server (server re-validates and applies authoritative reward)
    RemoteEvents.ClaimChallengeReward:FireServer(challengeId)

    -- Update button
    btn.Text = "Claimed"
    btn.BackgroundColor3 = Color3.fromRGB(60, 80, 60)
end

-- ── Reset countdown tickers ────────────────────────────────────────────────────
function ChallengesController._StartResetCountdowns()
    task.spawn(function()
        while challengesGui and challengesGui.Parent do
            task.wait(1)
            local dailyLbl  = challengesGui:FindFirstChild("DailyResetLabel", true)
            local weeklyLbl = challengesGui:FindFirstChild("WeeklyResetLabel", true)
            if dailyLbl  then dailyLbl.Text  = "Daily reset: "  .. Utils.FormatTime(SecondsUntilDailyReset())  end
            if weeklyLbl then weeklyLbl.Text = "Weekly reset: " .. Utils.FormatTime(SecondsUntilWeeklyReset()) end
        end
    end)
end

-- ── Server event — challenge completed ────────────────────────────────────────
function ChallengesController.OnChallengeCompleted(challengeId)
    -- Update progress in local data and re-render if menu is open
    local def = ChallengeData.Get(challengeId)
    if not def then return end

    if def.type == ChallengeData.Type.Daily and playerData.DailyChallenges[challengeId] then
        playerData.DailyChallenges[challengeId].progress = def.target
    elseif def.type == ChallengeData.Type.Weekly and playerData.WeeklyChallenges[challengeId] then
        playerData.WeeklyChallenges[challengeId].progress = def.target
    end

    if challengesGui and challengesGui.Enabled then
        ChallengesController.Refresh()
    end
end

-- ── Server confirmation of reward claim ──────────────────────────────────────
function ChallengesController.OnChallengeRewardClaimed(ok, challengeId, result)
    if not ok then
        warn("[ChallengesController] Claim rejected by server:", challengeId, result)
        -- Re-render to correct any optimistic UI state
        if challengesGui and challengesGui.Enabled then
            ChallengesController.Refresh()
        end
    end
end

-- ── Empty state helper ────────────────────────────────────────────────────────
function ChallengesController._AddEmptyState(scroll, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -16, 0, 60)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(100, 92, 84)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.TextWrapped = true
    lbl.Parent = scroll
end

return ChallengesController
