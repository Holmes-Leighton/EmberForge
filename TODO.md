# EmberForge to-do list

## Art and animation
- [x] ~~Pet movement animations~~ done: 14 segmented pets (ServerStorage > UploadedAssetSources > PetPack) animated by code (PetRig).
- [x] ~~Upload the new PetPack~~ done (136723892869054)
- [x] ~~Golem growth (Infant, Young, Adult, Elder, Ancient)~~ built: `GolemData.Stages`, grows while deployed (online full speed, offline half), stats x0.70..x1.30, size 0.62..1.16, new Golems start Infant, old saves count as Adult, Elite/Supreme fusion keeps 25% of the combined growth, trade value follows stage, inventory card shows stage + bar. Tier 5 renamed "Primordial Golem". Tests: `test_golemgrowth.lua`, `test_ui_golemstages.lua`.
- [ ] **Golem stage meshes** - IN PROGRESS: **Infant, Young, Elder and Ancient are done for the five elements** (Ember, Stone, Frost, Storm, Void), generated with Studio's mesh generator and loaded straight from the ids in `AssetData.StageModels` (no pack to assemble or upload: the generator publishes each model itself, and `GolemAssetLoader` renames the parts, drops the rig leftovers and sets the shoulder pivots). They use the same Parts animation as the original Golems (checked in Studio: arms, pickaxe and head swing while mining, and both legs swing on a walk). **Still to make:** all four stages for All (the event Golem) and the 8 specials (Patchwork, Woven, Coral, Clockwork, Alchemist, Gargoyle, Storm Jar, Dragonbone): 36 meshes. All 25 element models (5 elements x 5 stages with the Adults) were built together in Studio and run through the real animator: every one has the full set of parts, swings its arm and pickaxe while mining and swings its legs on a walk. Each Golem without a mesh for its stage keeps the Adult mesh dressed in code. Recipe that worked: prompt with the element's look from the Adult, name the face (eyes, eyebrows, nose, smiling mouth) and legs explicitly, `segmentation: explicit` with partNames `Torso, Head, ArmL, ArmR, LegL, LegR, PickHandle, PickHead`, size 6x8x4, 6000 triangles, prompt under about 600 characters (longer ones are rejected). **Publishing is rate limited: generate one or two at a time** (four at once made two fail with 'Too Many Requests'). Look at each next to its Adult before adopting it: the first Storm and Void babies did not match their Adults and were redone. The unused generations are still on your account.
      Every stage already differs on the Adult mesh in code (scale, head size, torso width, limb thickness, colour tone) plus dressing (sprout and eyes, buds, beard and runes, ground ring, back crest, stones).
- [x] ~~Stage colours and family cues~~ done: Infant and Young are duller (a baked texture ignores Part.Color, so a tinted SurfaceAppearance carries the same texture), Elder and Ancient glow brighter (runes, crown, motes, light), the element accent is the same at every stage, orbiting stones use each element's own material, and each stage has a badge colour in the inventory card, the Golem picker and over the Golem's head. Seen in Studio on Ember, Void and Frost. **Not checked:** the dull tint on skinned (rigged) models, and the lighting difference between the original texture and the PBR SurfaceAppearance on Infant and Young.
- [x] ~~Footprints, ground ring, back crest, slot rules~~ done: walking Golems press prints in their stage's style (client side, only near the camera, pooled, max 90), Elder and Ancient get an element-coloured ground ring, the Ancient wears an element-shaped crest up the back instead of a head crown, and chest runes are skipped under an Elite's plate. Unit-tested and the crest and ring seen in Studio on all five elements. **Not seen running in a playtest:** the footprints themselves (a playtest means adding a test Golem to your save). Check in a playtest that prints appear under a Golem walking home to be repaired and on its short walks between mining spots, and tune size and lifetime in `PRINT_STYLE` in `GolemAnimator.lua`.
- [x] ~~Tier 2+ shoulder plates~~ no longer added to a type's own model (they stuck out like planks on the detailed meshes); the shared base body keeps them.
- [x] ~~Growth Tonic~~ built: `GrowthTonic_1h` (99 R$, 2x growth for an hour, online and the covered part of an absence), shop button, handler, tests. **Needs the Developer Product created and its id pasted into `ProductData.lua`** (id 0 = not for sale yet).
- [x] ~~Welcome-back growth line~~ done: Golems that reach a new stage while you are away are listed in a notice after joining.
- [x] ~~Anvil preview label~~ done: "Adult stats (born at 70%)".
- [x] ~~Balance model with growth~~ done (`tools/balance_model.py`): at 1h/day online a Golem left deployed reaches Elder in about 4 days and Ancient in about 19; over a season growth adds roughly 17% to average output (Elder and Ancient are above Adult) and moves no ladder tier. Durability stops a worn-out Golem growing, so real players will be slower; revisit with play data.
- [x] ~~Golem Index~~ done: `data.GolemsSeen` records every type at every stage ever owned (crafting, growing up, trades and the Market all feed it; old saves fill in from the Golems they own, as Adults), shown as a Collection card above the Golem list in the inventory ("5 / 70 forms", five dots per type in the stage colours). Not seen in Studio: how the card looks at real window sizes; a direct player-to-player trade uses the same recording code as the Market but only the Market path is unit-tested.
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
- [x] ~~Premium Golem skins: signature back mesh~~ done: MagmaTitan, CrystalWraith, ThunderColossus, VoidWalker, PrimordialGolem each wear a mesh on the back (`Back_<Skin>` in
      `AssetData.GolemAccessoryMeshes`, placed in `GolemModel`) on top of their code-made material/detail. Seen on block Golems; check on an uploaded Golem model.
