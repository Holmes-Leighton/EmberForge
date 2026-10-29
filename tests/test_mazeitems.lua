-- The player's side of the Hollow Maze's tools: noise, carrying and using an item, taking orbs, and hiding in a crate.
QUIET = true
local MD = load("game/ReplicatedStorage/Shared/Data/MazeData")
local ML = load("game/ReplicatedStorage/Shared/Modules/MazeLayout")
local MZ = load("game/ReplicatedStorage/Shared/Modules/MazeZombie")
local MI = load("game/ReplicatedStorage/Shared/Modules/MazeItems")

print("== noise from movement")
expect(MI.Noise(16, 16) == "run" and MI.Noise(12, 16) == "run", "moving at pace is running")
expect(MI.Noise(6, 16) == "walk", "a slow walk is walking")
expect(MI.Noise(0, 16) == "still" and MI.Noise(1.5, 16) == "still", "standing about is still")
expect(MI.Noise(30, 32) == "run", "it is relative to the player's own pace (a trained runner at 30 of 32 is running)")
expect(MI.Noise(nil, nil) == "still", "no data is still")

print("== carrying one item")
local rec = {}
expect(MI.Give(rec, "stun") and rec.item == "stun", "an empty-handed player can take an item")
expect(not MI.Give(rec, "freeze") and rec.item == "stun", "but not a second one")
expect(not MI.Give({}, "no-such-item"), "or something that does not exist")

print("== using each item")
local M = ML.Build({ seed = 31, base = MD.BASE })
local function fresh() local z = MZ.New(M) z.awake = true return z end

local z1 = fresh()
local r1 = { item = "stun" }
local ok1, e1 = MI.Use(r1, z1, 0, 0, 100)
expect(ok1 and e1.kind == "stun" and MZ.IsStunned(z1) and r1.item == nil, "Storm Jolt stuns the zombie and empties the hands")
local z2 = fresh()
local ok2, e2 = MI.Use({ item = "freeze" }, z2, 0, 0, 100)
expect(ok2 and z2.slowFactor == MD.ITEMS.Frost.slow and z2.slowUntil > z2.clock, "Frost Snap slows it to " .. MD.ITEMS.Frost.slow)
local z3 = fresh()
local ok3, e3 = MI.Use({ item = "flare" }, z3, 12, 34, 100, "flare-1")
expect(ok3 and #z3.decoys == 1 and z3.decoys[1].x == 12 and z3.decoys[1].z == 34 and e3.x == 12, "Decoy Flare drops a decoy where the player stands")
local r4 = { item = "sprint" }
local ok4, e4 = MI.Use(r4, fresh(), 0, 0, 100)
expect(ok4 and MI.Sprinting(r4, 102) and not MI.Sprinting(r4, 106) and e4.speed == 1.35, "Sprint Tonic: faster for 5 seconds, then it wears off")
local r5 = { item = "cloak" }
MI.Use(r5, fresh(), 0, 0, 100)
expect(MI.Cloaked(r5, 103) and not MI.Cloaked(r5, 107), "Void Cloak: cloaked for 6 seconds")
expect(not MI.Use({}, fresh(), 0, 0, 0), "with nothing in hand there is nothing to use")
expect(MI.SprintSpeed(16) == 16 * 1.35 and MI.SprintSpeed(36) == MD.SPRINT_MAX_WALK and MI.SprintSpeed(40) == 40, "the sprint is held under the anti-cheat's limit (" .. MI.SprintSpeed(36) .. ")")

print("== taking orbs")
local orb = { x = 100, z = 50, item = MD.ITEMS.Frost }
local orbs = { orb, { x = 200, z = 50, item = MD.ITEMS.Storm } }
expect(MI.OrbAt(orbs, 102, 52, 10) == orb, "an orb can be taken from inside its radius")
expect(MI.OrbAt(orbs, 100 + MD.PICKUP_RADIUS + 1, 50, 10) == nil, "and not from beyond it")
local rp = {}
expect(MI.TakeOrb(rp, orb, 10) == "freeze" and rp.item == "freeze", "taking it gives that item")
expect(MI.OrbAt(orbs, 100, 50, 20) == nil, "a taken orb is gone for a while")
expect(MI.OrbAt(orbs, 100, 50, 10 + MD.PICKUP_RESPAWN + 0.1) == orb, "and back after " .. MD.PICKUP_RESPAWN .. " seconds")
local full = { item = "stun" }
local orb2 = { x = 0, z = 0, item = MD.ITEMS.Ember }
expect(MI.TakeOrb(full, orb2, 0) == nil and orb2.takenUntil == nil and full.item == "stun", "full hands leave the orb where it is")

print("== hiding")
local rh = {}
expect(MI.CanHide(rh, 0) and MI.Hide(rh, 0) and MI.Hidden(rh), "a player can climb into a crate")
expect(not MI.Hide(rh, 1) and select(2, MI.Hide(rh, 1)) == "already", "not twice")
expect(not MI.HideExpired(rh, MD.HIDE_MAX - 0.1) and MI.HideExpired(rh, MD.HIDE_MAX), "after " .. MD.HIDE_MAX .. " seconds they are pushed out")
expect(MI.Unhide(rh, 5) and not MI.Hidden(rh), "or climb out")
local okAgain, why = MI.Hide(rh, 6)
expect(not okAgain and why == "cooldown", "but must rest before hiding again")
expect(MI.Hide(rh, 5 + MD.HIDE_COOLDOWN + 0.1), "and can after " .. MD.HIDE_COOLDOWN .. " seconds")
expect(not MI.Unhide({}, 0), "climbing out of nothing does nothing")

print("== what the zombie sees")
local rt = {}
local t = MI.TargetFor(rt, 7, 10, 20, 1, 15, 16, 100)
expect(t.id == 7 and t.x == 10 and t.noise == "run" and t.hidden == nil and t.cloaked == nil, "an ordinary runner is loud and plain")
MI.Hide(rt, 100)
expect(MI.TargetFor(rt, 7, 10, 20, 1, 0, 16, 100).hidden == true, "a hidden one is marked hidden")
local rc = { cloakUntil = 110 }
expect(MI.TargetFor(rc, 7, 0, 0, 1, 15, 16, 105).cloaked == true and MI.TargetFor(rc, 7, 0, 0, 1, 15, 16, 111).cloaked == nil, "a cloaked one is marked while the cloak lasts")

print("== it all works together: a stunned zombie cannot catch a player who was about to be caught")
local Mh = ML.Build({ seed = 31, base = MD.BASE })
local zz = MZ.New(Mh)
zz.awake = true
local x, _, zc = ML.CellCenter(Mh, 3, Mh.start.y)
zz.x, zz.z = x + 2, zc
local rec2 = { item = "stun" }
local target = { MI.TargetFor(rec2, 1, x, zc, 1, 15, 16, 0) }
MI.Use(rec2, zz, x, zc, 0)
local caught = MZ.Step(Mh, zz, target, 0.1, 30)
expect(#caught == 0, "the Jolt saves a player the zombie was already on top of")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
