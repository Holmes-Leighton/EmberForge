# EmberForge feature walkthrough (achievability audit)

Automated part: `tests/test_reachability.lua`. It proves that every blueprint has a source, every recipe fits the forge's
material slots and craft tier, every mining zone can be unlocked, every recipe material can be obtained (supplier, mining,
smelting chain, challenge rewards), every Forge Builder piece appears in the shop, and the Ascension and ranked-ladder
goals are reachable. The whole mock suite is `python tests/run_tests.py` (17 files, all passing) plus
`python tests/check_calls.py` (every remote used is declared and handled).

Status key: **Verified** = seen working in Studio; **Unit** = mock tests only; **Needs ids** = code done, Roblox ids missing.

## Core loop
| Feature | How a player reaches it | Status |
|---|---|---|
| Tier 1 Golems (5 elements) | Starting blueprints; Basic Ore/Coal from the Supplier or mining | Verified |
| Tier 2-4 blueprints | Forge milestones (Lv3/4/5), weekly challenges, lifetime achievements, rare mining drops | Unit (audit) |
| 8 special Golems + skills | Patchwork/Woven at forge Lv3/4; the rest via rare blueprint drops | Unit |
| Mining zones, smelting | Craft a Golem of that element; Deep Forge needs Forge Lv8; every refined input reachable | Unit (audit) |
| Elite / Supreme Golems | Fuse 4 identical Golems, then 4 Elites; gear and unique crown | Verified visuals, Unit logic |
| Seasonal Golems | Season rewards + Event Catalysts (earned from two weekly challenges) | Unit |

## Companions
| Feature | How | Status |
|---|---|---|
| Pets, eggs, merge | Basic/Crystal eggs with coins; 4 pets merge up; odds always shown | Verified single-player |
| Robux Royal Egg | Hidden where Roblox restricts paid random items | **Needs ids** (RoyalEgg_x1/x5/x10) |

## Forge Builder (coins only)
| Feature | How | Status |
|---|---|---|
| 30-piece catalogue | Build menu: shop restocks every 5 minutes (same on every server), up to 3 of a piece per restock | Verified (buy, place, draw); Unit (rules) |
| Placing | Stand on your forge, press Place: it appears in front of you; server checks bounds, spacing, 30-piece cap | Verified |
| Perks | Small, capped at +20% per stat; only your best fire counts | Unit |
| Selling back | Half the price | Unit |

## Competitive and live ops
| Feature | How | Status |
|---|---|---|
| Hourly event | Automatic every UTC hour: Ember/Stone/Frost/Storm/Void Hour (x2 that element), Lucky, Double XP, Bonanza; banner with countdown | Verified banner, Unit logic |
| Surges | About a third of 3-hour windows get a 10-minute Meteor Shower / Rich Vein / Forge Frenzy, announced to everyone | Unit |
| Guilds | Create (500 coins), join by name or invite, chat, Guild Hall, guild level perk, weekly challenge, top-10 battle prizes, leaderboard | Verified live: create, chat, hall, invite popup; Unit: the rest |
| Trade requests | A request popup (avatar, name, forge level, title) must be accepted before the trade window opens | Verified popup; Unit not possible (needs two players) |
| Ascension | Forge Lv10, 25k x n^2 coins, 10 times; permanent bonuses, title, sign, leaderboard | Unit; menu verified |
| Ranked ladder | 4-week seasons; mining earns points; tiers Bronze..Champion; top-100 and tier prizes claimed next season | Unit; menu verified |
| Daily login streak | 7-day reward ladder granted on join; missing a day resets | Verified (day 1), Unit |
| Codes | Rewards menu: EMBERFORGE, LAUNCH, GOLEMS (edit `CodeData.lua` to add more) | Verified (redeem + repeat refused), Unit |
| Lucky Boost (Robux) | 1 hour of x2 rare drops, also given by streak day 7 and a code | **Needs id** (LuckBoost_1h) |
| Leaderboards | Resources, Golems, Forge, Trades, Ascended | Unit |

## Gaps and risks
1. Developer Product and Game Pass ids are still 0: Royal Egg x3, Lucky Boost, Speed-Ups, slot packs, Magnet, Event Catalyst,
   Season Pass, pads and forge skins. Nothing paid can be bought until they are set in `ProductData.lua`.
2. Not testable from one Studio client: pets seen by other players, builds seen by visitors, real purchase receipts,
   guild/ladder writes across servers, a full week/season rollover live.
3. Balance numbers (build prices, Ascension cost, ladder tiers, prize sizes) are first guesses and need real playtime data.
4. The Primordial ("All") event Golem now has a body (EF_All in the GolemPack in Studio): it shows in game once the GolemPack is re-uploaded and its id swapped in AssetData.Pack. Rail Track is built from parts in code instead of a mesh.
5. Game icon and thumbnails must be set in Creator Hub (draft screenshots in `marketing/draft-screenshots/`).
6. Guilds now have leader tools (remove member, hand over leadership), invites with an accept popup (same server only), filtered guild chat (last 30 messages, polled every 4s while open), a Guild Hall teleport and a guild level that gives members +2% mining per level (max +10%). Chat uses Roblox text filtering, which only runs on a published place, so test it there.
7. Codes are not capped globally across servers (`maxUses` is not enforced); keep any limited code generous.

## New-player walkthrough (played in Studio as a brand-new account)
Path: welcome screen -> Starter Pad (about 15s for the first 10 ore and 5 coal) -> Golem Anvil -> Forge -> Deploy -> Collect.
The tutorial completes in a couple of minutes and the Collect button, summary pop-up, Bag badge and "Claim your reward!" hint on Quests
all point the player at the next step. Menus checked: Anvil, Forge, Bag, Quests, Market, Shop, Pets, Season, plus the earlier ones.

Fixed during the walkthrough:
- The Quests screen showed the progress from login, so finished challenges still read 0/1. It now re-reads the server every time it opens.
- Tutorial tip box cut its hint off mid-sentence and sat on top of menu tabs and titles (now taller and below menus).
- Raw ids shown to players: challenge toast ("weekly_discover_zone"), reward lists ("RefinedOre"), deploy toast ("EmberDepths"),
  smelt toast, Season Pass rewards ("ChargedFlint x30"), "+1 BasicOre" pick-up text, "Best at: MiningRate".
- Toasts cut off long messages (now two lines); pick-up text printed several lines on top of each other (now one block).
- HUD: coins were shown with a lightning-bolt symbol (the same symbol as energy) and "M: Lv 1" was cryptic (now "400 Coins", "Mastery Lv 1").
- Bag title collided with its subtitle; Shop price text was tiny and hard to read; Season Pass benefit lines ran under the Buy buttons.
- Pets opened on an empty "My Pets" page for a new player (now opens on Eggs until you own a pet).
- Welcome text no longer uses an emoji that renders as a broken glyph.

Still open from the walkthrough:
- The anvil's E prompt only appeared/worked once the anvil was in front of the camera; I could not tell whether that is the test harness or the game.
  Worth checking on a real client, and consider a floating arrow to the anvil for step 2.
- The Forge menu opens on Blueprints while tutorial step 3 says "deploy" (Deploy is the second tab). Crafting is also possible from both the world Anvil and the Forge.
- The Anvil list has two entries both called "Storm Golem" (Tier 1 and Tier 4).
- World labels (pad names, anvil, "Open to everyone") stack on top of each other near the anvil.
- Several toasts at once cover the right-hand sidebar.
- The Royal Egg rows read "Coming soon" until their product ids exist.