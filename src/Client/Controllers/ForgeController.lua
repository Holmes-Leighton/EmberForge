-- Manages the Forge UI: smelt queue display, golem crafting, and deployment panels.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local RemoteEvents  = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local GolemData     = require(game.ReplicatedStorage.Shared.Data.GolemData)
local RecipeData    = require(game.ReplicatedStorage.Shared.Data.RecipeData)
local ForgeData     = require(game.ReplicatedStorage.Shared.Data.ForgeData)
local Utils         = require(game.ReplicatedStorage.Shared.Modules.Utils)

local ForgeController = {}

local forgeGui
local smeltQueueDisplay = {}  -- jobId → frame reference
local activeSmeltJobs   = {}  -- local mirror of smelt jobs for countdown

-- ── Init ──────────────────────────────────────────────────────────────────────
function ForgeController.Init(playerData)
    ForgeController._data = playerData

    task.spawn(function()
        forgeGui = PlayerGui:WaitForChild("ForgeMenu", 10)
        if not forgeGui then return end

        ForgeController._BuildBlueprintList()
        ForgeController._BuildSmeltPanel()
        ForgeController._BuildDeployPanel()
        ForgeController._StartSmeltCountdowns()
        ForgeController._WireFuseButton()
    end)
end

-- ── Blueprint / Crafting Panel ────────────────────────────────────────────────
function ForgeController._BuildBlueprintList()
    if not forgeGui then return end
    local scrollFrame = forgeGui:FindFirstChild("BlueprintScroll", true)
    if not scrollFrame then return end

    -- Clear existing
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local data = ForgeController._data
    local yOffset = 0

    for _, bpId in ipairs(data.Blueprints or {}) do
        local bp = RecipeData.Get(bpId)
        if not bp then continue end

        local card = ForgeController._CreateBlueprintCard(bp, data, yOffset)
        card.Parent = scrollFrame
        yOffset = yOffset + 120
    end

    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 10)
end

