# EmberForge to-do list

## Art and animation
- [x] ~~Pet movement animations~~ done: 14 segmented pets (ServerStorage > UploadedAssetSources > PetPack) animated by code (PetRig).
- [x] ~~Upload the new PetPack~~ done (136723892869054)
- [ ] Golem animations (idle, mine, walk): the code is ready for them (`AssetData.Golem.*.animations`), none are uploaded yet.
- [x] Game icon and 16:9 thumbnail made (`marketing/GameIcon.jpg`, `marketing/GameImageDisplay.jpg`; prompts and guide in `marketing/`).
- [x] Upload the icon and thumbnail in Creator Hub (done). Product and pass ids are set in `ProductData.lua`.
- [x] Landscape collision: the chunky scenery meshes (rock and crystal clusters, ore crates, stalagmites, boulders, glow clusters, spires, wall pieces, ice pieces) are solid
      now (`SOLID_PIECES` in `BiomeArt.lua`); hanging, floating, plant, pad and road-frame pieces stay walk-through. Walk the caves and the hub once to look for any place that
      now blocks a path or traps a player, and add `solid = false` to a piece if so.
- [ ] **A real mesh for the Cart Run depot** (the stone hall at the end of each course is built from parts now): an entrance arch, hall and buffer wall as one piece.
- [x] Cart Run depot: each course now ends in a stone hall (entrance frame and sign, roof, lanterns, a buffer wall) that the cart is pushed *into* and stops against
      (`CartCourseArt.BuildDepot`), built from parts.
- [ ] **Cart Run meshes**: swap in real meshes for the depot hall, the crusher gate, tunnel mouths, bridge planks and checkpoint banners (`CartCourseArt.lua`: each is a
      separate named part). Prompts for the mesh generator are in `ART_BRIEF.md` part B.
- [ ] **Everything in the forge should be a mesh (do this next; user request).** The house shells are now meshes (below), but these are still plain parts in `ForgeBuilder.lua`:
      the three elemental braziers (L5+, orange/blue/pink flames; `DoorAssets.brazier` mesh exists from the tower door), lava channels, furnace, anvil, workbench, crates, ore piles, wing
      chimneys, conduits and path. Replace each with a mesh (per look where it differs) and keep the part version as the fallback.
- [x] ~~Forge house meshes~~ done: 28 meshes (7 looks x 4 tiers, each a different design: volcano, igloo palace, tesla foundry, floating shard sanctum, Greek temple, steampunk factory, plain),
      wired through `AssetData.ForgeSkinMeshes` House1-4 and checked in Studio (default/ember/frost/bronze/ancient seen on real forges). Original brief, kept for the interior pieces:
- [ ] (original brief) The workshop building at the back of every plot (walls, pitched roof, chimney, furnace, workbench) is built from plain parts in
      `ForgeBuilder.lua`. Make it generated meshes with a **different design per skin family**, so skins differ in shape, not only colour, the same way the Gate and Fence now do
      (`ForgeSkinProps.Piece`, `AssetData.ForgeSkinMeshes`). Plan: 4 house tiers x 7 looks (plain/Basic, ember, frost, storm, void, ancient, bronze) = 28 meshes.
      Tiers (from `ForgeData` / ART_BRIEF section 5): **1-2** open lean-to shed over the forge; **3-5** enclosed stone workshop with pitched roof and chimney; **6-9** the same with a second wing
      (wider); **10** the Ancient Forge with kiln dome and aura ring. Each tier needs its own roof so levels visibly grow. Keep a wide open doorway at the front so the forge and Golems
      show from the courtyard, and add an invisible collider for the walls. Also give the furnace, anvil and workbench inside the house a mesh per look. Then wire a `House` piece
      per tier into `AssetData.ForgeSkinMeshes` and have `ForgeBuilder` use it (part-built house stays as the fallback, like the gate).
