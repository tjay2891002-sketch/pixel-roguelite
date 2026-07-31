extends SceneTree
## Headless weapon-pool test:
##   A) only the starter sword unlocked -> a weapon drop roll falls back to cells
##   B) unlocking dagger+axe puts them into the drop pool
##   C) shop weapon offer: interact buys -> unlocks (meta) + equips + charges
##   D) new weapon anims are registered (spear/greatsword/hammer)
##   E) the shop-bought spear swings for its real damage (7)
## Run: godot --headless --path <project> --script res://tools/weapon_pool_test.gd

const Drops := preload("res://level/drops.gd")
const SPEAR := preload("res://data/weapons/spear.tres")

var _frame := 0
var _player
var _dummy
var _save
var _stand
var _failures: Array[String] = []


func _initialize() -> void:
	Drops.auto_drops_enabled = false
	_save = root.get_node("SaveStub")
	var scene: PackedScene = load("res://level/playground.tscn")
	root.add_child(scene.instantiate())
	_player = root.get_node("Playground/Player")
	# NOTE: the dummy spawns in playground._ready, which hasn't run yet here
	# (combat_test documents this) — resolved lazily in phase E instead.


func _physics_process(_delta: float) -> bool:
	_frame += 1
	match _frame:
		# --- A: locked pool -> cells fallback
		2:
			_save.data["unlocked_weapons"] = [&"sword"]
			Drops.spawn(root.get_node("Playground"), &"weapon", Vector2(60, 120))
		5:
			var fell_back := true
			for child in root.get_node("Playground").get_children():
				if child is Area2D and child.get("kind") == &"weapon":
					fell_back = false
			_check(fell_back, "nothing unlocked to drop -> no weapon pickup (cells fallback)", "")
		# --- B: unlocked weapons enter the pool
		7:
			_save.data["unlocked_weapons"] = [&"sword", &"dagger", &"axe"]
			Drops.spawn(root.get_node("Playground"), &"weapon", Vector2(90, 120))
		10:
			var rolled: StringName = &""
			for child in root.get_node("Playground").get_children():
				if child is Area2D and child.get("kind") == &"weapon":
					rolled = (child.payload as WeaponData).id
			_check(rolled in [&"dagger", &"axe"], "unlocked weapon drops (not the held sword)", "rolled=%s" % rolled)
		# --- D: new weapon anims registered
		12:
			for clip in [&"spear_1", &"spear_2", &"spear_3", &"greatsword_1", &"greatsword_2", &"greatsword_3", &"hammer_1"]:
				_check(_player.anim_player.has_animation(clip), "anim exists: %s" % clip, "")
		# --- C: shop unlock purchase
		14:
			_save.data["currency"] = 30
			var stand_scene: PackedScene = load("res://level/shop_stand.tscn") # runtime: autoload ids inside
			_stand = stand_scene.instantiate()
			_stand.offer = &"weapon"
			_stand.cost = 20
			_stand.weapon = SPEAR
			root.get_node("Playground").add_child(_stand)
			_stand.global_position = _player.global_position
		18:
			_tap(&"interact")
		23:
			_check(_save.is_weapon_unlocked(&"spear"), "shop buy unlocks the spear (meta)", "")
			_check(_player.weapon.id == &"spear", "shop buy equips the spear", "weapon=%s" % _player.weapon.id)
			_check(int(_save.data["currency"]) == 10, "shop charges 20 of 30 cells", "cells=%d" % int(_save.data["currency"]))
			_check(not is_instance_valid(_stand), "stand is consumed", "")
		# --- E: the bought spear swings for real
		25:
			_dummy = root.get_node("Playground/Dummy")
			_teleport(Vector2(_dummy.global_position.x - 20.0, 139))
			_player.set_facing(1)
			_tap(&"attack")
		40:
			_check(_dummy.health.hp == 33, "spear step 1 deals 7 (40->33)", "hp=%d" % _dummy.health.hp)
			_finish()
	return false


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
		print("WEAPON POOL TEST: all checks passed")
	else:
		printerr("WEAPON POOL TEST: %d check(s) failed" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
