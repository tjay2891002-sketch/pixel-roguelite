extends Node2D
## Flat-ground alignment test with NUMERIC output: print each character's
## settled global_position.y and the ground top, so any float is exact.

const TILES := preload("res://level/tileset_builder.gd")
const GROUND_CELL_Y := 5
const BODY_HALF := {"player": 11, "rat": 9, "spitter": 9, "heavy": 13, "flyer": 6}

var frames := 0
var _actors := {}


func _ready() -> void:
	var layer := TileMapLayer.new()
	layer.tile_set = TILES.build()
	add_child(layer)
	for x in range(-4, 20):
		layer.set_cell(Vector2i(x, GROUND_CELL_Y), TILES.SURFACE, Vector2i(0, 0))

	_actors["player"] = _spawn("res://actors/player/player.tscn", Vector2(0, 60))
	_actors["rat"] = _spawn("res://actors/enemies/rat_rusher.tscn", Vector2(60, 60))
	_actors["spitter"] = _spawn("res://actors/enemies/spitter.tscn", Vector2(110, 60))
	_actors["heavy"] = _spawn("res://actors/enemies/heavy.tscn", Vector2(170, 60))
	_actors["flyer"] = _spawn("res://actors/enemies/flyer.tscn", Vector2(230, 30))

	var cam := Camera2D.new()
	cam.position = Vector2(115, 50)
	add_child(cam)
	cam.make_current()


func _spawn(path: String, pos: Vector2):
	var a = load(path).instantiate()
	add_child(a)
	a.global_position = pos
	return a


func _process(_delta: float) -> void:
	frames += 1
	if frames == 120:
		# ground top: cell row GROUND_CELL_Y top edge
		var ground_top := float(GROUND_CELL_Y) * 16.0
		print("ground_top_y = ", ground_top)
		for name in _actors:
			var a = _actors[name]
			var bh: float = BODY_HALF[name]
			var feet: float = a.global_position.y + bh
			print("%-8s center_y=%.1f  feet_y=%.1f  float=%.1f" % [name, a.global_position.y, feet, ground_top - feet])
		var img := get_viewport().get_texture().get_image()
		img.save_png("C:/Users/admin/.claude/jobs/0afce185/tmp/flat_test.png")
		get_tree().quit()
