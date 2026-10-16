-- Uploaded 3D art for the Golem. Every id is 0 until the art exists; with no id (or if the
-- load fails) the game keeps using the built-in block Golem, so nothing here is required.
--
-- The server loads each id once at start-up (GolemAssetLoader) and shares the result through
-- ReplicatedStorage.GolemAssets; GolemModel.Build clones from there. See ART_BRIEF.md section 4.
--
-- Upload the finished model with the Roblox Importer under the game's group, then paste the
-- number from the asset's page (the group must own it, or LoadAsset will refuse it).

local AssetData = {}

AssetData.TARGET_HEIGHT = 9.5      -- studs from the ground to the top of the head at tier 1 (matches the block Golem)
AssetData.LOAD_TIMEOUT  = 20       -- seconds the loader waits before logging that an asset is still loading

-- One base model for every Golem, recoloured by element. Set `Elements.<Name>.assetId` to give an
-- element its own model instead (any field left out is inherited from Default).
--
--   assetId       the model's asset id (number, 0 = not made yet)
--   mode          "Auto" | "Skinned" | "Parts" | "Static"
--                   Skinned: rigged FBX, played with the Idle/Mine animations below
--                   Parts:   separate parts named ArmL / ArmR / PickHandle / PickHead, swung in code
--                   Static:  one unsplit mesh, given a bob-and-sway
--                 Auto picks Skinned if the model has a rig AND an Idle or Mine animation id is set,
--                 Parts if it has a part called ArmR, otherwise Static.
--   elementTint   0..1, how strongly the element colour is mixed into an untextured-neutral model
--                 (0 = none). Ignored for an element that has its own model.
--   tierAddOns    true = still add the code-made core (T3), horns (T4) and halo (T5) on top.
--                 Set false once the art has its own tier pieces.
--   facing        degrees to turn the model so it faces -Z (0 if the artist already did)
--   animations    asset ids of the animations uploaded for this rig (0 = none)
AssetData.Golem = {
    Default = {
        assetId     = 85664844143538,
        mode        = "Parts",
        elementTint = 0.35,
        tierAddOns  = true,
        facing      = 0,
        animations  = { Idle = 0, Mine = 0, Walk = 0 },
    },
    Elements = {
        -- the five elements, each with its own body and size (height = studs at tier 1)
        Ember = { assetId = 0, height = 9.5  },   -- stocky molten brute
        Stone = { assetId = 0, height = 10   },   -- massive boulder golem
        Frost = { assetId = 0, height = 10.5 },   -- tall angular ice crystal
        Storm = { assetId = 0, height = 10.5 },   -- armoured, crackling
        Void  = { assetId = 0, height = 10   },   -- slim shard-and-galaxy
        All   = { assetId = 0, height = 12 },   -- the Primordial titan (seasonal event Golem); body comes from the pack's EF_All

        -- Special Golems (GolemData.Specials): each has its own body, size and look. Until an id is set the
        -- type falls back to the shared model dressed in code (GolemSkinData.Specials). `height` = studs at tier 1.
        Patchwork  = { assetId = 0, height = 7.5  },   -- squat and round
        Woven      = { assetId = 0, height = 11   },   -- tall and lanky
        Coral      = { assetId = 0, height = 10   },   -- broad reef golem
        Clockwork  = { assetId = 0, height = 10   },   -- slim brass automaton
        Alchemist  = { assetId = 0, height = 9.5  },   -- potbellied
        Gargoyle   = { assetId = 0, height = 10.5 },   -- hunched, winged
        StormJar   = { assetId = 0, height = 9    },   -- a jar on legs
        Dragonbone = { assetId = 0, height = 13   },   -- towering skeleton
        Maze       = { assetId = 71922150506963, height = 11 },   -- the Hollow Maze's hedge-and-stone labyrinth golem (its life stages are in StageModels)
    },
}

