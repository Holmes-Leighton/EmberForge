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
per_day = daily_login + streak + daily_quests + weekly_quests + guild + ladder
print(f"coins per day for a daily player: {per_day:,.0f}  (~{per_day*7:,.0f} a week)\n")

# ---- Ascension: BASE_COST * n^1.5 rounded to 100 ----
costs = [int(1500 * n ** 1.5 / 100 + 0.5) * 100 for n in range(1, 11)]
print("Ascension costs:", ", ".join(f"{c:,}" for c in costs))
print(f"  all ten: {sum(costs):,} coins = {sum(costs)/per_day:,.0f} days of income (about 10 months)\n")

# ---- what else costs coins ----
for name, price in [("Quarry (Core)", 10000), ("Quarry node", 4000), ("Molten Forge", 30000), ("Forgemaster's Throne", 20000), ("Royal-tier pieces (~5k)", 5000)]:
    print(f"  {name:26s} {price:>7,} coins = {price/per_day:5.1f} days")

# ---- ladder: points = resources mined; ONLINE_PRODUCTION_SPEED 60 means a Golem mines rate*60 per online hour ----
SPEED = 60
rates = {"T1": 50, "T2": 180, "T3": 520, "T4": 1400, "T5": 4000}       # GolemData.Tiers resourcesPerHour
tiers = [("Bronze", 0), ("Silver", 100_000), ("Gold", 500_000), ("Platinum", 2_000_000), ("Diamond", 8_000_000), ("Champion", 30_000_000)]
personas = [("new: 3 x T1", 3, "T1"), ("early: 3 x T2", 3, "T2"), ("mid: 4 x T3", 4, "T3"), ("late: 6 x T4", 6, "T4"), ("end: 8 x T5", 8, "T5")]
print("\nLadder tier for a 4-week season at 1 hour a day online (and at 3 hours):")
for label, n, t in personas:
    for hrs in (1, 3):
        pts = n * rates[t] * SPEED * hrs * 28
        tier = [name for name, p in tiers if pts >= p][-1]
        print(f"  {label:16s} {hrs}h/day: {pts:>13,.0f} points -> {tier}")
