QUIET = true
local RemoteEvents = load("game/ReplicatedStorage/Shared/Modules/RemoteEvents")
RemoteEvents.Notify = fireCounter()
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local Trading = load("SSS/EmberForge/Services/TradingService")

local alice, bob = newPlayer(1, "Alice"), newPlayer(2, "Bob")
local da = PDS.Load(alice); local db = PDS.Load(bob)
expect(da and db, "both players load")

da.Inventory.BasicOre = 100
da.Inventory.Coal = 50
db.EmberCoins = 1000
local golem = { id = "g1", element = "Frost", tier = 2, deployed = false }
table.insert(da.Golems, golem)

print("== market: hostile listings")
local before = da.Inventory.BasicOre
local l, err = Trading.ListOnMarket(alice, { type = "material", id = "BasicOre", qty = -1000 }, 50)
expect(l == nil and da.Inventory.BasicOre == before, "negative qty rejected, inventory unchanged (" .. tostring(err) .. ")")
l, err = Trading.ListOnMarket(alice, { type = "material", id = "BasicOre", qty = 1.5 }, 50)
expect(l == nil, "fractional qty rejected")
l, err = Trading.ListOnMarket(alice, { type = "material", id = "BasicOre", qty = 10 }, -5)
expect(l == nil, "negative price rejected")
l, err = Trading.ListOnMarket(alice, { type = "material", id = "BasicOre", qty = 10 }, 0/0)
expect(l == nil, "NaN price rejected")
l, err = Trading.ListOnMarket(alice, { type = "material", id = "BasicOre", qty = 10 }, 1e12)
expect(l == nil, "absurd price rejected")
l, err = Trading.ListOnMarket(alice, { type = "material", id = "BasicOre", qty = 101 }, 10)
expect(l == nil, "more than owned rejected")
l, err = Trading.ListOnMarket(alice, { type = "material", id = "Nonexistent", qty = 1 }, 10)
expect(l == nil, "unknown material rejected")
l, err = Trading.ListOnMarket(alice, { type = "blueprint", id = "BP_Ember_T1" }, 10)
expect(l == nil, "blueprint rejected")
l, err = Trading.ListOnMarket(alice, { type = "material", id = "EventCatalyst", qty = 1 }, 10)
expect(l == nil, "non-tradeable Event Catalyst rejected (" .. tostring(err) .. ")")
l, err = Trading.ListOnMarket(alice, "garbage", 10)
expect(l == nil, "non-table item rejected")

print("== market: valid material listing, then buy")
l, err = Trading.ListOnMarket(alice, { type = "material", id = "BasicOre", qty = 40, evil = "x" }, 100)
expect(l ~= nil and da.Inventory.BasicOre == 60, "valid listing takes exactly 40 ore")
expect(l.item.evil == nil, "client-supplied extra fields are dropped")
local ok, res = Trading.BuyFromMarket(alice, l.id)
expect(not ok, "cannot buy own listing")
ok, res = Trading.BuyFromMarket(bob, l.id)
expect(ok and db.Inventory.BasicOre == 40 and db.EmberCoins == 900, "buyer gets 40 ore for 100 coins")
ok, res = Trading.BuyFromMarket(bob, l.id)
expect(not ok, "second purchase of the same listing fails")

print("== market: golem listing keeps the real object")
l, err = Trading.ListOnMarket(alice, { type = "golem", id = "g1", junk = true }, 300)
expect(l ~= nil and #da.Golems == 0, "golem removed from seller")
ok, res = Trading.BuyFromMarket(bob, l.id)
local got = db.Golems[1]
expect(ok and got and got.element == "Frost" and got.tier == 2 and got.id == "g1", "buyer receives the real Frost T2 golem")
expect(rawequal(got, golem) or (got.element == "Frost"), "golem intact")

print("== market: deployed golem can't be listed; listing cap")
table.insert(da.Golems, { id = "g2", element = "Ember", tier = 1, deployed = true })
l, err = Trading.ListOnMarket(alice, { type = "golem", id = "g2" }, 10)
expect(l == nil, "deployed golem rejected (" .. tostring(err) .. ")")
da.Inventory.Coal = 1000
local count = 0
for i = 1, 25 do
    local x = Trading.ListOnMarket(alice, { type = "material", id = "Coal", qty = 1 }, 5)
    if x then count += 1 end
end
expect(count == 20 - 0 or count == 19 or count == 20, "listing cap enforced (created " .. count .. ")")

print("== direct trade")
da.Inventory.Coal = 100
local tid, e2 = Trading.InitiateTrade(alice, alice)
expect(tid == nil, "cannot trade with yourself")
tid = Trading.InitiateTrade(alice, bob)
expect(tid ~= nil, "trade opens")
local _, e3 = Trading.InitiateTrade(alice, bob)
expect(e3 ~= nil, "second simultaneous trade blocked")
ok, err = Trading.AddToOffer(alice, tid, { type = "material", id = "Coal", qty = -50 })
expect(not ok, "negative offer rejected")
ok, err = Trading.AddToOffer(alice, tid, { type = "material", id = "Coal", qty = 60 })
expect(ok, "valid offer accepted")
ok, err = Trading.AddToOffer(alice, tid, { type = "material", id = "Coal", qty = 60 })
expect(not ok, "same stack can't be offered twice beyond what's owned (" .. tostring(err) .. ")")
ok, err = Trading.AddToOffer(bob, tid, { type = "material", id = "BasicOre", qty = 10 })
expect(ok, "bob offers 10 ore")
ok, res = Trading.ConfirmTrade(alice, tid)
expect(ok and res == "waiting", "alice confirms, waiting")
Trading.AddToOffer(bob, tid, { type = "material", id = "BasicOre", qty = 5 })
local view = Trading.GetTradeView(alice, tid)
expect(view.youConfirmed == false and view.theyConfirmed == false, "editing an offer resets confirmations")
Trading.ConfirmTrade(alice, tid)
ok, res = Trading.ConfirmTrade(bob, tid)
expect(ok and type(res) == "table", "both confirmed -> executed")
expect(da.Inventory.Coal == 40 and (db.Inventory.Coal or 0) == 60, "coal moved 60 alice->bob")
expect(da.Inventory.BasicOre == 75 and db.Inventory.BasicOre == 25, "ore moved 15 bob->alice (bob had 40)")
expect(#da.TradeHistory == 1 and #db.TradeHistory == 1, "history recorded for both")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
