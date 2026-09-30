-- ── Minimal Roblox mock: enough to load and exercise the server modules ─────────
local clock = 1000000
local realOs = os
os = setmetatable({ time = function() return clock end }, { __index = realOs })
function advance(s) clock = clock + s end
tick = function() return clock end

-- coroutine-based task lib: infinite service loops yield at their first wait and are abandoned
local spawnDepth = 0
task = {
    spawn = function(f, ...)
        local co = coroutine.create(f)
        spawnDepth += 1
        local ok, e = coroutine.resume(co, ...)
        spawnDepth -= 1
        if not ok then print("[task.spawn error]", e) end
        return co
    end,
    wait = function(t) if spawnDepth > 0 then coroutine.yield() end return t or 0 end,
    delay = function(t, f) end,
    defer = function(f, ...) f(...) end,
}
warn = function(...) if QUIET then return end print("[warn]", ...) end

local guidN = 0
local Players = { _list = {}, GetPlayers = function(self) return self._list end,
    GetPlayerByUserId = function(self, id) for _, p in ipairs(self._list) do if p.UserId == id then return p end end end }
local stubs = {
    Players = Players,
    RunService = { IsStudio = function() return true end, Heartbeat = { Connect = function() end } },
    HttpService = { GenerateGUID = function() guidN += 1; return "guid-" .. guidN end },
    DataStoreService = { GetDataStore = function() error("Studio: publish to access DataStore") end,
                         GetOrderedDataStore = function() error("Studio") end },
    MarketplaceService = (function()
        local handlers = {}
        local m = { _owned = {}, prompted = {} }
        m.PromptGamePassPurchaseFinished = { Connect = function(_, f) table.insert(handlers, f) end }
        m.FireGamePassFinished = function(player, id, purchased) for _, f in ipairs(handlers) do f(player, id, purchased) end end
        m.UserOwnsGamePassAsync = function(_, uid, id) return m._owned[uid .. ":" .. id] == true end
        m.PromptGamePassPurchase = function(_, player, id) table.insert(m.prompted, id) end
        return m
    end)(),
    ReplicatedStorage = { FindFirstChild = function() return nil end }, UserService = {},
}
local ColorMeta = {}
ColorMeta.__index = { Lerp = function(a, b, t) return setmetatable({ R = a.R + (b.R - a.R) * t, G = a.G + (b.G - a.G) * t, B = a.B + (b.B - a.B) * t }, ColorMeta) end }
Color3 = { fromRGB = function(r, g, b) return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, ColorMeta) end,
           new = function(r, g, b) return setmetatable({ R = r, G = g, B = b }, ColorMeta) end }
UDim = { new = function(s, o) return { Scale = s, Offset = o } end }
UDim2 = { new = function(xs, xo, ys, yo) return { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) } end }
Vector2 = { new = function(x, y) return { X = x, Y = y } end }
Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
Enum = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, v) return k .. "." .. v end }) end })

local function newObj(path, parent)
    local o = { __path = path, __parent = parent, __kids = {} }
    return setmetatable(o, { __index = function(t, k)
        if k == "Parent" then return rawget(t, "__parent") end
        local kids = rawget(t, "__kids")
        if not kids[k] then kids[k] = newObj(path .. "/" .. k, t) end
        return kids[k]
    end })
end

local root = newObj("game", nil)
game = setmetatable({ JobId = "job-A", CreatorType = "User", CreatorId = 1,
    GetService = function(_, n) return stubs[n] or {} end,
    BindToClose = function() end }, { __index = function(_, k) return root[k] end })

local loaded = {}
local function fileFor(path)
    local p = path:gsub("^game/ReplicatedStorage/Shared", "src/Shared"):gsub("^SSS/EmberForge", "src/Server")
        :gsub("^SPS/EmberForge", "src/Client")
    return p .. ".lua"
end
function moduleEnv(path)
    -- `script` for a module: an object whose Parent is its folder
    local dir = path:match("^(.*)/[^/]+$")
    local env = setmetatable({}, { __index = getfenv(1) })
    local function objFromPath(pp)
        local up = pp:match("^(.*)/[^/]+$")
        return newObj(pp, up and objFromPath(up) or nil)
    end
    local parent = objFromPath(dir)
    env.script = setmetatable({ Parent = parent, Name = path:match("([^/]+)$") }, { __index = function(_, k) return newObj(path .. "/" .. k, nil) end })
    return env
end
local realRequire = require
function require(obj)
    local path = rawget(obj, "__path")
    if loaded[path] then return loaded[path] end
    local file = fileFor(path)
    local src = SOURCES[file]
    if not src then error("mock require: no source for " .. path .. " (" .. file .. ")") end
    local fn, err = loadstring(src, file)
    if not fn then error(err) end
    setfenv(fn, moduleEnv(path))
    local v = fn()
    loaded[path] = v
    return v
end
-- module lookup by repo-style path, for tests
function load(p) return require(newObj(p, nil)) end
function newPlayer(id, name)
    local p = { UserId = id, Name = name, DisplayName = name, Parent = true, Character = nil }
    table.insert(Players._list, p)
    return p
end
function fireCounter() return setmetatable({ n = 0, last = nil }, { __index = { FireClient = function(self, ...) self.n += 1; self.last = { ... } end } }) end
function expect(cond, msg) if cond then print("  ok   " .. msg) else print("  FAIL " .. msg); FAILED = (FAILED or 0) + 1 end end
