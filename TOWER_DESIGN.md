# Sky Tower: design (Courier Run, tall version)

Replaces the flat Courier courses as the main obstacle challenge. The three flat courses stay as the learner tier (they are built and working).

## What the biggest obbies do, and what we take from it

| Idea (from Tower of Hell, Mega Easy Obby) | How the Sky Tower uses it |
|---|---|
| A new random tower every few minutes: it never gets stale | Every round the tower is built from a seed: levels are drawn from a pool of sections, so no two rounds match. A new round starts on a timer. |
| A round timer and other players racing you | A round lasts about 8 minutes. Everyone in the server climbs the same tower, with a live "highest level" list. When someone reaches the top, the clock speeds up for everyone still climbing. |
| Pay as you go, with steep rewards for height | Every new level pays at once, and each level pays more than the last (a rising curve). The top pays a big bonus chest. |
| Checkpoints so mistakes are not crushing (Mega Easy) | Each level start is a checkpoint. A fall costs a few seconds and sends you back to the start of the level you are on, never lower. What you banked stays banked. |
| Pro towers: longer, harder, pay more | A Pro tower mode: more levels, more time, 2.5x pay. |
| Coins buy gear and mutators | Coins from the tower buy small run helpers (double jump pad, a slow-lava charge); a vote picks a "mutator" for the next round. (later) |
| Leaderboards | Highest level today / this week, and fastest summit. |

## The tower

- Built in the **sky**, thousands of studs above the cavern, so it can climb 700 studs or more through open air. A portal near the spawn takes you there; a button (and the top) brings you back.
- **Levels** (floors). Each is a short course of 2-3 obstacle sections (steps, moving and crumbling platforms, spinners, crushers, a beam) from the existing set, followed by a **climb** up to the next level. Levels alternate direction and shift sideways, so the tower zig-zags upward without overlapping.
- Difficulty by height: levels 1-10 use tier-1 sections, 11-20 tier-2, 21+ tier-3. Jump limits per tier are checked by tests, so every random tower is makeable.
- Lava chases from level 11 up (a wall rising from below at a fixed pace). Rookie levels never chase.

## Rewards by height

- `levelCoins(n)` rises steeply: a small payout for level 1, about 100x that at level 30 (the Tower of Hell curve).
- Level materials: raw bundles low down, refined and rare ones high up; rare drops get more likely with height.
- A bonus chest at the top, and a bigger one for a first-time summit each day.
- A daily allowance still caps coins, so the tower is not an unlimited faucet; XP and Courier Level are not capped.

## What exists already (reused)

`CourierLayout` (platform and obstacle geometry, jump rules), `CourierRunner` (checkpoints, falls, lava, spinners, crushers, cheat checks), `CourierRewards` (coins, materials, XP,
personal best, daily allowance), `CourierArt` and `CourierController` (drawing, animation, HUD, results).

## Build order

1. `TowerLayout`: composes a tower from a seed (levels drawn from section pools, stacked and mirrored). Tests prove every jump on every seed. **(first)**
2. Tower rewards (per-level curve, top chest) and rounds (timer, speed-up, new tower each round).
3. Tower art: platforms, climbs, level signs with a number, a sky backdrop, the portal and the return.
4. `TowerService` + client HUD: level counter, round clock, "highest level" list, level-up effects.
5. Boards, daily challenge, Pro mode, gear.
