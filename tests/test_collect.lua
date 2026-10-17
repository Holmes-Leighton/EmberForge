QUIET = true
-- Banking what the Golems mined happens by itself (CollectService): everything pending goes into the inventory, the bags are emptied, nothing happens in the Sky Tower or the
-- Hollow Maze, and the "collect" challenge is not completed in half a minute by the automatic collections.
local RemoteEvents = load("game/ReplicatedStorage/Shared/Modules/RemoteEvents")
RemoteEvents.Notify = fireCounter()
RemoteEvents.PendingUpdate = fireCounter()
RemoteEvents.ResourcesCollected = fireCounter()
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local CS = load("SSS/EmberForge/Services/CollectService")
local Challenge = load("SSS/EmberForge/Services/ChallengeService")

local p = newPlayer(41, "Miner")
local d = PDS.Load(p)
d.Golems = { { id = "g1", element = "Ember", tier = 1, deployed = true, _carriedResources = 40 } }
d.Pending = { BasicOre = 30, Coal = 5 }
local tracked = 0
local realTrack = Challenge.TrackEvent
Challenge.TrackEvent = function(_, name) if name == "GolemCollect" then tracked += 1 end end

print("== it banks by itself")
CS.Blocked = function() return nil end
CS.Tick()
expect((d.Inventory.BasicOre or 0) == 30 and (d.Inventory.Coal or 0) == 5, "pending ore and coal went into the inventory (" .. tostring(d.Inventory.BasicOre) .. ", " .. tostring(d.Inventory.Coal) .. ")")
expect(next(d.Pending) == nil and d.Golems[1]._carriedResources == 0, "the pool is empty and the Golem's bag is empty")
expect(RemoteEvents.ResourcesCollected.n == 1 and RemoteEvents.ResourcesCollected.last[3] == CS.AUTO, "the client is told, marked as automatic (" .. tostring(RemoteEvents.ResourcesCollected.last and RemoteEvents.ResourcesCollected.last[3]) .. ")")
CS.Tick()
expect(RemoteEvents.ResourcesCollected.n == 1, "nothing pending, nothing sent")

print("== not in the tower or the maze")
d.Pending = { BasicOre = 7 }
d.Golems[1]._carriedResources = 7
CS.Blocked = function() return "Hollow Maze" end
CS.Tick()
expect(d.Pending.BasicOre == 7 and (d.Inventory.BasicOre or 0) == 30 and d.Golems[1]._carriedResources == 7, "it waits while they are in the maze")
CS.Blocked = function() return nil end
CS.Tick()
expect((d.Inventory.BasicOre or 0) == 37 and next(d.Pending) == nil, "and is banked a moment after they are out")

print("== the collect challenge")
tracked = 0
for i = 1, 5 do d.Pending = { BasicOre = 1 } CS.Tick() end
expect(tracked == 0, "five automatic collections in a row do not complete a 'collect' challenge (counted " .. tracked .. ", one was counted already)")
d.Pending = { BasicOre = 3 }
local total = CS.Collect(p, CS.MANUAL)
expect(total == 3 and tracked == 1, "asking for it (the remote) always counts")

Challenge.TrackEvent = realTrack
print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