- [x] ~~Forge effects as meshes~~ done: the 6 floating pieces of an equipped forge effect are meshes per effect (AncientFlame, ArcLightning, IceFlow, MagmaFlow, VoidRift; `effects` in
      `AssetData.ForgeSkinMeshes`) that float and turn via DecorAnimator; the glow and particles stay. Seen on VoidRift; check the other four.
- [x] ~~Golem accessories as meshes~~ done: all 10 (`AssetData.GolemAccessoryMeshes`, loaded into `ReplicatedStorage.AccessoryAssets`, placed by `CrownModel.AttachAccessory` in `GolemModel`);
      the block crown / helm / hat / orb stays as the fallback. Seen on 10 Golems side by side in Studio; check fit on an uploaded Golem model with a different head size.
- [x] ~~Forge props as meshes~~ done (first pass): anvil, workbench and brazier have a different design per look (7 each); barrel, crate, coal pile and smelter are shared (plain set).
      Wired in `ForgeBuilder.lua` with `MeshProp`/`Ghost` (part version stays as invisible collider / fallback); checked on the void forge in Studio.
- [x] ~~Furnace, vault, banner, trophy, golem pedestal, wall gears, conveyor, floating crystals, side tower as meshes~~ done (furnace per look; the rest one shared design). Gears turn and
      crystals float via DecorAnimator. Checked in Studio on the live level-4 void forge and on level-10 storm, ancient and bronze forges: all sit and face correctly.
- [x] ~~Pad info boards~~ done: every mining pad has a framed mesh board behind it (name, speed, what it mines per second, stock cap, how to unlock; `PadService.BuildPad`). Standing on a paid pad you do not own now opens Roblox's purchase prompt (once per 30 s) as well as the unlock card. NOTE: Studio counts everyone as an admin (`IsAdmin` is true in Studio), so you will not see locked pads while testing there; `tests/test_core.lua` has 2 failures from the in-progress 'admins get every pad' change (mock IsStudio = true).
- [x] ~~Cart Runs harder~~ done: courses redesigned (Easy 600 / Cave 1040 / Deep 1480 studs; tight S-bends and hairpins down to radius 6-7, steeper hills, a 54-stud mountain with a drop), cart tips over if it takes a bend too fast (`CartSim.CornerLimit`), walk against the cart to brake (`CartSim.BRAKE`), depot hall is a mesh (`SignMeshes.Depot`).
- [x] ~~New obstacle types~~ done: lifts (up/down), depth movers (toward/away), orbiting platforms, swinging blade pendulums and beam pads (circles charge, then fire a beam that kills; random circle each shot, never the same twice running). Rules in `CourierLayout` (shared clock functions), kills in `CourierRunner` (used by Tower and Courier), animation in `CourierController`. 10 new Tower designs (Lift Shaft, Elevator Hop, Side Swipe, Back & Forth, Carousel, Orbit Ring, Blade Swing, Axe Alley, Beam Pads, Laser Grid). Animation seen in Studio (lift, blades, beam charge/fire); Hand-tested in Studio with the dev shortcut (set workspace attribute `DevTowerLevel` = N from the Server console to start a climber at level N): beam kill ('Zapped'), blade kill ('Hit by a swinging blade'), lift ride, depth mover and orbit carry all work. Found and fixed: sideways-moving platforms did not carry the player (`MoveCarrying` in CourierController; the old X movers had the same bug).
- [x] ~~Sky Tower and obstacle courses as meshes~~ done (`TowerSkin.lua`, `AssetData.TowerMeshes`): platform slabs, rest decks, crumbling and moving platforms, spinner bar, crusher, death tile, bounce pad, rainbow rings, scaffold girders and clouds (also used by the Courier runs). Seen in Studio: platforms, rest deck, rings, girders, clouds. NOT yet seen: spinner, crusher, death tile, bounce pad in action; conveyors / ice / pipe platforms are still plain; the tower's ground is a bare slab.
- [ ] **Play-through findings still open** (Studio, real input): (1) (partly done above) the **Sky Tower obby levels were all plain parts** - flat coloured pads, tile fields, rainbow rings, a huge lattice of wooden
      cables across the sky and a bare grey floor; they need meshes (platforms, rings, ladders, spinners, a sky backdrop). (2) The **Cart Run depot/tunnel mouth is a big plain brown block** (already
      listed above for CartCourseArt). (3) Not yet seen in Studio: Courier runs, and the Storm / Ancient / Bronze / plain forge looks on a real plot. (4) Camera near the forge gate is hard to place
      while testing; a debug 'jump to forge look' button would help.
