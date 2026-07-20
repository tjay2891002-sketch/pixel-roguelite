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
var _pending_blockers: Array = [] # blockers waiting for the player to step clear
var _state_name := "Idle"

@onready var _debug_label: Label = $HUD/DebugLabel


func _ready() -> void:
	RunManager.start_run()
	EventBus.enemy_killed.connect(_on_enemy_killed)
	_build_stage()


func _process(_delta: float) -> void:
	# deferred door-blocker enables: a blocker must never close ON the player
	if not _pending_blockers.is_empty():
		for blocker in _pending_blockers.duplicate():
			if not _blocker_overlaps_player(blocker):
				blocker.shape.disabled = false
				blocker.vis.visible = true
				_pending_blockers.erase(blocker)
	if player and _camera:
		_camera.global_position = player.global_position.round()
		_debug_label.text = "state: %s   hp: %d   cells: %d   stage: %d   fps: %d" % [
			_state_name, player.health.hp, int(SaveStub.data.get("currency", 0)),
			stage_index + 1, Engine.get_frames_per_second()]


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
		"locked": false,
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
	area.body_exited.connect(_on_room_bounds_exited.bind(room))
	add_child(area)

	if pl.role == 1: # COMBAT
		_spawn_enemies(room, pl)
		_make_blockers(room, pl)
		_make_lock_trigger(room)
	elif pl.role == 4: # BOSS
		_make_boss_door(pl)
	if pl.role in [2, 3, 5]: # SHOP / TREASURE / BRANCH
		_make_treasure(pl)


func _spawn_enemies(room: Dictionary, pl: Dictionary) -> void:
	var budget: int = pl.chunk.difficulty_budget
	for marker in pl.chunk.spawn_points(&"E"):
		if budget < 2:
			break
		var enemy := WalkerScene.instantiate()
		add_child(enemy)
		# lift off the marker: markers can sit a pixel inside platforms
		enemy.global_position = marker.global_position + Vector2(0, -12)
		enemy.set(&"room_bounds", room.bounds) # hard confinement to this room
		room.enemies.append(enemy)
		budget -= 2


## Lock trigger sits one tile INSIDE the room bounds: the player must be
## properly inside before the doors seal — locking from the doorway could
## close blockers with the player still outside, sealing enemies in and the
## main path behind them (playtest soft-lock).
func _make_lock_trigger(room: Dictionary) -> void:
	var area := Area2D.new()
	area.collision_layer = 256
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = room.bounds.size - Vector2(32, 32)
	shape.shape = rect
	shape.position = room.bounds.get_center()
	area.add_child(shape)
	area.body_entered.connect(_on_lock_trigger_entered.bind(room))
	add_child(area)


## Treasure cells (placeholder currency pickup; the shop UI arrives in M5).
func _make_treasure(pl: Dictionary) -> void:
	for marker in pl.chunk.spawn_points(&"T"):
		var pickup := Area2D.new()
		pickup.collision_layer = 128 # layer 8: pickup
		pickup.collision_mask = 2
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(8, 8)
		shape.shape = rect
		pickup.add_child(shape)
		var vis := Polygon2D.new()
		vis.polygon = PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
		vis.color = Color("c0ca33")
		pickup.add_child(vis)
		pickup.add_to_group(&"pickup")
		add_child(pickup)
		pickup.global_position = marker.global_position
		pickup.body_entered.connect(_on_treasure_collected.bind(pickup))


## Door blockers on every CONNECTED door of a combat room (sealed doors are
## already walls). Disabled until the player walks in.
func _make_blockers(room: Dictionary, pl: Dictionary) -> void:
	for conn in pl.used:
		var blocker := StaticBody2D.new()
		blocker.collision_layer = 1
		blocker.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(48, 48) # covers the 3-tall door + seam
		shape.shape = rect
		shape.disabled = true
		blocker.add_child(shape)
		var vis := Polygon2D.new()
		vis.polygon = PackedVector2Array([
			Vector2(-24, -24), Vector2(24, -24), Vector2(24, 24), Vector2(-24, 24)])
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


func _on_room_bounds_exited(_body: Node2D, room: Dictionary) -> void:
	# leaving a still-occupied combat room unlocks it — re-enter to fight.
	# (prevents sealing enemies in with the player stuck outside: soft-lock)
	if room.locked and not room.cleared:
		_set_room_locked(room, false)


func _on_lock_trigger_entered(_body: Node2D, room: Dictionary) -> void:
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


func _on_treasure_collected(_body: Node2D, pickup: Area2D) -> void:
	SaveStub.add_currency(5)
	EventBus.currency_dropped.emit(5, pickup.global_position)
	pickup.queue_free()


# --- helpers -----------------------------------------------------------------

func _apply_camera_bounds(rect: Rect2) -> void:
	_camera.limit_left = int(rect.position.x)
	_camera.limit_top = int(rect.position.y)
	_camera.limit_right = int(rect.end.x)
	_camera.limit_bottom = int(rect.end.y)


func _set_room_locked(room: Dictionary, locked: bool) -> void:
	room.locked = locked
	for blocker in room.blockers:
		if locked and _blocker_overlaps_player(blocker):
			# player is standing in the doorway — close it once they step clear
			_pending_blockers.append(blocker)
		else:
			# DEFERRED: this is called from body_entered (physics flush) —
			# collision state can't change mid-flush
			blocker.shape.set_deferred(&"disabled", not locked)
			blocker.vis.visible = locked
	if not locked:
		for blocker in room.blockers:
			_pending_blockers.erase(blocker)


func _blocker_overlaps_player(blocker: Dictionary) -> bool:
	if player == null:
		return false
	var brect := Rect2(blocker.body.global_position - Vector2(24, 24), Vector2(48, 48))
	var prect := Rect2(player.global_position - Vector2(5, 11), Vector2(10, 22))
	return brect.intersects(prect)


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
	_pending_blockers.clear() # old blockers are about to be freed
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
