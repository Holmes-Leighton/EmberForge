-- Code-driven animation for segmented pets. A pet is one model of separate mesh parts named for what they are
-- (Body, Head, LegFL, LegFR, LegBL, LegBR, Tail, Ears, ArmL, WingL, ...). Nothing is uploaded as an animation:
-- every frame each limb is swung about its joint, so walking, idling and cheering all come from the maths in `Angles`.
--
--   PetRig.Build(model)            -> rig (call once the model is built and scaled); nil if the model has no limbs
--   PetRig.Apply(rig, modelCF, st) -> poses every limb for this frame (call after PivotTo)
--   PetRig.Angles(kind, sx, sz, st) is pure maths (no Instances) so it is covered by tests
--
-- Conventions: a pet faces -Z, +Y is up, and angles are rotations about the MODEL's axes:
--   X swings a limb forward/back (legs, arms, head nod), Y turns it (tail sway, look around), Z lifts it sideways (wings, arms up).
--
-- `st` (state): t = clock (s), walk = 0..1 (how much it is walking), gait = walk-cycle phase (rad; one cycle = two footfalls),
--   happy = 0..1 (a cheer: arms up, wings out, legs tucked), fly = true for pets that float.

local PetRig = {}

-- part name -> kind of motion
local KINDS = {
    LegFL = "leg", LegFR = "leg", LegBL = "leg", LegBR = "leg", LegL = "leg", LegR = "leg", LegsL = "leg", LegsR = "leg",
    Legs = "legs",
    ArmL = "arm", ArmR = "arm",
    ClawL = "claw", ClawR = "claw",
    WingL = "wing", WingR = "wing",
    Tail = "tail", Ears = "ears", Head = "head", Jaw = "jaw",
    Antennae = "feelers", EyeStalks = "feelers", Horns = "horns",
    Halo = "spin", RingA = "spin", RingB = "spin", Gear = "spin", Sparkles = "spin", Sparks = "spin", Bubbles = "spin", Cloud = "spin", Bolt = "spin",
    Flask = "wobble", Cork = "wobble", Lid = "wobble", Anemone = "wobble", Crystals = "wobble",
    Hood = "wisp", WispL = "wisp", WispR = "wisp",
}

function PetRig.KindOf(partName) return KINDS[partName] end

local function sgn(v, threshold)
    if v > threshold then return 1 elseif v < -threshold then return -1 end
    return 0
end

