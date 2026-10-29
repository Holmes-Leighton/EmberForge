-- What the Hollow Maze pays, with no Roblox objects in it so tests can check the sums. Reaching a new section pays at once (PaySection); escaping pays a chest (PayEscape).
-- Coins count against a daily allowance for the maze; materials, rare drops and Courier XP are not capped (materials are limited by how many sections pay a bundle a day).
local MazeData       = require(game.ReplicatedStorage.Shared.Data.MazeData)
local CourierData    = require(game.ReplicatedStorage.Shared.Data.CourierData)
local CourierRewards = require(script.Parent.CourierRewards)

local MazeRewards = {}

function MazeRewards.State(data, today)
    local c = CourierRewards.State(data, today)
    if c.mazeDay ~= today then c.mazeDay, c.mazeEarned, c.mazeEscaped, c.mazeBest, c.mazeBundles = today, 0, false, c.mazeBest or 0, 0 end
    c.mazeEarned = c.mazeEarned or 0
    c.mazeBundles = c.mazeBundles or 0
    c.mazeBest = c.mazeBest or 0              -- the deepest section ever reached
    if c.mazePieceDay ~= today then c.mazePieceDay, c.mazePieceCount = today, 0 end      -- Maze Golem pieces found today (capped)
    c.mazePity = c.mazePity or 0                                                          -- section clears since the last piece (carries over days)
    c.mazePiecesTotal = c.mazePiecesTotal or 0                                            -- pieces found in all (for the milestone caches)
    return c
end

function MazeRewards.DailyCap(data)
    return (40 + 5 * (data.PlayerLevel or 1)) * MazeData.CAP_RUNS
end

-- What reaching `section` (1-based) pays. opts: { coinMultiplier, rng }
-- Returns { coins, xp, material, rare, section, levelUps, courierLevel, capped }
function MazeRewards.PaySection(data, section, today, opts)
    opts = opts or {}
    local c = MazeRewards.State(data, today)
    local wanted = MazeData.SectionCoins(data.PlayerLevel, section)
    local room = math.max(0, MazeRewards.DailyCap(data) - c.mazeEarned)
    local coins = math.min(wanted, room)
    c.mazeEarned += coins
    local paid = math.floor(coins * (opts.coinMultiplier or 1))
    data.EmberCoins = (data.EmberCoins or 0) + paid

    data.Inventory = data.Inventory or {}
    local material, rare
    local bundle = MazeData.Bundles[MazeData.SECTIONS[section]]
    if bundle and c.mazeBundles < MazeData.BUNDLES_PER_DAY then
        c.mazeBundles += 1
        data.Inventory[bundle.id] = (data.Inventory[bundle.id] or 0) + bundle.qty
        material = { id = bundle.id, qty = bundle.qty }
    end
    local chance = MazeData.RareChance + 0.02 * section
    if (opts.rng or math.random)() < chance then
        local drop = MazeData.RareFor(section)
        data.Inventory[drop.id] = (data.Inventory[drop.id] or 0) + drop.qty
        rare = { id = drop.id, qty = drop.qty }
    end

    local xp = 2 + 2 * section
    local lvl, cur, ups = CourierData.AddXp(c.level, c.xp, xp)
    c.level, c.xp = lvl, cur
    if section > c.mazeBest then c.mazeBest = section end
    return { coins = paid, xp = xp, material = material, rare = rare, section = section, levelUps = ups, courierLevel = lvl, capped = coins < wanted }
end

-- ── Maze Golem pieces ─────────────────────────────────────────────────────────
local function Have(data, id) return (data.Inventory and data.Inventory[id]) or 0 end