function ForgeController._CreateBlueprintCard(bp, data, yOffset)
    local card = Instance.new("Frame")
    card.Name = bp.id
    card.Size = UDim2.new(1, -10, 0, 110)
    card.Position = UDim2.new(0, 5, 0, yOffset + 5)
    card.BackgroundColor3 = Color3.fromRGB(40, 35, 30)
    card.BorderSizePixel = 0

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = card

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.7, 0, 0, 28)
    title.Position = UDim2.new(0, 8, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = (bp.element or "?") .. " — Tier " .. bp.tier
    title.TextColor3 = Color3.fromRGB(255, 200, 80)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    -- Requirements list
    local reqText = ""
    for i, req in ipairs(bp.materialsRequired or {}) do
        local have = (data.Inventory or {})[req.id] or 0
        local colour = have >= req.qty and "✓" or "✗"
        reqText = reqText .. colour .. " " .. req.id .. " x" .. req.qty
        if i < #bp.materialsRequired then reqText = reqText .. "\n" end
    end
    local reqs = Instance.new("TextLabel")
    reqs.Size = UDim2.new(1, -8, 0, 60)
    reqs.Position = UDim2.new(0, 8, 0, 32)
    reqs.BackgroundTransparency = 1
    reqs.Text = reqText
    reqs.TextColor3 = Color3.fromRGB(180, 180, 180)
    reqs.Font = Enum.Font.Code
    reqs.TextSize = 11
    reqs.TextXAlignment = Enum.TextXAlignment.Left
    reqs.TextYAlignment = Enum.TextYAlignment.Top
    reqs.TextWrapped = true
    reqs.Parent = card

    -- Craft button
    local craftBtn = Instance.new("TextButton")
    craftBtn.Size = UDim2.new(0, 90, 0, 28)
    craftBtn.Position = UDim2.new(1, -98, 0, 38)
    craftBtn.BackgroundColor3 = Color3.fromRGB(200, 120, 40)
    craftBtn.Text = "Craft"
    craftBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    craftBtn.Font = Enum.Font.GothamBold
    craftBtn.TextSize = 14
    craftBtn.BorderSizePixel = 0
    craftBtn.Parent = card

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = craftBtn

    craftBtn.MouseButton1Click:Connect(function()
        RemoteEvents.CraftGolem:FireServer(bp.id, "default")
        craftBtn.Text = "..."
        craftBtn.BackgroundColor3 = Color3.fromRGB(100, 80, 40)
        task.wait(1)
        craftBtn.Text = "Craft"
        craftBtn.BackgroundColor3 = Color3.fromRGB(200, 120, 40)
    end)

    return card
end

function ForgeController._WireFuseButton()
    if not forgeGui then return end
    local btn = forgeGui:FindFirstChild("FuseGolemsButton", true)
    if btn then
        btn.MouseButton1Click:Connect(function()
            ForgeController._OpenGolemFuseDialog()
        end)
    end
end

-- ── Smelt Panel ───────────────────────────────────────────────────────────────
function ForgeController._BuildSmeltPanel()
    if not forgeGui then return end
    local smeltPanel = forgeGui:FindFirstChild("SmeltPanel", true)
    if not smeltPanel then return end
    -- UI pre-built in Studio — we wire up the smelt button
    local smeltBtn = smeltPanel:FindFirstChild("SmeltButton", true)
    if smeltBtn then
        smeltBtn.MouseButton1Click:Connect(function()
            ForgeController._OpenSmeltDialog()
        end)
    end
end

function ForgeController._OpenSmeltDialog()
    local data = ForgeController._data
    if not data then return end
    local pg     = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local dialog = pg:FindFirstChild("SmeltDialog")
    if not dialog then return end
    local openFn = dialog:FindFirstChild("Open")
    if openFn then
        openFn:Invoke(data.Inventory or {})
    end
end

-- ── Smelt countdown timer ─────────────────────────────────────────────────────
function ForgeController._StartSmeltCountdowns()
    task.spawn(function()
        while true do
            task.wait(1)
            local now = Utils.UnixTimestamp()
            for jobId, jobFrame in pairs(smeltQueueDisplay) do
                local job = activeSmeltJobs[jobId]
                if job then
                    local remaining = math.max(0, job.endTime - now)
                    local timeLbl = jobFrame:FindFirstChild("TimeLabel")
                    if timeLbl then
                        timeLbl.Text = remaining > 0 and Utils.FormatTime(remaining) or "Done!"
                    end
                end
            end
        end
    end)
end

-- ── Deployment Panel ──────────────────────────────────────────────────────────
function ForgeController._BuildDeployPanel()
    if not forgeGui then return end
    -- Zone selection and golem deployment UI scaffold
    local deployPanel = forgeGui:FindFirstChild("DeployPanel", true)
    if not deployPanel then return end

    -- Populate zone buttons from unlocked zones
    local MiningZoneData = require(game.ReplicatedStorage.Shared.Data.MiningZoneData)
    local unlocked = MiningZoneData.GetUnlocked(ForgeController._data)

    for i, zoneId in ipairs(unlocked) do
        local zone = MiningZoneData.Get(zoneId)
        local btn  = Instance.new("TextButton")
        btn.Name   = zoneId
        btn.Size   = UDim2.new(0, 160, 0, 50)
        btn.Position = UDim2.new(0, (i - 1) * 170 + 5, 0, 5)
        btn.BackgroundColor3 = Color3.fromRGB(50, 90, 50)
        btn.Text   = zone and zone.displayName or zoneId
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font   = Enum.Font.Gotham
        btn.TextSize = 13
        btn.BorderSizePixel = 0
        btn.Parent = deployPanel

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 5)
        corner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            -- Show golem selection for deployment
            ForgeController._OpenGolemSelectForDeploy(zoneId)
        end)
    end
end

function ForgeController._OpenGolemSelectForDeploy(zoneId)
    local data = ForgeController._data
    if not data or #(data.Golems or {}) == 0 then return end

    local pg     = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local dialog = pg:FindFirstChild("GolemPickerDialog")
    if not dialog then return end
    local openFn = dialog:FindFirstChild("Open")
    if not openFn then return end

    -- BindableEvent receives the chosen golem id
    local callbackEvent = Instance.new("BindableEvent")
    callbackEvent.Event:Connect(function(golemId)
        RemoteEvents.DeployGolem:FireServer(golemId, zoneId)
        callbackEvent:Destroy()
    end)

    openFn:Invoke(data.Golems, "deploy", callbackEvent)
end

