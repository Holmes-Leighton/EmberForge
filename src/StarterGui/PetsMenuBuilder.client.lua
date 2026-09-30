-- Pets menu: hatch eggs with Ember Coins, choose which pets follow you (they give small boosts).

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Theme        = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI      = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local PetModel     = require(game.ReplicatedStorage.Shared.Modules.PetModel)
local PetData      = require(game.ReplicatedStorage.Shared.Data.PetData)
local Utils        = require(game.ReplicatedStorage.Shared.Modules.Utils)

RemoteEvents.Load()

local W, H = 760, 540
local tab = "Pets"
local data

-- ── Window ────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "PetsMenu"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 11
gui.Enabled = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local scrim = Instance.new("Frame")
scrim.Size = UDim2.new(1, 0, 1, 0)
scrim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
scrim.BackgroundTransparency = 0.5
scrim.BorderSizePixel = 0
scrim.Parent = gui

local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(0, W, 0, H)
container.BackgroundColor3 = Theme.Colors.Background
container.BorderSizePixel = 0
container.Parent = gui
Theme.AddCorner(container, Theme.Corner.Large)
ScaleUI.Apply(container, W, H)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Theme.Colors.Panel
titleBar.BorderSizePixel = 0
titleBar.Parent = container
Theme.AddCorner(titleBar, Theme.Corner.Large)
local tfill = Instance.new("Frame")
tfill.Size = UDim2.new(1, 0, 0, 12)
tfill.Position = UDim2.new(0, 0, 1, -12)
tfill.BackgroundColor3 = Theme.Colors.Panel
tfill.BorderSizePixel = 0
tfill.Parent = titleBar
local title = Theme.Label(titleBar, "Pets", Theme.TextSize.Title, Theme.Colors.AccentBright, Theme.Fonts.Title, "Title")
title.Position = UDim2.new(0, 16, 0, 0)
title.Size = UDim2.new(0.5, 0, 1, 0)
local coinsLbl = Theme.Label(titleBar, "", Theme.TextSize.Heading, Theme.Colors.Gold, Theme.Fonts.Heading, "Coins")
coinsLbl.AnchorPoint = Vector2.new(1, 0)
coinsLbl.Position = UDim2.new(1, -60, 0, 0)
coinsLbl.Size = UDim2.new(0.35, 0, 1, 0)
coinsLbl.TextXAlignment = Enum.TextXAlignment.Right
local closeBtn = Theme.Button(titleBar, "X", Theme.Colors.Danger, Color3.fromRGB(255, 255, 255), "CloseButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 7)
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

local tabCol = Instance.new("Frame")
tabCol.Position = UDim2.new(0, 8, 0, 58)
tabCol.Size = UDim2.new(0, 150, 1, -66)
tabCol.BackgroundColor3 = Theme.Colors.Panel
tabCol.BorderSizePixel = 0
tabCol.Parent = container
Theme.AddCorner(tabCol, Theme.Corner.Medium)
Theme.AddPadding(tabCol, 8, 8, 8, 8)
Theme.AddListLayout(tabCol, Enum.FillDirection.Vertical, 6)
local tabButtons = {}
for _, t in ipairs({ { "Pets", "My Pets" }, { "Eggs", "Eggs" } }) do
    local b = Theme.Button(tabCol, t[2], Theme.Colors.PanelAlt, Theme.Colors.TextSecondary, t[1] .. "Tab")
    b.Size = UDim2.new(1, 0, 0, 38)
    b.TextSize = 14
    tabButtons[t[1]] = b
end

local content = Theme.ScrollFrame(container, "Content")
content.Position = UDim2.new(0, 166, 0, 58)
content.Size = UDim2.new(1, -174, 1, -66)
Theme.AddListLayout(content, Enum.FillDirection.Vertical, 6)

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function Clear()
    for _, c in ipairs(content:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
end

local function Note(text, height)
    local l = Theme.Label(content, text, Theme.TextSize.Body, Theme.Colors.TextSecondary, Theme.Fonts.Body)
    l.Size = UDim2.new(1, -8, 0, height or 40)
    l.TextYAlignment = Enum.TextYAlignment.Top
    l.TextWrapped = true
    return l
end

local function Row(name, sub, color, buttonText, buttonColor, onClick, enabled, height, nameColor, glow, extra)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, height or 58)
    row.BackgroundColor3 = Theme.Colors.Panel
    row.BorderSizePixel = 0
    row.Parent = content
    Theme.AddCorner(row, Theme.Corner.Small)
    if glow then                                   -- Rare and above get a glowing border in their rarity colour
        local stroke = Instance.new("UIStroke")
        stroke.Color = color
        stroke.Thickness = glow
        stroke.Transparency = 0.25
        stroke.Parent = row
    end

    local swatch = Instance.new("Frame")
    swatch.Size = UDim2.new(0, 6, 1, -14)
    swatch.Position = UDim2.new(0, 6, 0, 7)
    swatch.BackgroundColor3 = color
    swatch.BorderSizePixel = 0
    swatch.Parent = row
    Theme.AddCorner(swatch, UDim.new(0, 3))

    local n = Theme.Label(row, name, Theme.TextSize.Heading, nameColor or Theme.Colors.TextPrimary, Theme.Fonts.Heading)
    n.Position = UDim2.new(0, 22, 0, 6)
    n.Size = UDim2.new(1, extra and -270 or -150, 0, 22)
    local s = Theme.Label(row, sub, Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Body)
    s.Position = UDim2.new(0, 22, 0, 30)
    s.Size = UDim2.new(1, extra and -270 or -150, 0, (height or 58) - 34)
    s.TextWrapped = true
    s.TextYAlignment = Enum.TextYAlignment.Top

    if buttonText then
        local b = Theme.Button(row, buttonText, buttonColor, Color3.fromRGB(255, 255, 255))
        b.AnchorPoint = Vector2.new(1, 0.5)
        b.Position = UDim2.new(1, -10, 0.5, 0)
        b.Size = UDim2.new(0, 110, 0, 34)
        b.TextSize = 13
        b.AutoButtonColor = enabled ~= false
        b.MouseButton1Click:Connect(function()
            if enabled ~= false and onClick then onClick() end
        end)
    end
    if extra then                                   -- a second button to the left (e.g. Merge)
        local b2 = Theme.Button(row, extra.text, extra.color, Color3.fromRGB(255, 255, 255))
        b2.AnchorPoint = Vector2.new(1, 0.5)
        b2.Position = UDim2.new(1, -130, 0.5, 0)
        b2.Size = UDim2.new(0, 110, 0, 34)
        b2.TextSize = 13
        b2.MouseButton1Click:Connect(function() if extra.onClick then extra.onClick() end end)
    end
    return row
end

local RARITY_ORDER = { Legendary = 1, Epic = 2, Rare = 3, Uncommon = 4, Common = 5 }

-- a short message strip along the bottom (e.g. "You need 150 coins")
local statusLbl = Theme.Label(container, "", Theme.TextSize.Body, Theme.Colors.Danger, Theme.Fonts.Heading, "Status")
statusLbl.AnchorPoint = Vector2.new(0.5, 1)
statusLbl.Position = UDim2.new(0.5, 80, 1, -8)
statusLbl.Size = UDim2.new(1, -200, 0, 24)
statusLbl.Visible = false
statusLbl.ZIndex = 5

-- ── Hatch reveal: a spinning 3D preview of the new pet ───────────────────────
local reveal = Instance.new("Frame")
reveal.Name = "Reveal"
reveal.Size = UDim2.new(0, 360, 0, 360)
reveal.AnchorPoint = Vector2.new(0.5, 0.5)
reveal.Position = UDim2.new(0.5, 0, 0.5, 0)
reveal.BackgroundColor3 = Theme.Colors.Panel
reveal.BorderSizePixel = 0
reveal.Visible = false
reveal.ZIndex = 20
reveal.Parent = gui
Theme.AddCorner(reveal, Theme.Corner.Large)
ScaleUI.Apply(reveal, 360, 360)

local viewport = Instance.new("ViewportFrame")
viewport.Size = UDim2.new(1, -20, 0, 220)
viewport.Position = UDim2.new(0, 10, 0, 10)
viewport.BackgroundColor3 = Theme.Colors.PanelAlt
viewport.BorderSizePixel = 0
viewport.LightColor = Color3.fromRGB(255, 240, 220)
viewport.Ambient = Color3.fromRGB(150, 140, 130)
viewport.ZIndex = 21
viewport.Parent = reveal
Theme.AddCorner(viewport, Theme.Corner.Medium)
local vpCam = Instance.new("Camera")
viewport.CurrentCamera = vpCam
vpCam.Parent = viewport

local revealStroke = Instance.new("UIStroke")             -- the pop-up's border takes the pet's rarity colour
revealStroke.Thickness = 4
revealStroke.Parent = reveal
local revealBanner = Theme.Label(reveal, "", Theme.TextSize.Heading, Theme.Colors.Gold, Theme.Fonts.Title)
revealBanner.Position = UDim2.new(0, 20, 0, 16)
revealBanner.Size = UDim2.new(1, -40, 0, 26)
revealBanner.ZIndex = 22
local revealName = Theme.Label(reveal, "", Theme.TextSize.Title, Theme.Colors.AccentBright, Theme.Fonts.Title)
revealName.Position = UDim2.new(0, 10, 0, 236)
revealName.Size = UDim2.new(1, -20, 0, 30)
revealName.ZIndex = 21
local revealSub = Theme.Label(reveal, "", Theme.TextSize.Body, Theme.Colors.TextSecondary, Theme.Fonts.Body)
revealSub.Position = UDim2.new(0, 10, 0, 268)
revealSub.Size = UDim2.new(1, -20, 0, 24)
revealSub.ZIndex = 21
local revealOk = Theme.Button(reveal, "Nice!", Theme.Colors.Accent, Color3.fromRGB(255, 255, 255), "RevealOk")
revealOk.Size = UDim2.new(0, 140, 0, 38)
revealOk.AnchorPoint = Vector2.new(0.5, 0)
revealOk.Position = UDim2.new(0.5, 0, 0, 308)
revealOk.ZIndex = 21

local spinModel, spinConn
local function CloseReveal()
    reveal.Visible = false
    if spinConn then spinConn:Disconnect() spinConn = nil end
    if spinModel then spinModel:Destroy() spinModel = nil end
end
revealOk.MouseButton1Click:Connect(CloseReveal)

local function ShowReveal(pet)
    CloseReveal()
    local def = PetData.Get(pet.type)
    if not def then return end
    local model = PetModel.Build(pet.type, pet.variant)
    if model then
        spinModel = model
        model.Parent = viewport
        local box, size = model:GetBoundingBox()
        local centre = box.Position
        local dist = math.max(size.X, size.Y, size.Z) * 1.6 + 4
        local angle = 0
        spinConn = RunService.RenderStepped:Connect(function(dt)
            angle += dt * 1.2
            vpCam.CFrame = CFrame.lookAt(centre + Vector3.new(math.sin(angle) * dist, size.Y * 0.15, math.cos(angle) * dist), centre)
        end)
    end
    local rc = Theme.Colors[def.rarity] or Theme.Colors.AccentBright
    local BANNERS = { Common = "NEW PET!", Uncommon = "NICE FIND!", Rare = "RARE PET!", Epic = "EPIC PET!!", Legendary = "✨ LEGENDARY!!! ✨" }
    revealBanner.Text = BANNERS[def.rarity] or "NEW PET!"
    revealBanner.TextColor3 = rc
    revealStroke.Color = rc
    if pet.variant == "MegaNeon" then revealBanner.Text = "👑 SUPREME!!! 👑" elseif pet.variant == "Neon" then revealBanner.Text = "⭐ ELITE! ⭐" end
    revealName.Text = PetData.DisplayName(pet)
    revealName.TextColor3 = rc
    revealSub.Text = string.upper(def.rarity) .. "  -  " .. PetData.BoostText(pet)
    reveal.Visible = true
end

-- ── Content ───────────────────────────────────────────────────────────────────
local function Reload()
    local fresh = RemoteEvents.GetPlayerData:InvokeServer()
    if fresh then data = fresh end
    for id, b in pairs(tabButtons) do
        local on = id == tab
        b.BackgroundColor3 = on and Theme.Colors.Accent or Theme.Colors.PanelAlt
        b.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Theme.Colors.TextSecondary
    end
    Clear()
    if not data then return end
    coinsLbl.Text = Utils.FormatNumber(data.EmberCoins or 0) .. " coins"

    if tab == "Eggs" then
        Note("Hatch an egg to get a pet. Pets trot along behind you and give small boosts. You can wear "
            .. PetData.SLOTS .. " at a time.", 44)
        for _, eggId in ipairs(PetData.EggOrder) do
            local egg = PetData.Eggs[eggId]
            local canAfford = (data.EmberCoins or 0) >= egg.cost
            Row(egg.displayName, egg.blurb, egg.color,
                string.format("Hatch  %d", egg.cost), canAfford and Theme.Colors.Accent or Theme.Colors.PanelAlt,
                function() RemoteEvents.HatchPet:FireServer(eggId) end, canAfford, 64)
            -- what can come out, rarest first
            local odds = PetData.Odds(eggId)
            table.sort(odds, function(a, b) return a.chance < b.chance end)
            local parts = {}
            for _, o in ipairs(odds) do
                local d = PetData.Get(o.type)
                table.insert(parts, d.displayName .. " " .. PetData.FormatOdds(o.chance))
            end
            Note("Odds: " .. table.concat(parts, "  |  "), 92)
        end
        return
    end

    -- My Pets
    local owned = data.OwnedPets or {}
    local worn = {}
    for _, id in ipairs(data.EquippedPets or {}) do worn[id] = true end
    Note(string.format("Wearing %d / %d. Pets you wear follow you and boost your Golems a little.",
        #(data.EquippedPets or {}), PetData.SLOTS), 26)
    if #owned == 0 then
        Note("You have no pets yet. Hatch an egg in the Eggs tab!", 40)
        return
    end
    -- group identical pets (same type and variant) so duplicates show as "x4" with a Merge button
    local groups, list = {}, {}
    for _, pet in ipairs(owned) do
        local def = PetData.Get(pet.type)
        if def then
            local key = pet.type .. "|" .. (pet.variant or "")
            local g = groups[key]
            if not g then
                g = { type = pet.type, variant = pet.variant, def = def, pets = {}, wornIds = {} }
                groups[key] = g
                table.insert(list, g)
            end
            table.insert(g.pets, pet)
            if worn[pet.id] then table.insert(g.wornIds, pet.id) end
        end
    end
    local VARIANT_ORDER = { MegaNeon = 1, Neon = 2 }
    table.sort(list, function(a, b)
        if a.def.rarity ~= b.def.rarity then return RARITY_ORDER[a.def.rarity] < RARITY_ORDER[b.def.rarity] end
        if a.type ~= b.type then return a.def.displayName < b.def.displayName end
        return (VARIANT_ORDER[a.variant or ""] or 9) < (VARIANT_ORDER[b.variant or ""] or 9)
    end)
    for _, g in ipairs(list) do
        local sample = g.pets[1]
        local isWorn = #g.wornIds > 0
        local rc = Theme.Colors[g.def.rarity] or Theme.Colors.Common
        local count = #g.pets
        local canMerge = count >= PetData.MERGE_COUNT and g.variant ~= "MegaNeon"
        local nextLabel = g.variant and PetData.Variants[g.variant] and PetData.Variants[g.variant].next
        nextLabel = nextLabel and PetData.Variants[nextLabel].label or "Neon"
        local sub = string.upper(g.def.rarity) .. "  -  " .. PetData.BoostText(sample)
        if g.variant ~= "MegaNeon" then
            sub ..= string.format("   (merge %d -> %s)", PetData.MERGE_COUNT, nextLabel)
        end
        Row(PetData.DisplayName(sample) .. (count > 1 and ("  x" .. count) or ""), sub, rc,
            isWorn and "Put away" or "Wear", isWorn and Theme.Colors.PanelAlt or Theme.Colors.Accent,
            function()
                local id = isWorn and g.wornIds[1] or g.pets[1].id
                RemoteEvents.EquipPet:FireServer(id, not isWorn)
                task.delay(0.4, Reload)
            end, true, 64, rc, (RARITY_ORDER[g.def.rarity] or 5) <= 3 and ((RARITY_ORDER[g.def.rarity] == 1) and 3 or 2) or nil,
            canMerge and { text = "Merge " .. PetData.MERGE_COUNT, color = Theme.Colors.Success,
                onClick = function() RemoteEvents.MergePets:FireServer(g.type, g.variant) end } or nil)
    end
end

for id, b in pairs(tabButtons) do
    b.MouseButton1Click:Connect(function() tab = id Reload() end)
end

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if gui.Enabled then task.spawn(Reload) else CloseReveal() end
end)

RemoteEvents.PetsMerged.OnClientEvent:Connect(function(ok, result)
    if ok and type(result) == "table" then
        ShowReveal(result)
        task.delay(0.3, Reload)
    else
        statusLbl.Text = tostring(result or "Couldn't merge those pets")
        statusLbl.Visible = true
        task.delay(3.5, function() statusLbl.Visible = false end)
    end
end)

RemoteEvents.PetHatched.OnClientEvent:Connect(function(ok, result)
    if ok and type(result) == "table" then
        ShowReveal(result)
        task.delay(0.3, Reload)
    else
        statusLbl.Text = tostring(result or "Couldn't hatch that egg")
        statusLbl.Visible = true
        task.delay(3.5, function() statusLbl.Visible = false end)
    end
end)
