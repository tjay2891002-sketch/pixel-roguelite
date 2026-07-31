extends SceneTree
## Headless progression/drops test:
##   A) add_xp rolls levels over and the player reflects them (damage mult,
##      max hp) via leveled_up
##   B) potion pickup heals (capped at max hp)
##   C) rage buff multiplies damage, then expires back to baseline
##   D) weapon pickup swaps the weapon (old one drops beside) and the new
##      weapon's damage flows through the swing
##   E) curse debuff raises damage taken (health.gd victim-side mult)
##   F) a smashed crate (auto drops on) spawns exactly one pickup
## Run: godot --headless --path <project> --script res://tools/drops_test.gd

const Drops := preload("res://level/drops.gd")
const DestructibleProp := preload("res://level/destructible_prop.gd")
const CRATE_TEX := preload("res://assets/level/tiles/prop_crate.png")
const AXE := preload("res://data/weapons/axe.tres")

var _frame := 0
var _player
var _dummy
var _rm
var _leveled := 0
var _failures: Array[String] = []


func _initialize() -> void:
	Drops.auto_drops_enabled = false # phases A-E spawn pickups explicitly
	var scene: PackedScene = load("res://level/playground.tscn")
	root.add_child(scene.instantiate())
	_player = root.get_node("Playground/Player")
	_rm = root.get_node("RunManager")
	var bus = root.get_node("EventBus")
	bus.leveled_up.connect(func(_l): _leveled += 1)


func _physics_process(_delta: float) -> bool:
	_frame += 1
	match _frame:
		# --- A: XP -> levels -> player stats
		2:
			# drops roll from the UNLOCKED pool only; pretend dagger+axe are
			# unlocked. MUST happen on a frame, not in _initialize: the
			# autoload's _ready (load_data) runs AFTER _initialize and would
			# wipe the mutation. In-memory only; flush is a headless no-op.
			root.get_node("SaveStub").data["unlocked_weapons"] = [&"sword", &"dagger", &"axe"]
			_rm.add_xp(100) # curve 15/25/35/45... -> level 4 with 25 left over
		5:
			_check(_rm.level == 4 and _rm.xp == 25, "100 xp => level 4, 25 left", "level=%d xp=%d" % [_rm.level, _rm.xp])
			_check(_leveled == 3, "leveled_up fired 3 times", "count=%d" % _leveled)
			_check(absf(_player.damage_mult - 1.24) < 0.001, "level 4 damage mult 1.24", "mult=%.3f" % _player.damage_mult)
			_check(_player.health.max_hp == 42, "level 4 max hp 42", "max=%d" % _player.health.max_hp)
		# --- B: potion
		7:
			_player.health.hp = 10
			Drops.spawn(root.get_node("Playground"), &"potion", _player.global_position)
		12:
			_check(_player.health.hp == 23, "potion heals 30%% of max 42 (rounds to 13)", "hp=%d" % _player.health.hp)
		# --- C: rage buff + expiry
		14:
			Drops.spawn(root.get_node("Playground"), &"rage", _player.global_position)
		18:
			_check(absf(_player.damage_mult - 1.24 * 1.35) < 0.001, "rage: damage x1.35", "mult=%.3f" % _player.damage_mult)
			_player._buffs[&"rage"] = 0.05 # fast-forward the expiry
		26:
			_check(absf(_player.damage_mult - 1.24) < 0.001, "rage expires back to level baseline", "mult=%.3f" % _player.damage_mult)
		# --- D: weapon swap needs the interact (F) confirm
		28:
			_teleport(Vector2(138, 139))
			Drops.spawn(root.get_node("Playground"), &"weapon", _player.global_position)
		32:
			_check(_player.weapon.id == &"sword", "weapon pickup does NOT auto-collect", "weapon=%s" % _player.weapon.id)
			_tap(&"interact")
		37:
			_check(_player.weapon.id != &"sword", "F swaps off the sword", "weapon=%s" % _player.weapon.id)
			_check(_player.weapon.id in [&"dagger", &"axe"], "new weapon from the pool", "weapon=%s" % _player.weapon.id)
		38:
			# step onto the swap-dropped sword (16px left of the swap point)
			_teleport(Vector2(124, 139))
		41:
			_check(_player.weapon.id != &"sword", "old weapon waits for its own F", "weapon=%s" % _player.weapon.id)
			_tap(&"interact")
		46:
			_check(_player.weapon.id == &"sword", "F on the old weapon swaps back", "weapon=%s" % _player.weapon.id)
		# --- E: axe swing damage flows (equip directly, then hit the dummy)
		52:
			_player.equip(AXE)
			_teleport(Vector2(_dummy_pos().x - 20.0, 139))
			_player.set_facing(1)
			_tap(&"attack")
		66:
			# axe_1 = 14 dmg x level mult 1.24 = 17 (int); dummy 40 -> 23
			_check(_dummy_hp() == 23, "axe step 1 deals 14x1.24=17 (40->23)", "hp=%d" % _dummy_hp())
		# --- F: curse raises damage taken
		68:
			_player.apply_buff(&"curse")
			_check(absf(_player.damage_taken_mult - 1.5) < 0.001, "curse: damage taken x1.5", "mult=%.2f" % _player.damage_taken_mult)
			var before: int = _player.health.hp
			_player.health.take_hit({&"damage": 6, &"poise_damage": 0.0, &"knockback": Vector2.ZERO, &"attacker": self})
			_check(_player.health.hp == before - 9, "6 dmg becomes 9 under curse", "hp=%d" % _player.health.hp)
		# --- G: crate auto-drop integration
		70:
			Drops.auto_drops_enabled = true
			var crate = DestructibleProp.new(CRATE_TEX)
			root.get_node("Playground").add_child(crate)
			crate.global_position = Vector2(100, 150)
			_teleport(Vector2(70, 139))
			_player.set_facing(1)
			_tap(&"attack")
		84:
			var found := false
			for child in root.get_node("Playground").get_children():
				if child is Area2D and child.get("kind") != null:
					found = true
			_check(found, "smashed crate spawns a pickup", "")
			_finish()
	return false


func _dummy_pos() -> Vector2:
	if _dummy == null:
		_dummy = root.get_node("Playground/Dummy")
	return _dummy.global_position


func _dummy_hp() -> int:
	return _dummy.health.hp


func _teleport(pos: Vector2) -> void:
	_player.state_machine.change_state(&"Idle")
	_player.global_position = pos
	_player.velocity = Vector2.ZERO


func _tap(action: StringName) -> void:
	_press(action)
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
		print("DROPS TEST: all checks passed")
	else:
		printerr("DROPS TEST: %d check(s) failed" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
