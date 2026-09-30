-- Golem skins: a whole different material and signature detail, not just a recolour.
-- Skins are cosmetic ids "GolemSkin_<Name>" (a trailing "_Premium" is ignored), owned and equipped
-- through the normal cosmetics system (CosmeticService). GolemModel.Build reads this table.
--
-- These are original looks built from the classic "golem made of X" idea (clay, iron, glass, bone,
-- wood...). They are not copies of any published artwork or game.
--
--   color / material / transparency   the body surface
--   accent                            glow colour: eyes and the signature detail
--   detail                            cracks | rivets | ribs | leaves | facets | runes | shards | trim
--   blurb                             one line for the Style menu

local GolemSkinData = {}

GolemSkinData.Skins = {
    -- material golems
    Clay     = { color = Color3.fromRGB(184, 110, 80),  material = Enum.Material.Brick,     accent = Color3.fromRGB(255, 210, 120), detail = "runes",
                 blurb = "Fired terracotta with glowing words pressed into its chest" },
    Iron     = { color = Color3.fromRGB(96, 102, 112),  material = Enum.Material.Metal,     accent = Color3.fromRGB(255, 150, 60),  detail = "rivets",
                 blurb = "Riveted iron plates with a furnace glow" },
    Glass    = { color = Color3.fromRGB(175, 228, 238), material = Enum.Material.Glass,     accent = Color3.fromRGB(120, 255, 255), detail = "facets", transparency = 0.35,
                 blurb = "See-through glass with cut gem facets" },
    Bone     = { color = Color3.fromRGB(232, 224, 200), material = Enum.Material.Limestone, accent = Color3.fromRGB(170, 255, 170), detail = "ribs",
                 blurb = "Bleached bone with a ribcage and green eyes" },
    Wood     = { color = Color3.fromRGB(128, 86, 52),   material = Enum.Material.Wood,      accent = Color3.fromRGB(150, 255, 110), detail = "leaves",
                 blurb = "Gnarled oak, sprouting leaves" },
    Gold     = { color = Color3.fromRGB(255, 206, 84),  material = Enum.Material.Metal,     accent = Color3.fromRGB(255, 244, 180), detail = "trim",
                 blurb = "Solid gold with shining trim" },
    Sand     = { color = Color3.fromRGB(224, 192, 130), material = Enum.Material.Sand,      accent = Color3.fromRGB(255, 170, 60),  detail = "runes",
                 blurb = "Desert sand held together by old magic" },
    Obsidian = { color = Color3.fromRGB(38, 32, 48),    material = Enum.Material.Slate,     accent = Color3.fromRGB(190, 90, 255),  detail = "cracks",
                 blurb = "Black volcanic glass with violet fractures" },
    Crystal  = { color = Color3.fromRGB(190, 140, 255), material = Enum.Material.Glass,     accent = Color3.fromRGB(240, 200, 255), detail = "facets", transparency = 0.25,
                 blurb = "Amethyst crystal growing out of its back" },

    -- the season reward skins (ART_BRIEF 4.6)
    MagmaTitan       = { color = Color3.fromRGB(44, 30, 28),   material = Enum.Material.Basalt,  accent = Color3.fromRGB(255, 110, 30),  detail = "cracks",
                         blurb = "Black basalt split by rivers of magma" },
    CrystalWraith    = { color = Color3.fromRGB(170, 225, 255), material = Enum.Material.Ice,    accent = Color3.fromRGB(200, 240, 255), detail = "facets", transparency = 0.3,
                         blurb = "A ghostly ice crystal figure" },
    ThunderColossus  = { color = Color3.fromRGB(72, 76, 104),  material = Enum.Material.Metal,  accent = Color3.fromRGB(190, 150, 255), detail = "runes",
                         blurb = "Storm-forged metal crackling with runes" },
    VoidWalker       = { color = Color3.fromRGB(60, 32, 104),  material = Enum.Material.Glass,  accent = Color3.fromRGB(170, 80, 255),  detail = "shards", transparency = 0.15,
                         blurb = "Glassy void with shards orbiting it" },
    PrimordialGolem  = { color = Color3.fromRGB(242, 236, 222), material = Enum.Material.Marble, accent = Color3.fromRGB(255, 215, 90), detail = "trim",
                         blurb = "The first Golem: white marble and living gold" },
}

-- Looks for the special Golem types (GolemData.Specials), keyed by their element id. Used when no
-- skin cosmetic is equipped. Extra detail kinds: stitches | rope | coral | gears | vials | wings | jar | skull
GolemSkinData.Specials = {
    Patchwork  = { color = Color3.fromRGB(176, 142, 118), material = Enum.Material.Fabric,    accent = Color3.fromRGB(255, 226, 120), detail = "stitches" },
    Woven      = { color = Color3.fromRGB(196, 156, 104), material = Enum.Material.Fabric,    accent = Color3.fromRGB(255, 220, 150), detail = "rope" },
    Coral      = { color = Color3.fromRGB(240, 128, 136), material = Enum.Material.Sandstone, accent = Color3.fromRGB(90, 235, 225),  detail = "coral" },
    Clockwork  = { color = Color3.fromRGB(200, 152, 72),  material = Enum.Material.Metal,     accent = Color3.fromRGB(255, 205, 100), detail = "gears" },
    Alchemist  = { color = Color3.fromRGB(120, 190, 160), material = Enum.Material.Glass,     accent = Color3.fromRGB(130, 255, 130), detail = "vials", transparency = 0.2 },
    Gargoyle   = { color = Color3.fromRGB(104, 108, 120), material = Enum.Material.Slate,     accent = Color3.fromRGB(255, 100, 70),  detail = "wings" },
    StormJar   = { color = Color3.fromRGB(150, 172, 214), material = Enum.Material.Glass,     accent = Color3.fromRGB(200, 170, 255), detail = "jar", transparency = 0.3 },
    Dragonbone = { color = Color3.fromRGB(228, 218, 192), material = Enum.Material.Limestone, accent = Color3.fromRGB(255, 120, 60),  detail = "skull" },
}

-- Returns the skin look and its name for a cosmetic id, or nil when the id isn't a known skin.
function GolemSkinData.Find(id)
    local name = tostring(id or ""):match("^GolemSkin_(.+)$")
    if not name then return nil end
    name = name:gsub("_Premium$", "")
    local look = GolemSkinData.Skins[name]
    if not look then return nil end
    return look, name
end

return GolemSkinData
