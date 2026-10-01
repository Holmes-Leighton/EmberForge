# EmberForge to-do list

## Art and animation
- [x] ~~Pet movement animations~~ done: 14 segmented pets (ServerStorage > UploadedAssetSources > PetPack) animated by code (PetRig).
- [x] ~~Upload the new PetPack~~ done (136723892869054)
- [ ] Golem animations (idle, mine, walk): the code is ready for them (`AssetData.Golem.*.animations`), none are uploaded yet.
- [ ] Game icon and thumbnails (Creator Hub); draft screenshots are in `marketing/draft-screenshots/`.

## Monetisation (needs ids from Creator Hub)
- [ ] Developer Product and Game Pass ids in `ProductData.lua`: Royal Egg x1/x5/x10, Lucky Boost, Speed-Ups, slot packs, Magnet,
      Event Catalyst, Season Pass, pads, forge skins. Until set they show "Coming soon".

## Testing that needs more than one player
- [ ] Other players seeing your pets and forge builds.
- [ ] Trade request popup: accept and decline end to end.
- [ ] Guild invites, chat, Guild Hall, guild and ladder writes across servers; a full week and season rollover.
- [ ] Guild chat text filtering (only runs on a published place).

## Gameplay and UX (from the new-player walkthrough)
- [ ] The anvil's E prompt only worked with the anvil in front of the camera: check on a real client; add a floating arrow for tutorial step 2.
- [x] ~~Forge menu opens on Blueprints while tutorial step 3 says deploy~~ now opens on Deploy when a Golem is waiting for work.
- [x] ~~Two Storm Golem entries in the Anvil list~~ stronger tiers carry their tier name.
- [x] World labels stacking near the anvil: pad signs now fade beyond 90 studs.
- [x] ~~Several toasts at once cover the sidebar~~ the stack now sits left of the button column.
- [ ] Ascension lives inside the Build menu: consider its own tile once players reach Forge Level 10; coin amounts now show as "25K" (done).
- [ ] Balance pass with real play data: build prices, Ascension costs, ladder tiers, prize sizes, pad ore rates.

## Universes / worlds (idea, not started - revisit once the game has players)
Recommendation: not yet. Six mining zones, the Quarry and pets already give plenty to do, and separate worlds would split a small player base.
- [ ] Cheaper first step: make each existing mining zone a more distinct biome (Lava, Ice, Grass/Forest, Desert, Swamp ...) with its own look, ambience and
      themed pets/Golem skins, so it feels like a new world without a new place.
- [ ] Prestige worlds: Ascension (or a new "Rebirth") moves you into a second world with a different resource chain, earned rather than separate.
- [ ] True separate worlds later: teleport hubs into extra places (each its own published place, shared player data through the same DataStore keys,
      a world picker in the HUD, per-world leaderboards and events). Needs the game published first, and cross-place data/trading rules decided.
- [ ] Per-world pets and eggs (a Lava Egg, an Ice Egg ...) fit the pet index: one more reason to collect.

## Features not built
- [ ] Rail track meshes (the AI generator makes them too small; the piece is built from parts in code).
- [ ] Guild extras beyond the current set: roles other than leader, guild banners, guild-vs-guild events.

## New feature ideas
- [x] ~~Player-built mining zones~~ built as the **Quarry** (Forge Level 6, 15,000 coins): 11 pieces, adjacency recipes, 5 exclusive materials, Core upgrades, animated by QuarryAnimator.
- [x] ~~Upload the QuarryPack~~ done (89170227615937)
- [x] Quarry crew: idle Golems can work the Quarry (+8% per tier, up to 4 Golems, +100% cap).
- [x] Quarry sign over the Core (owner, core level, nodes, crew).
- [ ] Quarry follow-ups: visitor view, Storm node mesh still renders pinkish-peach (the generator ignores yellow): swap for a better one, recolour in code if the generator allows.

- [x] Idle animations: pets (look about, stretch, shake, hop) and Golems (look, flex, stomp, inspect pickaxe) pick random moves with rests between (IdleMoves).

- [x] Pet maturity: Baby/Young/Adult/Elder (worn time 0/2/8/24h), boost x0.6/0.8/1.0/1.25, size 0.72-1.12, old pets count as Adult, merged pets start Young.
- [x] Quarry node maturity: Budding -> Mature (x1.3, after 1 day) -> Prime (x1.6, after 3 days); bigger models, menu shows progress, fair credit across stage changes, total output capped at x3, old nodes start Mature.
- [x] Pets can be traded and sold on the Market (Pets tab); duplicate pets can all be worn; pet Collection tab (index) with Elite/Supreme forms.
- [x] Face portraits (pets, Golems) and spinning 3D mesh icons (26 materials, 15 HUD buttons) in the menus.
- [x] Feature gates: Pets L2, Trades L3, Build L4, Guild L5, Quarry Forge 6 show a requirement label on the HUD button (table in FeatureGates.lua); server refuses the actions too.
- [ ] Place-based labels ("Go to your forge" for Build) and locks on options inside menus (Elite Forge tab etc.).
- [ ] More 3D icons: toasts, trade window and quest rewards still use plain text/emoji.

## Running the tests
`python tests/run_tests.py` needs the `luau` runtime (https://github.com/luau-lang/luau/releases) on PATH or in the `LUAU` environment variable.
