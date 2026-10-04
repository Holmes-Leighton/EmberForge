-- Draws the Cart Run carts smoothly and animates the crusher gates and retracting bridges. The server decides everything (the cart's distance PathS, its speed
-- PathV and the server time PathT they were true at; the gates and bridges run on a shared clock); this only draws it, so nobody sees a cart stutter and every
-- player sees the same gate open at the same moment. Carts are tagged "EFCourseCart" and hazards "EFCourseHazard" by CartCourseArt.
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local CartCourseData = require(game.ReplicatedStorage.Shared.Data.CartCourseData)
local CartPath       = require(game.ReplicatedStorage.Shared.Modules.CartPath)

local CartCourseController = {}

local carts, hazards = {}, {}
local MOVE_TIME = 0.35            -- seconds a gate door or bridge plate takes to move
local WARN_TIME = 1.2             -- the lamps turn amber this long before a change

local GREEN, AMBER, RED = Color3.fromRGB(80, 255, 120), Color3.fromRGB(255, 190, 50), Color3.fromRGB(255, 60, 50)

local function ServerNow() return workspace:GetServerTimeNow() end

local function CartCFrame(r, s)
    local x, y, z, fx, fy, fz, ux, uy, uz = CartPath.Frame(r.path, s)
    return CFrame.fromMatrix(Vector3.new(x, y + CartCourseData.RAIL_TOP, z), Vector3.new(fx, fy, fz), Vector3.new(ux, uy, uz))
end

local function AddCart(model)
    if not carts[model] then carts[model] = {} end
end

local function AddHazard(unit)
    if not hazards[unit] then hazards[unit] = {} end
end

local function StepCart(model, c, dt, now)
    local body = model.PrimaryPart
    if not body then return end
    if not c.r then
        local id = model:GetAttribute("CourseId")
        c.r = id and CartCourseData.Resolve(id)
        if not c.r then return end
    end
    local s0, v, t0 = model:GetAttribute("PathS") or 0, model:GetAttribute("PathV") or 0, model:GetAttribute("PathT") or now
    local ahead = math.clamp(now - t0, 0, 0.6)                         -- carry on at the last known speed, but never far past what we were told
    local target = math.clamp(s0 + v * ahead, 0, c.r.length)
    local jump = model:GetAttribute("Jump")
    if c.s == nil or jump ~= c.jump or math.abs(target - c.s) > 14 then
        c.s = target                                                    -- a reset or a long gap: snap
    else
        c.s += (target - c.s) * math.min(1, dt * 12)                    -- otherwise ease towards it
    end
    c.jump = jump
    model:PivotTo(CartCFrame(c.r, c.s))
end

local function StepHazard(unit, h, dt, now)
    if not h.def then
        local r = CartCourseData.Resolve(unit:GetAttribute("CourseId") or "")
        local def = r and r.hazards[unit:GetAttribute("HazardIndex") or 0]
        if not def then return end
        h.def, h.kind = def, unit:GetAttribute("Kind")
        h.mover = unit:FindFirstChild(h.kind == "Gate" and "Door" or "Plate")
        if not h.mover then h.def = nil return end
        h.base = h.mover:GetPivot()
        h.o = CartCourseData.HazardOpen(def, now) and 1 or 0
        h.lamps = {}
        for _, d in ipairs(unit:GetDescendants()) do
            if d:IsA("BasePart") and d.Name == "Lamp" then table.insert(h.lamps, d) end
        end
    end
    local open = CartCourseData.HazardOpen(h.def, now)
    local want = open and 1 or 0
    if h.o < want then h.o = math.min(want, h.o + dt / MOVE_TIME) elseif h.o > want then h.o = math.max(want, h.o - dt / MOVE_TIME) end
    if h.kind == "Gate" then
        h.mover:PivotTo(h.base * CFrame.new(0, h.o * (unit:GetAttribute("Lift") or 15), 0))
    else
        h.mover:PivotTo(h.base * CFrame.new(0, -(1 - h.o) * (unit:GetAttribute("Sink") or 3.5), 0))
    end
    local soon = CartCourseData.HazardChangesIn(h.def, now) < WARN_TIME
    local color = (open and not soon) and GREEN or (soon and AMBER or RED)
    if soon and math.floor(now * 6) % 2 == 0 then color = open and RED or GREEN end         -- flicker towards what is coming
    for _, lamp in ipairs(h.lamps) do lamp.Color = color end
end

local function Step(dt)
    local now = ServerNow()
    for model, c in pairs(carts) do
        if model.Parent then StepCart(model, c, dt, now) else carts[model] = nil end
    end
    for unit, h in pairs(hazards) do
        if unit.Parent then StepHazard(unit, h, dt, now) else hazards[unit] = nil end
    end
end

function CartCourseController.Init()
    for _, m in ipairs(CollectionService:GetTagged("EFCourseCart")) do AddCart(m) end
    CollectionService:GetInstanceAddedSignal("EFCourseCart"):Connect(AddCart)
    for _, u in ipairs(CollectionService:GetTagged("EFCourseHazard")) do AddHazard(u) end
    CollectionService:GetInstanceAddedSignal("EFCourseHazard"):Connect(AddHazard)
    RunService.RenderStepped:Connect(Step)
end

return CartCourseController
