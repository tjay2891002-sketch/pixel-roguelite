class_name BiomeConfig
extends Resource
## BiomeConfig — one biome's generation recipe (docs §5): the main-path role
## sequence plus weighted chunk pools per role. Role ints mirror
## RoomChunk.Role: 0=START 1=COMBAT 2=SHOP 3=TREASURE 4=BOSS 5=BRANCH.
## A TREASURE entry on the path may roll into SHOP at generation time.

@export var id := &"greybox"
## Palette/tileset variant (tileset_builder.TEXTURES key) — assigned to every
## chunk at generation time, so chunk scenes stay biome-agnostic.
@export var tileset_biome := &"greybox"
## Optional per-biome enemy scene overrides: map letter (E/R/F/H) -> scene.
@export var enemy_overrides: Dictionary = {}
@export var path_roles: Array[int] = [0, 1, 1, 3, 1, 4]
@export var start_chunks: Array[PackedScene] = []
@export var combat_chunks: Array[PackedScene] = []
@export var shop_chunks: Array[PackedScene] = []
@export var treasure_chunks: Array[PackedScene] = []
@export var boss_chunks: Array[PackedScene] = []
@export var branch_chunks: Array[PackedScene] = []
@export_range(0.0, 1.0) var branch_chance := 0.6
@export_range(0.0, 1.0) var shop_chance := 0.3


func pool_for(role: int) -> Array[PackedScene]:
	match role:
		0: return start_chunks
		1: return combat_chunks
		2: return shop_chunks
		3: return treasure_chunks
		4: return boss_chunks
		_: return branch_chunks
