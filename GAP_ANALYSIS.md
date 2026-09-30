# EmberForge — Spec Review & Gap Analysis

Reviewed: `EmberForge_Development_Specification.docx` (read in full, then re-read to verify) against every
file in `src/` (about 10.8k lines of Luau). Nothing was run in Roblox Studio, so runtime behaviour that I
couldn't confirm from the code is marked *unverified*.

Status key: **Done** = works as the spec describes, **Partial** = exists but incomplete or deviates,
**Missing** = not in the code, **Broken** = exists but doesn't work or is exploitable.

---

## 1. Headline

The core loop exists end to end: mine → smelt → craft → deploy → collect, with server-authoritative
data, DataStore persistence (with backup store and an in-memory fallback for Studio), rate limiting,
daily/weekly/lifetime challenges, mastery, season pass data, a market, leaderboards and forge-plot visiting.

However, **the code has several serious exploits and a number of features that look finished but can't
work**. Fix section 2 before anything is shown to players. Sections 3 and 4 are the remaining feature work.

---

## 2. Critical: exploits, data-loss and economy-breaking bugs (fix first)

| # | Problem | Where | Effect |
|---|---|---|---|
| C1 | **Negative quantity dupe on the Market.** `ListOnMarket` never validates `item.qty`. A negative `qty` passes `RemoveMaterial`'s `have < qty` check and *adds* materials. | `TradingService.lua:208`, `RemoteHandler` `ListOnMarket` | Unlimited free materials. |
| C2 | **Direct trades also accept negative/fractional `qty`.** `AddToOffer`/`_ExecuteTrade` trust the client's numbers. | `TradingService.lua` (AddToOffer, `_ExecuteTrade`) | Steals from or dupes for the other player. |
| C3 | **Market Golem listings destroy the Golem.** The real Golem is removed, but the listing stores the *client's* `{type,id}` table. The buyer receives that stub, which has no element or tier. Cancel does the same. | `TradingService.lua:255, 295` | The seller loses the Golem, the buyer gets a broken object. |
| C4 | **Lifetime achievement rewards can be claimed infinitely.** The claim entry is a temporary table, so `claimed = true` is never saved. | `ChallengeService.lua:178-179` | Unlimited coins, XP, titles. |
| C5 | **Challenge XP is awarded twice.** `ClaimReward` grants it, then `RemoteHandler` grants `result.xp` again. | `RemoteHandler.server.lua:301` | Double XP on every claim. |
| C6 | **Any season's rewards can be claimed now.** The week check uses the *current* season but the client supplies `seasonId`. | `SeasonPassService.lua:32` | Claim Season 5 rewards during Season 1. |
| C7 | **All season start dates are one year in the past** (2025, comments say 2026). `GetCurrentSeason()` therefore always returns Season 5 and every week is claimable. | `SeasonData.lua:21,62,…` | Season logic, event drop multipliers and weekly gating are all wrong. |
| C8 | **Robux purchases can't be granted.** `PRODUCT_HANDLERS` is keyed by strings such as `"EF_SpeedUp_x1"`, but `ProcessReceipt` looks up `tostring(receiptInfo.ProductId)` (a number). Every purchase returns `NotProcessedYet`. Client product IDs are all `0`. | `ShopService.lua:26-…`, `ShopController.lua:19-28` | No monetisation works. Players who pay would be charged and not receive anything once IDs are set. |
| C9 | **Client can dead-end on join.** If `GetPlayerData` is invoked before the server finishes loading, it returns `nil` and the whole client aborts with no retry. | `init.client.lua:24` | Blank game until rejoin (seen once in your logs). |
| C10 | **No DataStore session locking.** Two servers can hold the same player and overwrite each other; offline market payouts write straight to the store. | `PlayerDataService.lua` | Rollbacks and coin loss with multiple servers. |
| C11 | **Golem IDs can collide.** `GenerateId` is `tick()*1000` plus a 4-digit random number; "Craft All" can create many in the same millisecond (roughly a 14% collision chance for 50 in one ms). | `Utils.lua:89`, used at `GolemService.lua:46` | Deploy/recall acts on the wrong Golem. Use `HttpService:GenerateGUID`. |
| C12 | **Pads are an economy hole.** The Starter Pad gives 4 Ore + 2 Coal per second for free, with no cap; Copper/Iron/Gold give 3x/5x/10x. Admin gives 100x, and its output is tradeable. Basic Ore also feeds smelting (Refined Ore for Tier 2). | `PadService.lua`, `PadData.lua` | Trivialises Tier 1–2 and the market. This is my addition, not in the spec (see section 5). |
| C13 | **Season Pass grants 12 Golem slots immediately.** | `ShopService.lua` (pass handlers) | Contradicts "slots are earned, not purchased" (3.4), but the spec table also lists it, so needs a decision (section 5). |

