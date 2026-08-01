extends SceneTree
## Headless biome test (P2 — generator genericness):
##   stage_index 1 must build the CAVE biome from the same chunk scenes:
##   config picked up, cave tileset on chunks, slug enemies spawned via the
##   enemy override, and a full layout (boss room present) generated.
## Run: godot --headless --path <project> --script res://tools/biome_test.gd

const TileBuilder := preload("res://level/tileset_builder.gd")

var _frame := 0
var _stage
var _failures: Array[String] = []


func _initialize() -> void:
	var scene: PackedScene = load("res://level/stage.tscn")
	var stage = scene.instantiate()
	stage.stage_index = 1 # force the cave biome (index % 2)
	root.add_child(stage)
	_stage = root.get_node("Stage")


func _physics_process(_delta: float) -> bool:
	_frame += 1
	if _frame == 4:
		_check(_stage._config.id == &"cave", "stage 2 uses the cave biome", "id=%s" % _stage._config.id)
		# deterministic override check: an E spawn in the cave must BE a slug
		# (asserting "a slug exists in the layout" flakes — E-marker picks
		# are budgeted rng and may all roll non-E letters on some seeds)
		var before := get_nodes_in_group(&"enemy").size()
		_stage._spawn_enemy(_stage._rooms[0], &"E", Vector2(64, 64))
		var enemies := get_nodes_in_group(&"enemy")
		_check(enemies.size() == before + 1 and enemies[enemies.size() - 1].get("sprite_set") == &"slug",
			"enemy override: cave E-marker spawns a slug", "")
		enemies[enemies.size() - 1].queue_free()
		var boss_found := false
		for room in _stage._rooms:
			if room.role == 4:
				boss_found = true
		_check(boss_found, "cave biome generates a full layout (boss room)", "")
		var cave_tiles := false
		var chunk = _stage.get_node("Chunks").get_child(0)
		var layer = chunk.get_node("TileMapLayer")
		cave_tiles = layer.tile_set == TileBuilder.build(&"cave")
		_check(cave_tiles, "chunks built with the cave tileset", "")
	if _frame == 6:
		# regenerate as stage 3 -> sewer biome (_regenerate increments first)
		_stage.stage_index = 1
		_stage._regenerate()
	if _frame == 14:
		_check(_stage._config.id == &"sewer", "stage 3 regenerates as the sewer biome", "id=%s" % _stage._config.id)
		var before := get_nodes_in_group(&"enemy").size()
		_stage._spawn_enemy(_stage._rooms[0], &"R", Vector2(64, 64))
		var enemies := get_nodes_in_group(&"enemy")
		_check(enemies.size() == before + 1 and enemies[enemies.size() - 1].get("sprite_set") == &"piranha",
			"enemy override: sewer R-marker spawns a piranha", "")
		enemies[enemies.size() - 1].queue_free()
		var boss_found := false
		for room in _stage._rooms:
			if room.role == 4:
				boss_found = true
		_check(boss_found, "sewer biome generates a full layout (boss room)", "")
		var chunk2 = _stage.get_node("Chunks").get_child(0)
		_check(chunk2.get_node("TileMapLayer").tile_set == TileBuilder.build(&"sewer"),
			"chunks rebuilt with the sewer tileset", "")
		_finish()
	return false


func _check(condition: bool, what: String, detail := "") -> void:
	if condition:
		print("PASS: %s" % what)
	else:
		var message := "FAIL: %s (%s) [frame %d]" % [what, detail, _frame]
		_failures.append(message)
		printerr(message)


func _finish() -> void:
	if _failures.is_empty():
		print("BIOME TEST: all checks passed")
	else:
		printerr("BIOME TEST: %d check(s) failed" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
