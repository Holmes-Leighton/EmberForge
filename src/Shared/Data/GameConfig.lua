-- Central tuning constants. All live-ops rebalancing happens here.
local GameConfig = {}

-- Idle Engine
GameConfig.OFFLINE_STORAGE_BASE_HOURS = 4        -- base storage cap
GameConfig.OFFLINE_STORAGE_UPGRADED_HOURS = 8    -- upgraded Storage Vault
GameConfig.OFFLINE_STORAGE_PREMIUM_HOURS = 24    -- premium (Robux / Season Pass)

-- Online mining speed-up: 1 real second of a deployed Golem = this many seconds of its
-- hourly rate. 60 => a Tier 1 Golem (50/hr) mines ~0.8 resources per second while you play.
-- Offline production still uses real time. Set to 1 for true hourly rates.
GameConfig.ONLINE_PRODUCTION_SPEED = 60

-- Forge
GameConfig.BASE_SMELT_SLOTS = 5
GameConfig.MAX_SMELT_SLOTS = 10
GameConfig.MAX_FORGE_LEVEL = 10
GameConfig.FORGE_SMELT_TIME_REDUCTION_MAX = 0.40  -- 40% reduction at max level

-- Golem Slots
GameConfig.BASE_GOLEM_SLOTS = 3
GameConfig.MAX_GOLEM_SLOTS = 12

-- Economy rates
GameConfig.MATERIAL_DROP_RATES = {
    Common    = 0.60,
    Uncommon  = 0.25,
    Rare      = 0.10,
    Epic      = 0.04,
    Legendary = 0.01,
}

-- XP rewards
GameConfig.XP_PER_SMELT = 10
GameConfig.XP_PER_CRAFT_TIER = { 50, 150, 400, 1000, 3000 }  -- per tier
GameConfig.XP_PER_TRADE = 25

-- Mastery
GameConfig.MASTERY_XP_PER_HOUR_MINED = 1  -- mastery XP ticks per resource hour
GameConfig.MASTERY_MAX_LEVEL = 20
GameConfig.MASTERY_XP_THRESHOLDS = {
    0, 100, 250, 500, 900, 1400, 2100, 3000, 4200, 5700,
    7500, 9800, 12600, 16000, 20000, 25000, 31000, 38000, 46000, 55000,
}

-- DataStore
GameConfig.DATASTORE_SAVE_INTERVAL = 300  -- 5 minutes
GameConfig.DATASTORE_KEY_PREFIX = "EF_v1_"

-- Remote event rate limiting
GameConfig.REMOTE_RATE_LIMIT = 10  -- max requests per second per player

-- Trading
GameConfig.MAX_TRADE_ITEMS_PER_SIDE = 8
GameConfig.MARKET_LISTING_FEE_PERCENT = 0.05  -- 5% listing fee in Ember Coins

-- Ember Coins (in-game currency)
GameConfig.DAILY_COIN_REWARD = 100
GameConfig.COIN_PER_CHALLENGE = 50
GameConfig.STARTING_COINS = 200

-- Admins who may use the Admin mining pad (UserIds). The place owner and Studio always can.
GameConfig.ADMIN_USER_IDS = {}

-- Server
GameConfig.MAX_PLAYERS_PER_SERVER = 20

-- Season
GameConfig.SEASON_DURATION_WEEKS = 7

return GameConfig
