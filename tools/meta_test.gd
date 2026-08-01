extends SceneTree
## Headless meta-UI test (P3):
##   A) dying shows the death panel with the permanent-unlock list
##   B) a number key unlocks the weapon and deducts banked coins
##   C) re-press is a no-op; unaffordable unlock is denied
## Run: godot --headless --path <project> --script res://tools/meta_test.gd

var _frame := 0
var _stage
var _player
var _save
var _phase := 0
var _t0 := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var scene: PackedScene = load("res://level/stage.tscn")
	root.add_child(scene.instantiate())
	_stage = root.get_node("Stage")
	_save = root.get_node("SaveStub")


func _physics_process(_delta: float) -> bool:
	_frame += 1
	if _player == null:
		_player = _stage.player
	if _frame == 3:
		_save.data["coins"] = 25
		_player.health.take_hit({&"damage": 999, &"poise_damage": 0.0,
			&"knockback": Vector2.ZERO, &"attacker": _player})

	match _phase:
		0: # waiting for the wall-clock death beat to show the overlay
			if _stage._death_overlay.visible:
				_check("永久解锁" in _stage._death_text.text, "death panel shows the unlock list", "")
				_check("初始武器 ✓" in _stage._death_text.text, "starter sword listed as owned", "")
				_key(49) # [1] dagger, 15 of 25 coins
				_t0 = _frame
				_phase = 1
			elif _frame > 1500:
				_check(false, "death overlay appeared within the wait", "")
				_finish()
		1:
			if _frame >= _t0 + 6:
				_check(int(_save.data["coins"]) == 10, "unlock deducts coins (25->10)", "coins=%d" % int(_save.data["coins"]))
				_check(_save.is_weapon_unlocked(&"dagger"), "dagger permanently unlocked", "")
				_key(49) # again — already unlocked, no-op
				_t0 = _frame
				_phase = 2
		2:
			if _frame >= _t0 + 6:
				_check(int(_save.data["coins"]) == 10, "re-press is a no-op", "coins=%d" % int(_save.data["coins"]))
				_key(50) # [2] spear costs 20 > 10 -> deny
				_t0 = _frame
				_phase = 3
		3:
			if _frame >= _t0 + 6:
				_check(not _save.is_weapon_unlocked(&"spear"), "unaffordable unlock denied", "")
				_check(int(_save.data["coins"]) == 10, "deny keeps the coins", "coins=%d" % int(_save.data["coins"]))
				_finish()
	return false


func _key(keycode: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
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
		print("META TEST: all checks passed")
	else:
		printerr("META TEST: %d check(s) failed" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
