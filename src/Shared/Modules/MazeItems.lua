-- The player's side of the Hollow Maze's new tools, with no Roblox types so tests can run them: carrying one item at a time, using it against the Zombie Golem, hiding in a
-- crate, and how much noise a player is making. MazeService feeds it positions and the clock; the Zombie's own reactions live in MazeZombie.
--
-- A run record `rec` keeps: item (an item id or nil), sprintUntil, cloakUntil, hiddenAt (when it climbed into a crate), hideCooldownUntil. Times are the server clock.
local MazeData   = require(game.ReplicatedStorage.Shared.Data.MazeData)
local MazeZombie = require(script.Parent.MazeZombie)

local MazeItems = {}

-- ── Noise ─────────────────────────────────────────────────────────────────────
-- How loud a player is, from how fast they are moving compared with their walking pace: "run", "walk" or "still"
function MazeItems.Noise(speed, walkSpeed)
    local ratio = (speed or 0) / math.max(1, walkSpeed or 16)
    if ratio > MazeData.RUN_FRACTION then return "run" end
    if ratio > MazeData.WALK_FRACTION then return "walk" end
    return "still"
end

-- ── Carrying and using items ──────────────────────────────────────────────────
function MazeItems.Give(rec, itemId)
    if rec.item ~= nil or not MazeData.ItemById[itemId] then return false end
    rec.item = itemId
    return true
end

function MazeItems.Sprinting(rec, now) return rec.sprintUntil ~= nil and now < rec.sprintUntil end
function MazeItems.Cloaked(rec, now) return rec.cloakUntil ~= nil and now < rec.cloakUntil end

-- Use the carried item. `z` is the Zombie's state (MazeZombie); (x, zpos) where the player stands; `flareId` names a flare. Returns ok, effect where effect = { kind, seconds, ... }.
function MazeItems.Use(rec, z, x, zpos, now, flareId)
    local def = rec.item and MazeData.ItemById[rec.item]
    if not def then return false end
    rec.item = nil
    local effect = { kind = def.id, seconds = def.seconds }
    if def.id == "sprint" then
        rec.sprintUntil = now + def.seconds
        effect.speed = def.speed
    elseif def.id == "cloak" then
        rec.cloakUntil = now + def.seconds
    elseif def.id == "flare" then
        MazeZombie.AddDecoy(z, flareId or "flare", x, zpos, def.seconds)
        effect.x, effect.z = x, zpos
    elseif def.id == "freeze" then
        MazeZombie.Slow(z, def.slow, def.seconds)
    elseif def.id == "stun" then
        MazeZombie.Stun(z, def.seconds)
    end
    return true, effect
end

-- The walk speed a sprinting player should have: their own speed times the tonic, held under the anti-cheat's limit
function MazeItems.SprintSpeed(baseWalk)
    return math.min(baseWalk * MazeData.ITEMS.Stone.speed, math.max(baseWalk, MazeData.SPRINT_MAX_WALK))
end

-- ── Orbs ──────────────────────────────────────────────────────────────────────
-- `orbs` is a list of { x, z (world), item = the section's item, takenUntil = nil | time }. The orb a player is standing in, if it is there to take.
function MazeItems.OrbAt(orbs, x, z, now)
    for _, o in ipairs(orbs) do
        if not (o.takenUntil and now < o.takenUntil) then
            local dx, dz = o.x - x, o.z - z
            if dx * dx + dz * dz <= MazeData.PICKUP_RADIUS * MazeData.PICKUP_RADIUS then return o end
        end
    end
    return nil
end

-- Try to take an orb: only with empty hands. Returns the item id or nil. (A taken orb comes back after PICKUP_RESPAWN seconds.)
function MazeItems.TakeOrb(rec, orb, now)
    if rec.item ~= nil or (orb.takenUntil and now < orb.takenUntil) then return nil end
    if not MazeItems.Give(rec, orb.item.id) then return nil end
    orb.takenUntil = now + MazeData.PICKUP_RESPAWN
    return orb.item.id
end

-- ── Hiding ────────────────────────────────────────────────────────────────────
function MazeItems.Hidden(rec) return rec.hiddenAt ~= nil end

function MazeItems.CanHide(rec, now)
    if rec.hiddenAt then return false, "already" end
    if rec.hideCooldownUntil and now < rec.hideCooldownUntil then return false, "cooldown" end
    return true
end

function MazeItems.Hide(rec, now)
    local ok, why = MazeItems.CanHide(rec, now)
    if not ok then return false, why end
    rec.hiddenAt = now
    return true
end

-- Climb out (the player chose to, or was pushed out when the time ran out). A short rest before the next hide.
function MazeItems.Unhide(rec, now)
    if not rec.hiddenAt then return false end
    rec.hiddenAt = nil
    rec.hideCooldownUntil = now + MazeData.HIDE_COOLDOWN
    return true
end

function MazeItems.HideExpired(rec, now)
    return rec.hiddenAt ~= nil and now - rec.hiddenAt >= MazeData.HIDE_MAX
end

-- ── What the Zombie sees ──────────────────────────────────────────────────────
-- The target record MazeZombie.Step wants for one player
function MazeItems.TargetFor(rec, id, x, z, scale, speed, walkSpeed, now)
    return {
        id = id, x = x, z = z, scale = scale,
        noise = MazeItems.Noise(speed, walkSpeed),
        hidden = MazeItems.Hidden(rec) or nil,
        cloaked = MazeItems.Cloaked(rec, now) or nil,
    }
end

return MazeItems