-- The piece (index into MazeData.PIECES) a drop gives: `preferred` if you still need it, else a random one you do need, else nil (a full set: craft first)
local function ChoosePiece(data, preferred, rng)
    local need = MazeData.PIECE_NEED
    if preferred and Have(data, MazeData.PIECES[preferred].id) < need then return preferred end
    local missing = {}
    for i, p in ipairs(MazeData.PIECES) do if Have(data, p.id) < need then table.insert(missing, i) end end
    if #missing == 0 then return nil end
    return missing[math.floor(rng() * #missing) % #missing + 1]
end

local function GivePiece(data, c, index)
    local piece = MazeData.PIECES[index]
    data.Inventory = data.Inventory or {}
    data.Inventory[piece.id] = (data.Inventory[piece.id] or 0) + 1
    c.mazePieceCount += 1
    c.mazePity = 0
    c.mazePiecesTotal += 1
    local first = false
    data.Blueprints = data.Blueprints or {}
    if not table.find(data.Blueprints, MazeData.PIECE_BLUEPRINT) then table.insert(data.Blueprints, MazeData.PIECE_BLUEPRINT) first = true end
    local result = { id = piece.id, name = piece.name, have = data.Inventory[piece.id], need = MazeData.PIECE_NEED, firstBlueprint = first, total = c.mazePiecesTotal,
        goal = MazeData.PIECE_NEED * #MazeData.PIECES }
    -- every few pieces along the way pays a cache, so the long chase is full of rewards
    local milestone = MazeData.PIECE_MILESTONES[c.mazePiecesTotal]
    if milestone then
        data.EmberCoins = (data.EmberCoins or 0) + (milestone.coins or 0)
        for _, it in ipairs(milestone.items or {}) do data.Inventory[it.id] = (data.Inventory[it.id] or 0) + it.qty end
        result.milestone = { at = c.mazePiecesTotal, coins = milestone.coins, items = milestone.items }
    end
    return result
end

-- Rolls for a Maze Golem piece after reaching `section` (or, with `escape`, for opening the exit chest). Returns { id, name, have, need, firstBlueprint, total, goal, milestone } or nil, and a reason
-- ("capped") when today's limit stopped a drop. opts: { rng }
function MazeRewards.RollPiece(data, section, escape, today, opts)
    opts = opts or {}
    local rng = opts.rng or math.random
    local c = MazeRewards.State(data, today)
    local capped = c.mazePieceCount >= MazeData.PIECE_CAP_PER_DAY
    if not escape then c.mazePity += 1 end
    local chance = escape and MazeData.PIECE_ESCAPE or (MazeData.PIECE_CHANCE[section] or 0)
    -- the very first piece is guaranteed: the first time you get as deep as PIECE_FIRST_SECTION (or escape), so the chase always starts with a win
    local firstEver = c.mazePiecesTotal == 0 and (escape or section >= MazeData.PIECE_FIRST_SECTION)
    local hit = firstEver or rng() < chance or (not escape and c.mazePity >= MazeData.PIECE_PITY)
    if not hit then return nil end
    if capped then return nil, "capped" end
    local index = ChoosePiece(data, (not escape) and section or nil, rng)
    if not index then return nil, "full" end
    return GivePiece(data, c, index)
end

-- The Labyrinth Mind bonus (MazeGolem skill): the fraction added to the maze's coins and XP for `count` deployed Maze Golems
function MazeRewards.GolemBonus(count)
    local p = require(game.ReplicatedStorage.Shared.Data.GolemData).Specials.Maze.skill.params
    return math.min(p.mazeCap, p.mazePer * (count or 0))
end

-- The chest at the exit. Returns { coins, rare, firstToday, capped }
function MazeRewards.PayEscape(data, sections, today, opts)
    opts = opts or {}
    local c = MazeRewards.State(data, today)
    local first = not c.mazeEscaped
    c.mazeEscaped = true
    local wanted = math.floor(MazeData.SectionCoins(data.PlayerLevel, sections) * MazeData.ESCAPE_CHEST_MULT * (first and MazeData.FIRST_ESCAPE_MULT or 1))
    local room = math.max(0, MazeRewards.DailyCap(data) - c.mazeEarned)
    local coins = math.min(wanted, room)
    c.mazeEarned += coins
    local paid = math.floor(coins * (opts.coinMultiplier or 1))
    data.EmberCoins = (data.EmberCoins or 0) + paid
    data.Inventory = data.Inventory or {}
    local drop = MazeData.RareFor(sections)
    local qty = drop.qty * (first and 3 or 1)
    data.Inventory[drop.id] = (data.Inventory[drop.id] or 0) + qty
    return { coins = paid, rare = { id = drop.id, qty = qty }, firstToday = first, capped = coins < wanted }
end

-- The daily challenge: the first time today a run reaches the target section (MazeData.DailyTarget) it pays a bonus chest. Returns { coins, rare, target } or nil.
function MazeRewards.PayDaily(data, section, today, opts)
    opts = opts or {}
    local c = MazeRewards.State(data, today)
    local target = MazeData.DailyTarget(today)
    if section < target or c.mazeDailyDone == today then return nil end
    c.mazeDailyDone = today
    local coins = math.floor(MazeData.SectionCoins(data.PlayerLevel, target) * MazeData.DAILY_COIN_MULT * (opts.coinMultiplier or 1))
    data.EmberCoins = (data.EmberCoins or 0) + coins
    data.Inventory = data.Inventory or {}
    local drop = MazeData.RareFor(target)
    data.Inventory[drop.id] = (data.Inventory[drop.id] or 0) + drop.qty * 2
    return { coins = coins, rare = { id = drop.id, qty = drop.qty * 2 }, target = target }
end

function MazeRewards.DailyDone(data, today)
    return MazeRewards.State(data, today).mazeDailyDone == today
end

-- The total coins a run that reaches every section and escapes would pay (for the balance check)
function MazeRewards.FullRunCoins(playerLevel, firstToday)
    local sum = 0
    for n = 1, #MazeData.SECTIONS do sum += MazeData.SectionCoins(playerLevel, n) end
    return sum + MazeData.SectionCoins(playerLevel, #MazeData.SECTIONS) * MazeData.ESCAPE_CHEST_MULT * (firstToday and MazeData.FIRST_ESCAPE_MULT or 1)
end

return MazeRewards
