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
advance(6)
ok, res = Trading.ConfirmTrade(alice, tid)
expect(ok and res == "waiting", "alice confirms, waiting")
Trading.AddToOffer(bob, tid, { type = "material", id = "BasicOre", qty = 5 })
local view = Trading.GetTradeView(alice, tid)
expect(view.youConfirmed == false and view.theyConfirmed == false, "editing an offer resets confirmations")
advance(6)
Trading.ConfirmTrade(alice, tid)
ok, res = Trading.ConfirmTrade(bob, tid)
expect(ok and type(res) == "table", "both confirmed -> executed")
expect(da.Inventory.Coal == 40 and (db.Inventory.Coal or 0) == 60, "coal moved 60 alice->bob")
expect(da.Inventory.BasicOre == 75 and db.Inventory.BasicOre == 25, "ore moved 15 bob->alice (bob had 40)")
local function tradeLines(d) local n = 0 for _, h in ipairs(d.TradeHistory) do if not h.market then n += 1 end end return n end
expect(tradeLines(da) == 1 and tradeLines(db) == 1, "history recorded for both")

print("== pets can be traded and sold")
for _, mine in ipairs(Trading.GetMyListings(alice)) do Trading.CancelListing(alice, mine.id) end
da.OwnedPets = { { id = "p1", type = "Ember", grown = 10 * 3600 }, { id = "p2", type = "Frost", grown = 0 }, { id = "p3", type = "Stone" } }
da.EquippedPets = { "p3" }
db.OwnedPets = {}
db.EquippedPets = {}
ok, err = Trading.ListOnMarket(alice, { type = "pet", id = "p3" }, 100)
expect(not ok and #da.OwnedPets == 3, "a worn pet cannot be listed (" .. tostring(err) .. ")")
ok, err = Trading.ListOnMarket(alice, { type = "pet", id = "nope" }, 100)
expect(not ok, "an unknown pet id is rejected")
local pl = Trading.ListOnMarket(alice, { type = "pet", id = "p1", junk = 1 }, 250)
expect(pl ~= nil and #da.OwnedPets == 2 and pl.pet and pl.pet.grown == 10 * 3600 and pl.item.type == "pet", "listing takes the real pet out of the seller's box")
db.EmberCoins = 1000
ok = Trading.BuyFromMarket(bob, pl.id)
expect(ok and #db.OwnedPets == 1 and db.OwnedPets[1].id == "p1" and db.OwnedPets[1].grown == 10 * 3600 and db.EmberCoins == 750, "buyer receives the same pet, growth kept")
local pl2 = Trading.ListOnMarket(alice, { type = "pet", id = "p2" }, 50)
ok = Trading.CancelListing(alice, pl2.id)
expect(ok and #da.OwnedPets == 2, "cancelling a pet listing returns the pet")

tid = Trading.InitiateTrade(alice, bob)
ok, err = Trading.AddToOffer(alice, tid, { type = "pet", id = "p3" })
expect(not ok, "a worn pet cannot be offered in a trade")
ok = Trading.AddToOffer(alice, tid, { type = "pet", id = "p2" })
expect(ok, "an unworn pet can be offered")
ok, err = Trading.AddToOffer(alice, tid, { type = "pet", id = "p2" })
expect(not ok, "the same pet cannot be offered twice")
Trading.AddToOffer(bob, tid, { type = "pet", id = "p1" })
advance(6)
Trading.ConfirmTrade(alice, tid)
ok, res = Trading.ConfirmTrade(bob, tid)
local function has(d, id) for _, p in ipairs(d.OwnedPets) do if p.id == id then return true end end return false end
expect(ok and has(da, "p1") and has(db, "p2") and not has(da, "p2") and not has(db, "p1"), "pets swapped between the two players")


print("== anti-scam: confirm lock, warnings, audit log")
tid = Trading.InitiateTrade(alice, bob)
da.Inventory.Coal = 500
db.Inventory.Coal = 500
Trading.AddToOffer(alice, tid, { type = "material", id = "Coal", qty = 10 })
Trading.AddToOffer(bob, tid, { type = "material", id = "Coal", qty = 10 })
ok, res, soft = Trading.ConfirmTrade(alice, tid)
expect(not ok and soft == true and tostring(res):find("can confirm in"), "confirming right after a change is refused, and the trade stays open (" .. tostring(res) .. ")")
expect(Trading.GetTradeView(alice, tid).lockSeconds > 0, "the view tells the client how long the lock lasts")
advance(3)
ok, res, soft = Trading.ConfirmTrade(alice, tid)
expect(not ok and soft, "still locked after 3 seconds")
-- a bait and switch: partner changes the offer just before alice presses confirm
advance(6)
Trading.AddToOffer(bob, tid, { type = "material", id = "Coal", qty = 1 })
ok, res, soft = Trading.ConfirmTrade(alice, tid)
expect(not ok and soft, "a last-second change locks confirming again")
Trading.RemoveFromOffer(alice, tid, 1)
Trading.RemoveFromOffer(bob, tid, 2)
Trading.RemoveFromOffer(bob, tid, 1)
ok, res, soft = Trading.ConfirmTrade(alice, tid)
expect(not ok and soft and tostring(res):find("Add something"), "an empty trade cannot be confirmed")
-- giving something for nothing needs a second, deliberate confirm
Trading.AddToOffer(alice, tid, { type = "material", id = "Coal", qty = 10 })
advance(6)
local w = Trading.GetTradeView(alice, tid).warning
expect(w and w:find("nothing"), "giving items for nothing is flagged in the view (" .. tostring(w) .. ")")
ok, res, soft = Trading.ConfirmTrade(alice, tid)
expect(not ok and soft and tostring(res):find("WARNING"), "the first confirm only shows the warning")
ok, res = Trading.ConfirmTrade(alice, tid)
expect(ok and res == "waiting", "the second confirm goes through")
-- a lopsided swap: a Legendary pet for a few common materials
Trading.CancelTrade(alice, tid)
da.OwnedPets = { { id = "lp", type = "Dragonbone", grown = 30 * 3600 } }
da.EquippedPets = {}
tid = Trading.InitiateTrade(alice, bob)
Trading.AddToOffer(alice, tid, { type = "pet", id = "lp" })
Trading.AddToOffer(bob, tid, { type = "material", id = "Coal", qty = 2 })
advance(6)
ok, res, soft = Trading.ConfirmTrade(alice, tid)
expect(not ok and soft and tostring(res):find("lopsided"), "an Epic pet for 2 coal is called lopsided (" .. tostring(res) .. ")")
expect(Trading.GetTradeView(bob, tid).warning == nil, "the player getting the good side is not warned")
Trading.CancelTrade(alice, tid)
expect(Trading.ValueOf({ type = "pet", petType = "Ember", rarity = "Common", grown = 0 }) < Trading.ValueOf({ type = "pet", petType = "Ember", rarity = "Common", variant = "MegaNeon", grown = 30 * 3600 }), "a Supreme Elder is worth far more than a Baby")

print("== the permanent log")
local log = Trading.GetLog(alice.UserId, 100)
local kinds = {}
for _, e in ipairs(log) do kinds[e.kind .. ":" .. e.result] = (kinds[e.kind .. ":" .. e.result] or 0) + 1 end
expect((kinds["trade:completed"] or 0) >= 2, "completed trades are logged (" .. tostring(kinds["trade:completed"]) .. ")")
expect((kinds["trade:cancelled"] or 0) >= 1, "cancelled trades are logged")
expect((kinds["market:listed"] or 0) >= 1 and (kinds["market:sold"] or 0) >= 1, "market listings and sales are logged")
local first
for _, e in ipairs(log) do if e.kind == "trade" and e.result == "completed" then first = e break end end
expect(first and first.partnerId == bob.UserId and #first.gave >= 1 and first.gave[1].type ~= nil, "an entry records the partner's user id and the full item detail")
local blog = Trading.GetLog(bob.UserId, 100)
local seenByBob = false
for _, e in ipairs(blog) do if e.kind == "trade" and e.result == "completed" and e.partnerId == alice.UserId then seenByBob = true end end
expect(seenByBob, "the other player's log has the same trade")
expect(#(da.TradeHistory or {}) <= 50, "the in-game history is capped at 50")

print("== blocking and reporting")
ok = Trading.SetBlocked(bob, alice.UserId, true)
expect(ok and db.BlockedTraders[tostring(alice.UserId)] == true, "bob blocks alice")
expect(Trading.IsBlocked(alice, bob) and Trading.IsBlocked(bob, alice), "a block works in both directions")
local tidB, errB = Trading.InitiateTrade(alice, bob)
expect(tidB == nil and tostring(errB):find("isn't available"), "a trade cannot start between blocked players (" .. tostring(errB) .. ")")
ok = Trading.SetBlocked(bob, alice.UserId, false)
expect(ok and not Trading.IsBlocked(alice, bob), "unblocking works")
ok = Trading.SetBlocked(bob, bob.UserId, true)
expect(not ok, "you cannot block yourself")
ok = Trading.SetBlocked(bob, "x", true)
expect(not ok, "a bad id is refused")
ok = Trading.Report(alice, bob.UserId, "scam")
expect(ok, "a report is accepted")
ok = Trading.Report(alice, bob.UserId, "scam")
expect(not ok, "the same player cannot be reported again straight away")
local reports = Trading.GetReports(bob.UserId)
expect(#reports == 1 and reports[1].reporter == alice.UserId and reports[1].reason == "scam", "the report is kept with who sent it")
ok = Trading.Report(alice, alice.UserId, "scam")
expect(not ok, "you cannot report yourself")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
