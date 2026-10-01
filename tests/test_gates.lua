QUIET = true
local FG = load("game/ReplicatedStorage/Shared/Data/FeatureGates")

print("== feature gates")
local ok, reason, label = FG.Check("Pets", { PlayerLevel = 1 })
expect(not ok and label == "Level 2" and reason:find("Level 2"), "Pets are locked below player level 2 (" .. tostring(label) .. ")")
expect(FG.Check("Pets", { PlayerLevel = 2 }), "and open at level 2")
expect(FG.Check("Quarry", { ForgeLevel = 5 }) == false and FG.Check("Quarry", { ForgeLevel = 6 }), "the Quarry follows Forge Level")

print("== gates inside menus")
local okF, _, lbl = FG.Check("Fusion", { PlayerLevel = 5 })
expect(not okF and lbl == "Level 6", "Golem fusion is locked until level 6")
expect(FG.Check("Fusion", { PlayerLevel = 6 }), "and opens at 6")
local okE, why = FG.Check("EliteForge", { PlayerLevel = 7 })
expect(not okE and why:find("The Elite Forge") and why:find("8"), "the Elite Forge is locked until level 8 (" .. tostring(why) .. ")")
expect(FG.Check("EliteForge", { PlayerLevel = 8 }), "and opens at 8")
expect(not FG.Check("PetMerge", { PlayerLevel = 3 }) and FG.Check("PetMerge", { PlayerLevel = 6 }), "pet merging opens at level 6")
for id, def in pairs(FG.InMenu) do
    expect(def.level and def.level >= 2 and def.name, id .. " has a level and a name")
end
print("== Ascend tile")
expect(not FG.Revealed("AscendButton", { ForgeLevel = 9 }) and FG.Revealed("AscendButton", { ForgeLevel = 10 }), "the Ascend tile appears at Forge Level 10")
expect(FG.Revealed("ForgeButton", { ForgeLevel = 1 }), "other tiles are always shown")
print("== Anvil lists every Golem")
local CR = load("game/ReplicatedStorage/Shared/Modules/CraftRules")
local RD = load("game/ReplicatedStorage/Shared/Data/RecipeData")
local fresh = { Blueprints = { "BP_Ember_T1" }, ForgeLevel = 1, Inventory = {}, Golems = {} }
local owned = CR.ListBlueprints(fresh, {})
local everything = CR.ListBlueprints(fresh, {}, true)
local total = 0
for _, bp in pairs(RD.Blueprints) do if bp.element then total += 1 end end
expect(#owned == 1, "by default only owned blueprints are listed (" .. #owned .. ")")
expect(#everything == total and total > 5, "with the flag every Golem in the catalogue is listed (" .. #everything .. " of " .. total .. ")")
local locked = 0
for _, bp in ipairs(everything) do
    local why = CR.GetLockReason(fresh, bp, {})
    if bp.id ~= "BP_Ember_T1" then expect(why ~= nil, bp.id .. " is locked for a new player") end
    if why and why:find("not discovered") then locked += 1 end
end
expect(locked > 0, "undiscovered ones say so (" .. locked .. ")")
local found
for _, bp in pairs(RD.Blueprints) do if bp.source == RD.Source.RareDrop then found = bp break end end
expect(found and CR.HowToFind(found):find("rare"), "a rare-drop blueprint says where it comes from")
expect(CR.HowToFind(RD.Get("BP_Ember_T1")) == nil, "a starting blueprint needs no hint")
print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
