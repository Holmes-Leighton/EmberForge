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

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
