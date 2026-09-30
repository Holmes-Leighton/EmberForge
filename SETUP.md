# EmberForge: setup & operations

## 1. Run it in Studio
1. Install Rojo (Rojo plugin in Studio + `rojo` CLI or the VS Code extension).
2. In this folder run `rojo serve`, open a Baseplate place in Studio, Plugins → Rojo → Connect.
3. Press Play. Everything (world, pads, anvil, UI) is built by scripts. There is nothing to place by hand.

In Studio the game uses an in-memory save (a `[SafeDataStore]` warning appears) until the place is published.

## 2. Before you publish
| Task | Where |
|---|---|
| Publish the place, then Game Settings → Security → **Enable Studio Access to API Services** | Studio |
| Set **Max Players = 20** | Game Settings → Players |
| Create these **Game Passes** (Monetization → Passes) and paste each id into `ProductData.GamePasses` (id 0 = not for sale): Copper Pad 149, Iron Pad 299, Gold Pad 599, Storage Expansion 299, and Forge Skins Basic 200 / Ember, Frost, Storm 300 / Void 400 (R$). They are permanent, restored on every server, and can't be bought twice | Creator Dashboard → Monetization → Passes |
| Create the **Developer Products** (Speed-Ups, Slot Boost, Material Magnet, Event Catalyst, Season Passes) and paste each numeric id into `ProductData.Products` (id = 0 means "not for sale yet"). Season passes stay Developer Products because each season ends; the client refuses a second purchase of a tier already held | Creator Dashboard → Monetization |
| Add admin UserIds (the place owner and Studio are admins automatically) | `GameConfig.ADMIN_USER_IDS` |
| Add audio (your own or properly licensed; ids are 0 = silent) | `src/Shared/Data/AudioData.lua` |
| Season dates are UTC timestamps for 2026 | `src/Shared/Data/SeasonData.lua` |

## 3. Live operations (no update needed)
In-game, admins can type in chat:
- `/event xp 2 24` double XP for 24 hours · `/event drops 3 12` triple resource drops for 12 hours
- `/event list` · `/event clear`

Weekends (UTC Saturday and Sunday) are **Double XP** automatically. Tunable numbers (production speed, daily
coins, market fee, smelt XP…) can be changed remotely with `LiveOpsService.SetOverride("ONLINE_PRODUCTION_SPEED", 30)`
from the Studio command bar on a live server; they are clamped to safe ranges and refreshed every 5 minutes.

## 4. Tests
The repo has automated tests that run the real code against a mock Roblox environment:
```
python3 tests/run_tests.py        # all suites (needs the `luau` runtime on PATH, or LUAU=/path/to/luau)
python3 tests/check_calls.py      # cross-file check: every Module.func() call and RemoteEvent exists
```
Suites: `test_supplier` (standard-goods limits), `test_trading` (exploit attempts), `test_core` (saves, locking, claims, receipts), `test_progression`
(tier rules, smelting, blueprints), `test_neon` (rarity + Neon), `test_liveops`, `test_ui_load`, `test_ui_flows` and `test_ui_world` (world, forge and Golem model builders)
(every menu is built and its buttons clicked against a fake UI).
They can't replace a Studio playtest (real rendering, physics, DataStore, MarketplaceService), so please play it.

## 5. First playtest checklist
1. Join → loading screen → How-to-Play popup → tracker says "Stand on the Starter Pad".
2. Walk onto the glowing pad: Ore/Coal totals rise (stops at 300 / 150).
3. Golem Anvil → press E → pick a Golem → Forge. It appears in **Forge → Deploy** and in the Inventory.
4. Deploy it: a model appears in that zone's crystal area; the numbers above **Collect** climb; press Collect.
5. Forge → Neon Cave: with 4 identical idle Golems the button lights up.
6. Two players: visit each other's forge, Request Trade, add items, both confirm.
7. Style menu: equip a title and skin (unlock some with `/event`-free ways: level up or the Season Pass).
