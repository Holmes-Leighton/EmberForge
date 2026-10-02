QUIET = true
local RemoteEvents = load("game/ReplicatedStorage/Shared/Modules/RemoteEvents")
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local Supplier = load("SSS/EmberForge/Services/SupplierService")
local SD = load("game/ReplicatedStorage/Shared/Data/SupplierData")
local MD = load("game/ReplicatedStorage/Shared/Data/MaterialData")

local p = newPlayer(1, "Shopper"); local d = PDS.Load(p)
d.EmberCoins = 1000

print("== catalogue")
local cat = Supplier.GetCatalog(p)
expect(#cat == #SD.Items and cat[1].name == "Basic Ore" and cat[1].bought == 0, "lists every item with names")
for _, item in ipairs(SD.Items) do
    if item.kind == "material" then
        local m = MD.Get(item.id)
        expect(m and (m.rarity == "Common" or m.rarity == "Uncommon"), item.id .. " is Common/Uncommon only (" .. tostring(m and m.rarity) .. ")")
    end
end

print("== buying")
local ok, msg = Supplier.Buy(p, "BasicOre", 100)
expect(ok and d.Inventory.BasicOre == 100 and d.EmberCoins == 700, "100 ore for 300 coins (" .. msg .. ")")
ok, msg = Supplier.Buy(p, "BasicOre", -5)
expect(not ok, "negative quantity refused")
ok = Supplier.Buy(p, "BasicOre", 2.5)
expect(not ok, "fractional quantity refused")
ok = Supplier.Buy(p, "BasicOre", 0/0)
expect(not ok, "NaN refused")
ok = Supplier.Buy(p, "Nope", 1)
expect(not ok, "unknown item refused")
ok = Supplier.Buy(p, "MoltenCore", 1)
expect(not ok, "Rare materials are not sold")
ok, msg = Supplier.Buy(p, "EmberDust", 40)
expect(not ok and d.EmberCoins == 700, "can't afford 40 Ember Dust (need 1200): " .. msg)

print("== daily limits")
d.EmberCoins = 100000
ok, msg = Supplier.Buy(p, "BasicOre", 501)
expect(not ok, "only 500 left today (" .. msg .. ")")
ok = Supplier.Buy(p, "BasicOre", 500)
expect(ok and d.Inventory.BasicOre == 600, "buys the remaining 500")
ok, msg = Supplier.Buy(p, "BasicOre", 1)
expect(not ok and msg:find("Sold out"), "then sold out: " .. msg)
advance(86400)
ok = Supplier.Buy(p, "BasicOre", 1)
expect(ok, "stock returns the next UTC day")

print("== speed-ups")
ok = Supplier.Buy(p, "SpeedUp", 2)
expect(ok and d.SpeedUps == 2, "speed-ups are added to the counter")
ok = Supplier.Buy(p, "SpeedUp", 1)
expect(not ok, "limited to 2 a day")

print("== selling surplus")
for id, price in pairs(SD.SellPrices) do
    local m = MD.Get(id)
    expect(m and (m.rarity == "Common" or m.rarity == "Uncommon"), id .. " sold to the Supplier is Common/Uncommon")
    local buy = SD.Get(id)
    expect(not buy or price < buy.price, id .. " sells for less than it costs (no profit loop)")
end
local q = newPlayer(2, "Seller"); local e = PDS.Load(q)
e.Inventory.BasicOre = 1000; e.Inventory.MoltenCore = 5
local before = e.EmberCoins
local cap = SD.SellCap(e)
expect(cap == 150 + 20 + 15, "level 1 / forge 1 allowance is 185 (" .. cap .. ")")
ok, msg = Supplier.Sell(q, "BasicOre", 100)
expect(ok and e.Inventory.BasicOre == 900 and e.EmberCoins == before + 100, "sells 100 ore for 100 coins (" .. msg .. ")")
ok = Supplier.Sell(q, "MoltenCore", 1)
expect(not ok and e.Inventory.MoltenCore == 5, "Rare materials are not bought")
ok = Supplier.Sell(q, "BasicOre", 5000)
expect(not ok, "can't sell more than you hold")
ok = Supplier.Sell(q, "BasicOre", -1); expect(not ok, "negative refused")
ok = Supplier.Sell(q, "BasicOre", 0/0); expect(not ok, "NaN refused")
ok, msg = Supplier.Sell(q, "BasicOre", 500)
expect(ok and e.EmberCoins == before + cap and e.Inventory.BasicOre == 900 - (cap - 100), "sale is cut to the daily allowance (" .. msg .. ")")
ok, msg = Supplier.Sell(q, "BasicOre", 1)
expect(not ok and msg:find("limit"), "then the limit blocks: " .. msg)
local bl = Supplier.GetBuyList(q)
expect(bl.earned == cap and bl.cap == cap and #bl.items == 1 and bl.items[1].id == "BasicOre", "buy list reports the allowance")
advance(86400)
ok = Supplier.Sell(q, "BasicOre", 10)
expect(ok, "the allowance resets the next UTC day")
e.PlayerLevel, e.ForgeLevel, e.Ascensions = 40, 10, 3
expect(SD.SellCap(e) == 150 + 800 + 150 + 750, "allowance grows with level, forge level and ascensions (" .. SD.SellCap(e) .. ")")
e.PlayerLevel = 9999
expect(SD.SellCap(e) == SD.SELL_CAP_MAX, "and is hard-capped")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
