extends Node2D
## Greybox traversal circuit — M1's "done when": a run through gaps, a wall
## shaft, and a ledge block feels responsive with zero eaten jumps.
##
## Geometry is data-built at runtime (rectangles only) so tuning the circuit
## means editing the GEOMETRY table, not a scene file.

const FLOOR_COLOR := Color("8b9bb4")
const WALL_COLOR := Color("5a6988")
const BLOCK_COLOR := Color("7a6a8a")
const GOAL_COLOR := Color("c0ca33")

const SPAWN := Vector2(40, 139)

## [Rect2(x, y_top, w, h), color] — y is the TOP of the rect.
const GEOMETRY := [
	# --- run + gap section: 24px (trivial), 40px (single jump), 64px (double jump)
	[Rect2(-40, 150, 240, 60), FLOOR_COLOR],
	[Rect2(224, 150, 96, 60), FLOOR_COLOR],
	[Rect2(360, 150, 96, 60), FLOOR_COLOR],
	[Rect2(520, 150, 160, 60), FLOOR_COLOR],
	# --- steps up (24px each)
	[Rect2(700, 126, 48, 24), FLOOR_COLOR],
	[Rect2(772, 102, 48, 24), FLOOR_COLOR],
	# --- wall-jump shaft: interior 40px wide, walls 200 tall
	[Rect2(840, 150, 210, 60), FLOOR_COLOR],
	[Rect2(880, -50, 16, 200), WALL_COLOR],
	[Rect2(936, -50, 16, 200), WALL_COLOR],
	# --- shaft exit platform (32px above wall tops)
	[Rect2(968, -82, 120, 16), FLOOR_COLOR],
	# --- main floor resumes
	[Rect2(1050, 150, 398, 60), FLOOR_COLOR],
	# --- ledge block: top 90px above floor — needs a ledge grab to mantle
	[Rect2(1160, 60, 48, 90), BLOCK_COLOR],
]

const KILL_ZONE := Rect2(-40, 300, 1520, 40)

var player # untyped on purpose (see state.gd header comment)
var _camera: Camera2D
var _state_name := "Idle"

@onready var _debug_label: Label = $HUD/DebugLabel


func _ready() -> void:
	RunManager.start_run()
	_build_geometry()
	_build_kill_zone()
	_build_goal_flag()

	player = $Player
	player.position = SPAWN
	player.state_changed.connect(_on_player_state_changed)

	_camera = Camera2D.new()
	_camera.limit_left = -40
	_camera.limit_top = -200
	_camera.limit_right = 1480
	_camera.limit_bottom = 300
	_camera.global_position = SPAWN
	add_child(_camera)


func _process(_delta: float) -> void:
	# Quantized follow camera: whole-pixel steps only, so the pixel-art world
	# never shimmers sub-pixel (docs/ARCHITECTURE.md §7 camera jitter trap).
	_camera.global_position = player.global_position.round()
	_debug_label.text = "state: %s   fps: %d" % [_state_name, Engine.get_frames_per_second()]


func _build_geometry() -> void:
	for entry in GEOMETRY:
		var rect: Rect2 = entry[0]
		var color: Color = entry[1]
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		body.collision_layer = 1 # world
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = rect.size
		shape.shape = rect_shape
		var poly := Polygon2D.new()
		var half := rect.size / 2.0
		poly.polygon = PackedVector2Array([
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y),
		])
		poly.color = color
		body.add_child(shape)
		body.add_child(poly)
		add_child(body)


func _build_kill_zone() -> void:
	var area := Area2D.new()
	area.position = KILL_ZONE.get_center()
	area.collision_layer = 256 # layer 9: trigger
	area.collision_mask = 6    # player_body + enemy_body
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = KILL_ZONE.size
	shape.shape = rect_shape
	area.add_child(shape)
	area.body_entered.connect(_on_kill_zone_body_entered)
	add_child(area)


func _build_goal_flag() -> void:
	var pole := Polygon2D.new()
	pole.polygon = PackedVector2Array([Vector2(1378, 106), Vector2(1382, 106), Vector2(1382, 150), Vector2(1378, 150)])
	pole.color = GOAL_COLOR
	add_child(pole)
	var flag := Polygon2D.new()
	flag.polygon = PackedVector2Array([Vector2(1382, 106), Vector2(1400, 111), Vector2(1382, 116)])
	flag.color = GOAL_COLOR
	add_child(flag)


func _on_kill_zone_body_entered(body) -> void:
	body.global_position = SPAWN
	body.velocity = Vector2.ZERO


func _on_player_state_changed(state_name: StringName) -> void:
	_state_name = String(state_name)
