-- A route along straight legs through a list of waypoints, walked at a given distance. Used for a worn-out Golem's trip between its mining zone and its
-- owner's forge. Pure maths (points are { x, y, z } tables), covered by tests; GolemVisuals turns the numbers into a position.
--
--   local r = GolemRoute.New({ {x=0,y=0,z=0}, {x=10,y=0,z=0}, {x=10,y=0,z=20} })
--   r.total                     length of the whole route in studs (30)
--   GolemRoute.At(r, d)         x, y, z, dx, dz at distance d along it (clamped), where dx,dz is the unit direction of the leg it is on

local GolemRoute = {}

function GolemRoute.New(points)
    local lens, total = {}, 0
    for i = 2, #points do
        local a, b = points[i - 1], points[i]
        local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
        lens[i] = math.sqrt(dx * dx + dy * dy + dz * dz)
        total += lens[i]
    end
    return { points = points, lens = lens, total = total }
end

function GolemRoute.At(route, d)
    local pts = route.points
    d = math.clamp(d, 0, route.total)
    for i = 2, #pts do
        local len = route.lens[i]
        if d <= len or i == #pts then
            local a, b = pts[i - 1], pts[i]
            local k = len > 0 and math.min(1, d / len) or 1
            local fx, fz = b.x - a.x, b.z - a.z
            local flat = math.sqrt(fx * fx + fz * fz)
            local dx, dz = 0, -1
            if flat > 1e-6 then dx, dz = fx / flat, fz / flat end
            return a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k, a.z + (b.z - a.z) * k, dx, dz
        end
        d -= len
    end
    local last = pts[#pts]
    return last.x, last.y, last.z, 0, -1
end

return GolemRoute
