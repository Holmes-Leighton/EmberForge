# EmberForge: Art Brief

For 3D artists, 2D/UI artists, or Roblox's AI tools. Send whichever part applies.
Everything in the game is currently made from plain blocks in code. This brief describes what should replace it.

---

## 1. The game in one paragraph

EmberForge is an idle-crafting Roblox game. You mine ore on glowing **pads**, forge stone **Golems** at an **Anvil**, and send them to work in **mining caves**. They dig for you while you play and while you're away. You upgrade your own **Forge** (a personal plot that grows from a lean-to shed to a grand kiln), collect rare Golems (**Neon** and **Mega Neon** versions, like Adopt Me), and trade with other players. Audience: mostly young players on phones. Comparable feel: **Adopt Me!**, **Grow a Garden**, **+1 Speed Keyboard Escape**.

## 2. Art direction

- **Style:** chunky, cartoon, friendly, readable at a distance and on a small phone screen. Think "toy" not "realistic". Rounded, bevelled shapes. Bold silhouettes.
- **Setting:** one huge warm-lit **mine cavern**. Dark rock, wooden support beams, hanging lanterns, glowing ore veins, minecart tracks.
- **Palette:** warm dark browns and greys for the world, with bright saturated accents (orange forge glow, and one strong colour per element). The world should be dark so that the Golems and pads pop.
- **Element colours** (use as the main accent):
  - Ember: orange/red (#DC5020), lava cracks
  - Stone: earthy brown/green (#786446), moss
  - Frost: ice blue (#64AAE6), icicles
  - Storm: violet (#8C64DC), sparks
  - Void: deep purple (#643CA0), floating shards
  - All (rare event Golems): gold (#FFD75A)
- **Do not** copy any existing game's characters, logos or UI art. Use them for mood only.

## 3. Technical rules (all 3D assets)

| Item | Requirement |
|---|---|
| Format | `.fbx` (preferred) or `.gltf`, with textures. `.obj` has no rig or animation, so only for static props. Or delivered already uploaded to Roblox |
| Scale | Roblox studs: 1 stud is about 0.28 m. A tier 1 Golem is about **11 studs tall** (see section 4) |
| Triangles | Roblox's hard limit is **20,000 per mesh**; our budget is much lower. Golem: under **8,000**. Small props: under 1,500. Large scenery pieces: under 6,000. Fewer is better (phones) |
| Origin | On the ground, centred under the object. Facing **-Z** (Roblox "front") |
| Textures | 1024x1024 max per asset, 512 for props. No baked-in text |
| Materials | One or two per asset. Solid colours plus a simple texture is fine |
| Ownership | Uploaded under a **Roblox group** we own. Agree in writing that the game owns the finished assets and may modify them |
| No scripts | 3D assets contain meshes and textures only, no code |

## 4. The Golem (highest priority)

Golems are the heart of the game. They are shown on a mining floor swinging a pickaxe, in a menu preview that rotates, and on a pedestal in the player's forge.

### 4.1 Base body

- Proportions: chunky humanoid made of stone slabs. Broad torso, short thick legs, big fists. Slightly hunched. Friendly, not scary.
- Current block size for reference (tier 1): torso 3.2 x 4 x 2 studs, head 2.4 x 2.2 x 2.4, legs 1.3 x 3 x 1.4 each, arms 1.1 x 3 x 1.1 each. Overall about 9.5 studs to the top of the head, 11 with a hat.
- Glowing **eyes** (emissive) and a **chest socket** where a glowing core can sit (see tiers).

### 4.2 How to deliver the Golem: pick option A or B

The game loads your finished model from a Roblox asset id (`src/Shared/Data/AssetData.lua`) and, if that ever fails, falls back to the built-in block Golem. It scales the model by tier, tints it by element, makes it Neon / Mega Neon, and adds hats, crowns and effects itself, so **the artist does not need to make tiers, Neon or accessories**. Build one neutral Golem (light grey stone works best for tinting); a separate model per element is optional.

Rules for both options: stand on the ground with the origin at the feet, face **-Z**, roughly 9.5 studs tall to the top of the head at tier 1 (the game rescales to exactly that), symmetrical, meshes and textures only (no scripts; the game deletes any it finds), and keep eyes/glow parts on a **Neon** material so they stay bright.

**Option A: separate named parts (recommended for launch)**
One model, unrigged, made of separate meshes with these **exact names** (the game already looks for them):

| Part name | What it is |
|---|---|
| `Torso` | Main body |
| `Head` | Head with eyes |
| `ArmL`, `ArmR` | Arms. **The mesh pivot must sit at the shoulder**: the game swings `ArmR` to mine and `ArmL` a little |
| `Leg` (x2) | Legs |
| `PickHandle`, `PickHead` | Pickaxe held in the right hand (handle is wood, head is metal) |

Import with **Import Only As Model** off and **Merge Meshes** off (Merge would fuse the arms into the body). Set each arm's pivot at the shoulder in the importer's pivot option (or in the DCC tool before export).
If only one unsplit mesh is possible, that also works: the game gives it a bob-and-sway instead of an arm swing.

**Option B: rigged FBX with animations**
- **Rig type in the importer: Custom.** Roblox offers R15, Custom and No Rig. R15 (15 joints, plus up to 37 optional ones in Advanced R15) is the human player avatar rig with fixed joint names and hierarchy, which a blocky stone Golem does not need. Custom keeps your own skeleton.
- Skeleton with **one root bone/joint at (0,0,0)**, all bones with **frozen transforms** (scale 1,1,1, rotation 0,0,0), **no more than 4 bone influences per vertex**, none on the root bone.
- Animations, all looping except where noted: `Idle` (standing, breathing, 2 to 4 s), `Mine` (pickaxe swing, about 1.5 s, this is the one seen most), `Walk` (about 1 s, reserved for later). Roblox's mesh specification says an FBX carries a **single animation track per file**, so export each animation as its own FBX, import each in the Animation Editor / Importer, and send us the three animation asset ids. The Golem is not a Humanoid, so the game plays them through an `AnimationController` + `Animator` on the client.
- Animations must be uploaded by the **same group that owns the game**, or they will not play.
- Keep the rig small (about 25 bones or fewer). Up to 20 players may each have 12 Golems on screen, and every skinned Golem costs more than a plain one; the game already pauses animation for Golems far from the camera.

**Which to choose.** Option A for launch: it works with the code as it stands, needs no animation work, costs the least on phones, and looks fine at the size Golems appear in the cave. Option B is a good upgrade for the hero look (fluid mining, breathing idle) once the game is live; the loader is ready for it. Both are wired up; switch by dropping the asset id (and animation ids for B) into `AssetData.lua`.

What Roblox's docs say and don't say (checked against create.roblox.com): the Importer accepts `.fbx`, `.gltf`, `.obj`; FBX/glTF carry rigs and animation data; mesh limit is 20,000 triangles, geometry must be watertight, textures colour or PBR. The importer page itself gives no bone-count or file-size limit, so the bone budget above is our own safe target, not a Roblox rule.

### 4.3 Elements (5 looks + 1 event look)

Same body, different surface and details. The element must be readable from the colour alone.

| Element | Surface | Details to add |
|---|---|---|
| Ember | Dark basalt | Glowing orange cracks on the chest, a few ember sparks |
| Stone | Grey slate | Green moss patches, small crystals |
| Frost | Translucent ice | Icicle spikes on the back, frosty edges |
| Storm | Dark metal | Violet spark strips on the arms and chest |
| Void | Glassy purple | Shards floating around the body (separate parts) |
| All (event) | White marble with gold | Gold glowing trim |

### 4.4 Tiers (5 levels of detail, same element)

Each tier is bigger and fancier. The game scales the model (+18% per tier), so only the *details* need to change:

| Tier | Rarity | Add |
|---|---|---|
| 1 | Common | Plain body |
| 2 | Uncommon | Shoulder plates |
| 3 | Rare | Glowing chest core |
| 4 | Epic | Horns |
| 5 | Legendary | A halo or crown ring above the head |

**Efficient plan:** one body, then swap-in add-on pieces (shoulders, core, horns, halo) as separate meshes. That is much cheaper than 25 full models.

### 4.5 Variants

- **Neon:** the same Golem but glowing, bright and slightly translucent (like Adopt Me's Neon pets).
- **Mega Neon:** the same again, cycling through rainbow colours. The game changes the colour in code; the artist supplies a model with an **emissive/"Neon" material** on all body parts.

### 4.6 Special Golem skins (season rewards, each a unique look)

Magma Titan (Ember, tier 3), Crystal Wraith (Frost, tier 3), Thunder Colossus (Storm, tier 4), Void Walker (Void), Primordial Golem (All). These can come later.

## 5. Your Forge (the player's personal plot)

A 54 x 54 stud courtyard that grows over **10 Forge levels**. The game builds it from parts; the artist can supply replacement models. Same style as the rest.

| Level | Look |
|---|---|
| 1 | Open lean-to shed, furnace, anvil, workbench, barrels, coal pile, wooden fence with a gate |
| 3 | Enclosed stone workshop, pitched roof, chimney smoke |
| 5 | Elemental braziers (orange / blue / purple flames) and lava channels |
| 6 | Workshop gets a second wing |
| 8 | Animated gears on the wall, a beacon tower |
| 9 | Glowing runes on the courtyard floor |
| 10 | Kiln dome, aura ring, floating crystals |

Also: a **Storage Vault** building, **pedestals** for showing idle Golems, banners, a trophy.

## 6. Mine and world

- **Timber support frames** (posts and beam) that repeat along the main tunnel.
- **Hanging lanterns**, **minecarts** with ore heaps, **rails and sleepers**.
- **Glowing ore veins** in five colours (gold, orange, blue, purple, green), as wall-embedded crystal clusters.
- **Cave rock**: 8 to 10 modular rock formations (walls, overhangs, stalactites, stalagmites, boulders) that tile together.
- **Six mining caves**, each with a themed entrance and scenery:
  1. Ember Depths: lava pools, obsidian spires
  2. Granite Caverns: stalagmites, boulders
  3. Glacial Peaks: ice spikes, falling snow
  4. Stormrift Cliffs: lightning rods, dark cliffs
  5. The Hollow: floating void shards
  6. The Deep Forge: giant furnace with chimneys

## 7. Mining pads (very recognisable)

Big tiered square pads players stand on to mine faster. They must read from across the cave:

| Pad | Multiplier | Look |
|---|---|---|
| Starter | 1x | Wooden plinth |
| Copper | 3x | Corroded copper |
| Iron | 9x | Steel diamond-plate |
| Gold | 25x | Polished gold |
| Legend | 100x | Marble with pink glow, gem |
| Admin | 250x | Glowing red neon |

Each has a huge multiplier number on top, corner lantern posts, an arch with a name sign, a tall beam of light and a floating gem on the top four tiers.

## 8. 2D and UI art

- **Icons** (256x256, transparent PNG, chunky outline): Forge, Bag, Market, Quests, Shop, Trades, Season, Style, My Forge, Leaders.
- **Material icons** (128x128): Basic Ore, Coal, Refined Ore, Elemental Ingot, plus one per element material.
- **Rarity badges:** Common, Uncommon, Rare, Epic, Legendary.
- **Currency icon:** Ember Coins.
- **Shop art:** one square image per product (pads, +5 slots, offline storage, forge skins).
- **Loading screen** and **game thumbnail / icon** (Roblox specs: icon 512x512, thumbnails 1920x1080).

## 9. Cosmetics (visual only, optional later)

- **Forge skins** (5 colourways: Basic, Ember, Frost, Storm, Void)
- **Forge decorations:** statue, portal ring, obelisk, lightning rod, altar, lava river, pillar, anvil
- **Golem accessories:** crown, helm, hat, orb
- **Particle effects:** sparks, ember trail, frost trail, void burst, and so on

## 10. Deliverables and priorities

| Priority | Item |
|---|---|
| 1 | Base Golem (option A or B, one neutral model; see 4.2) |
| 2 | Element variations (5) |
| 3 | Tier add-ons (shoulders, core, horns, halo) |
| 4 | UI icons (10 hotbar icons first) |
| 5 | Mine props and pads |
| 6 | Forge level pieces |
| 7 | Cosmetics and season skins |

For each: source file, `.fbx`, textures, and a short note of any part names changed. Please deliver a **turntable image or short video** for approval before finishing textures.

---

# Part B: Using Roblox's AI tools

Roblox Studio has a built-in **Assistant** that can generate a textured 3D mesh from a text prompt, and an API (`GenerationService:GenerateModelAsync`) that does the same from a script. It gives a single mesh, not a rigged character, so use it for **props, scenery and a first-draft Golem**, and hire an artist for the final animated Golem.

## Prompts to try (copy-paste)

Include style words, materials and proportions. Set **max triangles** low (about 2,000 to 6,000) so it is phone-friendly.

**Golem (single mesh, static)**
> A chunky cartoon stone golem, friendly face, glowing orange eyes, thick short legs, big fists, broad shoulders, dark basalt rock with glowing orange lava cracks on the chest, stylised toy-like, symmetrical, standing pose, arms slightly out from the body

Variants: replace the rock and glow:
- Stone: "grey slate rock with green moss patches and small crystals"
- Frost: "translucent blue ice with icicle spikes on the back"
- Storm: "dark metal plates with glowing violet lightning strips"
- Void: "glassy deep purple stone with floating purple crystal shards"

**Pickaxe**
> A chunky cartoon pickaxe, wooden handle, grey metal head, low poly, stylised

**Mine props**
> A wooden mine cart full of glowing gold ore nuggets, cartoon, chunky, low poly
> A wooden mine support frame, two posts and a beam, with a hanging iron lantern, cartoon style, low poly
> A cluster of glowing blue crystals growing from dark rock, cartoon, low poly
> A stone furnace with a glowing orange mouth and a brick chimney, cartoon, chunky, low poly
> A stone pedestal for displaying a statue, marble, low poly, cartoon

**Pads**
> A square glowing mining platform, thick gold base with a bright rim, cartoon, chunky, low poly

## Tips
- Generate 4 to 8 versions and pick the best; results vary a lot.
- Ask for **"symmetrical"** and **"standing pose"** for characters.
- If it comes out too detailed, lower the triangle limit and add "low poly, simple shapes".
- You can pick a Part in your scene to act as a **bounding box** so the result fits the size you want.
- The AI can't reliably make separate arms and legs. If you need `ArmL`/`ArmR` parts, either hire an artist or try splitting the mesh into parts afterwards.
