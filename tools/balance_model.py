"""Back-of-envelope economy model behind the balance pass (run: python tools/balance_model.py).
Change the assumptions at the top, re-run, and compare with AscensionData / LadderData / QuarryData / ForgeBuildData.
It is a model, not play data: replace the persona numbers with real analytics once the game has players."""

# ---- coin income of an engaged daily player (coins per day) ----
daily_login   = 100                      # GameConfig.DAILY_COIN_REWARD
streak        = (100 + 150 + 0 + 250 + 100 + 400 + 600) / 7      # StreakData ladder, averaged
daily_quests  = 3 * 55                   # ChallengeData dailies (30-100 each)
weekly_quests = 2 * 450 / 7              # ChallengeData weeklies
guild         = 300 / 7                  # GuildData.REWARD once a week
ladder        = 800 / 28                 # mid-game tier prize per 4-week season
base_per_day = daily_login + streak + daily_quests + weekly_quests + guild + ladder

# ---- the newer coin sources, which scale with how far a player has got (all constants live in SupplierData / CartBountyData / EventScheduleData) ----
SELL_USE = 0.7      # share of the Supplier's daily sell allowance a player actually has surplus materials to use (they need the rest for crafting)
CART_USE = 0.6      # share of the cart-bounty allowance used (needs time in the hub; 12 shared carts, 2-minute reload)
def sell_cap(level, forge, ascensions):  return min(5000, 250 + 20 * level + 15 * forge + 250 * ascensions)
def cart_cap(level):                     return min(2500, 120 + 15 * level)
# events: a player online for an hour at a random time. Hourly events are 1 hour in 10 each; coin events are Coin Rush (x1.5 quest coins) and Market Hour
# (x2 Supplier sales). Surges (10 min, ~every 9h) and jackpots (3 min, ~daily) are so short that on average they add almost nothing, but they are felt.
EV_QUEST = 1 + 0.5 * (1 / 10)          # Coin Rush hour is 1 in 10
EV_SELL  = 1 + 1.0 * (1 / 10)          # Market Hour is 1 in 10

# ---- the activity sources added since: Cart Run courses, Courier Run, Sky Tower (formulas copied from CartBountyData / CartCourseData / CourierRewards / TowerData / TowerRewards) ----
# What a session of each pays, and how many sessions a daily player does, are assumptions: replace them with analytics. The allowances are the hard caps from the code.
def quick_reward(level):  return 30 + 4 * level                      # CartBountyData.Reward
def cartrun_cap(level):   return cart_cap(level) * 1.5                # CartBountyData.CourseCap
def cartrun_run(level):   return quick_reward(level) * 2 * 1.25       # the mid course (Cave Run, x2) plus its checkpoints (about 12% each, two of them)
CARTRUN_RUNS = 3
def courier_cap(level):   return (40 + 5 * level) * 10                # CourierRewards.DailyCap
def courier_run(level):   return (40 + 5 * level) * 1.0 * 1.2        # Cavern Courier (x1.0) with a Silver medal
COURIER_RUNS = 4
def tower_level_coins(level, n):  return max(1, int((0.4 + 0.08 * level) * n ** 1.35))      # TowerData.LevelCoins
def tower_cap(level):     return (40 + 5 * level) * 30                # TowerData.CAP_RUNS
def tower_climb(level, reach):    return sum(tower_level_coins(level, n) for n in range(1, reach + 1))
TOWER_CLIMBS, TOWER_REACH = 2, 15                                     # two 10-minute climbs a day, reaching about level 15 (the summit is level 30)
def tower_daily(level):   return min(tower_cap(level), TOWER_CLIMBS * tower_climb(level, TOWER_REACH) + tower_level_coins(level, 14) * 4)   # plus the daily challenge chest

personas_c = [("new (lvl 1, forge 1)", 1, 1, 0), ("early (lvl 10, forge 3)", 10, 3, 0), ("mid (lvl 25, forge 6)", 25, 6, 1), ("late (lvl 50, forge 10)", 50, 10, 3)]
print("coins per day, by how far a player has got:")
print(f"  {'':26s}{'old sources':>12s}{'sell':>8s}{'carts':>8s}{'events':>8s}{'cartrun':>9s}{'courier':>9s}{'tower':>8s}{'total':>9s}")
rows = []
for name, lvl, fg, asc in personas_c:
    sell = sell_cap(lvl, fg, asc) * SELL_USE * EV_SELL
    cart = cart_cap(lvl) * CART_USE
    ev = (daily_quests + weekly_quests) * (EV_QUEST - 1)
    cr = min(cartrun_cap(lvl), CARTRUN_RUNS * cartrun_run(lvl)) if lvl >= 4 else 0
    co = min(courier_cap(lvl), COURIER_RUNS * courier_run(lvl)) if lvl >= 3 else 0
    tw = tower_daily(lvl) if lvl >= 3 else 0
    total = base_per_day + sell + cart + ev + cr + co + tw
    rows.append((name, total))
    print(f"  {name:26s}{base_per_day:>12,.0f}{sell:>8,.0f}{cart:>8,.0f}{ev:>8,.0f}{cr:>9,.0f}{co:>9,.0f}{tw:>8,.0f}{total:>9,.0f}")