---

## 3. Built but not working / unreachable

| Feature | Problem |
|---|---|
| **Direct player trading** | There's no remote to add items to an offer (`AddToOffer` is never called). The trade window is static, so both players can only accept an empty trade. No live offer view, no confirm state, no trade history. |
| **Speed-ups** | Bought or earned, stored in `SpeedUps`, but there's no remote or UI that spends them (`SpeedUpSmelt` is never called). |
| **Repair Golem** | Server logic exists; no button or UI. Durability drains and a broken Golem silently stops producing. There's no durability display anywhere. |
| **Storage Vault craft** | Server logic exists; no UI. |
| **Storage Expansion product** | Adds +1 tier, so a player at tier 0 gets 8 h, not the 24 h the spec promises (`ShopService.lua:33`). |
| **Challenge completion notices** | `ChallengeCompleted` / `AchievementUnlocked` are never fired by the server; `TrackEvent` returns the completed IDs but callers ignore them. |
| **Mastery** | `MasteryLevelUp` fires *every tick* for every deployed Golem (not only on level-up) and no client listens. XP is credited to every deployed element for every material mined (`init.server.lua:108`), inflating it. |
| **Purchase/listing feedback** | No client handler for `PurchaseResult`, `StorageVaultCrafted`, `GolemRepaired`. Market buy/list and season claim errors are invisible; the Claim button says "Claimed" before the server answers. |
| **Season community progress** | Hard-coded `0 / 0` in the UI. |
| **Event Golems** | Blueprints are never unlocked (no Week 2 gating), `EventCatalyst` has no gameplay source (only Robux), and `element = "All"` (Primordial Golem) has no stat table, so it would produce nothing. |
| **Cosmetics** | Skins, accessories, particles, decorations and titles are stored in data but never displayed or applied anywhere. There's no cosmetic shop UI. |
| **Void progression is a dead end** | Void T1 needs Shadow Dust and a Tier 2 Golem; Shadow Dust only drops in The Hollow; The Hollow needs a Void Tier 2 Golem; Void T2 needs 30 Shadow Dust. Nothing breaks the cycle (only the Season 4 reward gives Shadow Dust). |
| **Tier 4 is unreachable** | T4 blueprints are marked seasonal-event only, the rare-drop code only rolls Tier ≤ 3, and T4 recipes need a `Blueprint_T4` item that isn't defined in `MaterialData` and has no source. |
| **Forge-milestone blueprints** | Spec 4.3 says Tier 2–3 blueprints unlock at forge-level milestones. No code grants them; T2/T3 only come from a few challenge rewards or a random rare drop. |

---

## 4. Spec compliance by section

### 2–3 Core loop, offline, Golems
| Requirement | Status | Notes |
|---|---|---|
| Idle loop, offline production, storage caps 4/8/24 h | **Done** | `IdleEngine`. Formula matches. Pending-pool collect flow added this session. |
| Tier table (stats, 50/180/520/1400/4000 per hr) | **Done** | `GolemData`. |
| Tier unlock conditions ("craft 3x T1", "craft 2x T2") | **Missing** | Strings exist but nothing enforces them; only forge level and the Void gate are checked. |
| Five element specialities | **Partial** | Stat multipliers exist. Storm's "powers other Golems" has no mechanic. Frost/Void "rare/hidden finds" is just the luck stat. |
| Stat modifiers: material quality | **Missing** | Higher-grade materials don't change stats. |
| Fusion "same tier" | **Partial** | Requires same element *and* tier (stricter than the spec). |
| Durability / maintenance | **Partial** | Drains; repair has no UI; no warning. |
| Slots 3→12 by milestone | **Partial** | Logic exists. "Forge Mastery challenge" is just forge level 5 again (grants two slot tiers at once). HUD shows total slots, not used/total. |
| Golem visuals per element/tier | **Partial** | One recoloured blocky placeholder for everything, scaled by tier. Tier 4–5 and event skins are missing. |

