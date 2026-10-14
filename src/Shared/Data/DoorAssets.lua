-- Real 3D art for the Sky Tower doorway (TowerArt.Portal): a banded stone pillar, a carved lintel, a hanging lantern, a brazier, a headframe with a winding wheel
-- and a crystal cluster. Each was generated in Studio and published to the game's owner, so the game can load it by id.
--   mesh / texture   the asset ids (a MeshPart is made from the mesh id, then given the texture)
--   size             the mesh's own size in studs; the door scales each piece from this
-- Any piece with an id of 0 (or that fails to load) is replaced by the block version in TowerArt, so the door always builds.
local DoorAssets = {}

DoorAssets.pillar    = { mesh = 122419648655921, texture = 70811044877528,  size = Vector3.new(7, 13.23, 6.97) }
DoorAssets.lintel    = { mesh = 102296121248886, texture = 139400023245247, size = Vector3.new(21.28, 6, 7.6) }
DoorAssets.lantern   = { mesh = 117387915062727, texture = 107960389267899, size = Vector3.new(2.09, 3.6, 2.11) }
DoorAssets.brazier   = { mesh = 117717094759741, texture = 119684446822177, size = Vector3.new(4, 2.45, 4) }
DoorAssets.headframe = { mesh = 87584037454288,  texture = 139741585830795, size = Vector3.new(8.47, 11.16, 7) }
DoorAssets.crystals  = { mesh = 97622765117227,  texture = 113552978661271, size = Vector3.new(4, 4.88, 3.98) }

return DoorAssets