function ForgeController._OpenGolemFuseDialog()
    local data = ForgeController._data
    if not data or #(data.Golems or {}) < 2 then return end

    local pg     = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local dialog = pg:FindFirstChild("GolemPickerDialog")
    if not dialog then return end
    local openFn = dialog:FindFirstChild("Open")
    if not openFn then return end

    -- First pick: the base golem
    local callbackBase = Instance.new("BindableEvent")
    callbackBase.Event:Connect(function(baseId)
        callbackBase:Destroy()
        -- Second pick: the sacrifice
        local callbackSac = Instance.new("BindableEvent")
        callbackSac.Event:Connect(function(sacId)
            callbackSac:Destroy()
            if baseId ~= sacId then
                RemoteEvents.FuseGolems:FireServer(baseId, sacId)
            end
        end)
        openFn:Invoke(data.Golems, "fuse", callbackSac)
    end)
    openFn:Invoke(data.Golems, "fuse", callbackBase)
end

-- ── Server response handlers ──────────────────────────────────────────────────
function ForgeController.OnGolemCrafted(golem)
    -- Re-render blueprint list to update material counts
    if ForgeController._data then
        ForgeController._BuildBlueprintList()
    end
end

function ForgeController.OnGolemDeployed(ok, golemId, zoneId, err)
    if ok and ForgeController._data then
        for _, g in ipairs(ForgeController._data.Golems or {}) do
            if g.id == golemId then
                g.deployed = true
                g.zoneId   = zoneId
                break
            end
        end
    end
end

function ForgeController.OnGolemReturned(result, golemId, err)
    if result and ForgeController._data then
        for _, g in ipairs(ForgeController._data.Golems or {}) do
            if g.id == golemId then
                g.deployed = false
                g.zoneId   = nil
                break
            end
        end
    end
end

local function _AddSmeltJobCard(job)
    if not forgeGui then return end
    local scroll = forgeGui:FindFirstChild("SmeltQueueScroll", true)
    if not scroll then return end

    local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)

    local card = Instance.new("Frame")
    card.Name             = job.id
    card.Size             = UDim2.new(1, -8, 0, 60)
    card.BackgroundColor3 = Theme.Colors.Panel
    card.BorderSizePixel  = 0
    card.Parent           = scroll
    Theme.AddCorner(card, Theme.Corner.Small)

    -- Material name
    local nameLbl = Theme.Label(card,
        (job.materialId or "?") .. "  →  " .. (job.outputId or "?"),
        Theme.TextSize.Body, Theme.Colors.TextPrimary, Theme.Fonts.Heading)
    nameLbl.Size     = UDim2.new(0.65, 0, 0, 22)
    nameLbl.Position = UDim2.new(0, 10, 0, 6)
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    -- Quantity badge
    local qtyLbl = Theme.Label(card, "×" .. (job.quantity or 1),
        Theme.TextSize.Small, Theme.Colors.Gold)
    qtyLbl.Size     = UDim2.new(0.2, 0, 0, 18)
    qtyLbl.Position = UDim2.new(0, 10, 0, 30)
    qtyLbl.TextXAlignment = Enum.TextXAlignment.Left

    -- Countdown
    local timeLabel = Theme.Label(card, "...", Theme.TextSize.Small,
        Theme.Colors.Accent, Theme.Fonts.Mono, "TimeLabel")
    timeLabel.Size     = UDim2.new(0.3, 0, 0, 22)
    timeLabel.Position = UDim2.new(1, -10, 0.5, -11)
    timeLabel.TextXAlignment = Enum.TextXAlignment.Right

    smeltQueueDisplay[job.id] = card
end

function ForgeController.OnSmeltQueued(job, err)
    if job then
        activeSmeltJobs[job.id] = job
        _AddSmeltJobCard(job)
    end
end

function ForgeController.OnSmeltCompleted(job)
    local card = smeltQueueDisplay[job.id]
    if card then card:Destroy() end
    activeSmeltJobs[job.id] = nil
    smeltQueueDisplay[job.id] = nil
end

function ForgeController.OnGolemFused(ok, golem1Id, err)
    if ok and ForgeController._data then
        -- Refresh lists after fusion (one golem removed, survivor boosted)
        ForgeController._BuildBlueprintList()
    end
end

function ForgeController.OnForgeUpgraded(newLevel)
    local fd = ForgeData.Get(newLevel)
    print("[ForgeController] Forge upgraded to level " .. newLevel ..
        (fd and ": " .. fd.displayName or ""))
    -- Re-render if UI visible
end

return ForgeController