### 4 Forge
| Requirement | Status | Notes |
|---|---|---|
| Forge levels 1–10 (XP curve, smelt slots, speed bonus) | **Done** | `ForgeData`. |
| Forge material slots (2…10) | **Missing** | Defined in data, used nowhere. |
| Smelt queue "up to 5 at base" | **Conflict** | Code gives 2 at level 1 (data table); spec 4.2 says 5, spec 4.1 says 2 "material slots". Needs a decision. |
| Smelt time per item | **Balance risk** | Duration is `smeltTime × quantity` (100 ore ≈ 8 h+) and slots are jobs, not items. |
| Smelting mechanics, offline continuation | **Done** | Persisted, restored on join. |
| Speed-ups | **Broken** | See section 3. |
| Forge visual upgrades per level | **Partial** | Only the Level 1 stone forge and fire pit. Nothing changes with level; no smelter/kiln objects; smelting is UI-only. |
| Blueprint sources (milestone, challenge, drops, seasonal, trade) | **Partial** | See section 3. Also spec conflict: 4.3 lists trading as a blueprint source, 7.1 says blueprints can't be traded. |

### 5–6 Mining, economy, progression
| Requirement | Status | Notes |
|---|---|---|
| Six zones, unlock rules, drop tables | **Done** | `MiningZoneData`. |
| Zone environments | **Partial** | Crystal landmarks only; no zone-specific terrain, deposits or Golem work animations beyond a swing. |
| Material tiers Common→Legendary | **Done** | |
| "Economy tunable server-side without an update" | **Missing** | All rates are in module scripts; no remote config. |
| Player XP from crafting, smelting, trading, challenges | **Partial** | Smelting gives *Forge* XP only, not Player XP. |
| Player level unlocks "cosmetic rewards and forge upgrades" | **Missing** | Level unlocks nothing except my Pads (which the spec says a level must not do for core content). |
| Mastery bonuses at 5/10/15/20 | **Partial** | Numbers implemented; L20 title isn't granted; no mastery UI beyond "M: Lv N". |
| Challenges (daily/weekly/lifetime) | **Partial** | Data, tracking and reset done. Bugs C4/C5, no completion notices. "Collect from 3 Golems" counts button presses, not Golems. |

### 7 Social & trading
| Requirement | Status |
|---|---|
| Forge Market (list/browse/buy, coin fee) | **Partial**: bugs C1/C3; rows show raw IDs; the element filter never matches; no expiry or listing cap; not synced across servers (last writer wins). |
| Direct trades | **Broken** (section 3). |
| Blueprints not tradeable | **Done** (server rejects them). `EventCatalyst` is marked non-tradeable but not enforced. |
| Trade history visible | **Missing** |
| Trade confirmation screen showing exact items | **Missing** (UI is a stub) |
| Forge visiting (free, open, trade request button) | **Done** (touch-based zones, overlay). Plot ownership isn't obvious (everyone spawns at one point). |
| Friends-only forge lock | **Missing** |
| Discovery board of top forges | **Missing** |
| Guilds | **Missing**: Phase 2 per spec, fine. |

### 8 Monetisation
| Requirement | Status |
|---|---|
| Season Pass (699 / 1,299), tracks, weekly claim | **Partial**: bugs C6/C7; reward names not shown; extra storage slot / preview access not implemented. |
| Limited event Golems + Catalyst (earnable *and* buyable) | **Partial/Broken**: see section 3. |
| Cosmetic shop (skins, accessories, particles, decorations, titles) | **Missing** (only 5 forge-skin handlers, no UI, not applied). |
| Convenience purchases | **Partial**: shop buttons exist, product IDs are `0`, receipts don't match (C8), speed-ups can't be used. Slot Boost and Material Magnet are implemented server-side. |
| "No material is exclusively purchasable" | **Broken** for Event Catalyst. |

