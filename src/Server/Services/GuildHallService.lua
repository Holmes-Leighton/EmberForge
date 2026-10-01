-- The Guild Hall: a small floating hall for each guild that has members on this server. Members teleport there from the
-- Guild menu to meet up. A sign shows the guild's name, level and weekly progress. It is built from plain parts, plus
-- a few Forge Builder props (campfire, fountain, banners) when those models are loaded.

local Players = game:GetService("Players")

local GuildData         = require(game.ReplicatedStorage.Shared.Data.GuildData)
local Utils             = require(game.ReplicatedStorage.Shared.Modules.Utils)
local PlayerDataService = require(script.Parent.PlayerDataService)

local GuildHallService = {}

local HALL_SIZE   = 60
local HALL_SPACING = 90
local HALL_Y      = 300                  -- a floating island, well clear of the world
local HALL_Z      = 800

local halls = {}                         -- guildId -> { model, index, sign }
local used = {}                          -- index -> true
local folder

local function EnsureFolder()
    if not folder or not folder.Parent then
        folder = workspace:FindFirstChild("GuildHalls")
        if not folder then
            folder = Instance.new("Folder")
            folder.Name = "GuildHalls"
            folder.Parent = workspace
        end
    end
end

local function Centre(index) return Vector3.new((index - 1) * HALL_SPACING, HALL_Y, HALL_Z) end

local function Prop(parent, name, height, pos, rot)
    local assets = game.ReplicatedStorage:FindFirstChild("BuildAssets")
    local template = assets and assets:FindFirstChild(name)
    if not template then return end
    local piece = template:Clone()
    for _, d in ipairs(piece:GetDescendants()) do
        if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false end
    end
    local _, size = piece:GetBoundingBox()
    if size.Y > 0.01 then piece:ScaleTo(piece:GetScale() * height / size.Y) end
    local _, s2 = piece:GetBoundingBox()
    piece:PivotTo(CFrame.new(pos + Vector3.new(0, s2.Y / 2, 0)) * CFrame.Angles(0, math.rad(rot or 0), 0))
    piece.Parent = parent
end

local function BuildHall(guildId, index, name)
    EnsureFolder()
    local c = Centre(index)
    local model = Instance.new("Model")
    model.Name = "GuildHall_" .. guildId

    local floor = Instance.new("Part")
    floor.Name = "Floor"
    floor.Size = Vector3.new(HALL_SIZE, 2, HALL_SIZE)
    floor.CFrame = CFrame.new(c)
    floor.Anchored = true
    floor.Material = Enum.Material.Slate
    floor.Color = Color3.fromRGB(78, 66, 60)
    floor.Parent = model

    local rim = Instance.new("Part")            -- a glowing edge so the island reads from far away
    rim.Name = "Rim"
    rim.Size = Vector3.new(HALL_SIZE + 2, 0.4, HALL_SIZE + 2)
    rim.CFrame = CFrame.new(c + Vector3.new(0, -0.9, 0))
    rim.Anchored, rim.CanCollide = true, false
    rim.Material = Enum.Material.Neon
    rim.Color = Color3.fromRGB(255, 160, 60)
    rim.Transparency = 0.4
    rim.Parent = model

    -- low walls so nobody walks off the edge
    for _, side in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
        local wall = Instance.new("Part")
        wall.Name = "Wall"
        local alongX = side[1] == 0
        wall.Size = alongX and Vector3.new(HALL_SIZE, 4, 1) or Vector3.new(1, 4, HALL_SIZE)
        wall.CFrame = CFrame.new(c + Vector3.new(side[1] * (HALL_SIZE / 2 - 0.5), 3, side[2] * (HALL_SIZE / 2 - 0.5)))
        wall.Anchored = true
        wall.Transparency = 0.6
        wall.Material = Enum.Material.Glass
        wall.Color = Color3.fromRGB(255, 190, 110)
        wall.Parent = model
    end

    local base = c + Vector3.new(0, 1, 0)
    Prop(model, "Campfire", 3, base + Vector3.new(-10, 0, 6))
    Prop(model, "Fountain", 7, base + Vector3.new(10, 0, 6))
    Prop(model, "BannerFlag", 9, base + Vector3.new(-22, 0, -22))
    Prop(model, "BannerFlag", 9, base + Vector3.new(22, 0, -22))
    Prop(model, "TrophyStatue", 8, base + Vector3.new(0, 0, -16))
    Prop(model, "Throne", 6, base + Vector3.new(0, 0, -24), 0)

    local spawn = Instance.new("Part")
    spawn.Name = "Arrival"
    spawn.Size = Vector3.new(6, 0.2, 6)
    spawn.CFrame = CFrame.new(c + Vector3.new(0, 1.1, 18))
    spawn.Anchored, spawn.CanCollide, spawn.Transparency = true, false, 1
    spawn.Parent = model

    local anchor = Instance.new("Part")           -- holds the sign
    anchor.Name = "SignAnchor"
    anchor.Size = Vector3.new(1, 1, 1)
    anchor.CFrame = CFrame.new(c + Vector3.new(0, 16, -10))
    anchor.Anchored, anchor.CanCollide, anchor.Transparency = true, false, 1
    anchor.Parent = model
    local gui = Instance.new("BillboardGui")
    gui.Name = "HallSign"
    gui.Size = UDim2.new(0, 360, 0, 120)
    gui.MaxDistance = 220
    gui.AlwaysOnTop = false
    gui.Parent = anchor
    local function line(nameStr, y, h, color, font)
        local l = Instance.new("TextLabel")
        l.Name = nameStr
        l.BackgroundTransparency = 1
        l.Position = UDim2.new(0, 0, 0, y)
        l.Size = UDim2.new(1, 0, 0, h)
        l.TextScaled = true
        l.Font = font
        l.TextColor3 = color
        l.TextStrokeTransparency = 0.4
        l.Text = ""
        l.Parent = gui
        return l
    end
    line("Title", 0, 50, Color3.fromRGB(255, 200, 80), Enum.Font.GothamBold).Text = name
    line("Level", 50, 28, Color3.fromRGB(235, 235, 235), Enum.Font.GothamMedium)
    line("Week", 80, 26, Color3.fromRGB(180, 220, 255), Enum.Font.Gotham)

    local light = Instance.new("PointLight")
    light.Range, light.Brightness, light.Color = 40, 1.5, Color3.fromRGB(255, 190, 120)
    light.Parent = anchor

    model.Parent = folder
    return { model = model, index = index, sign = gui, name = name, spawn = spawn }
