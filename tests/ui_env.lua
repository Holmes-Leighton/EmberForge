-- ── Fake Roblox UI tree, enough to run the client menu scripts and controllers ───────
-- Adds a real parent/child tree, signals you can fire from tests, and Instance.new for GUI classes.

local GUI_OBJECT = { Frame = true, TextLabel = true, TextButton = true, TextBox = true, ScrollingFrame = true,
    ImageLabel = true, ImageButton = true, ViewportFrame = true, CanvasGroup = true }
local BUTTONS = { TextButton = true, ImageButton = true }
local SIGNALS = { MouseButton1Click = true, MouseButton1Down = true, MouseButton1Up = true, MouseButton2Click = true, InputBegan = true, InputEnded = true,
    FocusLost = true, Focused = true, Changed = true, ChildAdded = true, ChildRemoved = true, DescendantAdded = true,
    DescendantRemoving = true, Touched = true, TouchEnded = true, Triggered = true, Completed = true, Activated = true,
    Event = true, OnServerEvent = true, OnClientEvent = true, PlayerAdded = true, PlayerRemoving = true, Chatted = true,
    Heartbeat = true, RenderStepped = true, Stepped = true, MouseEnter = true, MouseLeave = true, AncestryChanged = true }

function newSignal()
    local s = { _cbs = {} }
    function s:Connect(fn) table.insert(self._cbs, fn); return { Disconnect = function() end } end
    function s:Once(fn) return self:Connect(fn) end
    function s:Wait() return end
    function s:Fire(...) for _, cb in ipairs(self._cbs) do cb(...) end end
    return s
end

local instanceMeta = {}
local function isA(self, cls)
    local c = rawget(self, "ClassName")
    if c == cls then return true end
    if cls == "GuiObject" then return GUI_OBJECT[c] == true end
    if cls == "GuiButton" then return BUTTONS[c] == true end
    if cls == "BasePart" then return c == "Part" or c == "SpawnLocation" end
    if cls == "LayerCollector" then return c == "ScreenGui" end
    return false
end

local function descendants(self, out)
    for _, k in ipairs(rawget(self, "_kids")) do table.insert(out, k); descendants(k, out) end
    return out
end

local function find(self, name, recursive)
    for _, k in ipairs(rawget(self, "_kids")) do
        if rawget(k, "Name") == name then return k end
    end
    if recursive then
        for _, k in ipairs(rawget(self, "_kids")) do
            local r = find(k, name, true)
            if r then return r end
        end
    end
    return nil
end

local methods = {
    IsA = isA,
    FindFirstChild = function(self, n, r) return find(self, n, r) end,
    FindFirstChildOfClass = function(self, c) for _, k in ipairs(rawget(self, "_kids")) do if rawget(k, "ClassName") == c then return k end end end,
    FindFirstChildWhichIsA = function(self, c) for _, k in ipairs(rawget(self, "_kids")) do if isA(k, c) then return k end end end,
    WaitForChild = function(self, n) return find(self, n, false) or Instance.new("Folder", nil, n, self) end,
    GetChildren = function(self) local t = {} for i, k in ipairs(rawget(self, "_kids")) do t[i] = k end return t end,
    GetDescendants = function(self) return descendants(self, {}) end,
    Destroy = function(self) self.Parent = nil; rawset(self, "_destroyed", true) end,
    ClearAllChildren = function(self) for _, k in ipairs(self:GetChildren()) do k:Destroy() end end,
    IsDescendantOf = function(self, other) local p = rawget(self, "_parent") while p do if p == other then return true end p = rawget(p, "_parent") end return false end,
    SetAttribute = function(self, k, v) rawget(self, "_attrs")[k] = v; local s = rawget(self, "_propSignals")["attr:" .. k]; if s then s:Fire() end end,
    GetAttributeChangedSignal = function(self, k) local ps = rawget(self, "_propSignals"); if not ps["attr:" .. k] then ps["attr:" .. k] = newSignal() end return ps["attr:" .. k] end,
    GetAttribute = function(self, k) return rawget(self, "_attrs")[k] end,
    GetPropertyChangedSignal = function(self, prop)
        local s = rawget(self, "_propSignals")
        if not s[prop] then s[prop] = newSignal() end
        return s[prop]
    end,
    Clone = function(self) return Instance.new(rawget(self, "ClassName")) end,
    Play = function() end, Stop = function() end, Pause = function() end,
    Invoke = function(self, ...) local f = rawget(self, "_props").OnInvoke; if f then return f(...) end end,
    FireServer = function(self, ...) table.insert(rawget(self, "_fired"), { ... }) end,
    FireClient = function(self, ...) end,
    PivotTo = function(self, cf) rawset(self, "_pivot", cf) end,
    GetPivot = function(self) return rawget(self, "_pivot") or { Position = Vector3.new(0, 5, 0) } end,
    ScrollTo = function() end, CaptureFocus = function() end, ReleaseFocus = function() end,
}

