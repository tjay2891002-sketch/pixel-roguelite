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
		var slug_found := false
		for node in get_nodes_in_group(&"enemy"):
			if node.get("sprite_set") == &"slug":
				slug_found = true
		_check(slug_found, "enemy override spawns slugs in the cave", "")
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
