# The Hollow Maze: design

A race through a maze that a **Zombie Golem** hunts you through. You get a head start, then it comes for you. The maze is built from **five sections, one for each Golem
element** (Stone, Ember, Frost, Storm, Void), each with its own floors, walls, decorations and a small mechanic. It is the Sky Tower's sibling: a new maze every round,
shared by everyone in the server, paid by how far you get.

## The round (shared by everyone in the server)

| Phase | Length | What happens |
|---|---|---|
| Gather | 20 s | Walk into the portal in the hub. You arrive in the entrance chamber at the west end; a gate holds everyone in. A new maze (new seed) is already built. |
| Head start | 25 s | The gate opens, you run. The Zombie Golem sleeps in its coffin by the entrance, with a countdown. Latecomers can still enter during this phase. |
| Hunt | up to 300 s | The Zombie Golem wakes and hunts the **nearest** player along the maze's real paths, never through walls. It starts slower than you and speeds up as the hunt goes on. |
| Intermission | 25 s | Everyone is brought home with their results; the next maze is built. |

Rounds are numbered from the wall clock (like the Sky Tower), so every server is in the same round at the same moment, with the same seed.

- **Caught** (the Zombie Golem reaches you): you are out for this round and sent to the entrance chamber to watch. You keep what you earned from the sections you reached.
- **Escape** (you reach the exit at the east end): you are out safely with the escape chest. The first escapee speeds the round up (like the Tower's summit): the hunt ends
  `ESCAPE_SPEEDUP` seconds later, so slow players have to hurry.
- **Time up**: everyone still running escapes nothing but keeps their section rewards.

Entry opens at player level 4 (`MazeData.GATE_LEVEL`).

## The maze

- **40 x 10 cells** of 14 studs: five sections of 8 x 10, one per element, joined end to end. Walls are 16 studs high (you cannot see over them). It is built far from the
  cavern, out of sight of everything else (`MazeData.BASE`, opposite the Sky Tower), and roofed like a cave so nobody can look down on it.
- Built from a seed: each section is a random maze (recursive backtracker), then a share of the dead ends are opened into loops ("braiding") so there are loops to run
  around and no section is a pure trap. The sections are joined by a doorway at a seeded row. Tests prove, for hundreds of seeds, that the exit is reachable, every cell is
  reachable, the doorways line up, and the maze is the same for the same seed.
- Order, easy to hard: **Stone, Ember, Frost, Storm, Void**. Later sections are bigger loops of corridors with more dead ends and bring in the zombie's speed-up.

### The five sections (floors, walls and decoration are all generated meshes)

| Section | Floor | Walls | Decoration | Mechanic |
|---|---|---|---|---|
| Stone (Underground Caverns) | cobbled slate | mossy slate blocks | mossy pillars, crystal clusters, mine lanterns | none: the gentle opener |
| Ember (Volcano Depths) | cracked basalt with lava seams | charred basalt with glowing cracks | lava pools in alcoves, flame braziers, obsidian spikes | embers drift up; a faint orange glow |
| Frost (Frozen Peaks) | ice | ice blocks | ice crystals, snow drifts, frozen torches | the floor is slippery |
| Storm (Stormrift Cliffs) | riveted metal plates | gunmetal panels | tesla coils, lightning rods, cable bundles | lightning flashes light the corridors |
| Void (The Hollow) | dark crystal | obsidian with violet veins | floating shards, void rifts, crystal spires | the lights flicker and dim |

## The Zombie Golem

- A new mesh: a hunched, decayed Golem with a cracked stone body, glowing sickly-green eyes, moss and rot, dragging arms. Built from the same named parts as every Golem
  (Torso, Head, ArmL, ArmR, Leg x2) so it is animated by code: a lurching walk, arms reaching forward, and a faster, hungrier gait when it is close.
- The server moves it (a few studs per tick along the path to its target); every client animates it. It never leaves the maze's corridors.
- **Speed**: starts at 70 % of a player's walk speed and rises steadily, reaching about 105 % late in a long hunt, so lingering is punished and perfect running just outpaces it.
- **Fairness**: a coffin-glow and a roar warn when it wakes; a screen-edge warning tints as it gets close; it only catches within 5 studs.

## Rewards

- Each section **reached** pays at once, more for each: `coins(section) = (1.5 + 0.3 x playerLevel) x section^1.5` (the Tower's curve shape; a full first run at player level 10 pays about 430 coins), plus a **bundle of that
  element's own material** (Stone: Granite Shards, Ember: Ignite Ore, Frost: Glacial Crystal, Storm: Charged Flint, Void: Shadow Dust). Materials pay for a limited number of
  sections a day, like the Tower's bundles, so the maze is not a material faucet.
- **Escape chest** at the exit: a large coin payout and a rare drop, doubled for the first escape of the day, with a speed medal (Bronze / Silver / Gold by time).
- Coins share the **daily allowance** with the other runs; XP and the leaderboard counters are uncapped. Player XP is paid for each section and for escaping (`MazeData.PlayerXp`).
- A daily challenge target (a section to reach) pays a bonus chest once a day.

## What exists already and is reused

`CourierRewards` (daily allowance, Courier level), `TowerArt.Portal` (the doorway into the maze), the Sky Tower's pattern: data, pure layout, round clock, rewards, runner,
art, skin, service and client controller, plus the mesh pipeline (generated models listed in `AssetData`, loaded into `ServerStorage` by `GolemAssetLoader`, drawn on plain
parts through a mesh skin so the rules and collision never depend on a mesh having loaded).

## Build order

1. `MazeData` and `MazeLayout` (the maze from a seed) with tests. **(first)**
2. `MazeZombie` (the hunter's brain: shortest path to the nearest player, speed ramp), `MazeRound` (the clock), `MazeRewards`, with tests.
3. Meshes: the Zombie Golem, floors, walls and decorations for the five themes (generated, then listed in `AssetData.MazeMeshes`).
4. `MazeArt` (builds the maze, plain parts first, meshes drawn on top), `MazeService` (portal, rounds, zombie, catches, rewards, anti-cheat) and the remote events.
5. `MazeController` (HUD: countdown, section, warning, results; the zombie's animation).
6. Boards, daily challenge, Studio playtest, balance pass.
