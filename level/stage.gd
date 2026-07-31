extends Node2D
## Stage — one generated biome stage (docs §6: all chunks of a stage live in
## ONE scene; room "transitions" are camera-limit moves, combat rooms lock
## their doors until cleared, the boss door regenerates the next stage).

const PlayerScene := preload("res://actors/player/player.tscn")
const Generator := preload("res://level/generator/stage_generator.gd")
const GreyboxBiome := preload("res://data/biomes/greybox.tres")
const SFX := preload("res://fx/sfx_builder.gd")
const ShopStand := preload("res://level/shop_stand.tscn")
const DestructibleProp := preload("res://level/destructible_prop.gd")
const PROPS := [
	preload("res://assets/level/tiles/prop_barrel.png"),
	preload("res://assets/level/tiles/prop_crate.png"),
	preload("res://assets/level/tiles/prop_sign.png"),
	preload("res://assets/level/tiles/prop_street-lamp.png"),
]
# Crates/barrels are solid + smashable; tall decor (sign, lamp) stays
# visual-only — giving a 108px lamp a body would wall off rooms.
const BREAKABLE_PROPS := [
	preload("res://assets/level/tiles/prop_barrel.png"),
	preload("res://assets/level/tiles/prop_crate.png"),
]

const TILE := 16
const KEY_R := 82
const KEY_Q := 81
const KEY_S := 83
const KEY_ESCAPE := 4194305
const KEY_F3 := 4194334

## Title shows once per app launch (survives scene reloads; skipped in
## headless tests where current_scene is null).
static var _title_shown_once := false

## Spawn archetypes by map letter (M4). E = random pick from the pool.
const ENEMY_SCENES := {
	&"E": preload("res://actors/enemies/rat_rusher.tscn"),
	&"R": preload("res://actors/enemies/spitter.tscn"),
	&"F": preload("res://actors/enemies/flyer.tscn"),
	&"H": preload("res://actors/enemies/heavy.tscn"),
}
const ENEMY_COST := {&"E": 2, &"R": 2, &"F": 3, &"H": 4}
const RANDOM_POOL := [&"E", &"R", &"F", &"H"]

var stage_index := 0
var player # untyped (see state.gd convention)
var _camera: Camera2D
var _rooms: Array = [] # per-placement runtime records
var _pending_blockers: Array = [] # blockers waiting for the player to step clear
var _state_name := "Idle"
var _rng: RandomNumberGenerator

@onready var _debug_label: Label = $HUD/DebugLabel
@onready var _hp_fill: TextureRect = $HUD/HpBarFill
@onready var _cell_label: Label = $HUD/CellLabel
@onready var _info_label: Label = $HUD/InfoLabel
@onready var _title_overlay: CanvasLayer = $TitleOverlay
@onready var _death_overlay: CanvasLayer = $DeathOverlay
@onready var _death_text: Label = $DeathOverlay/DeathText
@onready var _pause_overlay: CanvasLayer = $PauseOverlay
@onready var _pause_text: Label = $PauseOverlay/PauseText
@onready var _juice: Node = $Juice


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # keep input alive while paused
	RunManager.start_run()
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_died.connect(_on_player_died)
	EventBus.leveled_up.connect(_on_leveled_up)
	_setup_background()
	_build_stage()
	if not _title_shown_once:
		await get_tree().process_frame
		if get_tree().current_scene == self:
			_title_shown_once = true
			_title_overlay.visible = true
			get_tree().paused = true


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
		# golden fill clipped by hp (44px full bar starting at left edge 16)
		_hp_fill.offset_right = 16.0 + 44.0 * (float(player.health.hp) / player.health.max_hp)
		_cell_label.text = "x %d" % int(SaveStub.data.get("currency", 0))
		_info_label.text = "stage: %d   %s   Lv%d (%d/%d xp)" % [
			stage_index + 1, player.weapon.display_name,
			RunManager.level, RunManager.xp, RunManager.xp_needed()]
		_debug_label.text = "state: %s   hp: %d   fps: %d" % [
			_state_name, player.health.hp, Engine.get_frames_per_second()]


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var key: int = event.physical_keycode
	if _title_overlay.visible:
		_title_overlay.visible = false
		get_tree().paused = false
		return
	if _death_overlay.visible:
		if key == KEY_R:
			get_tree().paused = false
			get_tree().reload_current_scene()
		return
	if _pause_overlay.visible:
		match key:
			KEY_R, KEY_ESCAPE:
				_toggle_pause()
			KEY_S:
				_juice.shake_enabled = not _juice.shake_enabled
				SaveStub.data["shake"] = _juice.shake_enabled
				SaveStub.flush()
				_update_pause_text()
			KEY_Q:
				get_tree().paused = false
				get_tree().reload_current_scene()
		return
	if key == KEY_ESCAPE:
		_toggle_pause()
	elif key == KEY_F3:
		_debug_label.visible = not _debug_label.visible


