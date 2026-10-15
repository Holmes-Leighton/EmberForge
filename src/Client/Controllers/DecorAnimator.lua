-- Moves the forge decorations' pieces (see ForgeDecorFx on the server). The server only builds the parts and tags them; every frame this sets each one's position or
-- look from the clock, so it costs the server nothing and every player sees the same motion.
--   EFOrbit      circles a centre:   OrbitCenter (Vector3), OrbitRadius, OrbitSpeed, OrbitPhase, OrbitTiltX / OrbitTiltZ (degrees), Tumble
--   EFBob        floats up and down: BobAmp, BobSpeed, BobPhase, SpinSpeed (a slow turn while it floats)
--   EFDecorSpin  turns about its own axis: SpinSpeed, SpinAxis ("X", "Y" or "Z")
--   EFPulse      breathes:           PulseLo, PulseHi (transparency range), PulseSpeed, PulsePhase
--   EFArc        a bolt that flashes on and off at random: ArcOnMin/Max, ArcOffMin/Max (seconds)
-- Anything farther than FAR studs from the camera is skipped (nobody can see the detail) and its last pose is kept.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local DecorAnimator = {}

local FAR = 140
local orbits, bobs, spins, pulses, arcs = {}, {}, {}, {}, {}

local function Add(set, part, make)
    if part:IsA("BasePart") then set[part] = make(part) end
end

local function Track(tag, set, make)
    for _, p in ipairs(CollectionService:GetTagged(tag)) do Add(set, p, make) end
    CollectionService:GetInstanceAddedSignal(tag):Connect(function(p) Add(set, p, make) end)
    CollectionService:GetInstanceRemovedSignal(tag):Connect(function(p) set[p] = nil end)
end

local function Near(part, camPos)
    return (part.Position - camPos).Magnitude < FAR
end

function DecorAnimator.Step(now)
    local cam = workspace.CurrentCamera
    local camPos = cam and cam.CFrame.Position or Vector3.zero

    for part, o in pairs(orbits) do
        if not part.Parent then orbits[part] = nil
        elseif Near(part, camPos) then
            local a = o.speed * now + o.phase
            local plane = CFrame.Angles(o.tiltX, 0, o.tiltZ)
            local offset = plane:VectorToWorldSpace(Vector3.new(math.cos(a) * o.radius, math.sin(a * 2) * 0.12 * o.radius, math.sin(a) * o.radius))
            part.CFrame = CFrame.new(o.center + offset) * CFrame.Angles(now * o.tumble, now * o.tumble * 0.7, 0)
        end
    end

    for part, b in pairs(bobs) do
        if not part.Parent then bobs[part] = nil
        elseif Near(part, camPos) then
            part.CFrame = b.base * CFrame.new(0, math.sin(now * b.speed + b.phase) * b.amp, 0) * CFrame.Angles(0, now * b.spin, 0)
        end
    end

    for part, s in pairs(spins) do
        if not part.Parent then spins[part] = nil
        elseif Near(part, camPos) then
            local r = now * s.speed
            local rot = s.axis == "Y" and CFrame.Angles(0, r, 0) or s.axis == "Z" and CFrame.Angles(0, 0, r) or CFrame.Angles(r, 0, 0)
            part.CFrame = s.base * rot
        end
    end

    for part, p in pairs(pulses) do
        if not part.Parent then pulses[part] = nil
        elseif Near(part, camPos) then
            local k = math.sin(now * p.speed + p.phase) * 0.5 + 0.5
            part.Transparency = p.lo + (p.hi - p.lo) * k
        end
    end

    for part, a in pairs(arcs) do
        if not part.Parent then arcs[part] = nil
        elseif now >= a.nextSwitch then
            a.on = not a.on
            a.nextSwitch = now + (a.on and (a.onMin + math.random() * (a.onMax - a.onMin)) or (a.offMin + math.random() * (a.offMax - a.offMin)))
            if a.on and Near(part, camPos) then
                -- each flash is a freshly jagged bolt: the ends stay put, the middle jumps sideways
                local mid = (a.a + a.b) / 2 + Vector3.new((math.random() - 0.5) * 1.2, (math.random() - 0.5) * 0.8, (math.random() - 0.5) * 1.2)
                part.CFrame = CFrame.lookAt((a.a + mid) / 2, mid)
                part.Size = Vector3.new(a.thick, a.thick, (mid - a.a).Magnitude)
            end
            part.Transparency = a.on and 0.05 or 1
        end
    end
end

function DecorAnimator.Init()
    Track("EFOrbit", orbits, function(p)
        return { center = p:GetAttribute("OrbitCenter") or p.Position, radius = p:GetAttribute("OrbitRadius") or 2, speed = p:GetAttribute("OrbitSpeed") or 1,
            phase = p:GetAttribute("OrbitPhase") or 0, tiltX = math.rad(p:GetAttribute("OrbitTiltX") or 0), tiltZ = math.rad(p:GetAttribute("OrbitTiltZ") or 0),
            tumble = p:GetAttribute("Tumble") or 0 }
    end)
    Track("EFBob", bobs, function(p)
        return { base = p.CFrame, amp = p:GetAttribute("BobAmp") or 0.4, speed = p:GetAttribute("BobSpeed") or 1.2, phase = p:GetAttribute("BobPhase") or 0,
            spin = p:GetAttribute("SpinSpeed") or 0 }
    end)
    Track("EFDecorSpin", spins, function(p)
        return { base = p.CFrame, speed = p:GetAttribute("SpinSpeed") or 1, axis = p:GetAttribute("SpinAxis") or "Y" }
    end)
    Track("EFPulse", pulses, function(p)
        return { lo = p:GetAttribute("PulseLo") or 0.2, hi = p:GetAttribute("PulseHi") or 0.7, speed = p:GetAttribute("PulseSpeed") or 1.5, phase = p:GetAttribute("PulsePhase") or 0 }
    end)
    Track("EFArc", arcs, function(p)
        local a = p:GetAttribute("ArcA") or p.Position
        return { a = a, b = p:GetAttribute("ArcB") or (p.Position + Vector3.new(0, 2, 0)), thick = p.Size.X, on = false, nextSwitch = 0,
            onMin = p:GetAttribute("ArcOnMin") or 0.05, onMax = p:GetAttribute("ArcOnMax") or 0.2, offMin = p:GetAttribute("ArcOffMin") or 0.2, offMax = p:GetAttribute("ArcOffMax") or 1 }
    end)
    RunService.RenderStepped:Connect(function() DecorAnimator.Step(workspace:GetServerTimeNow()) end)
end

return DecorAnimator