- [x] ~~Forge decorations as meshes with animations~~ done: all 10 (`AssetData.ForgeDecorationMeshes`, built and animated by `ForgeDecorFx.lua` + `DecorAnimator.lua`): living flames,
      orbiting and floating pieces, a swirling portal, flashing lightning arcs, mist, glitter and embers. The missing Forge Builder piece RailTrack is also done (`AssetData.BuildExtras`).
- [x] ~~Forge skin gate and fence meshes~~ done: a different gateway and fence section for every skin family.
- [ ] Look at the **Ancient** forge skin and the 10 decorations once on a real forge (your save only owns the Anvil decoration); tune the animation spots (flame positions, orbit radii) in `ForgeDecorFx.lua`.
- [ ] **My Forge needs a lot of visual work**: real meshes for the forge buildings and furniture (shed and workshop levels 1-10, furnace, anvil, workbench, vault,
      fences, banners, the Forge Builder pieces) in place of the plain parts, and every solid piece must **collide** (no walking through walls, furnaces,
      barrels, pedestals or fences; check each forge level and every Forge Builder piece). Includes the **Forge Skins** (Basic, Ember, Frost, Storm, Void: each
      needs its own materials and a distinct look, not only a recolour) and the Forge decorations. Code: `ForgeZoneService.lua`, `ForgeBuilder.lua`,
      `ForgeBuildData.lua`, `CosmeticData.lua`. Prompts and the level-by-level look are in `ART_BRIEF.md` section 5.

- [ ] **Season rewards: every week so far can be claimed at once.** Not an exploit: `SeasonPassService.ClaimWeekReward` only blocks weeks that have not started yet
      (`weekNumber > currentWeek`), and weeks unlock by the calendar. Season 3 started 2026-08-25, so on 2026-10-04 weeks 1 to 6 are all open, and a brand-new player
      can claim all of them in one go (the paid Standard/Premium tracks still need the pass). Decide whether that catch-up is wanted. If not, options: only let
      players claim the current and previous week, or unlock each week by progress (season XP / weekly challenges done) instead of by date.

- [ ] **The menus need to be more engaging.** They are plain dark panels with small text. Ideas to scope with the user: bolder cartoon styling in the game's own style
      (chunkier frames, bigger icons and headings, rarity colours and glows), animated opens and closes, sounds on every tap, reward and unlock moments with
      effects (confetti, glow, a count-up), progress bars and "next goal" hints on each menu, less text and more pictures, and a consistent look across Forge, Bag,
      Market, Quests, Shop, Pets, Season, Style and Guild. Check on a phone: bigger touch targets. Code: `Theme.lua` (shared look) and the `*MenuBuilder.client.lua` files.

## Monetisation
- [x] Developer Product and Game Pass ids are set in `ProductData.lua` (10 passes, 12 products).
- [ ] Buy one cheap product and one pass on the published place and confirm the item arrives (`LAUNCH_GUIDE.md` phase 4).

## Testing that needs more than one player
- [ ] Other players seeing your pets and forge builds.
- [ ] Trade request popup: accept and decline end to end.
- [ ] Guild invites, chat, Guild Hall, guild and ladder writes across servers; a full week and season rollover.
- [ ] Guild chat text filtering (only runs on a published place).

