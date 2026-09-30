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
        forgeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if forgeGui.Enabled then ForgeController.Resync() end
        end)
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
        local colour = have >= req.qty and "[OK]" or "[NEED]"
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

-- ── Live data / refresh ───────────────────────────────────────────────────────
-- The server is the source of truth: after any change, pull a fresh copy and redraw.
function ForgeController.Refresh()
    if not forgeGui or not ForgeController._data then return end
    ForgeController._BuildBlueprintList()
    ForgeController._BuildDeployPanel()
end

function ForgeController.Resync()
    task.spawn(function()
        local fresh = RemoteEvents.GetPlayerData:InvokeServer()
        if fresh then
            ForgeController._data = fresh
            ForgeController.Refresh()
        end
    end)
end

-- Materials arrive from pads/golems: keep the ✓/✗ counts honest while the menu is open
function ForgeController.OnResourcesCollected(gains)
    local data = ForgeController._data
    if not data then return end
    data.Inventory = data.Inventory or {}
    for matId, qty in pairs(gains or {}) do
        if type(qty) == "number" and matId:sub(1, 12) ~= "__blueprint:" then
            data.Inventory[matId] = (data.Inventory[matId] or 0) + qty
        end
    end
    if forgeGui and forgeGui.Enabled then ForgeController._BuildBlueprintList() end
end

-- ── Deployment Panel ──────────────────────────────────────────────────────────
function ForgeController._BuildDeployPanel()
    if not forgeGui then return end
    local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)
    local MiningZoneData = require(game.ReplicatedStorage.Shared.Data.MiningZoneData)
    local data = ForgeController._data

    -- Zone buttons (only unlocked zones)
    local strip = forgeGui:FindFirstChild("ZoneStrip", true)
    if strip then
        for _, child in ipairs(strip:GetChildren()) do
            if child:IsA("GuiButton") or child:IsA("TextLabel") then child:Destroy() end
        end
        local unlocked = MiningZoneData.GetUnlocked(data)
        table.sort(unlocked)
        if not (ForgeController._selectedZone and Utils.TableContains(unlocked, ForgeController._selectedZone)) then
            ForgeController._selectedZone = unlocked[1]
        end
        if #unlocked == 0 then
            local lbl = Theme.Label(strip, "Forge a Golem to unlock a mining zone.", Theme.TextSize.Body,
                Theme.Colors.TextSecondary, Theme.Fonts.Body)
            lbl.Size = UDim2.new(0, 360, 1, 0)
        end
        for _, zoneId in ipairs(unlocked) do
            local zone = MiningZoneData.Get(zoneId)
            local selected = zoneId == ForgeController._selectedZone
            local btn = Theme.Button(strip, (selected and "> " or "") .. (zone and zone.displayName or zoneId),
                selected and Theme.Colors.Success or Theme.Colors.PanelAlt,
                selected and Color3.fromRGB(255, 255, 255) or Theme.Colors.AccentBright, zoneId)
            btn.Size = UDim2.new(0, 170, 0, 56)
            btn.TextSize = 14
            btn.MouseButton1Click:Connect(function()
                ForgeController._selectedZone = zoneId
                ForgeController._BuildDeployPanel()
            end)
        end
    end

    -- Golem list
    local scroll = forgeGui:FindFirstChild("GolemDeployScroll", true)
    if not scroll then return end
    if not scroll:FindFirstChildOfClass("UIListLayout") then
        Theme.AddListLayout(scroll, Enum.FillDirection.Vertical, 6)
    end
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
    end

    local golems = data and data.Golems or {}
    if #golems == 0 then
        local empty = Theme.Label(scroll, "No Golems yet. Forge one at the Golem Anvil near spawn.",
            Theme.TextSize.Body, Theme.Colors.TextSecondary, Theme.Fonts.Body)
        empty.Size = UDim2.new(1, -8, 0, 40)
        return
    end

    for _, g in ipairs(golems) do
        local card = Instance.new("Frame")
        card.Name = g.id
        card.Size = UDim2.new(1, -8, 0, 54)
        card.BackgroundColor3 = Theme.Colors.Panel
        card.BorderSizePixel = 0
        card.Parent = scroll
        Theme.AddCorner(card, Theme.Corner.Small)

        local color = Theme.Colors[g.element] or Theme.Colors.TextPrimary
        local title = Theme.Label(card, string.format("%s Golem  •  Tier %d", tostring(g.element), g.tier or 1),
            Theme.TextSize.Body, color, Theme.Fonts.Heading)
        title.Size = UDim2.new(0.6, 0, 0, 22)
        title.Position = UDim2.new(0, 10, 0, 6)

        local zone = g.zoneId and MiningZoneData.Get(g.zoneId)
        local status = Theme.Label(card,
            g.deployed and ("⚡ Mining in " .. (zone and zone.displayName or tostring(g.zoneId))) or "💤 Idle",
            Theme.TextSize.Small, g.deployed and Theme.Colors.Success or Theme.Colors.TextSecondary)
        status.Size = UDim2.new(0.6, 0, 0, 18)
        status.Position = UDim2.new(0, 10, 0, 30)

        if not g.deployed then
            local zoneId = ForgeController._selectedZone
            local zoneData = zoneId and MiningZoneData.Get(zoneId)
            local deploy = Theme.Button(card,
                zoneId and "Deploy ▶" or "No zone",
                zoneId and Theme.Colors.Accent or Theme.Colors.PanelAlt, Color3.fromRGB(255, 255, 255))
            deploy.Size = UDim2.new(0, 96, 0, 30)
            deploy.Position = UDim2.new(1, -106, 0.5, -15)
            if zoneId then
                status.Text = "💤 Idle  →  " .. (zoneData and zoneData.displayName or zoneId)
                deploy.MouseButton1Click:Connect(function()
                    RemoteEvents.DeployGolem:FireServer(g.id, zoneId)
                end)
            end
        else
            local recall = Theme.Button(card, "Recall", Theme.Colors.PanelAlt, Theme.Colors.AccentBright)
            recall.Size = UDim2.new(0, 84, 0, 30)
            recall.Position = UDim2.new(1, -94, 0.5, -15)
            recall.MouseButton1Click:Connect(function()
                RemoteEvents.ReturnGolem:FireServer(g.id)
            end)
        end
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
    ForgeController.Resync()
end

function ForgeController.OnGolemDeployed(ok, golemId, zoneId, err)
    ForgeController.Resync()
end

function ForgeController.OnGolemReturned(result, golemId, err)
    ForgeController.Resync()
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
    if ok then ForgeController.Resync() end
end

function ForgeController.OnForgeUpgraded(newLevel)
    local fd = ForgeData.Get(newLevel)
    print("[ForgeController] Forge upgraded to level " .. newLevel ..
        (fd and ": " .. fd.displayName or ""))
    -- Re-render if UI visible
end

return ForgeController
