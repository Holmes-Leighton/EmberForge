-- Which parts of the game open up as the player grows. One table drives everything:
--   the HUD button shows a label saying what is needed ("Level 4") instead of opening, with a toast explaining why;
--   the server refuses the matching actions, so the rule cannot be skipped from the client.
-- Features not listed here are open from the start.
--   kind "player" = Player Level, kind "forge" = Forge Level.

local QuarryData = require(script.Parent.QuarryData)

local FeatureGates = {}

FeatureGates.List = {
    Pets   = { name = "Pets",   nav = "PetsButton",   kind = "player", level = 2 },
    Trades = { name = "Trades", nav = "TradeButton",  kind = "player", level = 3 },
    Build  = { name = "Build",  nav = "BuildButton",  kind = "player", level = 4 },
    Guild  = { name = "Guilds", nav = "GuildButton",  kind = "player", level = 5 },
    Quarry = { name = "The Quarry", nav = "QuarryButton", kind = "forge", level = QuarryData.UNLOCK_FORGE_LEVEL },
}

local function Have(def, data)
    if def.kind == "forge" then return (data and data.ForgeLevel) or 1 end
    return (data and data.PlayerLevel) or 1
end

-- ok, reason (long, for toasts), label (short, for the button)
function FeatureGates.Check(id, data)
    local def = FeatureGates.List[id]
    if not def then return true end
    local have = Have(def, data)
    if have >= def.level then return true end
    local what = def.kind == "forge" and "Forge Level" or "Level"
    return false,
        string.format("%s: available at %s %d (you are %s %d)", def.name, what, def.level, what, have),
        (def.kind == "forge" and "Forge " or "Level ") .. def.level
end

return FeatureGates
