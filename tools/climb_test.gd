extends SceneTree
## Headless climb test: performs the full wall-shaft climb with the intended
## technique (hold toward the wall, tap jump on every cling) and asserts the
## player actually reaches the top.
## Run: godot --headless --path <project> --script res://tools/climb_test.gd

var _frame := 0
var _player
var _jump_held := false
var _min_y := 9999.0
var _cling_count := 0
var _saw_ledge := false
var _last_state := &""
var _log: Array[String] = []


func _initialize() -> void:
	var scene: PackedScene = load("res://level/playground.tscn")
	root.add_child(scene.instantiate())
	_player = root.get_node("Playground/Player")


func _physics_process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		# spawn inside the shaft on its floor (shaft interior x=896..936)
		_player.global_position = Vector2(910, 139)
		_player.velocity = Vector2.ZERO
		_press(&"move_right") # hold D the whole climb
	elif _frame > 2 and _frame < 700:
		var s: StringName = _player.state_machine.current.name
		if s != _last_state:
			_log.append("f%-4d %-10s y=%-7.1f vy=%-7.1f" % [_frame, s, _player.global_position.y, _player.velocity.y])
			if s == &"WallCling":
				_cling_count += 1
			if s == &"LedgeClimb":
				_saw_ledge = true
			_last_state = s
		_min_y = minf(_min_y, _player.global_position.y)
		# Mash jump on every grounded/clinging state (1-frame taps: also
		# proves wall kicks aren't gutted by the jump-cut). Holding D the
		# whole time supplies the toward-wall input.
		if s in [&"Idle", &"Run", &"WallCling"] and not _jump_held:
			_press(&"jump")
			_jump_held = true
		elif _jump_held:
			_release(&"jump")
			_jump_held = false
	elif _frame >= 700:
		_finish()
	return false


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


func _finish() -> void:
	for line in _log:
		print(line)
	print("clings: %d   min_y: %.1f   ledge_mantle: %s" % [_cling_count, _min_y, _saw_ledge])
	# Success = mantled a wall top (ledge grab) or rose above the shaft's
	# right wall top (y=-50) — i.e., the climb can be completed.
	var ok := _saw_ledge or _min_y <= -45.0
	if ok:
		print("CLIMB TEST: PASS")
	else:
		printerr("CLIMB TEST: FAIL — never reached the shaft top")
	quit(0 if ok else 1)