func _build_stage() -> void:
	_rng = RunManager.stage_rng(stage_index)
	# difficulty curve: from stage 3, an extra combat room per stage before
	# the boss room (duplicate + copy the array so the base config is untouched)
	var config: BiomeConfig = GreyboxBiome
	if stage_index >= 2:
		config = GreyboxBiome.duplicate()
		config.path_roles = GreyboxBiome.path_roles.duplicate()
		for i in stage_index - 1:
			config.path_roles.insert(config.path_roles.size() - 1, 1)
	var layout := Generator.generate(config, _rng)
	if layout.is_empty():
		push_error("[Stage] generation failed; nothing to build")
		return
	Generator.instantiate(layout, $Chunks)
	_rooms.clear()
	for i in layout.size():
		_setup_room(layout[i], i)
	_setup_player(layout)
	# camera starts on the start room
	if not _rooms.is_empty():
		_apply_camera_bounds(_rooms[0].bounds)


# --- room setup --------------------------------------------------------------

func _setup_room(pl: Dictionary, path_index: int) -> void:
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
		_spawn_enemies(room, pl, path_index)
		_make_blockers(room, pl)
		_make_lock_trigger(room)
	elif pl.role == 4: # BOSS
		_make_boss_door(pl)
	if pl.role == 2: # SHOP
		_make_shop(pl)
	elif pl.role in [3, 5]: # TREASURE / BRANCH
		_make_treasure(pl)
	_scatter_props(room, pl)


## Room props: 1-2 per room at deterministic random floor spots, anchored to
## the floor. Breakables become DestructibleProps (solid to the player, blast
## enemies when smashed); decor stays visual-only at z=-1 — same layer as the
## tiles, so actors (z 0) always draw on top and it can't block the view.
func _scatter_props(room: Dictionary, pl: Dictionary) -> void:
	var floor_top: float = pl.pos.y + (pl.chunk.cell_size().y - 1) * TILE
	var w: float = pl.chunk.bounds().size.x
	var count := 1 + _rng.randi() % 2
	var margin := 24.0
	for i in count:
		var tex: Texture2D = PROPS[_rng.randi() % PROPS.size()]
		var span := maxf(0.0, w - margin * 2.0)
		var px: float = pl.pos.x + margin + _rng.randf() * span
		if BREAKABLE_PROPS.has(tex):
			var prop := DestructibleProp.new(tex)
			add_child(prop)
			prop.position = Vector2(px, floor_top) # origin at the feet
		else:
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.z_index = -1
			add_child(sprite)
			sprite.position = Vector2(px, floor_top - tex.get_height() / 2.0)


## Budgeted archetype spawning (M4): budget = chunk budget + distance from
## start (deeper rooms are harder). Map letters hint types (R/F/H exact,
## E = random affordable pick); unaffordable hints downgrade to a rusher.
func _spawn_enemies(room: Dictionary, pl: Dictionary, path_index: int) -> void:
	# budget: chunk budget + distance from start + stage depth (difficulty curve)
	var budget: int = pl.chunk.difficulty_budget + path_index / 2 + stage_index / 2
	for kind in [&"E", &"R", &"F", &"H"]:
		for marker in pl.chunk.spawn_points(kind):
			var pick: StringName = kind
			if kind == &"E":
				pick = _pick_affordable(budget)
			elif ENEMY_COST[kind] > budget:
				pick = &"E" if ENEMY_COST[&"E"] <= budget else &""
			if pick == &"":
				continue
			_spawn_enemy(room, pick, marker.global_position)
			budget -= ENEMY_COST[pick]


func _pick_affordable(budget: int) -> StringName:
	var options: Array = []
	for kind in RANDOM_POOL:
		if ENEMY_COST[kind] <= budget:
			options.append(kind)
	if options.is_empty():
		return &""
	return options[_rng.randi() % options.size()]


func _spawn_enemy(room: Dictionary, kind: StringName, pos: Vector2) -> void:
	var enemy = ENEMY_SCENES[kind].instantiate()
	add_child(enemy)
	# lift off the marker: markers can sit a pixel inside platforms
	enemy.global_position = pos + Vector2(0, -12)
	enemy.set(&"room_bounds", room.bounds) # hard confinement to this room
	room.enemies.append(enemy)


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


