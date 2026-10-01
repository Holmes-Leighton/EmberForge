# EmberForge to-do list

## Art and animation
- [ ] **Pet movement animations**: walk, idle and happy animations for the pets (legs, tail, head and body motion), instead of the
      current simple bob and hover in `PetController`. Needs animated rigs or per-part tweening for the 14 generated pet meshes.
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
- [ ] World labels (pad names, anvil, "Open to everyone") stack on each other near the anvil.
- [ ] Several toasts at once cover the sidebar.
- [ ] Ascension lives inside the Build menu: consider its own tile once players reach Forge Level 10; coin amounts show as "25.0K" (use 25K).
- [ ] Balance pass with real play data: build prices, Ascension costs, ladder tiers, prize sizes, pad ore rates.

## Features not built
- [ ] Rail track meshes (the AI generator makes them too small; the piece is built from parts in code).
- [ ] Guild extras beyond the current set: roles other than leader, guild banners, guild-vs-guild events.
