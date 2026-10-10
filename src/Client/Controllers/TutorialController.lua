-- First-run onboarding: a paged "How to Play" guide, a step-by-step objective tracker that advances as the player does each thing,
-- and a Help button to reopen the guide. Players who already own a Golem skip the tracker.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local Theme        = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI      = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local TutorialPointer = require(script.Parent.TutorialPointer)

local TutorialController = {}

-- The tracker: do these in order. Each one advances by itself when the game sees you do it.
local STEPS = {
    { title = "Stand on the Starter Pad", hint = "Head for the beam of light under the Mining Pads gate and stand on the Starter Pad. It mines for you: you need 10 Basic Ore and 5 Coal." },
    { title = "Forge your first Golem", hint = "Follow the arrow to the Golem Anvil near spawn, face it and press E. Pick a Golem from the list and press Forge." },
    { title = "Deploy your Golem",    hint = "Open the 🔥 Forge menu (bottom bar, or press F) and send your Golem to its mining zone." },
    { title = "Collect resources",    hint = "Golems mine on their own. Watch the totals build up above the button, then press ⛏ Collect." },
    { title = "Sell your spare materials", hint = "Open the 🏪 Market (M), choose Sell Surplus and sell some spare ore to the Supplier for coins." },
    { title = "Push a mine cart",     hint = "Follow the arrow to a mine cart, walk behind it to push it along its rail to the glowing depot. It pays a coin bounty. Bigger Cart Run courses wait in the south of the cavern." },
    { title = "Check your Quests",    hint = "Open 📋 Quests (Q). Daily and weekly challenges pay coins, XP and materials. Press Claim when one is done." },
}

-- The guide: one short page at a time. `lines` use bold lead-ins (RichText).
local PAGES = {
    { heading = "🔥  Your goal", lines = {
        "<b>Golems mine for you</b>, even while you are away from the game.",
        "You turn what they mine into <b>stronger Golems</b>, which mine more and open up new mining zones.",
        "Grow your <b>Forge</b>, build your own <b>Quarry</b>, trade with other players and climb the <b>Leaderboard</b>.",
        "Come back, collect, craft and send them out again: that is the loop.",
    } },
    { heading = "🚀  Your first ten minutes", lines = {
        "<b>1.</b>  Stand on the glowing <b>Starter Pad</b> under the Mining Pads gate. It gives free Basic Ore and Coal.",
        "<b>2.</b>  Press <b>E</b> at the <b>Golem Anvil</b> near spawn, pick a Golem and forge it (10 Basic Ore + 5 Coal).",
        "<b>3.</b>  Open the <b>Forge menu (F)</b> and deploy your Golem to a mining zone.",
        "<b>4.</b>  Press <b>Collect Resources</b> to bank what it mined. Then do it all again with a better Golem.",
    } },
    { heading = "⚒  Materials and crafting", lines = {
        "Golems bring back <b>raw materials</b>. Some are smelted in your Forge into <b>refined</b> ones: it takes time, and a Speed-Up finishes a smelt at once.",
        "The <b>Golem Anvil</b> lists every Golem. Each shows what it needs and where to find what you are missing.",
        "Each element (<b>Ember, Stone, Frost, Storm, Void</b>) opens its own mining zone, through the tunnels in the far wall.",
        "Rarer materials come from mining, from your Quarry and from other players on the Market.",
    } },
    { heading = "🛠  Looking after your Golems", lines = {
        "Golems <b>wear out</b> as they work. A bar over each one shows its health: green, amber, red.",
        "A tired Golem slows down. At zero it <b>stops, walks back to your forge</b> and sits down to wait.",
        "Stand next to it and press <b>E</b> to <b>repair</b> it. That costs 20% of what it cost to craft, and it walks back to work.",
        "The Golems row on the left panel has one pip per slot: <b>red pips</b> need repairing.",
    } },
    { heading = "💰  Earning coins", lines = {
        "<b>Rewards</b> and your login streak, and <b>Quests (Q)</b>: daily and weekly challenges.",
        "<b>Market → Sell Surplus</b>: sell spare Common and Uncommon materials to the Supplier. Your daily allowance grows as you level up.",
        "<b>Mine carts</b>: push a loaded cart along its rail to the glowing depot for a bounty (a cart reloads after two minutes).",
        "Level-ups, the Season pass, Guild rewards and Ladder prizes pay too. Spend coins on your <b>Quarry</b>, <b>Forge Builder</b> pieces and <b>Ascensions</b>.",
    } },
    { heading = "📈  Pads and levels", lines = {
        "Mining Pads multiply what you gather: <b>Copper x3</b> (level 5), <b>Iron x9</b> (10), <b>Gold x25</b> (20), <b>Legend x100</b> (35).",
        "<b>Walk up to a pad you cannot use yet</b> to see how to unlock it: reach the level, or buy it forever with Robux.",
        "Your <b>Forge level</b> opens features: the <b>Quarry</b> at Forge 6, <b>Ascension</b> at Forge 10.",
        "Level up by crafting, mining and finishing quests.",
    } },
    { heading = "⏰  Events", lines = {
        "The banner at the top shows the live bonus. <b>Gold</b> = the hourly event: double XP, luckier drops, an element's Golems mining double, <b>Coin Rush</b>, <b>Market Hour</b> and more.",
        "<b>Red</b> = a <b>Surge</b>: bigger bonuses for just 10 minutes, every few hours.",
        "<b>Pulsing bright gold</b> = a <b>Jackpot</b>: the biggest of all, but only 3 minutes, about once a day.",
        "The rarer the event, the shorter it lasts. You get a message the moment a Surge or Jackpot starts.",
    } },
    { heading = "🎯  Controls and tips", lines = {
        "<b>F</b> Forge   <b>B</b> Bag   <b>M</b> Market   <b>Q</b> Quests   <b>P</b> Shop.   <b>E</b> uses whatever is in front of you: the Anvil, a repair, a pad's info.",
        "Hatch <b>Pets</b> for small boosts, join a <b>Guild</b> for weekly rewards and duels, and visit other players' forges to trade.",
        "Not sure what to do next? Open <b>Quests</b>, or check the objective tip under the banner.",
        "Press <b>?  Help</b> (bottom left) any time to read this again.",
    } },
}