## Shop room: one stand per T marker — heal first, dagger second.
func _make_shop(pl: Dictionary) -> void:
	var markers = pl.chunk.spawn_points(&"T")
	var offers := [
		[&"heal", 10, "Heal 10HP"],
		[&"dagger", 15, "Dagger"],
	]
	var floor_top: float = pl.pos.y + (pl.chunk.cell_size().y - 1) * TILE
	for i in mini(offers.size(), markers.size()):
		var stand := ShopStand.instantiate()
		stand.offer = offers[i][0]
		stand.cost = offers[i][1]
		stand.stand_text = offers[i][2]
		add_child(stand)
		# stands sit on the floor below their marker, reachable by the player
		stand.global_position = Vector2(markers[i].global_position.x, floor_top - 5.0)


## Treasure cells (placeholder currency pickup; the shop UI arrives in M5).
func _make_treasure(pl: Dictionary) -> void:
	var floor_top: float = pl.pos.y + (pl.chunk.cell_size().y - 1) * TILE
	for marker in pl.chunk.spawn_points(&"T"):
		var pickup := Area2D.new()
		pickup.collision_layer = 128 # layer 8: pickup
		pickup.collision_mask = 2
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(10, 10)
		shape.shape = rect
		pickup.add_child(shape)
		# bright gold cell with a dark outline + a bob, so it reads against tiles
		var outline := Polygon2D.new()
		outline.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
		outline.color = Color("3a2a10")
		pickup.add_child(outline)
		var vis := Polygon2D.new()
		vis.polygon = PackedVector2Array([Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)])
		vis.color = Color("ffd54a")
		pickup.add_child(vis)
		pickup.add_to_group(&"pickup")
		add_child(pickup)
		pickup.global_position = Vector2(marker.global_position.x, floor_top - 6.0)
		pickup.body_entered.connect(_on_treasure_collected.bind(pickup))
		# gentle bob so the cell catches the eye — bound to the PICKUP (not the
		# stage): a stage-bound infinite tween outlives queue_free(), its freed
		# targets collapse the loop to 0 duration ("Infinite loop detected").
		var tween := pickup.create_tween().set_loops()
		tween.tween_property(vis, "position:y", -4.0, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(vis, "position:y", 0.0, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(outline, "position:y", -4.0, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(outline, "position:y", 0.0, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


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
	RunManager.add_xp(int(enemy.get("xp_value") or 0))
	for room in _rooms:
		if room.enemies.has(enemy):
			room.enemies.erase(enemy)
			if room.enemies.is_empty():
				room.cleared = true
				_set_room_locked(room, false)
				EventBus.room_cleared.emit(room.chunk)
				AudioBus.play_sfx(SFX.unlock(), player.global_position)
			return


func _on_boss_door_entered(_body: Node2D) -> void:
	_regenerate.call_deferred()


func _on_leveled_up(_lvl: int) -> void:
	AudioBus.play_sfx(SFX.levelup(), player.global_position)


func _on_player_died() -> void:
	AudioBus.play_sfx(SFX.death(), player.global_position)
	# wall-clock beat (ignore_time_scale): the killing blow's hitstop would
	# otherwise stretch this timer several-fold
	await get_tree().create_timer(0.8, true, false, true).timeout
	_death_text.text = "YOU DIED\n\ncells collected: %d\n\n[R] restart" % int(SaveStub.data.get("currency", 0))
	_death_overlay.visible = true
	get_tree().paused = true


func _toggle_pause() -> void:
	if _title_overlay.visible or _death_overlay.visible:
		return
	_pause_overlay.visible = not _pause_overlay.visible
	get_tree().paused = _pause_overlay.visible
	if _pause_overlay.visible:
		_update_pause_text()


func _update_pause_text() -> void:
	# PauseTitle shows the title; this label is just the option lines
	_pause_text.text = "[R]esume   [S]hake: %s   [Q]uit run" % ("ON" if _juice.shake_enabled else "OFF")


## Two-layer parallax town backdrop behind the chunks (replaces the void).
func _setup_background() -> void:
	var bg := ParallaxBackground.new()
	add_child(bg)
	bg.add_child(_make_bg_layer(preload("res://assets/level/bg_far.png"), 0.2))
	bg.add_child(_make_bg_layer(preload("res://assets/level/bg_mid.png"), 0.5))


func _make_bg_layer(tex: Texture2D, scale: float) -> ParallaxLayer:
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(scale, scale)
	layer.motion_mirroring = Vector2(384, 0)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	layer.add_child(sprite)
	return layer


func _on_treasure_collected(_body: Node2D, pickup: Area2D) -> void:
	SaveStub.add_currency(5)
	EventBus.currency_dropped.emit(5, pickup.global_position)
	AudioBus.play_sfx(SFX.pickup(), pickup.global_position)
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
