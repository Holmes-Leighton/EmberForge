QUIET = true
-- Pet maturity: stages, scaling bonuses, growth while worn, merging and old saves.
local RemoteEvents = load("game/ReplicatedStorage/Shared/Modules/RemoteEvents")
for _, n in ipairs({ "Notify", "PetHatched", "PetsMerged" }) do RemoteEvents[n] = fireCounter() end
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local PS = load("SSS/EmberForge/Services/PetService")
local PD = load("game/ReplicatedStorage/Shared/Data/PetData")

local function mk(id, coins)
    local p = newPlayer(id, "G" .. id)
    local d = PDS.Load(p)
    d.EmberCoins = coins or 100000
    return p, d
end
local H = 3600

print("== stages")
local function stageAt(hours) return PD.StageOf({ type = "Ember", grown = hours * H }) end
expect(stageAt(0).id == "Baby" and stageAt(1.9).id == "Young" == false and stageAt(2).id == "Young", "Baby until 2 hours, then Young")
expect(stageAt(7.9).id == "Young" and stageAt(8).id == "Adult" and stageAt(23.9).id == "Adult" and stageAt(24).id == "Elder" and stageAt(500).id == "Elder", "Young to 8h, Adult to 24h, then Elder")
local _, idx, prog, left = stageAt(5)
expect(idx == 2 and math.abs(prog - 0.5) < 1e-9 and math.abs(left - 3) < 1e-9, "5 hours in is halfway from Young to Adult, 3 hours to go")
local _, _, pe, le = stageAt(100)
expect(pe == 1 and le == nil, "an Elder has nothing left to grow")
expect(PD.StageOf({ type = "Ember" }).id == "Adult", "an old pet (no growth record) counts as Adult")

print("== the bonus grows with the pet")
local base = PD.Pets.Ember.value
expect(math.abs(PD.Value({ type = "Ember", grown = 0 }) - base * 0.6) < 1e-9, "a Baby gives 60% of the boost")
expect(math.abs(PD.Value({ type = "Ember", grown = 3 * H }) - base * 0.8) < 1e-9, "a Young pet 80%")
expect(math.abs(PD.Value({ type = "Ember" }) - base) < 1e-9, "an old pet gives its full boost (nothing is lost on update)")
expect(math.abs(PD.Value({ type = "Ember", grown = 30 * H }) - base * 1.25) < 1e-9, "an Elder gives 125%")
expect(math.abs(PD.Value({ type = "Ember", variant = "MegaNeon", grown = 30 * H }) - base * 2.0 * 1.25) < 1e-9, "variant and stage multiply")
local d = { OwnedPets = {}, EquippedPets = {} }
for i = 1, 2 do table.insert(d.OwnedPets, { id = "s" .. i, type = "All", variant = "MegaNeon", grown = 99 * H }) table.insert(d.EquippedPets, "s" .. i) end
local b = PD.Boosts(d)
expect(b.rate <= PD.STAT_CAP + 1e-9 and b.luck <= PD.STAT_CAP + 1e-9, "growth never pushes a stat past the +20% cap (" .. string.format("%.2f", b.rate) .. ")")
expect(PD.BoostText({ type = "Ember", grown = 0 }):find("1.8%%"), "the text shows the real current boost (" .. PD.BoostText({ type = "Ember", grown = 0 }) .. ")")

print("== growing while worn")
local a, da = mk(1)
PS.Hatch(a, "Basic")
local pet = da.OwnedPets[1]
expect(pet.grown == 0 and #da.EquippedPets == 1, "a new pet is a Baby, and is worn")
local grew = PS.Grow(a, 30)
expect(pet.grown == 30 and #grew == 0, "30 worn seconds count")
local grew2 = PS.Grow(a, 2 * H)
expect(#grew2 == 1 and grew2[1].stage.id == "Young", "crossing 2 hours turns it Young and says so")
expect(RemoteEvents.Notify.last and RemoteEvents.Notify.last[2] == "Your pet grew up!", "the player is told")
expect((a:GetAttribute("EFPets") or ""):find(":Young"), "the replicated string carries the stage (" .. tostring(a:GetAttribute("EFPets")) .. ")")
PS.Hatch(a, "Basic")
local second = da.OwnedPets[2]
PS.Equip(a, second.id, false)                               -- put it away
PS.Grow(a, H)
expect(second.grown == 0, "a pet you are not wearing does not grow")
PS.Equip(a, pet.id, false)
local before = pet.grown
PS.Grow(a, H)
expect(pet.grown == before, "nothing grows when no pet is worn")

print("== merging and old saves")
local m, dm = mk(2)
dm.OwnedPets = {
    { id = "p1", type = "Ember", grown = 20 * H }, { id = "p2", type = "Ember", grown = 0 }, { id = "p3", type = "Ember", grown = 5 * H },
    { id = "p4", type = "Ember", grown = 1 * H }, { id = "p5", type = "Ember", grown = 30 * H },
}
dm.EquippedPets = {}
local merged = PS.Merge(m, "Ember", nil)
expect(merged and merged.variant == "Neon" and merged.grown == PD.MERGED_START_HOURS * H, "a merged pet starts Young, not Baby")
local left = {}
for _, p in ipairs(dm.OwnedPets) do if p.type == "Ember" and not p.variant then table.insert(left, p.id) end end
expect(#left == 1 and left[1] == "p5", "merging uses the youngest pets and keeps the most grown (kept " .. table.concat(left, ",") .. ")")
local oldPet = { id = "old", type = "Stone" }
expect(PD.StageOf(oldPet).id == "Adult" and PD.BoostText(oldPet):find("4.0"), "a pet from before maturity keeps its boost")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
