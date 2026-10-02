-- Pays the Mine Cart Delivery bounty (see CartBountyData). BiomeArt builds the carts (tagged "EFCart", with HomeX/HomeZ attributes and a "Loaded" attribute);
-- this watches them: when a loaded cart has been pushed far enough along its rail, the nearest player gets the bounty, the cart empties, rolls home and
-- is loaded again after a cooldown.
local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local CartBountyData    = require(game.ReplicatedStorage.Shared.Data.CartBountyData)
local RemoteEvents      = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local LiveOpsService    = require(script.Parent.LiveOpsService)

local CartBountyService = {}

local function Counters(data)
    local today = CartBountyData.Today()
    local c = data.CartBounty
    if type(c) ~= "table" or c.day ~= today then
        c = { day = today, earned = 0, deliveries = 0 }
        data.CartBounty = c
    end
    return c
end

-- Pays `player` for a delivery. Returns ok, message, coins. The daily allowance counts the normal reward; coin events (Coin Rush etc.) pay extra on top.
function CartBountyService.Deliver(player)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data", 0 end
    local c = Counters(data)
    local room = CartBountyData.Cap(data) - c.earned
    if room <= 0 then return false, "You've made all the deliveries the depot will pay for today. It resets at midnight UTC.", 0 end
    local base = math.min(CartBountyData.Reward(data), room)
    local coins = math.floor(base * LiveOpsService.GetMultiplier("coins"))
    data.EmberCoins = (data.EmberCoins or 0) + coins
    c.earned = c.earned + base
    c.deliveries = c.deliveries + 1
    PlayerDataService.MarkDirty(player)
    return true, string.format("Delivery complete! +%d coins", coins), coins
end

-- The player closest to `position` within `range` studs, or nil
local function NearestPlayer(position, range)
    local best, bestD = nil, range
    for _, p in ipairs(Players:GetPlayers()) do
        local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local d = (root.Position - position).Magnitude
            if d <= bestD then best, bestD = p, d end
        end
    end
    return best
end

local function SetSign(model, text)
    local body = model.PrimaryPart
    local sign = body and body:FindFirstChild("CartSign")
    local label = sign and sign:FindFirstChild("Text")
    if label then label.Text = text end
end

local state = setmetatable({}, { __mode = "k" })      -- cart model -> { phase = "loaded" | "returning" | "reloading", at = seconds }

local function Step(now)
    for _, model in ipairs(CollectionService:GetTagged("EFCart")) do
        local body = model.PrimaryPart
        local s = state[model]
        if body and body.Parent and model:GetAttribute("HomeX") then
            if not s then
                s = { phase = "loaded", at = now }
                state[model] = s
            end
            local homeX, homeZ = model:GetAttribute("HomeX"), model:GetAttribute("HomeZ")
            if s.phase == "loaded" then
                if body.Position.X - homeX >= CartBountyData.DELIVER_AT then
                    local who = NearestPlayer(body.Position, CartBountyData.RANGE)
                    s.phase, s.at = "returning", now
                    model:SetAttribute("Loaded", false)
                    SetSign(model, "Delivered!")
                    if who then
                        local ok, msg = CartBountyService.Deliver(who)
                        RemoteEvents.Notify:FireClient(who, ok and "Mine Cart Delivery" or "Delivery limit", msg)
                    end
                end
            elseif s.phase == "returning" then
                if now - s.at >= CartBountyData.RETURN_AFTER then
                    body.AssemblyLinearVelocity = Vector3.zero
                    body.AssemblyAngularVelocity = Vector3.zero
                    body.CFrame = CFrame.new(homeX, 3, homeZ)                 -- wheeled back, empty
                    s.phase, s.at = "reloading", now
                    SetSign(model, "Reloading...")
                end
            elseif s.phase == "reloading" then
                if now - s.at >= CartBountyData.COOLDOWN then
                    s.phase, s.at = "loaded", now
                    model:SetAttribute("Loaded", true)
                    SetSign(model, "Push me to the depot for coins")
                end
            end
        end
    end
end

function CartBountyService.Init()
    task.spawn(function()
        while true do
            task.wait(0.4)
            Step(os.clock())
        end
    end)
end

return CartBountyService
