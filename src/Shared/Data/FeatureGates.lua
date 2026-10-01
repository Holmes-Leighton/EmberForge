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

-- Options inside a menu that open later than the menu itself. `button` is the name of the control the client locks (found anywhere in
-- PlayerGui); the server refuses the action either way. Pet merging has no fixed button (its buttons are rebuilt each time), so it is
-- only enforced on the server, which tells the player why.
FeatureGates.InMenu = {
    Fusion     = { name = "Golem fusion", kind = "player", level = 6, button = "FuseGolemsButton" },
    EliteForge = { name = "The Elite Forge", kind = "player", level = 8, button = "Elite ForgeTab" },
    PetMerge   = { name = "Pet merging", kind = "player", level = 6 },
}

-- HUD tiles that stay hidden until the player is far enough along (the opposite of a lock: nothing to show yet)
FeatureGates.Reveal = {
    AscendButton = { kind = "forge", level = 10 },       -- Ascension lives in the Build menu until Forge Level 10 (AscensionData.FORGE_LEVEL)
}

function FeatureGates.Revealed(buttonName, data)
    local def = FeatureGates.Reveal[buttonName]
    if not def then return true end
    local have = def.kind == "forge" and ((data and data.ForgeLevel) or 1) or ((data and data.PlayerLevel) or 1)
    return have >= def.level
end

-- Options that only work in a particular place. Checked after the level rules; `need` is a value of the player's "EFPlace" attribute
-- (set by ForgeZoneService.PlaceOf). With no place known they stay open.
FeatureGates.PlaceRules = {
    Build = { need = "MyForge", name = "Build", label = "At your forge", reason = "Build: go to your own forge to build (the My Forge button takes you there)" },
}

-- Buttons that make no sense where you already are (not a lock: just a label)
FeatureGates.Here = {
    HomeButton = { place = "MyForge", label = "You're home", reason = "You are already at your forge." },
}

local function Have(def, data)
    if def.kind == "forge" then return (data and data.ForgeLevel) or 1 end
    return (data and data.PlayerLevel) or 1
end

-- ok, reason (long, for toasts), label (short, for the button).  `place` is the player's current EFPlace (optional).
function FeatureGates.Check(id, data, place)
    local def = FeatureGates.List[id] or FeatureGates.InMenu[id]
    if def then
        local have = Have(def, data)
        if have < def.level then
            local what = def.kind == "forge" and "Forge Level" or "Level"
            return false,
                string.format("%s: available at %s %d (you are %s %d)", def.name, what, def.level, what, have),
                (def.kind == "forge" and "Forge " or "Level ") .. def.level
        end
    end
    local rule = FeatureGates.PlaceRules[id]
    if rule and place and place ~= rule.need then return false, rule.reason, rule.label end
    return true
end

return FeatureGates
