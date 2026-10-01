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
- [ ] Forge menu opens on Blueprints while tutorial step 3 says "deploy" (Deploy is the second tab).
- [ ] Two "Storm Golem" entries in the Anvil list (Tier 1 and Tier 4): show the tier or a distinct name.
- [x] World labels stacking near the anvil: pad signs now fade beyond 90 studs.
- [ ] Several toasts at once cover the sidebar.
- [ ] Ascension lives inside the Build menu: consider its own tile once players reach Forge Level 10; coin amounts show as "25.0K" (use 25K).
- [ ] Balance pass with real play data: build prices, Ascension costs, ladder tiers, prize sizes, pad ore rates.

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
- [ ] Quarry node maturity (nodes grow Mature/Prime for more output and a bigger model) - next.