-- Rotation (rx, ry, rz) in radians for one limb. sx = which side of the body (-1 left / +1 right / 0 centre),
-- sz = front (-1) or back (+1) of the body (0 = middle).
function PetRig.Angles(kind, sx, sz, st)
    local t, walk, gait, happy = st.t, st.walk or 0, st.gait or 0, st.happy or 0
    local idle = 1 - walk

    if kind == "leg" then
        -- four legs trot in diagonal pairs (front-left with back-right); two legs simply alternate
        local phase
        if sz ~= 0 then phase = gait + ((sx * sz > 0) and 0 or math.pi) else phase = gait + (sx > 0 and math.pi or 0) end
        return math.sin(phase) * 0.8 * walk - 0.7 * happy, 0, 0
    elseif kind == "legs" then
        return math.sin(gait * 2) * 0.12 * walk - 0.4 * happy, 0, 0
    elseif kind == "arm" then
        -- arms swing against the leg on their side, hang loose when still and go up when cheering
        local swing = math.sin(gait + (sx > 0 and 0 or math.pi)) * 0.6 * walk
        return swing + math.sin(t * 1.7 + sx) * 0.05 * idle, 0, sx * 1.2 * happy
    elseif kind == "claw" then
        return math.sin(gait + (sx > 0 and math.pi or 0)) * 0.35 * walk + math.sin(t * 2.2 + sx) * 0.06 * idle - 0.3 * happy, 0, sx * 0.5 * happy
    elseif kind == "wing" then
        -- floaters flap constantly; walkers keep them folded with a flutter, and spread them to cheer
        local lift
        if st.fly then lift = 0.35 + 0.35 * math.sin(t * 13) + 0.3 * happy
        else lift = 0.08 + 0.06 * math.sin(t * 2.4) + 0.2 * walk * math.sin(gait * 2) + happy * (0.55 + 0.45 * math.sin(t * 20)) end
        return 0, 0, sx * lift
    elseif kind == "tail" then
        local rate = 2.3 + 4.5 * walk + 5 * happy
        return -0.1 * walk, math.sin(t * rate) * (0.25 + 0.3 * walk + 0.35 * happy), 0
    elseif kind == "ears" then
        local flick = math.max(0, math.sin(t * 0.9 + 1)) ^ 14                  -- now and then an ear flicks
        return math.sin(gait * 2 + 1) * 0.16 * walk + math.sin(t * 1.1) * 0.04 + flick * 0.35 + 0.3 * happy, 0, 0
    elseif kind == "head" then
        return math.sin(gait * 2) * 0.07 * walk - 0.25 * happy, math.sin(t * 0.6) * 0.35 * idle, 0
    elseif kind == "jaw" then
        return -(0.04 + 0.5 * happy + 0.18 * (math.max(0, math.sin(t * 0.8)) ^ 8) * idle), 0, 0
    elseif kind == "feelers" then
        return math.sin(t * 3.1) * 0.12, math.sin(t * 2.3) * 0.12, 0
    elseif kind == "horns" then
        return math.sin(gait * 2) * 0.04 * walk, 0, 0
    elseif kind == "spin" then
        return 0, (t * 2.2) % (math.pi * 2), 0
    elseif kind == "wobble" then
        return 0, 0, math.sin(t * 3) * 0.06 + math.sin(gait * 2) * 0.1 * walk
    elseif kind == "wisp" then
        return math.sin(t * 1.6 + sx) * 0.08, math.sin(t * 2 + sx * 2) * 0.15, math.sin(t * 2.4 + sx) * 0.1
    end
    return 0, 0, 0
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Finds each limb's joint (the point of the part nearest the body) and remembers where it sits at rest
function PetRig.Build(model)
    local body = model.PrimaryPart
    if not body then return nil end
    local pivotCF = model:GetPivot()
    local bodyPos = body.Position
    local extent = math.max(model:GetExtentsSize().X, model:GetExtentsSize().Z, 0.1)
    local limbs = {}
    for _, p in ipairs(model:GetChildren()) do
        local kind = p:IsA("BasePart") and p ~= body and KINDS[p.Name] or nil
        if kind then
            local rel = pivotCF:ToObjectSpace(p.CFrame)
            local half = p.Size / 2
            local nearest = p.CFrame:PointToObjectSpace(bodyPos)
            local joint = Vector3.zero
            if kind ~= "spin" then
                joint = Vector3.new(clamp(nearest.X, -half.X, half.X), clamp(nearest.Y, -half.Y, half.Y), clamp(nearest.Z, -half.Z, half.Z))
            end
            local offset = pivotCF:PointToObjectSpace(p.Position)
            table.insert(limbs, {
                part = p, kind = kind, rel = rel,
                pivot = rel:PointToWorldSpace(joint),         -- the joint, in the model's space
                sx = sgn(offset.X, extent * 0.08), sz = sgn(offset.Z, extent * 0.12),
            })
        end
    end
    if #limbs == 0 then return nil end
    return { limbs = limbs }
end

function PetRig.Apply(rig, modelCF, st)
    for _, l in ipairs(rig.limbs) do
        local rx, ry, rz = PetRig.Angles(l.kind, l.sx, l.sz, st)
        if rx == 0 and ry == 0 and rz == 0 then
            l.part.CFrame = modelCF * l.rel
        else
            l.part.CFrame = modelCF * (CFrame.new(l.pivot) * CFrame.Angles(rx, ry, rz) * CFrame.new(-l.pivot) * l.rel)
        end
    end
end

-- Puts every limb back at rest (used when a pet is far away and not being animated)
function PetRig.Rest(rig, modelCF)
    for _, l in ipairs(rig.limbs) do l.part.CFrame = modelCF * l.rel end
end

return PetRig