### 9–10 Technical, assets, audio
| Requirement | Status |
|---|---|
| Server-authoritative economy, receipt validation, atomic trades, rate limit 10/s | **Partial**: rate limit and authority are good; the trade/market/season/receipt bugs above undermine them. |
| DataStore every 5 min + on leave, backup store | **Done** (no session locking, no request-budget checks). |
| Offline calc < 500 ms | **Done** (cheap calculation). |
| Server 60 fps / mobile 30 fps / Golem LOD | **Risk**: `GolemVisuals` animates every Golem's parts on the *server* every frame; with 20 players × up to 12 Golems that's heavy. Should animate on the client. No LOD. |
| Max 20 players/server | **Manual**: `MAX_PLAYERS_PER_SERVER` is config only; set it in Studio's game settings. |
| Mobile support | **Missing/unverified**: most menus are fixed pixel sizes (only the Anvil scales); side panels will overlap on phones. |
| 3D assets (15 + 10 Golems, 5 forge variants, 6 zones, 8 equipment, 25 items) | **Missing**: all placeholder primitives. |
| UI: HUD Golem status, smelt queue, notifications, icons, loading screen, main menu | **Partial**: no HUD Golem/smelt/durability indicators, no icons, no loading screen or menu. |
| Audio (ambient, crafting, UI, music) | **Missing** entirely. |
| Analytics/KPI tracking (risk register says "from day one") | **Missing** |
| LiveOps: weekly events (double XP), seasonal week structure, Week 2/Week 4 messaging | **Missing** (no event framework). |

---

## 5. Decisions needed (spec conflicts and my additions)

1. **Pads (mine, not in spec).** They replace the spec's "collect materials" step for the very first Golem, but they run forever and scale up to 100x. Options: cap them (per hour / only until you own N Golems), restrict to tutorial materials, or remove. Also decide whether Admin-pad output may be traded.
2. **Level-gated pads.** The spec says Player Level "never gates core gameplay content". Pads gate income by level.
3. **Two crafting UIs.** The Anvil (world object, my addition) and the Forge menu's Blueprints tab both craft. The spec has one personal Forge. Suggest keeping one and using the other as a shortcut.
4. **Smelt queue size:** 2 (forge data) or 5 (spec 4.2)?
5. **Season Pass slots:** grant +3 (spec 3.4) vs jump to 12 (code) vs remove (spec core principle).
6. **Blueprint trading:** 4.3 lists it as a source, 7.1 forbids it.
7. **Tier 4 source:** the tier table says "Unlock Tier 4 Forge" but the blueprint table says event-only.
8. **Void unlock:** needs an alternative Shadow Dust source.

---

## 6. Recommended order

1. **Security & data (C1–C11):** validate all quantities/prices (positive integers, upper bounds), store the real Golem in listings, persist lifetime claims, remove the double XP, validate `seasonId`, fix season dates, retry on join, GUID IDs, session locking.
2. **Make monetisation real:** real product IDs, match `ProcessReceipt` by ID, spend Speed-ups, fix Storage Expansion, PurchaseResult feedback.
3. **Finish trading:** add-item remote and live offer UI, confirm state, history.
4. **Progression holes:** forge-milestone blueprints, Tier 2/3 unlock rules, Void/Shadow Dust, Tier 4 route, Event Catalyst gameplay source.
5. **Pad economy decision** (cap or scope down).
6. **UX:** durability/repair UI, Storage Vault UI, HUD Golem and smelt status, mastery and challenge notifications, mobile scaling.
7. **Performance:** client-side Golem animation and LOD.
8. **Content/polish:** real models, forge upgrade visuals, audio, cosmetics, loading screen, analytics, LiveOps framework, remote config.

---

## 7. Second-read verification

Re-reading the spec against this list, I confirmed each item above and added these that the first pass had not
caught: smelting XP (6.1), player-level unlocks (6.1), material-quality stat modifier (3.3), the Storm
"powers other Golems" speciality (3.1), Storage Expansion tier (8.1), the Discovery board and friends-only lock
(7.2), trade history (7.1), analytics and remote config (13, 5.3), the blueprint-trading contradiction
(4.3 vs 7.1), the smelt-queue-size contradiction (4.1/4.2), forge material slots (4.1), and the "explore
the forge / blueprint research" session activities (2.2), which have no mechanic behind them.