local gui, tracker, trackerTitle, trackerHint, howTo
local guide = {}        -- the pieces of the guide window
local stepIndex = 1
local active = false
local pageIndex = 1
local CORE_STEPS = 4                -- steps 1-4 are the core loop (the welcome gift comes after step 4); the rest are bonus steps
local QUICK_PAGES = { 1, 2 }        -- what a brand-new player sees: goal + first ten minutes. The Help button opens the full guide.
local shownPages = {}               -- indexes into PAGES for the guide window as it is now open

-- ── The guide ─────────────────────────────────────────────────────────────────
local function ShowPage(n)
    pageIndex = math.clamp(n, 1, #shownPages)
    local page = PAGES[shownPages[pageIndex]]
    guide.heading.Text = page.heading
    local lines = {}
    for _, line in ipairs(page.lines) do
        table.insert(lines, line:match("^<b>%d%.") and line or ("•  " .. line))      -- numbered steps keep their number, the rest get a bullet
    end
    guide.body.Text = table.concat(lines, "\n\n")
    guide.counter.Text = string.format("%d / %d", pageIndex, #shownPages)
    guide.back.Visible = pageIndex > 1
    guide.next.Text = pageIndex == #shownPages and "Let's go!" or "Next  ▶"
    for i, dot in ipairs(guide.dots) do
        dot.Visible = i <= #shownPages
        dot.BackgroundColor3 = i == pageIndex and Theme.Colors.AccentBright or Theme.Colors.PanelAlt
        dot.Size = i == pageIndex and UDim2.new(0, 22, 0, 8) or UDim2.new(0, 8, 0, 8)
    end
end

local function OpenGuide(page, quick)
    shownPages = {}
    for i = 1, #PAGES do shownPages[i] = i end
    if quick then shownPages = QUICK_PAGES end
    ShowPage(page or 1)
    howTo.Visible = true
end

-- ── UI ────────────────────────────────────────────────────────────────────────
local function Build()
    gui = Instance.new("ScreenGui")
    gui.Name = "TutorialGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 8        -- below the menus (11) so the tip never covers a window's tabs or title
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = PlayerGui

    -- Objective tracker (top centre, under the HUD bar)
    tracker = Instance.new("Frame")
    tracker.Name = "Tracker"
    tracker.AnchorPoint = Vector2.new(0.5, 0)
    tracker.Size = UDim2.new(0, 420, 0, 92)
    tracker.Position = UDim2.new(0.5, 0, 0, 98)       -- under the event banner
    tracker.BackgroundColor3 = Theme.Colors.Panel
    tracker.BackgroundTransparency = 0.05
    tracker.BorderSizePixel = 0
    tracker.Visible = false
    tracker.Parent = gui
    Theme.AddCorner(tracker, Theme.Corner.Large)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Colors.Accent
    stroke.Thickness = 2
    stroke.Parent = tracker

    trackerTitle = Theme.Label(tracker, "", 16, Theme.Colors.AccentBright, Theme.Fonts.Heading, "Title")
    trackerTitle.Position = UDim2.new(0, 12, 0, 6)
    trackerTitle.Size = UDim2.new(1, -70, 0, 22)

    trackerHint = Theme.Label(tracker, "", 13, Theme.Colors.TextPrimary, Theme.Fonts.Body, "Hint")
    trackerHint.Position = UDim2.new(0, 12, 0, 30)
    trackerHint.Size = UDim2.new(1, -24, 0, 54)       -- room for three lines, so no hint is cut off
    trackerHint.TextYAlignment = Enum.TextYAlignment.Top

    local skip = Theme.Button(tracker, "Skip", Theme.Colors.PanelAlt, Theme.Colors.TextSecondary, "Skip")
    skip.Size = UDim2.new(0, 60, 0, 28)
    skip.Position = UDim2.new(1, -68, 0, 4)
    skip.TextSize = 13
    skip.MouseButton1Click:Connect(function()
        active = false
        tracker.Visible = false
    end)

    -- the tip must not run into the player card (left) and the button column (right) on a narrow screen
    local function FitTracker()
        local cam = workspace.CurrentCamera
        local vx = cam and cam.ViewportSize.X or 1280
        local w = math.clamp(vx - 440, 240, 420)
        local narrow = w < 340
        tracker.Size = UDim2.new(0, w, 0, narrow and 108 or 92)
        trackerHint.TextSize = narrow and 12 or 13
        trackerHint.Size = UDim2.new(1, -24, 0, narrow and 72 or 54)
        trackerTitle.Size = UDim2.new(1, -84, 0, 22)
    end
    FitTracker()
    if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(FitTracker) end

    -- Help button (bottom left)
    local help = Theme.Button(gui, "?  Help", Theme.Colors.Accent, Color3.fromRGB(255, 255, 255), "HelpButton")
    help.Size = UDim2.new(0, 86, 0, 34)
    help.Position = UDim2.new(0, 12, 1, -52)
    help.TextSize = 14
    help.MouseButton1Click:Connect(function() OpenGuide(1) end)

    -- How to Play guide
    howTo = Instance.new("Frame")
    howTo.Name = "HowToPlay"
    howTo.Size = UDim2.new(1, 0, 1, 0)
    howTo.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    howTo.BackgroundTransparency = 0.45
    howTo.BorderSizePixel = 0
    howTo.Active = true
    howTo.Visible = false
    howTo.Parent = gui

    local box = Instance.new("Frame")
    box.Name = "Box"
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.Size = UDim2.new(0, 620, 0, 480)
    ScaleUI.Apply(box, 620, 480)
    box.Position = UDim2.new(0.5, 0, 0.5, 0)
    box.BackgroundColor3 = Theme.Colors.Background
    box.BorderSizePixel = 0
    box.Parent = howTo
    Theme.AddCorner(box, Theme.Corner.Large)
    Theme.AddStroke(box, Theme.Colors.Accent, 2, 0.3)

    guide.heading = Theme.Label(box, "", Theme.TextSize.Title, Theme.Colors.AccentBright, Theme.Fonts.Title, "Title")
    guide.heading.Position = UDim2.new(0, 24, 0, 16)
    guide.heading.Size = UDim2.new(1, -150, 0, 36)

    guide.counter = Theme.Label(box, "", 14, Theme.Colors.TextDim, Theme.Fonts.Body, "Counter")
    guide.counter.Position = UDim2.new(1, -120, 0, 22)
    guide.counter.Size = UDim2.new(0, 96, 0, 24)
    guide.counter.TextXAlignment = Enum.TextXAlignment.Right

    local rule = Instance.new("Frame")
    rule.Position = UDim2.new(0, 24, 0, 58)
    rule.Size = UDim2.new(1, -48, 0, 2)
    rule.BackgroundColor3 = Theme.Colors.Accent
    rule.BackgroundTransparency = 0.5
    rule.BorderSizePixel = 0
    rule.Parent = box

    guide.body = Theme.Label(box, "", 17, Theme.Colors.TextPrimary, Theme.Fonts.Body, "Body")
    guide.body.RichText = true
    guide.body.Position = UDim2.new(0, 24, 0, 74)
    guide.body.Size = UDim2.new(1, -48, 1, -170)
    guide.body.TextYAlignment = Enum.TextYAlignment.Top

    -- page dots
    local dotRow = Instance.new("Frame")
    dotRow.Name = "Dots"
    dotRow.BackgroundTransparency = 1
    dotRow.AnchorPoint = Vector2.new(0.5, 0)
    dotRow.Position = UDim2.new(0.5, 0, 1, -88)
    dotRow.Size = UDim2.new(0, 260, 0, 12)
    dotRow.Parent = box
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 6)
    layout.Parent = dotRow
    guide.dots = {}
    for i = 1, #PAGES do
        local dot = Instance.new("TextButton")
        dot.Name = "Dot" .. i
        dot.Text = ""
        dot.AutoButtonColor = false
        dot.BorderSizePixel = 0
        dot.Size = UDim2.new(0, 8, 0, 8)
        dot.LayoutOrder = i
        dot.Parent = dotRow
        Theme.AddCorner(dot, UDim.new(1, 0))
        dot.MouseButton1Click:Connect(function() ShowPage(i) end)
        guide.dots[i] = dot
    end

    guide.back = Theme.Button(box, "◀  Back", Theme.Colors.PanelAlt, Theme.Colors.TextSecondary, "BackButton")
    guide.back.Size = UDim2.new(0, 130, 0, 42)
    guide.back.Position = UDim2.new(0, 24, 1, -62)
    guide.back.TextSize = 16
    guide.back.MouseButton1Click:Connect(function() ShowPage(pageIndex - 1) end)

    guide.next = Theme.Button(box, "Next  ▶", Theme.Colors.Accent, Color3.fromRGB(255, 255, 255), "StartButton")
    guide.next.Size = UDim2.new(0, 170, 0, 42)
    guide.next.Position = UDim2.new(1, -194, 1, -62)
    guide.next.TextSize = 17
    guide.next.MouseButton1Click:Connect(function()
        if pageIndex >= #shownPages then howTo.Visible = false else ShowPage(pageIndex + 1) end
    end)

    local close = Theme.Button(box, "Close", Theme.Colors.PanelAlt, Theme.Colors.TextSecondary, "CloseButton")
    close.Size = UDim2.new(0, 90, 0, 42)
    close.Position = UDim2.new(0.5, -45, 1, -62)
    close.TextSize = 15
    close.MouseButton1Click:Connect(function() howTo.Visible = false end)

    shownPages = QUICK_PAGES
    ShowPage(1)
end

-- ── Steps ─────────────────────────────────────────────────────────────────────
-- Where the arrow points for a step (nil = no arrow)
local function EmberWorld() return workspace:FindFirstChild("EmberWorld") end
local function PointerFor(step)
    if step == 1 then
        return { name = "Starter Pad", position = function()
            local world = EmberWorld()
            local pad = world and world:FindFirstChild("PadModel_Starter")
            return pad and (pad:GetPivot().Position + Vector3.new(0, 10, 0)) or nil
        end }
    elseif step == 2 then
        return { name = "Golem Anvil", position = function()
            local world = EmberWorld()
            local anvil = world and world:FindFirstChild("GolemAnvil")
            return anvil and (anvil.Position + Vector3.new(0, 40, 0)) or nil
        end }
    elseif step == 6 then
        return { name = "Mine cart", position = function()
            local char = Players.LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then return nil end
            local best, bestD
            for _, cart in ipairs(game:GetService("CollectionService"):GetTagged("EFCart")) do          -- the road carts (the Cart Run ones are far away)
                local body = cart.PrimaryPart
                if body then
                    local d = (body.Position - root.Position).Magnitude
                    if not bestD or d < bestD then best, bestD = body, d end
                end
            end
            return best and (best.Position + Vector3.new(0, 14, 0)) or nil
        end }
    end
    return nil
end

local function ShowStep()
    local step = STEPS[stepIndex]
    if not step then
        active = false
        tracker.Visible = false
        TutorialPointer.Clear()
        return
    end
    TutorialPointer.Set(PointerFor(stepIndex))
    if stepIndex <= CORE_STEPS then
        trackerTitle.Text = string.format("Step %d/%d:  %s", stepIndex, CORE_STEPS, step.title)
    else
        trackerTitle.Text = string.format("Bonus %d/%d:  %s", stepIndex - CORE_STEPS, #STEPS - CORE_STEPS, step.title)
    end
    trackerHint.Text = step.hint
    tracker.Visible = true
end

local function Advance(fromStep)
    if not active or stepIndex ~= fromStep then return end
    stepIndex += 1
    if fromStep == CORE_STEPS then
        RemoteEvents.ClaimTutorialReward:FireServer()          -- the server checks it and pays the welcome gift once
    end
    if stepIndex > #STEPS then
        active = false
        tracker.Visible = false
        TutorialPointer.Clear()
        local HUDController = require(script.Parent.HUDController)
        HUDController.ShowNotification("Tutorial complete!", "You're up and running. Press ? Help any time to read the guide again.")
    else
        ShowStep()
    end
end

-- ── Init ──────────────────────────────────────────────────────────────────────
local MENU_NAMES = { "InventoryMenu", "ForgeMenu", "MarketMenu", "TradeMenu", "ShopMenu", "SeasonMenu", "ChallengesMenu", "StyleMenu",
    "LeaderboardMenu", "AnvilMenu", "PetsMenu", "GuildMenu", "BuildMenu", "RewardsMenu", "QuarryMenu" }

function TutorialController.Init(playerData)
    Build()
    TutorialPointer.Init()

    -- The tip hides while any menu is open, so it never covers a window's tabs or title (menus draw at different layers)
    task.spawn(function()
        while true do
            task.wait(0.2)
            if active and tracker then
                local open = false
                for _, name in ipairs(MENU_NAMES) do
                    local g = PlayerGui:FindFirstChild(name)
                    if g and g:IsA("ScreenGui") and g.Enabled then open = true break end
                end
                tracker.Visible = not open and STEPS[stepIndex] ~= nil
                -- opening the Quests window is the last step
                local quests = PlayerGui:FindFirstChild("ChallengesMenu")
                if open and stepIndex == 7 and quests and quests.Enabled then Advance(7) end
            end
        end
    end)

    -- Players who already own a Golem have done the basics: skip the tracker
    if playerData and playerData.Golems and #playerData.Golems > 0 then return end

    active = true
    OpenGuide(1, true)       -- two short pages; the rest of the guide is behind the Help button
    ShowStep()

    -- Steps follow the server's events
    local ore, coal = 0, 0
    RemoteEvents.ResourcesCollected.OnClientEvent:Connect(function(gains, elapsed)
        if not gains then return end
        if stepIndex == 1 then
            ore  += gains.BasicOre or 0
            coal += gains.Coal or 0
            if ore >= 10 and coal >= 5 then Advance(1) end
        elseif stepIndex == 4 and elapsed == -1 and next(gains) ~= nil then   -- -1 = manual Collect
            Advance(4)
        end
    end)
    -- A player who gets ahead of the tip (buys ore, crafts at the forge, deploys early) skips the steps they've already done
    RemoteEvents.GolemCrafted.OnClientEvent:Connect(function(golem)
        if golem then for s = stepIndex, 2 do Advance(s) end end
    end)
    RemoteEvents.GolemDeployed.OnClientEvent:Connect(function(ok)
        if ok then for s = stepIndex, 3 do Advance(s) end end
    end)
    -- the Supplier sale and the cart delivery both announce themselves with a notification
    RemoteEvents.Notify.OnClientEvent:Connect(function(title)
        if title == "Sold" then Advance(5)
        elseif title == "Mine Cart Delivery" or (type(title) == "string" and title:find(" complete!", 1, true)) then Advance(6) end
    end)
end

return TutorialController