end

local function Freeindex()
    local i = 1
    while used[i] do i += 1 end
    used[i] = true
    return i
end

-- Fill the sign from a guild snapshot (see GuildService.GetMine)
local function UpdateSign(hall, snap)
    if not hall or not snap then return end
    hall.sign.Title.Text = snap.name
    local bonus = math.floor(snap.levelBonus * 100 + 0.5)
    local nextLine = snap.nextLevelTotal and string.format("   -   next level at %s mined", Utils.FormatNumber(snap.nextLevelTotal)) or "   -   max level"
    hall.sign.Level.Text = string.format("Guild Level %d  (+%d%% mining)%s", snap.level, bonus, nextLine)
    hall.sign.Week.Text = string.format("This week: %s / %s   -   %d members", Utils.FormatNumber(snap.weekly), Utils.FormatNumber(snap.target), snap.memberCount)
end

-- Take a member to their guild's hall (building it first if nobody from the guild has been there yet)
function GuildHallService.Teleport(player, guildSnapshot)
    local data = PlayerDataService.Get(player)
    local char = player.Character
    if not data or not data.GuildId then return false, "Join a guild first" end
    if not char or not char.PrimaryPart then return false, "Try again in a moment" end
    local hall = halls[data.GuildId]
    if not hall or not hall.model.Parent then
        hall = BuildHall(data.GuildId, Freeindex(), guildSnapshot and guildSnapshot.name or "Guild Hall")
        halls[data.GuildId] = hall
    end
    UpdateSign(hall, guildSnapshot)
    char:PivotTo(hall.spawn.CFrame + Vector3.new(0, 3, 0))
    return true
end

-- Keep every hall's sign fresh while it has someone from the guild on the server; remove empty halls
function GuildHallService.Start(getSnapshot)
    task.spawn(function()
        while true do
            task.wait(30)
            for guildId, hall in pairs(halls) do
                local member
                for _, p in ipairs(Players:GetPlayers()) do
                    local d = PlayerDataService.Get(p)
                    if d and d.GuildId == guildId then member = p break end
                end
                if member then
                    local ok, snap = pcall(getSnapshot, member)
                    if ok and snap then UpdateSign(hall, snap) end
                else
                    hall.model:Destroy()
                    used[hall.index] = nil
                    halls[guildId] = nil
                end
            end
        end
    end)
end

return GuildHallService
