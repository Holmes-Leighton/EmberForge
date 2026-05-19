-- Manages the trade request UI and Forge Market browser.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local Utils        = require(game.ReplicatedStorage.Shared.Modules.Utils)

local TradingController = {}

local tradeGui
local marketGui
local activeTradeId = nil

-- ── Init ──────────────────────────────────────────────────────────────────────
function TradingController.Init(playerData)
    TradingController._data = playerData

    task.spawn(function()
        tradeGui  = PlayerGui:WaitForChild("TradeMenu",  10)
        marketGui = PlayerGui:WaitForChild("MarketMenu", 10)

        if tradeGui  then TradingController._SetupTradeGui()  end
        if marketGui then TradingController._SetupMarketGui() end
    end)
end

-- ── Trade GUI ─────────────────────────────────────────────────────────────────
function TradingController._SetupTradeGui()
    local closeBtn = tradeGui:FindFirstChild("CloseButton", true)
    if closeBtn then
        closeBtn.MouseButton1Click:Connect(function()
            if activeTradeId then
                RemoteEvents.DeclineTrade:FireServer(activeTradeId)
                activeTradeId = nil
            end
            tradeGui.Enabled = false
        end)
    end

    local acceptBtn = tradeGui:FindFirstChild("AcceptButton", true)
    if acceptBtn then
        acceptBtn.MouseButton1Click:Connect(function()
            if activeTradeId then
                RemoteEvents.AcceptTrade:FireServer(activeTradeId)
            end
        end)
    end

    local declineBtn = tradeGui:FindFirstChild("DeclineButton", true)
    if declineBtn then
        declineBtn.MouseButton1Click:Connect(function()
            if activeTradeId then
                RemoteEvents.DeclineTrade:FireServer(activeTradeId)
                activeTradeId = nil
            end
            tradeGui.Enabled = false
        end)
    end
end

function TradingController.OnTradeOffer(tradeId, err)
    if err then
        print("[TradingController] Trade error:", err)
        return
    end
    activeTradeId = tradeId
    if tradeGui then
        tradeGui.Enabled = true
        -- Update trade UI header
        local header = tradeGui:FindFirstChild("TradeHeader", true)
        if header then
            header.Text = "Trade Request — ID: " .. tradeId
        end
    end
end

function TradingController.OnTradeCompleted(result)
    activeTradeId = nil
    if tradeGui then
        tradeGui.Enabled = false
    end
    -- Update local data mirror for items exchanged
    if result then
        -- In a full build, re-sync inventory from server or apply delta
        print("[TradingController] Trade completed:", result.tradeId)
    end
end

-- ── Forge Market GUI ──────────────────────────────────────────────────────────
function TradingController._SetupMarketGui()
    local refreshBtn = marketGui:FindFirstChild("RefreshButton", true)
    if refreshBtn then
        refreshBtn.MouseButton1Click:Connect(function()
            TradingController._RefreshMarket()
        end)
    end

    local listBtn = marketGui:FindFirstChild("ListItemButton", true)
    if listBtn then
        listBtn.MouseButton1Click:Connect(function()
            TradingController._OpenListingDialog()
        end)
    end

    -- Tabs: Materials / Golems
    local matTab  = marketGui:FindFirstChild("MaterialsTab", true)
    local golemTab = marketGui:FindFirstChild("GolemsTab", true)

    if matTab then
        matTab.MouseButton1Click:Connect(function()
            TradingController._RefreshMarket("material")
        end)
    end
    if golemTab then
        golemTab.MouseButton1Click:Connect(function()
            TradingController._RefreshMarket("golem")
        end)
    end
end

function TradingController._RefreshMarket(filterType)
    local listings = RemoteEvents.GetMarketListings:InvokeServer(filterType, nil)
    TradingController._RenderListings(listings)
end

function TradingController._RenderListings(listings)
    if not marketGui then return end
    local scroll = marketGui:FindFirstChild("ListingScroll", true)
    if not scroll then return end

    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local yOff = 0
    for _, listing in ipairs(listings or {}) do
        local row = TradingController._CreateListingRow(listing, yOff)
        row.Parent = scroll
        yOff = yOff + 60
    end
    scroll.CanvasSize = UDim2.new(0, 0, 0, yOff + 5)
end

function TradingController._CreateListingRow(listing, yOff)
    local row = Instance.new("Frame")
    row.Name = listing.id
    row.Size = UDim2.new(1, -10, 0, 56)
    row.Position = UDim2.new(0, 5, 0, yOff + 2)
    row.BackgroundColor3 = Color3.fromRGB(35, 30, 25)
    row.BorderSizePixel = 0

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = row

    -- Item name
    local itemLbl = Instance.new("TextLabel")
    itemLbl.Size = UDim2.new(0.5, 0, 0, 56)
    itemLbl.Position = UDim2.new(0, 8, 0, 0)
    itemLbl.BackgroundTransparency = 1
    itemLbl.Text = (listing.item.id or "?") ..
        (listing.item.qty and " x" .. listing.item.qty or "") ..
        "\nby " .. (listing.sellerName or "?")
    itemLbl.TextColor3 = Color3.fromRGB(220, 210, 200)
    itemLbl.Font = Enum.Font.Gotham
    itemLbl.TextSize = 12
    itemLbl.TextXAlignment = Enum.TextXAlignment.Left
    itemLbl.TextYAlignment = Enum.TextYAlignment.Center
    itemLbl.TextWrapped = true
    itemLbl.Parent = row

    -- Price
    local priceLbl = Instance.new("TextLabel")
    priceLbl.Size = UDim2.new(0.25, 0, 0, 56)
    priceLbl.Position = UDim2.new(0.5, 0, 0, 0)
    priceLbl.BackgroundTransparency = 1
    priceLbl.Text = Utils.FormatNumber(listing.priceCoins) .. " ⚡"
    priceLbl.TextColor3 = Color3.fromRGB(255, 200, 50)
    priceLbl.Font = Enum.Font.GothamBold
    priceLbl.TextSize = 14
    priceLbl.TextXAlignment = Enum.TextXAlignment.Center
    priceLbl.Parent = row

    -- Buy button
    local buyBtn = Instance.new("TextButton")
    buyBtn.Size = UDim2.new(0, 70, 0, 30)
    buyBtn.Position = UDim2.new(1, -78, 0.5, -15)
    buyBtn.BackgroundColor3 = Color3.fromRGB(50, 160, 80)
    buyBtn.Text = "Buy"
    buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    buyBtn.Font = Enum.Font.GothamBold
    buyBtn.TextSize = 13
    buyBtn.BorderSizePixel = 0
    buyBtn.Parent = row

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = buyBtn

    buyBtn.MouseButton1Click:Connect(function()
        RemoteEvents.BuyFromMarket:FireServer(listing.id)
        row:Destroy()  -- optimistic removal
    end)

    return row
end

function TradingController._OpenListingDialog()
    local data = TradingController._data
    if not data then return end

    local pg     = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local dialog = pg:FindFirstChild("MarketListingDialog")
    local openFn = dialog and dialog:FindFirstChild("Open")
    if openFn then
        openFn:Invoke(data.Inventory or {})
    end
end

return TradingController