- [x] ~~Mining Pads gateway (behind the Golem Anvil) as a mesh~~ done (`PlazaGate` in `AssetData.SignMeshes`, placed by `SignArt.Piece`); lettering moved to a thin invisible panel in front.
- [x] ~~Hub floor clutter~~ done: 8 solid mesh pieces (rubble, broken planks, ore sacks, wheelbarrows, barrel stacks, tool racks, glowing cave mushrooms, floor lanterns; about 1,050 in all,
      nearly half lining the main road) added to the `World` set in `AssetData.BiomeMeshes` and scattered by `BiomeArt` (`BuildScatter`). They are solid, like the rest of the scenery (`SOLID_PIECES`); only the hanging Stalactites are walk-through. The older RockCluster / CrystalCluster / OreCrates / Stalagmite scenery is solid as well.
- [x] ~~Boards and signs as meshes~~ done (`SignArt.lua`, `AssetData.SignMeshes`): a carved frame mesh around the Top Forges notice board and the Courier boards, a plank-sign frame around the
      Cart Runs signpost, and a mesh post for each. The lettering stays on the original panel so text still works; the plain parts stay as fallback. Seen in Studio on the Top Forges board and
      the Cart Runs sign. Not yet framed: the Cart Run depot panels and the Tower portal plank (already a mesh), and billboard-only signs (Welcome, pad names) which have no board.
- [x] ~~Forge ground and remaining plain parts as meshes~~ done: courtyard slab (a design per look), cobbled path, hearth, lava channels, conduits and rune tiles are meshes.
      Left as parts on purpose: the glowing kiln door, aura ring and ForgeDesk (neon effects / invisible prompt anchor), the Golem-gallery trim and the skin-trim neon strips.
      Seen on level-9 ember and void forges; frost, storm, ancient and bronze courtyards not yet viewed.
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

- [x] **Hollow Maze** (user request: a maze with a head start before a Zombie Golem hunts you, one section per Golem family, mesh floors/walls/decor, a new Zombie Golem). Design in `MAZE_DESIGN.md`. Built:
      `MazeData`/`MazeLayout`/`MazeZombie` (shared, seeded from the wall clock so every server has the same maze), `MazeRound`/`MazeRewards` (server rules, tested in `tests/test_maze.lua`), `MazeArt`/`MazeSkin`
      (5 themed sections Stone, Ember, Frost, Storm, Void with mesh floors, walls and decorations; lobby with the coffin; victory room with the exit arch), `MazeService` (portal in the cavern, run, catches,
      rewards, escape speed-up) and `MazeController` (HUD, danger glow, summary card, and the Zombie Golem's walk, drawn on each client). Played through in Studio: all five sections, a full escape (gold time,
      coins, XP, material bundle, summary card) and the zombie waking and catching a player in the lobby. Meshes are generated (`AssetData.MazeMeshes`, `MazeZombie`); the maze works as plain blocks if they do not load.
- [x] **Maze Golem** (user request: the maze's very hard reward, a long-term goal; it follows the Infant to Ancient path). Five pieces (Foot from Stone, Heart from Ember, Pickaxe from Frost, Eye from Storm,
      Crown from Void), 12 of each (60) plus 20 Primordial Ingots craft one Tier 5 Maze Golem. Pieces are bound to the account, the Golem is tradable. At most 2 pieces a day; each section clear rolls its piece
      (1.5% to 4%, deeper is better), the escape chest rolls 7% for one you still need, and a guaranteed piece after 30 clears with none. Simulated: a player escaping 6 times a day takes about 38 days, one
      escaping twice a day about 110. The first piece finds the blueprint so the recipe shows progress. Skill 'Labyrinth Mind': each deployed Maze Golem adds 10% (up to 30%) to the maze's coins and XP.
      Meshes: all five stages and the five pieces are generated (`AssetData.Golem.Elements.Maze`, `StageModels`, `MaterialMeshes`) and were checked in Studio. Rules in `MazeRewards.RollPiece`, tests in `tests/test_maze.lua`.
