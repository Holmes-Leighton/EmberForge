# EmberForge: spec review, gap analysis and status

This started as the gap analysis of the code against `EmberForge_Development_Specification.docx` (read in full,
then re-read to verify). It has since been worked through; this version records **what was found, what was fixed,
and what is still open**. Nothing has been run in Roblox Studio itself. The code is verified with the Luau
analyzer, cross-file checks and a mock-environment test suite (see SETUP.md), which is strong evidence but not a
substitute for a playtest.

## 1. Critical issues found, and fixed

| # | Problem | Status |
|---|---|---|
| C1/C2 | Negative / fractional quantities duplicated items in the Market and in trades | **Fixed**: every quantity, price and id is validated; items are rebuilt from server data (test_trading) |
| C3 | Market Golem listings destroyed the Golem (buyer got a stub) | **Fixed**: the real Golem is stored and delivered |
| C4/C5 | Lifetime achievement rewards claimable forever; challenge XP granted twice | **Fixed**; lifetime rewards now also pay out when they unlock (they never paid before) |
| C6/C7 | Any season claimable; season dates one year in the past | **Fixed** |
| C8 | Robux receipts never matched (string keys vs numeric ids); product ids unset | **Fixed** in code (`ProductData`); **you must paste real product ids** |
| C9 | Client dead-ended if data loaded slowly | **Fixed** (retry) |
| C10 | No session locking; unsafe fallback to fresh data after a failed load | **Fixed**: session lock, safe load, credits for offline sellers, save on shutdown |
| C11 | Golem id collisions | **Fixed** (GUIDs) |
| C12 | Pads were an unlimited faucet | **Fixed**: pads top stock up to a cap (300 Ore / 150 Coal); higher pads only fill it faster |
| C13 | Season Pass jumped slots to 12 | **Fixed**: pass gives +3 slots on top of earned ones (spec 3.4) |
| new | Smelt dialog crashed on selecting a material (blocked all smelting) | **Fixed** (found by the analyzer) |
| new | Mastery XP inflated, level-up spam; challenge completions re-reported | **Fixed** |

## 2. Features that were built but unreachable, now working
Direct trading (offers, live view, confirmations, history) · Market (Golems, my listings, cancel, names) · Speed-Ups ·
Repair and durability display · Storage Vault · challenge/achievement/mastery notifications · purchase and claim
feedback · season community progress and real claim states · event Golems (window: week 2 onward of the live
season) · Event Catalyst earnable through weekly challenges · Void / Shadow Dust dead end · Tier 4 route (rare drops +
challenges) · forge-milestone blueprints · tier unlock rules (3x T1 → T2, 2x T2 → T3) · cosmetics (equip, titles, store).

## 3. Spec sections: current status
| Area | Status |
|---|---|
| Core loop, offline production, storage 4/8/24h | Done |
| Golem tiers, stats, slots, durability, repair, fusion | Done (fusion: any elements, same tier) |
| **Rarity + Neon / Mega Neon** (added at your request; rarity comes from tier, never a dice roll) | Done |
| Material-quality stat bonus, Storm boosting other Golems | Done |
| Forge levels: unlocks, material slots, 5 smelt slots at base, batch smelting times, Player XP from smelting | Done |
| Forge visuals that change with level (L1 / 3 / 5 / 8 / 10), animated gears, aura ring | Done (procedural) |
| Mining zones: unlocks, drop tables, six biome environments | Done (procedural) |
| Mastery bonuses + Mastery UI + level-20 title | Done |
| Player level rewards (cosmetics, coins) | Done |
| Daily / weekly / lifetime challenges | Done |
| Trading, Forge Market, trade history | Done |
| Forge visiting, friends-only lock, Top Forges board, "My Forge" teleport | Done |
| Season Pass tracks, weekly claims, community milestone | Done (rewards are data-driven; see open items) |
| Monetisation: purchases, receipts, Speed-Ups, Slot Boost, Magnet, Storage, cosmetics store | Done in code; needs product ids |
| Security: server authority, rate limits, validation, receipts, atomic trades | Done |
| Performance: Golem animation is client-side with distance LOD; UI scales for small screens | Done (untested on a real phone) |
| Live ops: remote config, timed events, Double-XP weekends, admin commands | Done |
| Analytics hooks, loading screen, audio framework | Done (audio silent until you add sounds) |
| **Forge Supplier** (standard goods always in stock, daily limits, coin sink) and **notification badges** on the sidebar | Done |

## 4. Still open
**Needs you (cannot be done from code)**
- Real **3D models / animation** (Golems, forge, zones are procedural placeholders), **audio** files, **icons**.
- **Developer Product ids** in `ProductData.lua`, group / permissions, Discord etc. (business setup).
- A **Studio playtest** on desktop and a phone: rendering, physics, MarketplaceService and real DataStores behave differently from my mocks.

**Design decisions taken on your behalf** (easy to change)
- Pads (mine, not in the spec): capped stock, level-gated speed tiers, admin pad 100x. Two crafting UIs exist (world Anvil + Forge menu).
- Smelt queue: 5 slots at base (spec 4.2) rather than the 2 in the forge table.
- Tier 4 blueprints come from rare drops and challenges (the tier table says "Unlock Tier 4 Forge"; the blueprint table says event-only, so I chose the reachable reading). Tier 5 stays event-only.
- Blueprint trading stays forbidden (spec 7.1) although 4.3 lists it as a source: contradiction in the spec.

**Not built**
- **Guilds** (Phase 2 in the spec).
- "Blueprint research" and "Golem specialisation" (spec 2.2 lists them as session activities but defines no mechanic).
- Season Pass extras: Premium "early access to next season preview"; event storyline; Week 3 / Week 4 event messaging beyond the live-ops notifications.
- Seasonal event Golem-specific art (Magma Titan etc. use the generic model at their tier).
- Achievement badges via Roblox BadgeService; friend-invite rewards.
