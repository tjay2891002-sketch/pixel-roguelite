extends SceneTree
## Headless boss test (stage-based, boss room is guaranteed by the generator):
##   A) boss room spawns a boss; entering locks the room and shows the bar;
##      the boss door DENIES stage advance while the boss lives
##   B) at <=50% hp the brain enrages (faster, tinted) and alternates
##      melee / volley on each return to Chase
##   C) killing the boss clears the room (blockers open, bar hides, flags go
##      gold), awards its 40 xp, and the door now advances the stage
## Run: godot --headless --path <project> --script res://tools/boss_test.gd

var _frame := 0
var _stage
var _player
var _boss_room
var _boss
var _failures: Array[String] = []


func _initialize() -> void:
	var scene: PackedScene = load("res://level/stage.tscn")
	root.add_child(scene.instantiate())
	_stage = root.get_node("Stage")


func _physics_process(_delta: float) -> bool:
	_frame += 1
	# stage._ready() runs after _initialize — resolve lazily
	if _player == null:
		_player = _stage.player
	if _boss_room == null:
		for room in _stage._rooms:
			if room.role == 4:
				_boss_room = room
				_boss = room.boss

	match _frame:
		# --- A: boss presence + sealed door
		4:
			_check(_boss_room != null, "found the boss room", "")
			_check(_boss != null, "boss spawned into the room", "")
			_check(_boss_room.enemies.has(_boss), "boss counts as a room enemy", "")
			# step in: the fight locks the player in, bar shows
			_player.global_position = _boss_room.bounds.get_center()
		8:
			_check(_boss_room.locked, "entering the boss room locks it", "")
			_check(_stage._boss_bar.visible, "boss bar shows during the fight", "")
			_stage._on_boss_door_entered(null, _boss_room)
		12:
			_check(_stage.stage_index == 0, "door denies advance while the boss lives", "")
		# --- B: enrage at half hp
		14:
			_check(_boss.move_speed == 16.0, "phase 1 speed baseline", "speed=%.1f" % _boss.move_speed)
			_check(_boss.attack_state == &"Attack", "phase 1 is melee", "state=%s" % _boss.attack_state)
			_boss.health.take_hit({&"damage": 61, &"poise_damage": 0.0,
				&"knockback": Vector2.ZERO, &"attacker": _player})
		18:
			_check(_boss.health.hp == 59, "boss took the 61 hit (120->59)", "hp=%d" % _boss.health.hp)
			_check(_boss.move_speed > 16.0, "enrage: faster", "speed=%.1f" % _boss.move_speed)
			_check(_boss.visual.modulate != Color.WHITE, "enrage: red tint", "")
			_boss.emit_state(&"Chase")
			_check(_boss.attack_state == &"RangedAttack", "enrage alternates: volley next", "state=%s" % _boss.attack_state)
			_boss.emit_state(&"Chase")
			_check(_boss.attack_state == &"Attack", "enrage alternates: melee next", "state=%s" % _boss.attack_state)
		# --- C: kill -> cleared, xp, open door
		30: # well past the 0.15s hit grace from f14 (hitstop stretches ticks)
			_boss.health.take_hit({&"damage": 999, &"poise_damage": 0.0,
				&"knockback": Vector2.ZERO, &"attacker": _player})
		34:
			_check(_boss_room.cleared, "boss kill clears the room", "")
			_check(not _stage._boss_bar.visible, "boss bar hides on clear", "")
			_check(_boss_room.boss_flags.is_empty() or _boss_room.boss_flags[0].color == Color("ffd54a"),
				"door flag turns gold", "")
			_check(root.get_node("RunManager").level == 3, "boss xp 40 levels 1->3 (15/25)", "level=%d" % root.get_node("RunManager").level)
			_stage._on_boss_door_entered(null, _boss_room)
		40:
			_check(_stage.stage_index == 1, "cleared door advances the stage", "stage_index=%d" % _stage.stage_index)
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
		print("BOSS TEST: all checks passed")
	else:
		printerr("BOSS TEST: %d check(s) failed" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