- [x] Automatic collection (user request: no Collect button): `CollectService` banks everything the Golems mined every 8 seconds (bags emptied too), and waits while the player is in the Sky Tower or the Hollow Maze. The Collect button, the pending list and the Welcome back card's Collect/Later buttons are gone (it is a single Nice!); the tutorial and goal text no longer mention collecting. An automatic collection counts for the 'collect' challenges at most once every 5 minutes. Not checked: the Courier run and Cart runs still bank while you are in them (only the tower and maze pause it, as asked); Golem carrying capacity now rarely limits anything because bags are emptied every 8 seconds.
- [x] Sky Tower made harder (user feedback): the spinners were frozen on screen (the angle was the server clock times the turn speed, 1.8 billion, and CFrame.Angles keeps 32 bits, so it only changed every couple of minutes while the server still judged the bar moving; now wrapped into one turn first). Every level above tier 1 now climbs on mixed ledges instead of plain ones (narrow ledges and crumbling ledges, 3 styles a tier). New obstacles: slalom walls to weave round, low hurdles to jump, and bright yellow strips across a platform that send you back to the level start if you touch them (jump them). Harmless edge trim is now pale and the scaffold rails steel grey, so bright yellow only means danger. Not tuned by real play: how hard the new levels feel, and the strips' kill height.
- [x] Maze: when the Zombie Golem catches you, 2.5 seconds later you are back in the lobby to try again at once (rewards for sections already reached are not paid twice) and the Zombie goes back to the far end if nobody else is running.
- [x] Cart Run track and carts (user feedback): the road was drawn in straight pieces 8 studs long, so on a 7-stud bend the outside of every join gaped and the rails cut across; Deep Run also had a real kink (local radius 3.4). The route is now sampled every stud and its sharpest bends are opened to a 7-stud radius (`CartPath.MIN_RADIUS`; Cave Run's tightest bend measures 9.4, Deep Run's 8.6 over 14 studs, so they are still the tight ones), the road and tunnel pieces come closer together on bends and are lengthened to cover the gap, each rail follows its own side of the bend, and the sleepers are spaced by distance. The crystal cart (Cave Run) was modelled with its wheels on the ends so it rolled sideways: it is turned a quarter turn. Seen in Studio: the tightest bend from above and the Cave Run cart on the rails; not yet pushed round a whole course.
- [x] Hats and crowns fit the Golems' heads (user feedback): crowns and hats were placed on the top of the head part's bounding box, which for generated Golems often reaches far past the visible head (horns, hoods, crests), so they floated or were far too wide. `AssetData.HeadFit` now holds, for every type and stage, where the crown seat is and how wide the head is there, measured by firing a grid of rays onto each head mesh; `GolemModel` uses it for Elite and Supreme crowns and for equipped hats and helms, and `CrownModel` sinks them slightly onto the head. Seen in Studio on Maze, Dragonbone, Gargoyle, Void, Storm, Frost, Stone and Ember. Not every type and stage was looked at (the numbers for the Infant and Ancient stages are measured the same way but unseen), and a new Golem mesh needs its row measured again.
- [x] Found while checking: the Maze Golem's parts came out named like ["Torso" (the list of part names was passed as text) and wrapped in a model each, so the loader did not recognise its head, arms or legs and it could not be animated. The loader now cleans the names, unwraps nested models, flattens per-part wrappers and adapts the Adult Maze Golem like the stage models. Its parts are now Torso, Head, ArmL, ArmR, two Legs, PickHandle and PickHead like every other Golem. Not yet watched walking.
- [ ] Maze Golem, still open: not played end to end yet (a real piece drop, the crafting menu, the Golem growing); the piece drop chances are a first guess to tune with real play; the Maze Golem has not been
      watched walking with the real animator (the stage models are adapted like the others).
- [x] Hollow Maze entry: you can now walk in from the start of a round until the last minute of the hunt (it was only the first 45 of 370 seconds, so the portal looked dead most of the time); a late arrival's time is measured from when they came in; the portal has a live status board (open / hunt on / closed with a countdown). Run timers (Courier, Sky Tower, Maze) sit down the left with the event cards instead of the middle of the screen.
- [ ] Hollow Maze, still open: the Courier run's new timer position and the phone layout of the run panels have not been looked at on screen; the Zombie's walk animation and the red edge glow have only been seen standing still (a test walker could not stay ahead of it to film a real chase; watch one by hand); after an escape speed-up the next round still starts on the fixed schedule, so there is a wait of up to about 4 minutes (rounds are clock-aligned across servers);
      `MazeMeshes.Gate` is unused (the gate is a neon barrier); balance numbers (`SectionCoins`, `ESCAPE_CHEST_MULT`) are first guesses (a level 27 escape paid about 1,000 coins).

## Running the tests
`python tests/run_tests.py` needs the `luau` runtime (https://github.com/luau-lang/luau/releases) on PATH or in the `LUAU` environment variable.