-- One upload holding every Golem (the easiest way to ship all of them): put the Golems in one Model,
-- each child Model named EF_<Type> (EF_Ember, EF_Stone, EF_Frost, EF_Storm, EF_Void, EF_Patchwork ...),
-- upload it once and set its id here. A type that has its own `assetId` below uses that instead.
AssetData.Pack = { assetId = 130561025606346 }

-- Life-stage models. The models above are the ADULT look (GolemData.Stages). Every other stage can have its own mesh: one pack per
-- stage, built like the Golem Pack (a Model whose children are named EF_<Type>: EF_Ember, EF_Stone ... and EF_Default for the shared
-- body). Infant is drawn small with a big head, Elder and Ancient grander and more weathered; GolemModel scales each to its stage's size.
-- A type with no mesh for a stage still shows its Adult mesh, grown or shrunk to the stage and dressed in code (sprout and big eyes for an
-- Infant, runes and a beard for an Elder, a crystal crown and orbiting rune stones for an Ancient), so nothing here is required.
AssetData.StagePacks = {
    Infant  = { assetId = 0 },
    Young   = { assetId = 0 },
    Elder   = { assetId = 0 },
    Ancient = { assetId = 0 },
}

-- Or one generated model per type and stage, with no pack to assemble: Studio's mesh generator publishes each result as its own Model asset
-- (the `publishedAssetId` it reports). Generate it with the part names Torso, Head, ArmL, ArmR, LegL, LegR, PickHandle, PickHead; the loader
-- renames them (Torso_geom -> Torso, LegL / LegR -> Leg), drops the generator's rig leftovers, and sets the arm pivots at the shoulders.
-- StageModels.<Stage>.<Type> = asset id. Use either this or a StagePacks entry for a type and stage, not both (whichever loads last would win).
AssetData.StageModels = {
    Infant = {
        Ember = 111539969041635,       -- baby armoured lava golem: big grin, flame tuft, glowing chest window
        Stone = 134957530416757,       -- baby slate golem: green eyes, moss, teal crystals
        Frost = 127416852047379,       -- baby ice golem: icicle crown, frosty collar
        Storm = 84746662214065,        -- baby gunmetal golem: violet glow, exhaust pipes
        Void  = 123168681093153,       -- baby hooded void golem: purple eyes, shoulder crystals, crystal staff
        Patchwork  = 118601811288943,   -- stitched fabric rag-doll: button eyes, thread
        Woven      = 103950483499267,   -- knotted rope and reeds
        Coral      = 112254032083811,   -- branching reef coral with a seashell
        Clockwork  = 111666023672540,   -- brass automaton with gears and a wind-up key
        Alchemist  = 108258527114640,   -- potbellied stone with glass vials of brews
        Gargoyle   = 85360440614614,   -- stone guardian with wings and horns
        StormJar   = 90127070400225,   -- glass jar of storm cloud on stone legs
        Dragonbone = 124844006804174,   -- pale bone with ribcage, spine fins and dragon horns
        Maze       = 123624746289490,   -- baby hedge-and-stone labyrinth golem: leaf sprout, big teal eyes, gold maze belly
        All        = 97151946959544,   -- the event Primordial: white marble with gold
    },
    Young = {
        Ember = 104010269078604,       -- teenage armoured lava golem: small flame crest, glowing chest window
        Stone = 86951893097205,        -- teenage slate golem: green eyes, a few moss patches
        Frost = 72851227271034,        -- teenage ice golem: small icicle crown, frost collar (regenerated: moderation flagged a mesh in the first one, 112831766869171)
        Storm = 79448496845941,        -- teenage gunmetal golem: violet strips, small exhaust pipes
        Void  = 134191012882976,       -- teenage hooded void golem: small shoulder crystals, crystal staff
        Patchwork  = 74891539568121,   -- stitched fabric rag-doll: button eyes, thread
        Woven      = 124067343464960,   -- knotted rope and reeds
        Coral      = 116452271145528,   -- branching reef coral with a seashell
        Clockwork  = 82725080220978,   -- brass automaton with gears and a wind-up key
        Alchemist  = 89857740816876,   -- potbellied stone with glass vials of brews
        Gargoyle   = 138577960470626,   -- stone guardian with wings and horns
        StormJar   = 76449428466688,   -- glass jar of storm cloud on stone legs
        Dragonbone = 123641423182564,   -- pale bone with ribcage, spine fins and dragon horns
        Maze       = 139885972269659,   -- teenage labyrinth golem: maze-wall ridges, gold maze chest, ivy
        All        = 112097798700099,   -- the event Primordial: white marble with gold
    },
    Elder = {
        Ember = 140330012269546,       -- scarred veteran lava golem: cracked basalt, lava fissures, carved face, hunched
        Stone = 137589488564405,       -- weathered veteran stone golem: craggy boulders, runes, moss
        Frost = 128287318474889,       -- weathered veteran frost golem: cracked glacial ice, ice spikes
        Storm = 84243756303150,        -- battered veteran storm golem: dented gunmetal, rivets, lightning scars
        Void  = 102403356535230,       -- veteran void golem: cracked obsidian-purple under a tattered cloak, shoulder crystals
        Patchwork  = 125755513476399,   -- stitched fabric rag-doll: button eyes, thread
        Woven      = 115660624627300,   -- knotted rope and reeds
        Coral      = 116813500967487,   -- branching reef coral with a seashell
        Clockwork  = 130342029098358,   -- brass automaton with gears and a wind-up key
        Alchemist  = 81650450930350,   -- potbellied stone with glass vials of brews
        Gargoyle   = 134833935260971,   -- stone guardian with wings and horns
        StormJar   = 137102980932096,   -- glass jar of storm cloud on stone legs
        Dragonbone = 140066674708713,   -- pale bone with ribcage, spine fins and dragon horns
        Maze       = 136036037067840,   -- elder labyrinth golem: mossy stone, tall maze-wall ridges, deep gold maze chest
        All        = 112622455588150,   -- the event Primordial: white marble with gold
    },
    Ancient = {
        Ember = 92964913353272,        -- lava elder: flame horns, grey stone beard, glowing runes
        Stone = 116300288792738,       -- slate elder: mossy beard, green runes, teal crystals
        Frost = 106028488407980,       -- ice elder: icicle crown and beard, frost collar
        Storm = 118919561871911,       -- gunmetal elder: wire beard, violet lightning, exhaust stacks
        Void  = 75333919674843,        -- hooded void elder: wispy beard, big purple crystals, crystal staff
        Patchwork  = 73184511367765,   -- stitched fabric rag-doll: button eyes, thread
        Woven      = 107172418198283,   -- knotted rope and reeds
        Coral      = 137576219164670,   -- branching reef coral with a seashell
        Clockwork  = 103602529394507,   -- brass automaton with gears and a wind-up key
        Alchemist  = 115804801565762,   -- potbellied stone with glass vials of brews
        Gargoyle   = 88893956980538,   -- stone guardian with wings and horns
        StormJar   = 119408960303164,   -- glass jar of storm cloud on stone legs
        Dragonbone = 82391878046515,   -- pale bone with ribcage, spine fins and dragon horns
        Maze       = 104011302909112,   -- ancient labyrinth golem: emerald hedge, violet-gold maze, floating maze-wall crown
        All        = 136276480675150,   -- the event Primordial: white marble with gold
    },
}

