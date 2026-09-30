# EmberForge feature walkthrough (achievability audit)

Automated part: `tests/test_reachability.lua` (198 checks, all pass). It proves that every blueprint has a source,
every recipe fits the forge's material slots and craft tier, every mining zone can be unlocked, and every recipe
material can be obtained (supplier, mining, smelting chain, challenge rewards).

Status key: **Verified** = seen working in Studio; **Unit** = mock tests only; **Needs ids** = code done, Roblox ids missing.

| Feature | How a player reaches it | Status |
|---|---|---|
| Tier 1 Golems (5 elements) | Starting blueprints; Basic Ore/Coal from Supplier or mining | Verified |
| Tier 2-4 blueprints | Forge milestones (Lv3/4/5), weekly challenges, lifetime achievements, rare mining drops (forge level - 2 or higher) | Unit (audit) |
| 8 special Golems + skills | Patchwork/Woven at forge Lv3/4; Coral, Clockwork, Alchemist, Gargoyle, StormJar, Dragonbone via rare blueprint drops | Unit |
| Mining zones | Craft a Golem of that element (Void needs Tier 2); Deep Forge needs forge Lv8 | Unit (audit) |
| Smelting | Raw -> refined chain; every refined input reachable | Unit (audit) |
| Elite / Supreme Golems | Fuse 4 identical Golems (Elite), 4 Elite (Supreme); gear + unique crown | Verified visuals, Unit logic |
| Pets, eggs, merge | Basic/Crystal eggs with coins; 4 pets merge to Elite, 4 Elite to Supreme; odds always shown | Verified single-player |
| Robux Royal Egg | Hidden unless the player's region allows paid random items | **Needs ids** (RoyalEgg_x1/x5/x10) |
| Guilds | Menu: create (500 coins), join by name, weekly challenge, claimable reward, leaderboard | Unit; live only the insufficient-coins path |
| Seasonal Golems | Season rewards + Event Catalysts (earned from two weekly challenges) | Unit |
| Pads, zones, game passes | In-world prompts | **Needs ids** (product ids still 0 = "Coming soon") |
| Phone layout | Sidebar/menus respect the top bar | Verified in emulator |

## Gaps and risks found
1. Developer Product / Game Pass ids are still 0 (Royal Egg, pads, zones, catalyst). Nothing paid can be bought until they are set.
2. Pets seen by *other* players, real receipts, multi-server guild writes: untested (need a live 2-player test).
3. The "All" (Primordial) event Golem has no unique body (intentional for now).
4. Game icon / thumbnails must be set in Creator Hub (only draft screenshots exist in `marketing/draft-screenshots/`).
5. Design tension: the spec says players build companions rather than buy them; random pet eggs (especially Robux) bend that. Pet boosts are capped at +20% per stat, so progression isn't gated, but this is a product decision to confirm.
6. Guild extras (shared Guild Forge, invites/roles, chat) are not built.
