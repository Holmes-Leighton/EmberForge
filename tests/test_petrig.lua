QUIET = true
-- Pet rig maths: gaits, idle, cheering, flying, and that every part of the segmented pet pack is classified.
local PR = load("game/ReplicatedStorage/Shared/Modules/PetRig")

local function ang(kind, sx, sz, st) local x, y, z = PR.Angles(kind, sx, sz, st) return x, y, z end
local still = { t = 3.3, walk = 0, gait = 0, happy = 0 }

print("== the parts the pet pack uses")
local PARTS = {
    Ember = "Body Head LegFL LegFR LegBL LegBR Tail Ears", Stone = "Shell Head LegFL LegFR LegBL LegBR Tail Crystals",
    Frost = "Body Head Ears ArmL ArmR LegL LegR Tail", Storm = "Body WingL WingR ArmL ArmR Tail Halo Sparks",
    Void = "Body Eyes ArmL ArmR Tail WispL WispR Hood", Patchwork = "Body Head ArmL ArmR LegL LegR Ears Tail",
    Woven = "Body Head LegFL LegFR LegBL LegBR Tail Ears", Coral = "Shell Body ClawL ClawR LegsL LegsR EyeStalks Anemone",
    Clockwork = "Body Head LegsL LegsR WingL WingR Antennae Gear", Alchemist = "Body Flask Cork ArmL ArmR Bubbles Tail Eyes",
    Gargoyle = "Body Head WingL WingR ArmL ArmR Legs Tail", StormJar = "Jar Cloud Lid LegL LegR ArmL ArmR Bolt",
    Dragonbone = "Body Head Jaw WingL WingR Legs Tail Horns", All = "Body RingA RingB ArmL ArmR Tail Crown Sparkles",
}
local unknown = {}
local main = { Body = true, Shell = true, Jar = true, Eyes = true, Crown = true }     -- body parts and fixed details that do not move
for pet, list in pairs(PARTS) do
    for name in list:gmatch("%S+") do
        if not main[name] and not PR.KindOf(name) then table.insert(unknown, pet .. "." .. name) end
    end
end
expect(#unknown == 0, "every moving part of every pet has a motion (" .. table.concat(unknown, ", ") .. ")")

print("== walking")
local walk = function(gait) return { t = 1, walk = 1, gait = gait, happy = 0 } end
local fl = ang("leg", -1, -1, walk(1.0))
local br = ang("leg", 1, 1, walk(1.0))
local fr = ang("leg", 1, -1, walk(1.0))
local bl = ang("leg", -1, 1, walk(1.0))
expect(math.abs(fl - br) < 1e-9 and math.abs(fr - bl) < 1e-9, "a quadruped trots in diagonal pairs")
expect(math.abs(fl + fr) < 1e-9 and math.abs(fl) > 0.3, "the two diagonal pairs swing against each other")
local l2 = ang("leg", -1, 0, walk(0.8))
local r2 = ang("leg", 1, 0, walk(0.8))
expect(math.abs(l2 + r2) < 1e-9 and math.abs(l2) > 0.2, "two legs alternate")
local maxLeg = 0
for g = 0, 6.3, 0.05 do maxLeg = math.max(maxLeg, math.abs((ang("leg", -1, -1, walk(g))))) end
expect(maxLeg > 0.7 and maxLeg < 1.0, "legs swing about 0.8 rad (" .. string.format("%.2f", maxLeg) .. ")")
local a1 = ang("arm", 1, 0, walk(1.0))
local legSameSide = ang("leg", 1, 0, walk(1.0))
expect(a1 * legSameSide < 0, "an arm swings against the leg on its side")
expect(ang("leg", -1, -1, { t = 1, walk = 0, gait = 1, happy = 0 }) == 0, "legs stay still when the pet is standing")

print("== standing")
for _, kind in ipairs({ "leg", "legs", "claw" }) do
    local x = ang(kind, 1, -1, still)
    expect(math.abs(x) < 0.1, kind .. " is nearly still when standing")
end
local _, lookY = ang("head", 0, 0, still)
expect(math.abs(lookY) <= 0.35 + 1e-9, "the head looks about (up to 0.35 rad)")
local _, _, wingZ = ang("wing", 1, 0, still)
expect(wingZ > 0 and wingZ < 0.2, "a walker's wings stay folded when standing")
local _, wingL = nil, select(3, ang("wing", -1, 0, still))
expect(wingL < 0, "the left wing lifts the opposite way to the right")

print("== cheering and flying")
local cheer = { t = 1, walk = 0, gait = 0, happy = 1 }
local armX, _, armZ = ang("arm", 1, 0, cheer)
local armXl, _, armZl = ang("arm", -1, 0, cheer)
expect(armZ > 1 and armZl < -1, "arms go up and out when cheering")
expect(ang("leg", 1, -1, cheer) < -0.5, "legs tuck up when cheering")
local _, _, wingCheer = ang("wing", 1, 0, cheer)
expect(wingCheer > 0.5, "wings spread when cheering")
local flapMin, flapMax = 9, -9
for t = 0, 2, 0.01 do
    local _, _, z = ang("wing", 1, 0, { t = t, walk = 0, gait = 0, happy = 0, fly = true })
    flapMin, flapMax = math.min(flapMin, z), math.max(flapMax, z)
end
expect(flapMax - flapMin > 0.5 and flapMin >= -0.01, "a floater's wings flap up and down (" .. string.format("%.2f..%.2f", flapMin, flapMax) .. ")")
local _, spin1 = ang("spin", 0, 0, { t = 1, walk = 0, gait = 0, happy = 0 })
local _, spin2 = ang("spin", 0, 0, { t = 2, walk = 0, gait = 0, happy = 0 })
expect(spin1 ~= spin2 and spin1 >= 0 and spin2 < math.pi * 2, "halos, rings and gears turn")

print("== limits")
local worst = 0
for _, kind in ipairs({ "leg", "legs", "arm", "claw", "wing", "tail", "ears", "head", "jaw", "feelers", "horns", "wobble", "wisp" }) do
    for t = 0, 10, 0.37 do
        for _, w in ipairs({ 0, 0.5, 1 }) do
            for _, h in ipairs({ 0, 1 }) do
                local x, y, z = ang(kind, 1, -1, { t = t, walk = w, gait = t * 2, happy = h, fly = t % 2 > 1 })
                worst = math.max(worst, math.abs(x), math.abs(y), math.abs(z))
                if x ~= x or y ~= y or z ~= z then expect(false, kind .. " produced NaN") end
            end
        end
    end
end
expect(worst < 1.6, "no limb ever turns more than 1.6 rad (" .. string.format("%.2f", worst) .. ")")
local ux, uy, uz = ang("nonsense", 1, 1, still)
expect(ux == 0 and uy == 0 and uz == 0, "an unknown part type is left alone")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