-- Per-model animation settings for a generated stage model, picked up by the animator through an attribute on the model.
--   walkSwing   how much its arms swing while it walks, 0..1 (default 1). A model with something attached to an arm (the Ancient Gargoyle's wing is part
--               of its arm mesh) uses a small value so that piece does not flail about as the Golem walks.
AssetData.StageSettings = {
    Ancient = {
        Gargoyle = { walkSwing = 0.2 },
    },
}

-- The same idea for pets (PetData): one Model whose children are named PET_<Type> (PET_Ember, PET_Coral ...).
-- Each pet is shown at the size in PetData.Looks. Pets without a model show a mini Golem.
AssetData.PetPack = { assetId = 136723892869054 }   -- segmented, animated pets (the old one-piece pack was 94911546053505)

-- Crowns for Elite and Supreme Golems and pets: one unique crown design per type (Ember flames, Frost
-- icicles, Clockwork gears ...), shared by that type's Golem and pet. One Model whose children are named
-- CROWN_<Type>, each a single mesh with its pivot at the centre of its base. Without one, a plain gold
-- circlet is built in code instead.
AssetData.CrownPack = { assetId = 133428041942823 }

-- Forge buildings and props for the Forge Builder (mine cart, racks, furnaces ...): one Model whose children are
-- named after ForgeBuildData items (MineCart, Hearth ...), each a model of mesh parts.
-- The Quarry's nodes and buildings: one Model whose children are named after QuarryData pieces (EmberNode, DrillRig ...).
AssetData.QuarryPack = { assetId = 89170227615937 }
-- Forge Skin scenery meshes: per skin family three generated meshes (plus Gate and Fence: the forge's own gateway and fence section, each a different design per skin) published as Model assets. Tall = the landmark at the gate and plot sides,
-- Mid = the medium piece, Small = the scatter piece. House1-4 = the workshop building for Forge levels 1-2 / 3-5 / 6-9 / 10 (a different architecture per family). GolemAssetLoader loads them into ServerStorage.ForgeSkinAssets.<family> and ForgeSkinProps
-- stands them around the plot (always walk-through). 0 = not made yet, that piece is built from parts instead. Prompts: ART_BRIEF.md part C.
AssetData.ForgeSkinMeshes = {
    ember   = { Tall = 113286426348095, Mid = 82598483901973, Small = 94530198177129, Gate = 104718511127042, Fence = 100754788871174, House1 = 114749316544634, House2 = 80573107536079, House3 = 81934643493013, House4 = 113671754580944, Anvil = 135588010630129, Bench = 112003917430988, Brazier = 120927558048885, Furnace = 70896281506136, Courtyard = 101367665982511 },
    frost   = { Tall = 72153475431516, Mid = 105669868402606, Small = 139041116592338, Gate = 120098805760549, Fence = 83671943199913, House1 = 115824682366838, House2 = 106376199155123, House3 = 119709333379027, House4 = 87131250472409, Anvil = 88731255063188, Bench = 137354611664075, Brazier = 76299420772848, Furnace = 103687946757088, Courtyard = 114025867961191 },
    storm   = { Tall = 109199962977202, Mid = 126294315938392, Small = 136655038933529, Gate = 112731620934057, Fence = 137054566927411, House1 = 115737089558443, House2 = 121032286078054, House3 = 122778162702391, House4 = 96977364280944, Anvil = 128392853569781, Bench = 81151418563277, Brazier = 106081180077348, Furnace = 139918860810359, Courtyard = 94261051067726 },
    void    = { Tall = 106112007239651, Mid = 86444841246092, Small = 134293612945890, Gate = 127969678018833, Fence = 77253272581309, House1 = 124781063255529, House2 = 86966525819712, House3 = 97986333051746, House4 = 106953915293869, Anvil = 71587473551707, Bench = 106427193969996, Brazier = 93181490925814, Furnace = 122228860992072, Courtyard = 122823014875765 },
    ancient = { Tall = 108095459175142, Mid = 98276002414634, Small = 77227356398565, Gate = 137798871163806, Fence = 119688125488967, House1 = 122155731345822, House2 = 124425291467617, House3 = 130463838393931, House4 = 85948259936647, Anvil = 75165410368275, Bench = 97407682323377, Brazier = 130552646718626, Furnace = 78424430859616, Courtyard = 139448879723779 },
    effects = { AncientFlame = 131499047102186, ArcLightning = 93977601896473, IceFlow = 89693392300923, MagmaFlow = 121181214200390, VoidRift = 109623380686608 },   -- the 6 floating pieces of an equipped forge effect
    default = { Gate = 86112927033841, Fence = 91415998090317, House1 = 102129495011002, House2 = 116063025716877, House3 = 110747979355307, House4 = 126339780868000, Anvil = 96111284437141, Bench = 85466793899664, Brazier = 121761347023963, Barrel = 137331680174926, Crate = 121511859761734, Coal = 114168515405950, Smelter = 102946450779223, Furnace = 75985265802756, Vault = 78280073712358, Banner = 133253807951066, Trophy = 83550535862062, Pedestal = 73908685168914, Gear = 140100102492400, Conveyor = 85697335479249, Crystal = 91176558771194, Tower = 111724041495803, Chimney = 86503399257699, Hearth = 111581729236401, Courtyard = 93894968692187, Path = 104726115028029, LavaChannel = 88234038114355, Conduit = 116499078014481, Rune = 104190323019905 },   -- no skin family (plain / Basic): a timber mining-camp gate and fence
    bronze  = { Tall = 139002811098879, Mid = 131030556850095, Small = 113563159092596, Gate = 120756347546288, Fence = 131841480987914, House1 = 134617096948644, House2 = 111322231438729, House3 = 111513605926638, House4 = 75225411864069, Anvil = 116178063915659, Bench = 76435509331162, Brazier = 86797203632722, Furnace = 84918124336276, Courtyard = 97043662644393 },
}
-- Forge decorations (CosmeticData ForgeDecoration_*): one generated mesh each, published as a Model asset. GolemAssetLoader loads them into
-- ServerStorage.ForgeDecorAssets.<cosmetic id>; ForgeBuilder stands the chosen one in the forge and ForgeDecorFx animates it. 0 / missing = built from parts.
AssetData.ForgeDecorationMeshes = {
    ForgeDecoration_EmberStatue    = 85571771855085,
    ForgeDecoration_AncientAltar   = 85524620480235,
    ForgeDecoration_IceStatue      = 106012056674039,
    ForgeDecoration_GlacialPillar  = 100628353043835,
    ForgeDecoration_LavaRiver      = 115682648637382,
    ForgeDecoration_LightningRod   = 74194546856970,
    ForgeDecoration_StormPillar    = 101507058893718,
    ForgeDecoration_VoidObelisk    = 86344530175839,
    ForgeDecoration_VoidPortal     = 131396096897669,
    ForgeDecoration_PrimordialPillar = 103304628149392,
}
-- Extra Forge Builder pieces that are not in the Build Pack yet: one asset per piece (named after the ForgeBuildData id), loaded into ReplicatedStorage.BuildAssets.
-- Golem accessory meshes: GolemAccessory_<Name> id -> mesh (CrownModel.Attach(.., "AccessoryAssets")). A missing / failed one falls back to the block-built crown / helm / hat / orb.
AssetData.GolemAccessoryMeshes = {
    LavaCrown = 109591769142974, EmberHelm = 132968658457545,
    BlizzardCrown = 125136739365054, IceHelm = 121421801378622,
    StormCrown = 125168510926458, ThunderHelm = 85452206245205,
    VoidCrown = 96426446641776, VoidHelm = 133062122250030,
    PrimordialHelm = 127117349777244, MinerHelm = 108545169935730,
    -- premium Golem skins: a signature piece on the back (placed by GolemModel; a skin without one keeps its code-made detail)
    Back_MagmaTitan = 70503951278705, Back_CrystalWraith = 99175317148481, Back_ThunderColossus = 72488345640248,
    Back_VoidWalker = 139069642941237, Back_PrimordialGolem = 93782867502032,
}

-- Frames and posts for the world's text boards and signs (SignArt): NoticeFrame = big notice board, PlankFrame = wide plank sign, SignPost = upright post.
AssetData.SignMeshes = { NoticeFrame = 109410470926629, PlankFrame = 136746390001122, SignPost = 71436887776527, PlazaGate = 140390958058695, Depot = 95799192853820 }

-- Meshes for the Sky Tower and the obstacle courses (TowerSkin): platform slabs, rest decks, crumbling and moving platforms, spinner bar, crusher, death tile,
-- bounce pad, rainbow ring, scaffold girder and cloud.
AssetData.TowerMeshes = {
    Platform = 74638111743775, Rest = 130909452112747, Crumble = 70614088193274, Mover = 92745299589030, Spinner = 88751484752289, Crusher = 139253370426718,
    DeathTile = 138462734309138, Bounce = 124685272887092, Ring = 91475482649523, Girder = 93266726839537, Cloud = 102244566507695,
    Blade = 120155553107921, BeamPad = 131637819605325,
}

-- Meshes for the Hollow Maze (MazeSkin; see MAZE_DESIGN.md). Each is a generated model published as a Model asset; GolemAssetLoader loads them into ServerStorage.MazeAssets and
-- MazeSkin draws them on the maze's plain parts, so the maze works (as plain blocks) even if one fails to load. Floor_ is a floor tile, Wall_ a wall piece, the rest decorations.
AssetData.MazeMeshes = {
    Floor_Stone = 116301876437735, Floor_Ember = 98013816587843, Floor_Frost = 132233262200580, Floor_Storm = 77351753539817, Floor_Void = 108775162916473,
    Wall_Stone = 98832026807407, Wall_Ember = 137282095049004, Wall_Frost = 113348642756004, Wall_Storm = 89213533436453, Wall_Void = 97695946912166,
    Coffin = 79995476710788, Gate = 131025798194399, ExitArch = 104124325491080,
    Stone_Pillar = 87583280689702, Stone_Crystals = 87750532897059, Stone_Lantern = 89918830030367, Stone_Rocks = 109309233482525,
    Ember_LavaPool = 79553626351660, Ember_Brazier = 74995747674256, Ember_Spikes = 137529258726374, Ember_Coals = 131198470126860,
    Frost_Crystals = 129164262897675, Frost_Drift = 134625650927605, Frost_Torch = 122124936932387, Frost_Pillar = 115847711705712,
    Storm_Tesla = 105413539781317, Storm_Rod = 105948781705444, Storm_Cables = 110173882948518, Storm_Generator = 86959267037442,
    Void_Shards = 124215681873370, Void_Rift = 134217299564382, Void_Spire = 123915002741977, Void_Altar = 82540900597973,
}
-- The Zombie Golem: a generated model with the Golem part names (Torso, Head, ArmL, ArmR, LegL, LegR). GolemAssetLoader adapts it like a stage model and keeps it as
-- ReplicatedStorage.GolemAssets.Zombie_Maze; `height` is how tall it stands in studs. (Its first, rounder version, 70885855813899, was not used.)
AssetData.MazeZombie = { assetId = 123766477167126, height = 11 }

AssetData.BuildExtras = {
    RailTrack = 98515694214823,
}
-- Mining-zone and hub scenery meshes, one asset id per piece (each is a generated mesh published as a Model asset; GolemAssetLoader loads them into
-- ServerStorage.BiomeAssets.<Zone> and BiomeArt places them). A zone with no ids, or a piece that fails to load, falls back to pieces built from parts.
-- Every zone but Glacial Peaks uses the same seven piece names; Glacial Peaks keeps the names BiomeArt's Glacial builder uses.
AssetData.BiomeMeshes = {
    GlacialPeaks = {
        PadCrystals = 101967249752492, IceSpires = 139671736216015, FrozenFalls = 116246960530806, SnowPine = 87740268281257,
        IceCrystals = 123799570185346, SnowBoulder = 99023961205039, FloatingShard = 135106810772880, IceStalactite = 129502847479173,
    },
    EmberDepths = {
        PadPiece = 126719407630672, Spires = 97622011353183, WallPiece = 102589271885312, Flora = 97426858110519,
        GlowCluster = 84269256282626, Boulder = 87420004016439, FloatingPiece = 117190593986583,
    },
    GraniteCaverns = {
        PadPiece = 139020023032175, Spires = 124693675588375, WallPiece = 79324610365947, Flora = 80756903063205,
        GlowCluster = 136738324471908, Boulder = 93248726217435, FloatingPiece = 105950731666921,
    },
    StormriftCliffs = {
        PadPiece = 118528448462482, Spires = 101502350446283, WallPiece = 96328250388913, Flora = 73381690984639,
        GlowCluster = 115616990397536, Boulder = 135159275139763, FloatingPiece = 133303526067750,
    },
    TheHollow = {
        PadPiece = 96955122592402, Spires = 96873549161640, WallPiece = 82350914320986, Flora = 73497287373743,
        GlowCluster = 127513625520155, Boulder = 115265764760469, FloatingPiece = 125255941958654,
    },
    TheDeepForge = {
        PadPiece = 105684285295980, Spires = 118297309685650, WallPiece = 98049151652092, Flora = 104053299856574,
        GlowCluster = 83918826188549, Boulder = 71900023894219, FloatingPiece = 106569186177475,
    },
    World = {
        PadStarter = 111177879306009, PadCopper = 123195080353933, PadIron = 112430349013618,
        PadGold = 112129818110095, PadLegend = 113037444351955, PadAdmin = 103717249592542,
        CartGold = 98489401322118, CartCrystal = 88573853323324, TimberFrame = 92943577852045,
        OreCrates = 130388675708310, RockCluster = 102073740936074, CrystalCluster = 115852827884095,
        Stalagmite = 108378956476502, Stalactite = 130560032309476,
        GolemAnvil = 120881231422580,     -- the big golden Anvil at the start; its parts are named anvil / chains / stone platform
        -- floor clutter scattered through the hub (BiomeArt.HubScatter); all walk-through
        Rubble = 80069580574333, BrokenPlanks = 110505573270903, OreSacks = 81262382977371, Wheelbarrow = 79558315011742,
        BarrelStack = 111929352969724, ToolRack = 75655976922958, CaveMushrooms = 139148677029268, FloorLantern = 107081953072745,
    },
}
AssetData.BuildPack = { assetId = 108557283111622 }

-- 3D spinning icons for the HUD buttons (HUDBuilder NAV names), loaded into ReplicatedStorage.IconAssets as Nav_<Name>.
AssetData.NavIconMeshes = {
    Nav_Forge = 121785137007817,
    Nav_Bag = 117433505026316,
    Nav_Market = 98005070809085,
    Nav_Quests = 121776594255286,
    Nav_Shop = 72202648087682,
    Nav_Season = 120243851539190,
    Nav_Style = 113654917456922,
    Nav_Pets = 72851002005036,
    Nav_Rewards = 119914608023855,
    Nav_Trades = 109591411900091,
    Nav_Quarry = 99475618905787,
    Nav_Build = 99636508183014,
    Nav_Guild = 124665514857100,
    Nav_Home = 82414444283523,
    Nav_Leaders = 114358582557981,
}

-- One generated mesh per material (MaterialData ids). Loaded by GolemAssetLoader into ReplicatedStorage.MaterialAssets;
-- MaterialIcon draws them in the menus. A material without one keeps its lettered tile.
AssetData.MaterialMeshes = {
    BasicOre = 117308458941304,
    Coal = 82793928556878,
    IgniteOre = 95491104642503,
    MoltenCore = 91143722326428,
    AncientBedrock = 94651533937019,
    GlacialCrystal = 114370828716636,
    EternalIce = 105033188208568,
    ChargedFlint = 76933705602929,
    ThunderShard = 128232234133958,
    ShadowDust = 86811512393028,
    VoidEssence = 114012372064230,
    GraniteShard = 85247538364266,
    PrimordialOre = 137759538706157,
    RefinedOre = 87675658742580,
    EmberDust = 81667665834934,
    ElementalIngot = 75370874468098,
    CrystalFragment = 111738750867959,
    EssenceShard = 95153260195282,
    PureIngot = 117957342934601,
    EventCatalyst = 104958134512199,
    TemperedEmber = 133917670512775,
    Stormglass = 99737376753074,
    PrimordialIngot = 122126190476359,
    FrostfireGem = 123351298386815,
    Voidstone = 91156670078621,
    PrismaticShard = 135173389733208,
    MazeFoot = 128107563770840, MazeHeart = 77150126445937, MazePick = 74531057806425, MazeEye = 118194365780311, MazeCrown = 94179495423788,   -- the Maze Golem's pieces
}

local MODES = { Auto = true, Skinned = true, Parts = true, Static = true }

-- The per-type settings a Golem Pack model is given: Default's settings with that type's own on top
-- (and no element tint, since a type's own model already has its look).
function AssetData.PackEntries()
    local def = AssetData.Golem.Default
    local out = {}
    for name, own in pairs(AssetData.Golem.Elements) do
        if (own.assetId or 0) <= 0 then
            local cfg = {}
            for k, v in pairs(def) do cfg[k] = v end
            for k, v in pairs(own) do cfg[k] = v end
            if own.elementTint == nil then cfg.elementTint = 0 end
            cfg.animations = own.animations or def.animations
            if not MODES[cfg.mode] then cfg.mode = "Auto" end
            out[name] = cfg
        end
    end
    return out
end

-- The settings for every model in a stage pack: each type (and "Default") with the same settings as its Adult model. Keys are the
-- names the pack's EF_<Type> children go by.
function AssetData.StageEntries()
    local def = AssetData.Golem.Default
    local out = {}
    local function entry(own, isDefault)
        local cfg = {}
        for k, v in pairs(def) do cfg[k] = v end
        for k, v in pairs(own) do cfg[k] = v end
        if not isDefault and own.elementTint == nil then cfg.elementTint = 0 end
        cfg.animations = own.animations or def.animations
        if not MODES[cfg.mode] then cfg.mode = "Auto" end
        return cfg
    end
    out.Default = entry({}, true)
    for name, own in pairs(AssetData.Golem.Elements) do out[name] = entry(own, false) end
    return out
end

-- Returns the key ("Ember" or "Default") and the merged config for an element, or nil when no
-- asset is configured for it.
function AssetData.Resolve(element)
    local def = AssetData.Golem.Default
    local own = AssetData.Golem.Elements[element]
    local key, cfg = "Default", {}
    for k, v in pairs(def) do cfg[k] = v end
    if own and (own.assetId or 0) > 0 then
        key = element
        for k, v in pairs(own) do cfg[k] = v end
        if own.elementTint == nil then cfg.elementTint = 0 end     -- own model already has its element look
        cfg.animations = own.animations or def.animations
    end
    if (cfg.assetId or 0) <= 0 then return nil end
    if not MODES[cfg.mode] then cfg.mode = "Auto" end
    return key, cfg
end

-- Every distinct (key, config) pair that has an asset id, for the loader.
function AssetData.All()
    local out = {}
    local seen = {}
    local function add(element)
        local key, cfg = AssetData.Resolve(element)
        if key and not seen[key] then
            seen[key] = true
            table.insert(out, { key = key, config = cfg })
        end
    end
    for name in pairs(AssetData.Golem.Elements) do add(name) end
    return out
end

function AssetData.AnimationId(id)
    if type(id) == "number" and id > 0 then return "rbxassetid://" .. math.floor(id) end
    return nil
end

return AssetData
