QUIET = true
local RemoteEvents = load("game/ReplicatedStorage/Shared/Modules/RemoteEvents")
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local Bounty = load("SSS/EmberForge/Services/CartBountyService")
local CD = load("game/ReplicatedStorage/Shared/Data/CartBountyData")
load("SSS/EmberForge/Services/LiveOpsService").HourlyEnabled = false      -- these tests are about the base payouts, whatever event the mock clock happens to be in

print("== Mine Cart Delivery bounty")
local p = newPlayer(1, "Pusher"); local d = PDS.Load(p)
local start = d.EmberCoins
expect(CD.Reward(d) == 34, "a level 1 delivery pays 34 coins (" .. CD.Reward(d) .. ")")
expect(CD.Cap(d) == 135, "level 1 daily allowance is 135 (" .. CD.Cap(d) .. ")")

local ok, msg, coins = Bounty.Deliver(p)
expect(ok and coins == 34 and d.EmberCoins == start + 34, "a delivery pays the reward (" .. msg .. ")")
expect(d.CartBounty.deliveries == 1 and d.CartBounty.earned == 34, "and is counted")

for _ = 1, 2 do Bounty.Deliver(p) end
expect(d.CartBounty.earned == 102, "three deliveries earn 102")
ok, msg, coins = Bounty.Deliver(p)
expect(ok and coins == 33 and d.CartBounty.earned == 135, "the fourth is trimmed to what is left of the allowance (" .. coins .. ")")
ok, msg, coins = Bounty.Deliver(p)
expect(not ok and coins == 0 and msg:find("midnight"), "then the depot stops paying: " .. msg)
expect(d.EmberCoins == start + 135, "total from deliveries is the allowance")

advance(86400)
ok = Bounty.Deliver(p)
expect(ok, "the allowance resets the next UTC day")

d.PlayerLevel = 50
expect(CD.Reward(d) == 230 and CD.Cap(d) == 870, "rewards and allowance grow with level (" .. CD.Reward(d) .. "/" .. CD.Cap(d) .. ")")
d.PlayerLevel = 99999
expect(CD.Cap(d) == CD.CAP_MAX, "and the allowance is hard-capped")

print("== carts are bounty-ready")
expect(CD.DELIVER_AT < 55, "the delivery line is inside the 55-stud rail")
expect(CD.COOLDOWN > CD.RETURN_AFTER, "a cart reloads after it has rolled home")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
