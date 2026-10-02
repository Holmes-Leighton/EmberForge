QUIET = true
local GR = load("game/ReplicatedStorage/Shared/Modules/GolemRoute")

print("== Golem route")
local r = GR.New({ { x = 0, y = 0, z = 0 }, { x = 10, y = 0, z = 0 }, { x = 10, y = 0, z = 20 } })
expect(math.abs(r.total - 30) < 1e-9, "total is the sum of the legs (" .. r.total .. ")")

local x, y, z, dx, dz = GR.At(r, 0)
expect(x == 0 and z == 0 and dx == 1 and dz == 0, "starts at the first point heading along the first leg")
x, y, z, dx, dz = GR.At(r, 5)
expect(x == 5 and z == 0 and dx == 1, "half way along the first leg")
x, y, z, dx, dz = GR.At(r, 20)
expect(x == 10 and z == 10 and dx == 0 and dz == 1, "turns the corner onto the second leg (" .. x .. "," .. z .. ")")
x, y, z = GR.At(r, 999)
expect(x == 10 and z == 20, "clamped at the end")
x, y, z = GR.At(r, -5)
expect(x == 0 and z == 0, "clamped at the start")

local s = GR.New({ { x = 0, y = 0, z = 0 }, { x = 0, y = 10, z = 0 } })
local _, py, _, ddx, ddz = GR.At(s, 5)
expect(py == 5 and ddx == 0 and ddz == -1, "a purely vertical leg interpolates height and keeps a sane direction")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