## Gameplay and UX (from the new-player walkthrough)
- [x] The anvil's E prompt only shows while the anvil is on screen (a Roblox rule): the tutorial now points the way with a bobbing arrow plus an edge-of-screen marker with the distance (`TutorialPointer.lua`, steps 1, 2 and 6), the prompt reaches 16 studs, and the hint says to face the Anvil. Still worth one check on a real phone.
- [x] ~~Forge menu opens on Blueprints while tutorial step 3 says deploy~~ now opens on Deploy when a Golem is waiting for work.
- [x] ~~Two Storm Golem entries in the Anvil list~~ stronger tiers carry their tier name.
- [x] World labels stacking near the anvil: pad signs now fade beyond 90 studs.
- [x] ~~Several toasts at once cover the sidebar~~ the stack now sits left of the button column.
- [x] Ascension tile: an Ascend button appears in the side column at Forge Level 10 and opens the Build menu on its Ascension tab. It uses the emoji icon until a 3D "Nav_Ascend" mesh is added to the nav icon pack.
- [x] Balance pass (model-based, `tools/balance_model.py`): Ascension now 1.5k -> 47k (was 25k -> 2.5M, impossible), ladder tiers re-sized to Golem output, Quarry 10k, Molten Forge 30k, Throne 20k. Pads are capped top-ups so left alone.
- [ ] Re-run the balance pass with real play data once players exist (the model's income and hours-per-day are assumptions).

## Universes / worlds (idea, not started - revisit once the game has players)
Recommendation: not yet. Six mining zones, the Quarry and pets already give plenty to do, and separate worlds would split a small player base.
- [ ] Cheaper first step: make each existing mining zone a more distinct biome (Lava, Ice, Grass/Forest, Desert, Swamp ...) with its own look, ambience and
      themed pets/Golem skins, so it feels like a new world without a new place.
- [ ] Prestige worlds: Ascension (or a new "Rebirth") moves you into a second world with a different resource chain, earned rather than separate.
- [ ] True separate worlds later: teleport hubs into extra places (each its own published place, shared player data through the same DataStore keys,
      a world picker in the HUD, per-world leaderboards and events). Needs the game published first, and cross-place data/trading rules decided.
- [ ] Per-world pets and eggs (a Lava Egg, an Ice Egg ...) fit the pet index: one more reason to collect.

## Features not built
- [x] Rail track: built from parts in code (the AI mesh generator makes them too small), so no mesh is needed. Look at it in Studio and say if it needs more detail.
- [x] Guild extras: officers (up to 3, can remove plain members), leader-set banners (colour + emblem), weekly guild-vs-guild duels (challenge, accept, winner's contributors claim 400 coins + a Speed-Up next week).

## Cart Run (courses in `CartCourseData.lua`; code in `CartRunner`, `CartCourseService`, `CartCourseArt`, `CartCourseController`)
- [x] Three cart courses (Easy Haul, Cave Run, Deep Run) with tunnels, hills, crusher gates and retracting bridges; cart collision body; own daily allowance.
- [ ] Check it in Studio at a real frame rate (the test session ran at about 15 fps): smooth cart, gate and bridge animation, signs, tunnels, the solid cart body.
- [x] A signpost near the spawn pointing east to the courses (names and levels on the board), plus a tall beam over each course's start.
- [x] Balance pass for Cart Run, Courier Run and the Sky Tower (`tools/balance_model.py` now models them): together they paid about 4,100 coins a day at level 10, four times everything else, so pay was scaled down (cart courses x0.8 / x2 / x4.5 with a 1.5x allowance, Courier x0.4 / x1 / x2.5 with a 10-reward allowance, tower coins (0.4 + 0.08 x level) x n^1.35 with a 30-reward allowance): now about 1,600 a day at level 10 (total 2.9k). Still assumptions: replace the session counts in the model with real analytics once players exist.
- [x] Courier Run v1 works end to end in Studio: three flat-ish obstacle courses in the north strip (crate pickup, timer HUD, checkpoints, falls, lava chase, spinners,
      crushers, moving and crumbling platforms, drop-off, results screen with confetti, Courier Level, fastest-time boards, daily challenge). Code: `CourierData`,
      `CourierLayout`, `CourierRunner`, `CourierRewards`, `CourierArt`, `CourierService`, `CourierController`.
- [ ] **Sky Tower** (user request: levels, climb really high like the top obbies, higher = better rewards). Design in `TOWER_DESIGN.md`, modelled on Tower of Hell
      (random tower each round, timer, pay per level rising steeply, speed-up when someone summits) and Mega Easy Obby (a checkpoint every level). Decisions made:
      built in the sky far above the cavern, every level pays and the top pays most. Build order:
      1. [x] `TowerLayout.lua`: composes a tower from a seed (30 levels, about 770 studs; 60 for Pro); tests prove every jump on 60 random seeds.
      2. [x] Tower rewards (`TowerData`, `TowerRewards`: coin curve about 100x from level 1 to 30, a bundle every 5th level that improves with height, rare drops that get
         likelier, a top chest that pays double the first time each day, a daily coin allowance) and rounds (`TowerRound`: 8-minute rounds, a new seed each round on the
         wall clock, 60 s left after a summit). Pay levels are a first guess (a perfect climb is about 3.9k coins at player level 10): check with `tools/balance_model.py`.
      3. [x] Tower art (`TowerArt`, `TowerService`): floating platforms with glowing edges, climbs, a big numbered sign and a colour per level (rainbow with height), the summit ring, a lobby, a portal in the hub near the spawn, and ways back at the lobby and the summit. Seen in Studio. A new tower is built each round.
      4. [x] `TowerService` + `TowerController` HUD (level counter, round clock, live highest-level list, lava sea, level-up and fall effects, end summary), plugged into the
         main game: player XP (`ProgressionService.AddPlayerXP`), new daily/weekly/lifetime Quests (TowerLevel, TowerSummit, CourierDelivery, CourierGold), a "Tower" leaderboard
         tab, coin events, a per-round pay-once rule and a daily material cap. Verified in Studio: the portal starts a run and levels 1-7 paid 2, 9, 16, 24, 33, 42, 52 coins.
      6. [x] Level variety, round 1 (after "absolutely awful obstacle run"): 28 hand-named level designs in 3 difficulty tiers, each with its own look (9 themes) and a name on
         its sign; ladders (real trusses), conveyor belts, slippery ice, bounce pads that throw you up and forward, sweeper bars, tiny islands, and combinations; a tower deals
         from a shuffled deck (28 different designs in 30 levels). The tower stays compact. **Still needs the user's playtest**: which levels are fun, which are dull or unfair,
         and what to add next (jump distances and difficulty are tuned by number, not by feel). The portal now triggers when you walk into it.
      7. [x] Look, round 2 (user: "so basic ... scaffolding pipes things to climb"): the tower sits inside a construction-scaffold frame (four steel corner poles the full height with
         braces, X-diagonals and yellow couplings); metal, dark, lava, slate and wood levels have scaffold-style platforms (cross-beams under the planks, pipe railings); "Pipe Walk" and
         "Pipe Run" levels and the beams in Ice Beam / Narrow Sweep are round steel pipes with flanges and hazard bands. 30 designs now. Still all built from plain parts.
      7b. [x] Look, round 3, from the user's screenshot of the top obbies (Mega Easy Obby, oMega Obby, Ultimate Easy Obby): they are BRIGHT and chunky, not realistic. The tower now uses
         saturated rainbow colours (a hue per level, by height) in smooth plastic with pale glowing edges, a giant rainbow ring you run through at every level start, soft clouds around the
         tower and a cloud sea hiding the cavern floor far below, and a bright yellow scaffold. **Not yet looked at in Studio** (the place was closed): check the colours, ring size and clouds.
         Next ideas from the same screenshot: huge rainbow spiral tunnels, wide striped ramps, hollow square frames to run round, bold zigzag slabs, bigger and fewer platforms.
      7c. [x] Obstacles, round 2 (user: "it isn't just jumping: spinners, floors that fall, tiles that kill you and make you start again"): 9 new designs (39 now): death-tile floors
         (hand-made patterns of red tiles: step on one and you go back to the start of the level; a test proves a safe route exists), falling floors (a grid of tiles that each drop
         after you touch them, with holes), 2- and 3-bar spinners, and combinations (Kill & Fall, Fall & Spin, Kill Sweep). **Not yet seen in Studio.** Open question: should a kill tile on
         the hardest levels send you back further than the level start (Tower of Hell sends you to the bottom)?
      8. [ ] Real meshes for the hero pieces (the user wants scaffolding, pipes and girders to look like the top obbies): generate them with Studio's mesh generator, upload under the
         game's owner, and swap them in (`CourierArt` names every piece; prompts in `ART_BRIEF.md` part B). I cannot see other games, so the user should name or screenshot the look.
      5. [x] Daily challenge (`TowerData.DailyTarget`, `TowerRewards.PayDaily`): a target level that changes through the week; reaching it pays a 4x chest once a day; shown in the HUD
         ("Daily: reach level N") with a banner when done. The leaderboard has a "Tower" tab (highest level ever) and the best summit time is saved.
         [ ] Still to do: a fastest-summit board at the portal, Pro mode (60 levels, 2.5x; the code supports it, there is no way in yet), gear and mutators.
- [ ] Courier Run: play it by hand at a real frame rate on a phone and a PC and tune the jump distances, platform sizes, speeds and lava pace.

## New feature ideas
- [x] ~~Player-built mining zones~~ built as the **Quarry** (Forge Level 6, 15,000 coins): 11 pieces, adjacency recipes, 5 exclusive materials, Core upgrades, animated by QuarryAnimator.
- [x] ~~Upload the QuarryPack~~ done (89170227615937)
- [x] Quarry crew: idle Golems can work the Quarry (+8% per tier, up to 4 Golems, +100% cap).
- [x] Quarry sign over the Core (owner, core level, nodes, crew).
- [x] Storm node mesh pinkish-peach: now painted in code (texture dropped, yellow Neon) via `recolour = true` in QuarryData. Check how it looks in Studio.
- [x] Quarry visitor view: standing in someone's Quarry shows a read-only panel (owner, Core level, nodes by element, helpers, crew); respects friends-only.

- [x] Idle animations: pets (look about, stretch, shake, hop) and Golems (look, flex, stomp, inspect pickaxe) pick random moves with rests between (IdleMoves).

- [x] Pet maturity: Baby/Young/Adult/Elder (worn time 0/2/8/24h), boost x0.6/0.8/1.0/1.25, size 0.72-1.12, old pets count as Adult, merged pets start Young.
- [x] Quarry node maturity: Budding -> Mature (x1.3, after 1 day) -> Prime (x1.6, after 3 days); bigger models, menu shows progress, fair credit across stage changes, total output capped at x3, old nodes start Mature.
- [x] Pets can be traded and sold on the Market (Pets tab); duplicate pets can all be worn; pet Collection tab (index) with Elite/Supreme forms.
- [x] Face portraits (pets, Golems) and spinning 3D mesh icons (26 materials, 15 HUD buttons) in the menus.
- [x] Feature gates: Pets L2, Trades L3, Build L4, Guild L5, Quarry Forge 6 show a requirement label on the HUD button (table in FeatureGates.lua); server refuses the actions too.
- [x] Place-based labels: Build says "At your forge" until you stand on your forge; My Forge says "You're home"; blueprint badges show the short reason ("Forge Lv 4").
- [x] Locks inside menus (`FeatureGates.InMenu`): Golem fusion Lv 6, Elite Forge Lv 8, pet merging Lv 6; the client labels the control, the server refuses the action. Check the levels feel right in play.
- [x] Trading safety: permanent audit log (trades + market, admin readable), 5s confirm lock after any change, give-for-nothing / lopsided warnings, block a player from the request popup, report from the trade window.
- [x] Admin panel (Admin button, admins only): kick, ban and mute (held across servers), gift coins, materials, eggs, pets, Golems, start/clear events, announce, player lookup (trade log, reports, admin actions); all admin actions are logged. Minimum account age to trade/use the Market (`TRADE_MIN_ACCOUNT_AGE_DAYS`, 7).
- [ ] Trading safety, still open: tuning of the lopsided-value numbers with real play.
- [x] Admin panel extras done: blueprint and cosmetic gifts, player inspector, events pushed to every server at once (MessagingService, falls back to the 5-minute refresh).
- [ ] Admin panel, still open: economy dashboard (coins in circulation, faucet/sink totals), gifting Season Pass items.
- [x] 3D icons: toasts about a material now show its spinning mesh (trade window and quest rewards already did).

## Running the tests
`python tests/run_tests.py` needs the `luau` runtime (https://github.com/luau-lang/luau/releases) on PATH or in the `LUAU` environment variable.
