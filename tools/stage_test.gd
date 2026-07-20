extends SceneTree
## Headless stage test: room lockdown lifecycle + treasure pickups.
##   A) entering a combat room locks it; leaving unlocks it; re-entering
##      locks again; killing all enemies unlocks permanently (cleared)
##   B) walking into a treasure cell grants currency
## Run: godot --headless --path <project> --script res://tools/stage_test.gd

var _frame := 0
var _stage
var _player
var _combat_room
var _pickup
var _heal_stand
var _dagger_stand
var _had_pickup := false # freed pickups are falsy — capture before collecting
var _had_shop := false   # freed stands are falsy too — capture before buying
var _had_dagger := false
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
	if _pickup == null:
		_pickup = get_first_node_in_group(&"pickup")
	if _heal_stand == null or _dagger_stand == null:
		for node in get_nodes_in_group(&"shop_stand"):
			if node.offer == &"heal":
				_heal_stand = node
			elif node.offer == &"dagger":
				_dagger_stand = node

	match _frame:
		3:
			root.get_node("SaveStub").data.clear() # deterministic currency count
			for room in _stage._rooms:
				if room.role == 1 and not room.enemies.is_empty():
					_combat_room = room
					break
			_check(_combat_room != null, "found a combat room with enemies", "")
			_check(_pickup != null or _heal_stand != null, "found a pickup or shop stand", "")
			_had_pickup = _pickup != null
			_had_shop = _heal_stand != null
			_had_dagger = _dagger_stand != null
			if _combat_room:
				_player.global_position = _combat_room.bounds.get_center()
		15:
			_check(_blockers_enabled(), "room locks on player entry", "")
			# step back out: leaving must unlock the room
			_player.global_position = _combat_room.bounds.position + Vector2(-64, 32)
		25:
			_check(_blockers_disabled(), "leaving the room unlocks it", "")
			_player.global_position = _combat_room.bounds.get_center()
		36:
			_check(_blockers_enabled(), "re-entering locks again", "")
			for enemy in _combat_room.enemies.duplicate():
				enemy.health.take_hit({
					&"damage": 999, &"poise_damage": 0.0,
					&"knockback": Vector2.ZERO, &"attacker": _player})
		46:
			_check(_combat_room.cleared, "room cleared after kills", "")
			_check(_blockers_disabled(), "blockers open after clear", "")
			if _had_pickup:
				_player.global_position = _pickup.global_position
			elif _had_shop:
				# fund the purchase, walk to the heal stand, press up to buy
				root.get_node("SaveStub").data["currency"] = 15
				_player.global_position = _heal_stand.global_position
		50:
			if not _had_pickup and _had_shop:
				_press(&"move_up")
		51:
			if not _had_pickup and _had_shop:
				_release(&"move_up")
		56:
			if _had_pickup:
				_check(int(root.get_node("SaveStub").data.get("currency", 0)) == 5,
					"treasure cell grants 5 currency", "currency=%s" % root.get_node("SaveStub").data.get("currency", -1))
			elif _had_shop:
				_check(int(root.get_node("SaveStub").data.get("currency", -1)) == 5,
					"heal purchase deducts 10 (15->5)", "currency=%s" % root.get_node("SaveStub").data.get("currency", -1))
		57:
			if not _had_pickup and _had_dagger:
				root.get_node("SaveStub").data["currency"] = 20
				_player.global_position = _dagger_stand.global_position
		60:
			if not _had_pickup and _had_dagger:
				_press(&"move_up")
		61:
			if not _had_pickup and _had_dagger:
				_release(&"move_up")
		66:
			if not _had_pickup and _had_dagger:
				_check(_player.weapon.id == &"dagger", "dagger purchase equips the weapon", "weapon=%s" % _player.weapon.id)
				_check(int(root.get_node("SaveStub").data.get("currency", -1)) == 5,
					"dagger purchase deducts 15 (20->5)", "currency=%s" % root.get_node("SaveStub").data.get("currency", -1))
		70:
			# lethal damage -> death screen must appear (RunManager no longer
			# auto-reloads; the stage owns the death flow)
			_player.health.take_hit({
				&"damage": 999, &"poise_damage": 0.0,
				&"knockback": Vector2.ZERO, &"attacker": _player})
		125:
			_check(_stage.get_node("DeathOverlay").visible, "death overlay appears on death", "")
			_finish()
	return false


func _blockers_enabled() -> bool:
	if _combat_room == null or _combat_room.blockers.is_empty():
		return false
	for blocker in _combat_room.blockers:
		if blocker.shape.disabled:
			return false
	return true


func _blockers_disabled() -> bool:
	if _combat_room == null:
		return false
	for blocker in _combat_room.blockers:
		if not blocker.shape.disabled:
			return false
	return true


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
		print("STAGE TEST: all checks passed")
	else:
		printerr("STAGE TEST: %d check(s) failed" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
