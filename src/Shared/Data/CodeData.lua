-- Redeemable codes (for creators, launches and events). Each code can be redeemed once per player.
-- Codes are matched ignoring case. `expires` is an optional unix time; `maxUses` an optional global cap that counts every
-- redemption on every server. Add new codes here and ship; nothing else needs changing.
local CodeData = {}

CodeData.Codes = {
    EMBERFORGE = { coins = 500, speedUps = 1, note = "Welcome to EmberForge!" },
    LAUNCH     = { coins = 1000, speedUps = 2, note = "Launch celebration" },
    GOLEMS     = { coins = 300, luckBoostSeconds = 1800, note = "Golem fans" },
}

function CodeData.Normalise(raw)
    if type(raw) ~= "string" then return nil end
    local code = raw:gsub("^%s+", ""):gsub("%s+$", ""):upper()
    if #code < 3 or #code > 24 or code:find("[^%w_]") then return nil end
    return code
end

function CodeData.Get(raw)
    local code = CodeData.Normalise(raw)
    return code and CodeData.Codes[code], code
end

return CodeData
