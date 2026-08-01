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
		# --- boss pool smoke: the other two bosses build and are wired
		2:
			var witch = load("res://actors/enemies/witch_boss.tscn").instantiate()
			var redcap = load("res://actors/enemies/redcap_boss.tscn").instantiate()
			_stage.add_child(witch)
			_stage.add_child(redcap)
			witch.global_position = Vector2(-600, -200)
			redcap.global_position = Vector2(-700, -200)
		3:
			var witch = _stage.get_node("WitchBoss")
			var redcap = _stage.get_node("RedcapBoss")
			_check(witch.get_node("Brain").bar_name == "HEXCASTER", "witch boss: bar name", "")
			_check(witch.attack_state == &"RangedAttack" and witch.volley_count == 3,
				"witch boss: ranged from phase 1, 3-ball", "")
			_check(witch.get_node("Brain").enrage_volley_count == 5, "witch enrage: 5-ball", "")
			_check(witch.visual.sprite_frames != null, "witch anims built", "")
			_check(redcap.get_node("Brain").bar_name == "STREET STRAY", "redcap boss: bar name", "")
			_check(not redcap.get_node("Brain").enrage_alternate, "redcap enrage: pure melee", "")
			_check(redcap.visual.sprite_frames != null, "redcap anims built", "")
			witch.queue_free()
			redcap.queue_free()
		# --- A: boss presence + sealed door + bar follows lock state
		4:
			_check(_boss_room != null, "found the boss room", "")
			_check(_boss != null, "boss spawned into the room", "")
			_check(_boss_room.enemies.has(_boss), "boss counts as a room enemy", "")
			# step in: the fight locks the player in, bar shows
			_player.global_position = _boss_room.bounds.get_center()
		8:
			_check(_boss_room.locked, "entering the boss room locks it", "")
			_check(_stage._boss_bar.visible, "boss bar shows during the fight", "")
			_check(_stage._boss_name.text == "GATEKEEPER", "bar names the stage-1 boss", "name=%s" % _stage._boss_name.text)
			_stage._on_boss_door_entered(null, _boss_room)
		11:
			_check(_stage.stage_index == 0, "door denies advance while the boss lives", "")
			# step OUT mid-fight: the room unlocks and the bar must hide
			# (regression: it stayed on, even into the next stage)
			_player.global_position = _boss_room.bounds.position + Vector2(-64, 32)
		15:
			_check(not _boss_room.locked, "stepping out unlocks the fight", "")
			_check(not _stage._boss_bar.visible, "bar hides when the fight disengages", "")
			# back in: re-locks, bar returns
			_player.global_position = _boss_room.bounds.get_center()
		19:
			_check(_boss_room.locked, "re-entering re-locks", "")
			_check(_stage._boss_bar.visible, "bar returns on re-lock", "")
		# --- B: enrage at half hp
		21:
			_check(_boss.move_speed == 16.0, "phase 1 speed baseline", "speed=%.1f" % _boss.move_speed)
			_check(_boss.attack_state == &"Attack", "phase 1 is melee", "state=%s" % _boss.attack_state)
			_check(_boss.aim_mode == &"shot" and _boss.volley_count == 3,
				"boss volley config: aim line + 3-ball spread", "")
			_boss.health.take_hit({&"damage": 61, &"poise_damage": 0.0,
				&"knockback": Vector2.ZERO, &"attacker": _player})
		25:
			_check(_boss.health.hp == 59, "boss took the 61 hit (120->59)", "hp=%d" % _boss.health.hp)
			_check(_boss.move_speed > 16.0, "enrage: faster", "speed=%.1f" % _boss.move_speed)
			_check(_boss.visual.modulate != Color.WHITE, "enrage: red tint", "")
			_boss.emit_state(&"Chase")
			_check(_boss.attack_state == &"RangedAttack", "enrage alternates: volley next", "state=%s" % _boss.attack_state)
			_boss.emit_state(&"Chase")
			_check(_boss.attack_state == &"Attack", "enrage alternates: melee next", "state=%s" % _boss.attack_state)
		# --- C: kill -> cleared, xp, open door
		37: # well past the 0.15s hit grace from f21 (hitstop stretches ticks)
			_boss.health.take_hit({&"damage": 999, &"poise_damage": 0.0,
				&"knockback": Vector2.ZERO, &"attacker": _player})
		41:
			_check(_boss_room.cleared, "boss kill clears the room", "")
			_check(not _stage._boss_bar.visible, "boss bar hides on clear", "")
			_check(_boss_room.boss_flags.is_empty() or _boss_room.boss_flags[0].color == Color("ffd54a"),
				"door flag turns gold", "")
			_check(root.get_node("RunManager").level == 3, "boss xp 40 levels 1->3 (15/25)", "level=%d" % root.get_node("RunManager").level)
			var pickups := 0
			for child in _stage.get_children():
				if child is Area2D and child.get("kind") != null:
					pickups += 1
			_check(pickups >= 3, "boss drops a reward burst (weapon+potion+cells)", "pickups=%d" % pickups)
			_stage._on_boss_door_entered(null, _boss_room)
		47:
			_check(_stage.stage_index == 1, "cleared door advances the stage", "stage_index=%d" % _stage.stage_index)
			_check(not _stage._boss_bar.visible, "bar stays hidden on the next stage", "")
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