per_day = base_per_day
print(f"\nold model (no new sources): {base_per_day:,.0f} a day.\n")

print("days to afford, for each persona:")
goals = [("1st Ascension", 1500), ("Quarry (Core)", 4500), ("Quarry node", 2000), ("Forgemaster's Throne", 20000), ("Molten Forge", 30000)]
print(f"  {'':24s}" + "".join(f"{n.split()[0]:>10s}" for n, _ in rows))
for g, price in goals:
    print(f"  {g:24s}" + "".join(f"{price / t:>10.1f}" for _, t in rows))
asc_total = sum(int(1500 * n ** 1.5 / 100 + 0.5) * 100 for n in range(1, 11))
print(f"  {'all ten Ascensions':24s}" + "".join(f"{asc_total / t:>10.0f}" for _, t in rows))
print("  (target from the pacing review: first big purchase in 3-5 days, a visible step every few days, the long goals a season or two)\n")

# ---- Ascension: BASE_COST * n^1.5 rounded to 100 (see AscensionData) ----
costs = [int(1500 * n ** 1.5 / 100 + 0.5) * 100 for n in range(1, 11)]
print("Ascension costs:", ", ".join(f"{c:,}" for c in costs))

# ---- ladder: points = resources mined; ONLINE_PRODUCTION_SPEED 60 means a Golem mines rate*60 per online hour ----
SPEED = 60
rates = {"T1": 50, "T2": 180, "T3": 520, "T4": 1400, "T5": 4000}       # GolemData.Tiers resourcesPerHour
tiers = [("Bronze", 0), ("Silver", 100_000), ("Gold", 500_000), ("Platinum", 2_000_000), ("Diamond", 8_000_000), ("Champion", 30_000_000)]
personas = [("new: 3 x T1", 3, "T1"), ("early: 3 x T2", 3, "T2"), ("mid: 4 x T3", 4, "T3"), ("late: 6 x T4", 6, "T4"), ("end: 8 x T5", 8, "T5")]
# ---- growth (GolemData.Stages): a new Golem is an Infant and grows while deployed: online time at full speed, offline time at half ----
STAGES = [("Infant", 0, 0.70), ("Young", 1, 0.85), ("Adult", 8, 1.00), ("Elder", 48, 1.15), ("Ancient", 240, 1.30)]     # name, hours of work to reach it, share of stats
GROW_OFFLINE = 0.5
def mult_at(work_hours):  return [m for _, at, m in STAGES if work_hours >= at][-1]
def work_hours_per_day(online_hrs, deployed_hrs=24):   # a Golem that stays deployed: online hours at 1, the rest at the offline rate
    return online_hrs + GROW_OFFLINE * max(0, deployed_hrs - online_hrs)
print("\nGrowth: days of work to reach each stage, by hours online a day (a Golem left deployed all day):")
print(f"  {'online h/day':14s}" + "".join(f"{n:>9s}" for n, at, _ in STAGES[1:]))
for hrs in (1, 3, 6):
    rate = work_hours_per_day(hrs)
    print(f"  {hrs:<14d}" + "".join(f"{at / rate:>8.1f}d" for _, at, _ in STAGES[1:]))
print("  (with a Growth Tonic the online hours count double)")

def season_avg_mult(online_hrs, days=28):    # average share of full stats over a season for a Golem crafted on day 1
    rate = work_hours_per_day(online_hrs)
    return sum(mult_at(rate * (d + 0.5)) for d in range(days)) / days

print("\nLadder tier for a 4-week season at 1 hour a day online (and at 3 hours), Golems crafted on day 1 and growing:")
for label, n, t in personas:
    for hrs in (1, 3):
        avg = season_avg_mult(hrs)
        full = n * rates[t] * SPEED * hrs * 28
        pts = full * avg
        tier = [name for name, p in tiers if pts >= p][-1]
        full_tier = [name for name, p in tiers if full >= p][-1]
        print(f"  {label:16s} {hrs}h/day: {pts:>13,.0f} points -> {tier:9s} (average {avg:.2f} of full stats; fully grown from day 1 it would be {full_tier})")
