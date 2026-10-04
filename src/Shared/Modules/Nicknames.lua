-- Player-chosen names for Golems and pets. Cleaning only (length, odd characters, markup); Roblox's text filter runs on the server (NicknameService).
local Nicknames = {}

Nicknames.MAX_LENGTH = 16       -- characters

-- Returns true + the cleaned name ("" means "remove the name"), or false + a reason players can read
function Nicknames.Clean(text)
    if type(text) ~= "string" then return false, "Type a name first" end
    text = text:gsub("%c", " ")                  -- tabs, line breaks and other control characters
    text = text:gsub("[<>&\"]", "")              -- menus use rich text, so no markup
    text = text:gsub("%s+", " ")
    text = text:match("^%s*(.-)%s*$")
    local len = utf8.len(text)
    if not len then return false, "That name has characters we can't use" end
    if len > Nicknames.MAX_LENGTH then
        return false, string.format("Names can be up to %d letters", Nicknames.MAX_LENGTH)
    end
    return true, text
end

-- Cuts text down to the limit without splitting a character (used while typing)
function Nicknames.Trim(text)
    local len = utf8.len(text)
    if not len then return "" end
    if len <= Nicknames.MAX_LENGTH then return text end
    return text:sub(1, utf8.offset(text, Nicknames.MAX_LENGTH + 1) - 1)
end

return Nicknames
