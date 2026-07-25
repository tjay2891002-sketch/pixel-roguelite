extends Node2D
## Flat-ground alignment test with NUMERIC output: print each character's
## settled global_position.y and the ground top, so any float is exact.

const TILES := preload("res://level/tileset_builder.gd")
const GROUND_CELL_Y := 5
const BODY_HALF := {"player": 11, "rat": 9, "spitter": 9, "heavy": 13, "flyer": 6}

var frames := 0
var _actors := {}
var _frames_to_attack := -1


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
	_frames_to_attack = 100

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
	if frames == 60:
		var e := InputEventAction.new()
		e.action = &"roll"
		e.pressed = true
		Input.parse_input_event(e)
	elif frames == 64:
		get_viewport().get_texture().get_image().save_png("C:/Users/admin/.claude/jobs/0afce185/tmp/roll_a.png")
	elif frames == 70:
		get_viewport().get_texture().get_image().save_png("C:/Users/admin/.claude/jobs/0afce185/tmp/roll_b.png")
	elif frames == 100:
		get_tree().quit()