instanceMeta.__index = function(self, key)
    local props = rawget(self, "_props")
    if props[key] ~= nil then return props[key] end
    if key == "Parent" then return rawget(self, "_parent") end
    if key == "Name" then return rawget(self, "Name") end
    if key == "ClassName" then return rawget(self, "ClassName") end
    if methods[key] then return methods[key] end
    if SIGNALS[key] then
        local sig = rawget(self, "_signals")
        if not sig[key] then sig[key] = newSignal() end
        return sig[key]
    end
    if key == "AbsoluteSize" then return Vector2.new(400, 400) end
    if key == "AbsolutePosition" then return Vector2.new(0, 0) end
    return nil
end

instanceMeta.__newindex = function(self, key, value)
    if key == "Parent" then
        local old = rawget(self, "_parent")
        if old then
            local kids = rawget(old, "_kids")
            for i, k in ipairs(kids) do if k == self then table.remove(kids, i) break end end
        end
        rawset(self, "_parent", value)
        if value then table.insert(rawget(value, "_kids"), self) end
    elseif key == "Name" then
        rawset(self, "Name", value)
    else
        rawget(self, "_props")[key] = value
        local ps = rawget(self, "_propSignals")[key]
        if ps then ps:Fire() end
    end
end

Instance = {
    new = function(class, parent, name, forceParent)
        local o = setmetatable({ ClassName = class, Name = name or class, _kids = {}, _props = {}, _signals = {}, _propSignals = {},
            _attrs = {}, _fired = {}, _parent = nil }, instanceMeta)
        if class == "ScrollingFrame" then rawget(o, "_props").AbsoluteCanvasSize = Vector2.new(0, 0) end
        local p = forceParent or parent
        if p then o.Parent = p end
        return o
    end,
}

-- extra value types the UI code uses
NumberRange = { new = function(a, b) return { Min = a, Max = b or a } end }
NumberSequence = { new = function(a, b) return { a, b } end }
ColorSequence = { new = function(a, b) return { a, b } end }
ColorSequenceKeypoint = { new = function(t, c) return { Time = t, Value = c } end }
TweenInfo = { new = function() return {} end }
Random = { new = function(seed)
    local state = seed or 1
    return { NextInteger = function(_, a, b) state = (state * 1103515245 + 12345) % 2147483648; return a + state % (b - a + 1) end,
             NextNumber = function(_, a, b) state = (state * 1103515245 + 12345) % 2147483648; return (a or 0) + (state / 2147483648) * ((b or 1) - (a or 0)) end } end }
local V3 = {}
V3.__index = V3
V3.__mul = function(a, b)
    if type(a) == "number" then a, b = b, a end
    if type(b) == "number" then return setmetatable({ X = a.X * b, Y = a.Y * b, Z = a.Z * b }, V3) end
    return setmetatable({ X = a.X * b.X, Y = a.Y * b.Y, Z = a.Z * b.Z }, V3)
end
V3.__add = function(a, b) return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, V3) end
V3.__sub = function(a, b) return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z }, V3) end
Vector2 = { new = function(x, y) return { X = x, Y = y, Magnitude = 0 } end }
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end }
local CF = {}
CF.__index = CF
CF.__mul = function(a, b)
    if getmetatable(b) == V3 then return b end
    return setmetatable({ Position = a.Position }, CF)
