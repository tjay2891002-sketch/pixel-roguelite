extends SceneTree
## Headless combat test (M2's done-when, machine-checkable parts):
##   A) sword swings damage the dummy; a 3-hit chain breaks poise -> Stagger;
##      further swings kill it -> enemy_killed
##   B) the walker telegraphs, then its swipe damages the player
##   C) rolling through the swipe (timed off the telegraph, as a human would)
##      takes NO damage — roll i-frames
##   D) at 1 hp, a swipe kills the player -> player_died -> Dead state
## Run: godot --headless --path <project> --script res://tools/combat_test.gd

var _frame := 0
var _player
var _dummy
var _walker
var _enemy_killed := false
var _player_died := false
var _watch_roll := false
var _telegraph_frame := -1
var _roll_pressed := false
var _failures: Array[String] = []
var _last_pstate := &""
var _last_idx := -1
var _last_inv := false
var _last_wstate := &""


func _initialize() -> void:
	var scene: PackedScene = load("res://level/playground.tscn")
	root.add_child(scene.instantiate())
	_player = root.get_node("Playground/Player")
	# Autoload names don't resolve at compile time in a --script main loop,
	# so grab the singleton from the tree instead.
	var bus = root.get_node("EventBus")
	bus.enemy_killed.connect(func(_e): _enemy_killed = true)
	bus.player_died.connect(func(): _player_died = true)
	bus.hit_landed.connect(func(info): print("  [hit] f%d %s -> %s dmg=%d" % [_frame, info.attacker.name, info.victim.name, info.damage]))


## Enemies are spawned by playground._ready(), which hasn't run yet during
## _initialize — resolve lazily on the first physics frame.
func _resolve_enemies() -> void:
	if _dummy == null:
		_dummy = root.get_node_or_null("Playground/Dummy")
	if _walker == null:
		_walker = root.get_node_or_null("Playground/Enemy")


func _physics_process(_delta: float) -> bool:
	_frame += 1
	_resolve_enemies()

	# --- diagnostic trace
	var ps: StringName = &"" if _player.state_machine.current == null else _player.state_machine.current.name
	var idx: int = _player.attack_step_index
	if ps != _last_pstate or idx != _last_idx:
		print("  [p] f%d %s idx=%d" % [_frame, ps, idx])
		_last_pstate = ps
		_last_idx = idx
	if _player.invulnerable != _last_inv:
		print("  [inv] f%d invulnerable=%s" % [_frame, _player.invulnerable])
		_last_inv = _player.invulnerable
	if _walker != null:
		var ws_now: StringName = &"" if _walker.state_machine.current == null else _walker.state_machine.current.name
		if ws_now != _last_wstate and ws_now in [&"Telegraph", &"Attack", &"Stagger"]:
			print("  [w] f%d %s" % [_frame, ws_now])
		_last_wstate = ws_now
	# --- B-phase diagnostics: every 20 frames after the approach
	if _frame >= 114 and _frame % 20 == 0:
		var ws: StringName = _walker.state_machine.current.name
		print("  [dbg] f%d player=(%d,%d) walker=(%d,%d) wstate=%s target=%s" % [
			_frame, _player.global_position.x, _player.global_position.y,
			_walker.global_position.x, _walker.global_position.y, ws, _walker.target != null])

	# Phase C: react to the telegraph like a human — roll in its second half
	# so the i-frames cover the strike (telegraph 27f > roll 19f).
	if _watch_roll and _walker != null:
		var ws: StringName = _walker.state_machine.current.name
		if ws == &"Telegraph" and _telegraph_frame < 0:
			_telegraph_frame = _frame
		elif ws != &"Telegraph" and ws != &"Attack":
			_telegraph_frame = -1
			_roll_pressed = false
		if _telegraph_frame >= 0 and not _roll_pressed and _frame >= _telegraph_frame + 12:
			_press(&"roll")
			_roll_pressed = true

	match _frame:
		# NOTE: in unthrottled headless, input dispatch to state entry lags
		# ~4-5 physics ticks; check frames below include that slack.
		# --- A: dummy
		2:
			_teleport(Vector2(138, 139)) # left of the dummy (x=150)
		5:
			_tap(&"attack")
		18:
			_check(_dummy.health.hp == 32, "first swing deals 8 (40->32)", "hp=%d" % _dummy.health.hp)
		20:
			_tap(&"attack")
		34:
			_tap(&"attack")
		56:
			_check(_dummy.health.hp == 12, "3-hit chain deals 28 (40->12)", "hp=%d" % _dummy.health.hp)
			_check(_dummy.state_machine.current.name == &"Stagger", "chain breaks poise => Stagger", "state=%s" % _dummy.state_machine.current.name)
		62:
			_teleport(Vector2(_dummy.global_position.x - 12, 139)) # re-approach: knockback slid it away
			_tap(&"attack")
		80:
			_teleport(Vector2(_dummy.global_position.x - 12, 139))
			_tap(&"attack")
		98:
			_teleport(Vector2(_dummy.global_position.x - 12, 139))
			_tap(&"attack")
		112:
			_check(_enemy_killed, "dummy dies => enemy_killed emitted", "hp=%d" % _dummy.health.hp)
		# --- B: walker swipe lands
		114:
			_teleport(_walker.global_position + Vector2(-12, 0))
		155:
			_check(_player.health.hp == 24, "walker swipe deals 6 (30->24)", "hp=%d" % _player.health.hp)
			_watch_roll = true
		# --- C: roll through the next swipe
		240:
			_check(_player.health.hp == 24, "roll-through swipe: no damage (i-frames)", "hp=%d" % _player.health.hp)
		# --- D: death
		242:
			_player.health.hp = 1
		320:
			_check(_player_died, "lethal swipe => player_died emitted", "")
			_check(_player.state_machine.current.name == &"Dead", "player enters Dead state", "state=%s" % _player.state_machine.current.name)
			_finish()
	return false


func _teleport(pos: Vector2) -> void:
	_player.state_machine.change_state(&"Idle")
	_player.global_position = pos
	_player.velocity = Vector2.ZERO


func _tap(action: StringName) -> void:
	_press(action)
	# release next frame via a one-shot deferred call
	_release.call_deferred(action)


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


func _release(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)


func _check(condition: bool, what: String, detail := "") -> void:
	if condition:
		print("PASS: %s" % what)
	else:
		var message := "FAIL: %s (%s) [frame %d]" % [what, detail, _frame]
		_failures.append(message)
		printerr(message)


func _finish() -> void:
	if _failures.is_empty():
		print("COMBAT TEST: all checks passed")
	else:
		printerr("COMBAT TEST: %d check(s) failed" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
