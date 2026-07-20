extends SceneTree
## Headless stage test: room lockdown lifecycle.
##   teleporting into a combat room locks its blockers (deferred, no
##   physics-flush errors); killing all its enemies unlocks them.
## Run: godot --headless --path <project> --script res://tools/stage_test.gd

var _frame := 0
var _stage
var _player
var _combat_room
var _failures: Array[String] = []


func _initialize() -> void:
	var scene: PackedScene = load("res://level/stage.tscn")
	root.add_child(scene.instantiate())
	_stage = root.get_node("Stage")


func _physics_process(_delta: float) -> bool:
	_frame += 1
	# stage._ready() runs after _initialize — resolve the player lazily
	if _player == null:
		_player = _stage.player
	match _frame:
		3:
			for room in _stage._rooms:
				if room.role == 1 and not room.enemies.is_empty():
					_combat_room = room
					break
			_check(_combat_room != null, "found a combat room with enemies", "")
			if _combat_room:
				_player.global_position = _combat_room.bounds.get_center()
		15:
			if _combat_room:
				var locked = not _combat_room.blockers.is_empty()
				for blocker in _combat_room.blockers:
					if blocker.shape.disabled:
						locked = false
				_check(locked, "room locks on player entry", "")
				for enemy in _combat_room.enemies.duplicate():
					enemy.health.take_hit({
						&"damage": 999, &"poise_damage": 0.0,
						&"knockback": Vector2.ZERO, &"attacker": _player})
		25:
			if _combat_room:
				_check(_combat_room.cleared, "room cleared after kills", "")
				var unlocked := true
				for blocker in _combat_room.blockers:
					if not blocker.shape.disabled:
						unlocked = false
				_check(unlocked, "blockers open after clear", "")
			_finish()
	return false


func _check(condition: bool, what: String, detail := "") -> void:
	if condition:
		print("PASS: %s" % what)
	else:
		var message := "FAIL: %s (%s) [frame %d]" % [what, detail, _frame]
		_failures.append(message)
		printerr(message)


func _finish() -> void:
	if _failures.is_empty():
		print("STAGE TEST: all checks passed")
	else:
		printerr("STAGE TEST: %d check(s) failed" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