end
CFrame = {
    new = function(x, y, z)
        local pos = type(x) == "table" and x or Vector3.new(x, y, z)
        return setmetatable({ Position = pos }, CF)
    end,
    Angles = function() return setmetatable({ Position = Vector3.new(0, 0, 0) }, CF) end,
    lookAt = function(a) return setmetatable({ Position = a }, CF) end,
}
Color3.fromHSV = function(h, s, v) return Color3.fromRGB(h * 255, s * 255, v * 255) end
Color3.new = Color3.new

-- services the UI touches
local tweenService = { Create = function() local t = Instance.new("Tween"); return t end }
local collection = { GetTagged = function() return {} end, AddTag = function() end,
    GetInstanceAddedSignal = function() return newSignal() end, GetInstanceRemovedSignal = function() return newSignal() end }
local marketplace = { PromptProductPurchase = function(_, _, id) _G_PURCHASE_PROMPTS = (_G_PURCHASE_PROMPTS or 0) + 1 end, ProcessReceipt = nil }
local playerGui = Instance.new("PlayerGui")
LocalPlayerMock = Instance.new("Player")
LocalPlayerMock.UserId = 999
LocalPlayerMock.Name = "Me"; LocalPlayerMock.DisplayName = "Me"
LocalPlayerMock.PlayerGui = playerGui
playerGui.Parent = LocalPlayerMock
LocalPlayerMock.PlayerScripts = Instance.new("Folder", LocalPlayerMock)
PlayerGui = playerGui

local realGetService = game.GetService
local services = {
    TweenService = tweenService, CollectionService = collection, MarketplaceService = marketplace,
    RunService = { IsStudio = function() return true end, Heartbeat = newSignal(), RenderStepped = newSignal() },
    SoundService = Instance.new("Folder"), ContentProvider = {}, ReplicatedFirst = { RemoveDefaultLoadingScreen = function() end },
    Lighting = Instance.new("Lighting"),
    ProximityPromptService = { PromptTriggered = newSignal() },
    UserInputService = { InputBegan = newSignal(), GetFocusedTextBox = function() return nil end },
    Players = setmetatable({ LocalPlayer = LocalPlayerMock, PlayerAdded = newSignal(), PlayerRemoving = newSignal(),
        _list = {}, GetPlayers = function(self) return self._list end,
        GetPlayerByUserId = function() return nil end }, {}),
}
rawset(game, "GetService", function(_, name) return services[name] or realGetService(game, name) end)
workspace = Instance.new("Workspace")
workspace.CurrentCamera = { ViewportSize = Vector2.new(1280, 720), GetPropertyChangedSignal = function() return newSignal() end,
    CFrame = { Position = Vector3.new(0, 0, 0) } }

-- RemoteEvents: fake remotes with signals + recorders, built from the declarations in the real module
fakeRemotes = {}
function installFakeRemotes(handlers)
    handlers = handlers or {}
    local RemoteEvents = load("game/ReplicatedStorage/Shared/Modules/RemoteEvents")
    local src = SOURCES["src/Shared/Modules/RemoteEvents.lua"]
    for name, kind in src:gmatch("%s+(%w+)%s*=%s*\"(%w+)\"") do
        if kind == "event" or kind == "function" then
            local remote = { OnClientEvent = newSignal(), OnServerEvent = newSignal(), fired = {} }
            function remote:FireServer(...) table.insert(self.fired, { ... }) end
            function remote:FireClient() end
            function remote:InvokeServer(...)
                local h = handlers[name]
                if type(h) == "function" then return h(...) end
                return h
            end
            RemoteEvents[name] = remote
            fakeRemotes[name] = remote
        end
    end
    RemoteEvents.Load = function() end
    return RemoteEvents
end

-- run a StarterGui / client script file in a fresh environment; returns ok, err
function runScriptFile(path)
    local src = SOURCES[path]
    assert(src, "no source " .. path)
    local fn, err = loadstring(src, path)
    if not fn then return false, err end
    local env = setmetatable({}, { __index = getfenv(1) })
    env.script = Instance.new("LocalScript"); env.script.Name = path:match("([^/]+)%.lua$")
    setfenv(fn, env)
    return pcall(fn)
end
