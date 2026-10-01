QUIET = true
-- Forge Builder: stock, buying, placing, perks and their cap.
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local FB = load("SSS/EmberForge/Services/ForgeBuildService")
local FD = load("game/ReplicatedStorage/Shared/Data/ForgeBuildData")
local IE = load("SSS/EmberForge/Services/IdleEngine")

local function mk(id, name, coins)
    local p = newPlayer(id, name)
    local d = PDS.Load(p)
    d.EmberCoins = coins or 100000
    return p, d
end

print("== the catalogue")
for _, it in ipairs(FD.Items) do
    expect(it.price > 0 and it.height > 0 and it.maxOwned >= 1, it.id .. " has a price, height and limit")
    expect(it.category == "decor" or it.perk ~= nil, it.id .. " is decor or has a perk")
    if it.perk then for stat, v in pairs(it.perk) do expect(v > 0 and v <= 0.10, it.id .. " perk " .. stat .. " is small") end end
end

print("== stock")
local now = os.time()
local stock = FD.Stock(now)
expect(table.find(stock, "Hearth") and table.find(stock, "LanternPost") and table.find(stock, "MineCart"), "starter pieces are always in stock")
local same = FD.Stock(now + 5)
expect(#same == #stock, "stock is stable within a restock")
local differ = false
for h = 1, 40 do if #FD.Stock(now + h * 300) ~= #stock then differ = true end end
expect(differ, "stock changes between restocks")
local rareSeen = 0
for h = 0, 199 do if table.find(FD.Stock(now + h * 300), "CrystalPedestal") then rareSeen += 1 end end
expect(rareSeen > 5 and rareSeen < 80, "the Epic piece is rarely in stock (" .. rareSeen .. "/200)")

print("== buying")
local a, da = mk(1, "Ada")
local ok, err = FB.Buy(a, "Hearth")
expect(ok and da.EmberCoins == 100000 - 600 and da.ForgeBuild.owned.Hearth == 1, "buy a Hearth for its price (" .. tostring(err) .. ")")
local ok2, err2 = FB.Buy(a, "Hearth")
expect(not ok2 and err2:find("at most"), "can't own more than the limit (" .. tostring(err2) .. ")")
for i = 1, 3 do FB.Buy(a, "MineCart") end
local ok3, err3 = FB.Buy(a, "MineCart")
expect(not ok3, "a piece is limited per restock or by ownership (" .. tostring(err3) .. ")")
local ok4, err4 = FB.Buy(a, "Nonsense")
expect(not ok4, "unknown piece refused")
local poor = mk(2, "Poor", 10)
local ok5, err5 = FB.Buy(poor, "LanternPost")
expect(not ok5 and err5:find("coins"), "not enough coins refused (" .. tostring(err5) .. ")")

print("== placing")
local okp, perr = FB.Place(a, "Hearth", 15, 15, 0)
expect(okp, "place a Hearth (" .. tostring(perr) .. ")")
expect(not FB.Place(a, "Hearth", 20, 20, 0), "no second Hearth to place")
expect(not FB.Place(a, "MineCart", 3, 3, 0), "the middle of the forge stays clear")
expect(not FB.Place(a, "MineCart", 40, 0, 0), "outside the plot is refused")
expect(not FB.Place(a, "MineCart", 15.4, 15.2, 0), "too close to another piece is refused")
expect(not FB.Place(a, "MineCart", 0 / 0, 5, 0), "NaN position refused")
expect(FB.Place(a, "MineCart", -15, 15, 45) and da.ForgeBuild.placed[2].rot == 90 or da.ForgeBuild.placed[2].rot == 0, "rotation snaps to 90 degrees")
expect(not FB.Place(a, "Waterwheel", 15, -15, 0), "can't place what you don't own")

print("== perks")
local snap = FB.Snapshot(a)
expect(snap.perks.rate == 0.03 and snap.perks.carry == 0.03, "Hearth +3% speed and a Mine Cart +3% carry")
local auras = IE.CrewAuras(da)
expect(math.abs(auras.rate - 0.03) < 1e-9 and math.abs(auras.carry - 0.03) < 1e-9, "IdleEngine reads them")
-- only the best fire counts
local d2 = { ForgeBuild = { placed = { { id = "Hearth" }, { id = "IronFurnace" }, { id = "MoltenForge" } } } }
expect(math.abs(FD.Perks(d2.ForgeBuild.placed).rate - 0.10) < 1e-9, "only the best fire counts (+10%)")
-- caps
local many = {}
for i = 1, 24 do many[i] = { id = "Grindstone" } end
expect(FD.Perks(many).wear == FD.BUILD_CAP, "a stat is capped at " .. FD.BUILD_CAP)

print("== picking up and selling")
expect(not FB.Sell(a, "Hearth"), "can't sell a placed piece")
expect(FB.Pickup(a, 1) and #da.ForgeBuild.placed == 1, "pick a piece back up")
local before = da.EmberCoins
local sold, refund = FB.Sell(a, "Hearth")
expect(sold and refund == 300 and da.EmberCoins == before + 300 and da.ForgeBuild.owned.Hearth == nil, "selling refunds half")
expect(not FB.Pickup(a, 99), "bad index refused")

print("== a full plot")
local b, db = mk(3, "Bo")
db.ForgeBuild = { owned = { LanternPost = 99 }, placed = {}, bought = { slot = 0, counts = {} } }
local placed = 0
for i = 0, 40 do
    local x = -26 + (i % 9) * 6
    local z = (i < 9) and 14 or (i < 18) and 20 or (i < 27) and 26 or (i < 36) and -14 or -20
    if FB.Place(b, "LanternPost", x, z, 0) then placed += 1 end
end
expect(placed == FD.MAX_PLACED, "no more than " .. FD.MAX_PLACED .. " pieces (" .. placed .. ")")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
