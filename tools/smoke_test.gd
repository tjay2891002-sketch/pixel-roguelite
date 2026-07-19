extends SceneTree
## Headless smoke test for the M1 player controller.
## Run: godot --headless --path <project> --script res://tools/smoke_test.gd
##
## Drives synthetic input through Input.parse_input_event (real input events,
## so _unhandled_input jump buffering is exercised) across three phases:
##   A: wall cling + wall jump (teleported into the shaft)
##   B: ledge grab + climb (teleported at the ledge block)
##   C: run / jump+cut / land / facing flip / roll i-frames (from spawn)
## Exit code 0 = all checks passed.

var _frame := 0
var _player
var _failures: Array[String] = []


func _initialize() -> void:
	var scene: PackedScene = load("res://level/playground.tscn")
	root.add_child(scene.instantiate())
	_player = root.get_node("Playground/Player")


func _physics_process(_delta: float) -> bool:
	_frame += 1
	match _frame:
		# --- Phase A: wall cling + wall jump
		2:
			_teleport(Vector2(902, 40)) # inside shaft, near left wall (face x=896, wall spans y=-50..80)
			_press(&"move_left")
		10:
			_check(_state() == &"WallCling", "drift into wall => WallCling", "got %s" % _state())
		11:
			_press(&"jump")
		12:
			_release(&"jump")
		16:
			_check(_state() == &"WallJump", "jump from cling => WallJump", "got %s" % _state())
			_check(_player.velocity.x > 80.0, "wall jump pushes away from wall", "velocity.x=%s" % _player.velocity.x)
		17:
			_release(&"move_left")
		# --- Phase B: ledge grab + climb
		44:
			_force_idle()
		45:
			# 1153 puts the 8px rays in contact with the block face (x=1160)
			# immediately — mimicking a real approach with horizontal speed.
			_teleport(Vector2(1153, 65)) # beside ledge block (face x=1160, top y=60)
			_press(&"move_right")
		53:
			_check(_state() == &"LedgeClimb", "fall toward ledge => LedgeClimb", "got %s" % _state())
		68:
			_release(&"move_right")
		70:
			_check(_player.global_position.y < 60.0, "standing on block top", "y=%s" % _player.global_position.y)
		76:
			# ground_decel from full run takes ~4 frames after input release
			_check(_state() == &"Idle", "climb finishes => Idle", "got %s" % _state())
		# --- Phase C: ground movement from spawn
		80:
			_force_idle()
		81:
			_teleport(Vector2(40, 139))
			_press(&"move_right")
		105:
			_check(_state() == &"Run", "moving right => Run", "got %s" % _state())
			_check(_player.velocity.x > 50.0, "run speed near max", "velocity.x=%s" % _player.velocity.x)
		106:
			_press(&"jump")
		107:
			_release(&"jump") # early release: jump cut should apply
		111:
			_check(_state() == &"Jump", "jump press => Jump", "got %s" % _state())
			_check(_player.velocity.y < 0.0, "ascending after jump", "velocity.y=%s" % _player.velocity.y)
		155:
			_check(_state() in [&"Run", &"Idle", &"Fall"], "landed by frame 155", "got %s" % _state())
		156:
			_release(&"move_right")
			_press(&"move_left")
		157:
			_press(&"roll")
		158:
			_release(&"roll")
		161:
			_check(_player.facing == -1, "facing flips left", "facing=%s" % _player.facing)
		166:
			_check(_state() == &"Roll", "roll press => Roll", "got %s" % _state())
			_check(_player.invulnerable, "i-frames during roll", "invulnerable=false")
		195:
			_check(not _player.invulnerable, "i-frames end after roll", "still invulnerable")
			_finish()
	return false


func _teleport(pos: Vector2) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO


func _force_idle() -> void:
	_player.state_machine.change_state(&"Idle")


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


func _state() -> StringName:
	return _player.state_machine.current.name


func _check(condition: bool, what: String, detail := "") -> void:
	if condition:
		print("PASS: %s" % what)
	else:
		var message := "FAIL: %s (%s) [frame %d]" % [what, detail, _frame]
		_failures.append(message)
		printerr(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE TEST: all checks passed")
	else:
		printerr("SMOKE TEST: %d check(s) failed" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
