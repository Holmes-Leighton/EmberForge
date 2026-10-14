-- The smelt dialog as a player uses it: select, unselect, select all (limited by free smelter slots), start smelting.
QUIET = true
installFakeRemotes({ GetPlayerData = function() return {} end })
assert(runScriptFile("src/StarterGui/SmeltDialogBuilder.client.lua"))
local dialog
for _, c in ipairs(PlayerGui:GetChildren()) do if c.Name == "SmeltDialog" then dialog = c end end
local open = dialog:FindFirstChild("Open")
local scroll = dialog:FindFirstChild("MaterialScroll", true)
local inv = { BasicOre = 120, IgniteOre = 40, ShadowDust = 15, GlacialCrystal = 30, ChargedFlint = 22, GraniteShard = 50 }

local function cards()
    local list = {}
    for _, c in ipairs(scroll:GetChildren()) do if c.ClassName == "Frame" and c:FindFirstChild("SelectBtn") then table.insert(list, c) end end
    return list
end
local function click(btn) btn.MouseButton1Click:Fire() end
local function picked()
    local n = 0
    for _, c in ipairs(cards()) do if c:FindFirstChild("SelectBtn").Text == "Selected" then n += 1 end end
    return n
end
local sent
local function sends() return #fakeRemotes.StartSmelt.fired end
local function reopen(free)
    fakeRemotes.StartSmelt.fired = {}
    dialog.Enabled = false
    open:Invoke(inv, free)
end
local function find(name) return dialog:FindFirstChild(name, true) end

print("== the list is shown rarest first, and Select All takes from the top")
reopen(5)
local orderOk, last = true, 0
for _, c in ipairs(cards()) do
    if c.LayoutOrder <= last then orderOk = false end
    last = c.LayoutOrder
end
expect(orderOk and cards()[1].LayoutOrder == 1, "cards carry an increasing LayoutOrder")
expect(find("MaterialScroll"):FindFirstChildOfClass("UIListLayout").SortOrder == Enum.SortOrder.LayoutOrder, "and the list obeys it")

print("== select and unselect")
reopen(5)
local list = cards()
expect(#list == 6, "six smeltable materials are listed (" .. #list .. ")")
click(list[1]:FindFirstChild("SelectBtn"))
expect(picked() == 1 and list[1]:FindFirstChild("SelectBtn").Text == "Selected", "clicking Select selects it")
click(list[1]:FindFirstChild("SelectBtn"))
expect(picked() == 0 and list[1]:FindFirstChild("SelectBtn").Text == "Select", "clicking it again unselects it")
click(list[2]:FindFirstChild("SelectBtn")); click(list[3]:FindFirstChild("SelectBtn"))
expect(picked() == 2, "several can be selected at once")
click(find("ClearSelectionButton"))
expect(picked() == 0, "Clear Selection empties it")

print("== smelting several at once")
click(list[1]:FindFirstChild("SelectBtn")); click(list[2]:FindFirstChild("SelectBtn")); click(list[3]:FindFirstChild("SelectBtn"))
click(find("ConfirmButton"))
expect(sends() == 3, "three selected materials send three smelts (" .. sends() .. ")")
local ids = {}
for _, f in ipairs(fakeRemotes.StartSmelt.fired) do ids[f[1]] = f[2] end
local ok = true
for _, c in ipairs({ list[1], list[2], list[3] }) do if ids[c.Name] ~= inv[c.Name] then ok = false end end
expect(ok, "each is sent with everything owned of it")
expect(dialog.Enabled == false, "the dialog closes")

print("== Select All stops at the free smelter slots")
reopen(3)
click(find("SelectAllButton"))
expect(picked() == 3, "3 free slots: Select All picks 3 of 6 (" .. picked() .. ")")
expect(find("SlotLimitLabel").Text:find("Only 3"), "and says why (" .. find("SlotLimitLabel").Text .. ")")
click(find("ConfirmButton"))
expect(sends() == 3, "and starts exactly 3 smelts")

print("== a pick beyond the free slots is refused")
reopen(2)
list = cards()
click(list[1]:FindFirstChild("SelectBtn")); click(list[2]:FindFirstChild("SelectBtn")); click(list[3]:FindFirstChild("SelectBtn"))
expect(picked() == 2, "the third pick is refused (" .. picked() .. " selected)")
click(list[2]:FindFirstChild("SelectBtn"))
click(list[3]:FindFirstChild("SelectBtn"))
expect(picked() == 2 and list[3]:FindFirstChild("SelectBtn").Text == "Selected", "unselecting one frees room for another")

print("== no free slots")
reopen(0)
list = cards()
click(list[1]:FindFirstChild("SelectBtn"))
expect(picked() == 0 and find("SlotLimitLabel").Text:find("No free"), "nothing can be selected (" .. find("SlotLimitLabel").Text .. ")")
click(find("ConfirmButton"))
expect(sends() == 0, "nothing is sent")

print("== plenty of slots: Select All takes everything")
reopen(10)
click(find("SelectAllButton"))
expect(picked() == 6, "all 6 selected")
click(find("SelectAllButton"))
click(find("ConfirmButton"))
expect(sends() == 6, "all 6 are smelted (" .. sends() .. ")")

print("== a single material still uses the quantity box")
reopen(5)
list = cards()
click(list[1]:FindFirstChild("SelectBtn"))
find("QtyInput").Text = "7"
click(find("ConfirmButton"))
expect(sends() == 1 and fakeRemotes.StartSmelt.fired[1][2] == 7, "one material, quantity 7")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
