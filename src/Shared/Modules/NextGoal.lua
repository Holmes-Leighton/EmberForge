-- One line telling the player what to do next, shown on the HUD card. Pure: it only reads the player's data, so the server and tests can use it too.
local FeatureGates = require(script.Parent.Parent.Data.FeatureGates)
local ForgeData    = require(script.Parent.Parent.Data.ForgeData)
local GameConfig   = require(script.Parent.Parent.Data.GameConfig)

local NextGoal = {}

local function XPForLevel(level) return math.floor(100 * level ^ 1.8) end

local function Pretty(n)
    n = math.max(0, math.ceil(n))
    if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
    if n >= 1000 then return string.format("%.1fK", n / 1000) end
    return tostring(n)
end

-- Everything that opens by level, nearest first: { name, kind, level }
local function Locks()
    local list = {}
    for _, def in pairs(FeatureGates.List) do table.insert(list, def) end
    for _, def in pairs(FeatureGates.InMenu) do table.insert(list, def) end
    table.sort(list, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.name < b.name
    end)
    return list
end

function NextGoal.For(data)
    data = data or {}
    local golems = data.Golems or {}
    if #golems == 0 then return "Forge your first Golem at the Anvil" end

    local deployed = false
    for _, g in ipairs(golems) do if g.deployed then deployed = true break end end
    if not deployed then return "Deploy a Golem from the Forge menu" end

    local pending = 0
    for _, n in pairs(data.Pending or {}) do pending += n end
    if pending > 0 then return "Press Collect to bank what your Golems mined" end

    local level, xp = data.PlayerLevel or 1, data.PlayerXP or 0
    local forge, forgeXP = data.ForgeLevel or 1, data.ForgeXP or 0
    -- the nearest thing still locked
    for _, def in ipairs(Locks()) do
        if def.kind == "forge" then
            if forge < def.level then
                local need = (ForgeData.ByLevel[def.level] and ForgeData.ByLevel[def.level].xpRequired or 0) - forgeXP
                return string.format("Forge Level %d opens %s: %s Forge XP to go", def.level, def.name, Pretty(need))
            end
        elseif level < def.level then
            return string.format("Level %d opens %s: %s XP to go", def.level, def.name, Pretty(XPForLevel(def.level) - xp))
        end
    end

    if forge < GameConfig.MAX_FORGE_LEVEL then
        local nextFd = ForgeData.ByLevel[forge + 1]
        if nextFd then return string.format("Forge Level %d: %s Forge XP to go", forge + 1, Pretty(nextFd.xpRequired - forgeXP)) end
    end
    return "Ascend your Forge in the Build menu, or climb the Leaderboard"
end

return NextGoal
