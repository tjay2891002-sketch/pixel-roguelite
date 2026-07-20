extends Node2D
## Stage — one generated biome stage (docs §6: all chunks of a stage live in
## ONE scene; room "transitions" are camera-limit moves, combat rooms lock
## their doors until cleared, the boss door regenerates the next stage).

const PlayerScene := preload("res://actors/player/player.tscn")
const WalkerScene := preload("res://actors/enemies/enemy_base.tscn")
const Generator := preload("res://level/generator/stage_generator.gd")
const GreyboxBiome := preload("res://data/biomes/greybox.tres")

const TILE := 16

var stage_index := 0
var player # untyped (see state.gd convention)
var _camera: Camera2D
var _rooms: Array = [] # per-placement runtime records
var _state_name := "Idle"

@onready var _debug_label: Label = $HUD/DebugLabel


func _ready() -> void:
	RunManager.start_run()
	EventBus.enemy_killed.connect(_on_enemy_killed)
	_build_stage()


func _process(_delta: float) -> void:
	if player and _camera:
		_camera.global_position = player.global_position.round()
		_debug_label.text = "state: %s   hp: %d   stage: %d   fps: %d" % [
			_state_name, player.health.hp, stage_index + 1, Engine.get_frames_per_second()]


func _build_stage() -> void:
	var rng := RunManager.stage_rng(stage_index)
	var layout := Generator.generate(GreyboxBiome, rng)
	if layout.is_empty():
		push_error("[Stage] generation failed; nothing to build")
		return
	Generator.instantiate(layout, $Chunks)
	_rooms.clear()
	for pl in layout:
		_setup_room(pl)
	_setup_player(layout)
	# camera starts on the start room
	if not _rooms.is_empty():
		_apply_camera_bounds(_rooms[0].bounds)


# --- room setup --------------------------------------------------------------

func _setup_room(pl: Dictionary) -> void:
	var room := {
		"chunk": pl.chunk,
		"role": pl.role,
		"bounds": Rect2(pl.pos, pl.chunk.bounds().size),
		"enemies": [] as Array,
		"blockers": [] as Array,
		"cleared": false,
	}
	_rooms.append(room)

	# camera bounds trigger (layer 9 trigger, mask 2 = player_body)
	var area := Area2D.new()
	area.collision_layer = 256
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = room.bounds.size
	shape.shape = rect
	shape.position = room.bounds.get_center()
	area.add_child(shape)
	area.body_entered.connect(_on_room_bounds_entered.bind(room))
	add_child(area)

	if pl.role == 1: # COMBAT
		_spawn_enemies(room, pl)
		_make_blockers(room, pl)
	elif pl.role == 4: # BOSS
		_make_boss_door(pl)


func _spawn_enemies(room: Dictionary, pl: Dictionary) -> void:
	var budget: int = pl.chunk.difficulty_budget
	for marker in pl.chunk.spawn_points(&"E"):
		if budget < 2:
			break
		var enemy := WalkerScene.instantiate()
		add_child(enemy)
		enemy.global_position = marker.global_position
		room.enemies.append(enemy)
		budget -= 2


## Door blockers on every CONNECTED door of a combat room (sealed doors are
## already walls). Disabled until the player walks in.
func _make_blockers(room: Dictionary, pl: Dictionary) -> void:
	for conn in pl.used:
		var blocker := StaticBody2D.new()
		blocker.collision_layer = 1
		blocker.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(32, 32)
		shape.shape = rect
		shape.disabled = true
		blocker.add_child(shape)
		var vis := Polygon2D.new()
		vis.polygon = PackedVector2Array([
			Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)])
		vis.color = Color(0.8, 0.3, 0.3, 0.6)
		vis.visible = false
		blocker.add_child(vis)
		add_child(blocker)
		blocker.global_position = pl.pos + conn.position + Vector2(conn.dir * (TILE / 2.0))
		room.blockers.append({"body": blocker, "shape": shape, "vis": vis})


func _make_boss_door(pl: Dictionary) -> void:
	for marker in pl.chunk.spawn_points(&"B"):
		var area := Area2D.new()
		area.collision_layer = 256
		area.collision_mask = 2
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 12.0
		shape.shape = circle
		area.add_child(shape)
		var flag := Polygon2D.new()
		flag.polygon = PackedVector2Array([
			Vector2(-1, -16), Vector2(1, -16), Vector2(1, 0), Vector2(-1, 0),
			Vector2(1, -16), Vector2(12, -13), Vector2(1, -10)])
		flag.color = Color("c0ca33")
		area.add_child(flag)
		add_child(area)
		area.global_position = marker.global_position
		area.body_entered.connect(_on_boss_door_entered)


# --- signals -----------------------------------------------------------------

func _on_room_bounds_entered(_body: Node2D, room: Dictionary) -> void:
	_apply_camera_bounds(room.bounds)
	if room.role == 1 and not room.cleared and not room.enemies.is_empty():
		_set_room_locked(room, true)


func _on_enemy_killed(enemy: Node2D) -> void:
	for room in _rooms:
		if room.enemies.has(enemy):
			room.enemies.erase(enemy)
			if room.enemies.is_empty():
				room.cleared = true
				_set_room_locked(room, false)
				EventBus.room_cleared.emit(room.chunk)
			return


func _on_boss_door_entered(_body: Node2D) -> void:
	_regenerate.call_deferred()


# --- helpers -----------------------------------------------------------------

func _apply_camera_bounds(rect: Rect2) -> void:
	_camera.limit_left = int(rect.position.x)
	_camera.limit_top = int(rect.position.y)
	_camera.limit_right = int(rect.end.x)
	_camera.limit_bottom = int(rect.end.y)


func _set_room_locked(room: Dictionary, locked: bool) -> void:
	for blocker in room.blockers:
		blocker.shape.disabled = not locked
		blocker.vis.visible = locked


func _setup_player(layout: Array) -> void:
	if player == null:
		player = PlayerScene.instantiate()
		add_child(player)
		player.state_changed.connect(func(s): _state_name = String(s))
	if _camera == null:
		_camera = Camera2D.new()
		_camera.add_to_group(&"player_camera")
		add_child(_camera)
	# player start = P marker of the START chunk
	for pl in layout:
		if pl.role == 0:
			var markers = pl.chunk.spawn_points(&"P")
			if not markers.is_empty():
				player.global_position = markers[0].global_position
				player.velocity = Vector2.ZERO
				_camera.global_position = player.global_position.round()
				return


func _regenerate() -> void:
	stage_index += 1
	for child in $Chunks.get_children():
		child.queue_free()
	for child in get_children():
		if child is Area2D or child is StaticBody2D:
			child.queue_free()
	# enemies were added to self — free those too
	for child in get_children():
		if child is CharacterBody2D and child != player:
			child.queue_free()
	await get_tree().process_frame
	_build_stage()
