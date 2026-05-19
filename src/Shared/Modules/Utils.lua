-- General-purpose utility functions shared between server and client.
local Utils = {}

-- Deep-copy a table
function Utils.DeepCopy(original)
    local copy
    if type(original) == "table" then
        copy = {}
        for k, v in pairs(original) do
            copy[Utils.DeepCopy(k)] = Utils.DeepCopy(v)
        end
        setmetatable(copy, getmetatable(original))
    else
        copy = original
    end
    return copy
end

-- Clamp a number between min and max
function Utils.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

-- Round a number to n decimal places
function Utils.Round(value, decimals)
    decimals = decimals or 0
    local mult = 10 ^ decimals
    return math.floor(value * mult + 0.5) / mult
end

-- Format a large number with K/M suffixes
function Utils.FormatNumber(n)
    if n >= 1000000 then
        return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n / 1000)
    else
        return tostring(math.floor(n))
    end
end

-- Format seconds as a readable countdown string
function Utils.FormatTime(seconds)
    seconds = math.floor(seconds)
    if seconds >= 3600 then
        local h = math.floor(seconds / 3600)
        local m = math.floor((seconds % 3600) / 60)
        return string.format("%dh %02dm", h, m)
    elseif seconds >= 60 then
        local m = math.floor(seconds / 60)
        local s = seconds % 60
        return string.format("%dm %02ds", m, s)
    else
        return string.format("%ds", seconds)
    end
end

-- Get current Unix timestamp (seconds since epoch)
function Utils.UnixTimestamp()
    return os.time()
end

-- Check if a table contains a value
function Utils.TableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then return true end
    end
    return false
end

-- Count entries in a mixed/hash table
function Utils.TableCount(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

-- Merge table b into table a (shallow, overwrites on conflict)
function Utils.MergeTable(a, b)
    for k, v in pairs(b) do
        a[k] = v
    end
    return a
end

-- Generate a simple unique ID using tick and a random suffix
function Utils.GenerateId()
    return string.format("%d_%d", math.floor(tick() * 1000), math.random(1000, 9999))
end

-- Weighted random selection: pool is array of { item, weight }
function Utils.WeightedRandom(pool)
    local total = 0
    for _, entry in ipairs(pool) do
        total = total + entry.weight
    end
    local roll = math.random() * total
    local cumulative = 0
    for _, entry in ipairs(pool) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry.item
        end
    end
    return pool[#pool].item
end

-- Safely get nested value: Utils.SafeGet(t, "a", "b", "c") → t.a.b.c or nil
function Utils.SafeGet(tbl, ...)
    local current = tbl
    for _, key in ipairs({...}) do
        if type(current) ~= "table" then return nil end
        current = current[key]
    end
    return current
end

-- Returns true if the player record passes a basic schema sanity check
function Utils.ValidatePlayerData(data)
    return type(data) == "table"
        and type(data.PlayerLevel) == "number"
        and type(data.ForgeLevel) == "number"
        and type(data.Golems) == "table"
        and type(data.Inventory) == "table"
        and type(data.Blueprints) == "table"
        and type(data.LastOnline) == "number"
end

return Utils
