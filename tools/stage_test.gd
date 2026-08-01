extends SceneTree
## Headless stage test: room lockdown lifecycle + treasure pickups.
##   A) entering a combat room locks it; leaving unlocks it; re-entering
##      locks again; killing all enemies unlocks permanently (cleared)
##   B) walking into a treasure coin grants coins
##   C) prop scatter: every prop has solid floor beneath (no floaters over
##      bottom-door pits) and lamps stay within their per-stage cap
## Run: godot --headless --path <project> --script res://tools/stage_test.gd

const LAMP_TEX := preload("res://assets/level/tiles/prop_street-lamp.png")
const PROP_TEXES := [
	preload("res://assets/level/tiles/prop_barrel.png"),
	preload("res://assets/level/tiles/prop_crate.png"),
	preload("res://assets/level/tiles/prop_sign.png"),
	preload("res://assets/level/tiles/prop_street-lamp.png"),
]

var _frame := 0
var _stage
var _player
var _combat_room
var _pickup
var _heal_stand
var _weapon_stand
var _weapon_id := &""
var _had_pickup := false # freed pickups are falsy — capture before collecting
var _had_shop := false   # freed stands are falsy too — capture before buying
var _had_weapon := false
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
	if _heal_stand == null or _weapon_stand == null:
		for node in get_nodes_in_group(&"shop_stand"):
			if node.offer == &"heal":
				_heal_stand = node
			elif node.offer == &"weapon":
				_weapon_stand = node
				_weapon_id = _weapon_stand.weapon.id

	match _frame:
		3:
			root.get_node("SaveStub").data.clear() # deterministic coin count
			for room in _stage._rooms:
				if room.role == 1 and not room.enemies.is_empty():
					_combat_room = room
					break
			_check(_combat_room != null, "found a combat room with enemies", "")
			_check(_pickup != null or _heal_stand != null, "found a pickup or shop stand", "")
			_had_pickup = _pickup != null
			_had_shop = _heal_stand != null
			_had_weapon = _weapon_stand != null
			if _combat_room:
				_player.global_position = _combat_room.bounds.get_center()
		4:
			_check_prop_scatter()
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
				# fund the purchase, walk to the heal stand, press F to buy
				root.get_node("SaveStub").data["coins"] = 15
				_player.global_position = _heal_stand.global_position
		50:
			if not _had_pickup and _had_shop:
				_press(&"interact")
		51:
			if not _had_pickup and _had_shop:
				_release(&"interact")
		56:
			if _had_pickup:
				_check(int(root.get_node("SaveStub").data.get("coins", 0)) == 5,
					"treasure coin grants 5 coins",
					"coins=%s pickup_valid=%s dist=%.1f" % [
						root.get_node("SaveStub").data.get("coins", -1),
						is_instance_valid(_pickup),
						_player.global_position.distance_to(_pickup.global_position) if is_instance_valid(_pickup) else -1.0])
			elif _had_shop:
				_check(int(root.get_node("SaveStub").data.get("coins", -1)) == 5,
					"heal purchase deducts 10 (15->5)",
					"coins=%s in_range=%s dist=%.1f" % [
						root.get_node("SaveStub").data.get("coins", -1),
						_heal_stand._in_range if is_instance_valid(_heal_stand) else "?",
						_player.global_position.distance_to(_heal_stand.global_position) if is_instance_valid(_heal_stand) else -1.0])
		57:
			if not _had_pickup and _had_weapon:
				root.get_node("SaveStub").data["coins"] = _weapon_stand.cost
				_player.global_position = _weapon_stand.global_position
		60:
			if not _had_pickup and _had_weapon:
				_press(&"interact")
		61:
			if not _had_pickup and _had_weapon:
				_release(&"interact")
		66:
			if not _had_pickup and _had_weapon:
				# the offered weapon is the seeded random locked pick
				_check(_player.weapon.id == _weapon_id, "weapon purchase equips the offered weapon",
					"weapon=%s in_range=%s dist=%.1f" % [
						_player.weapon.id,
						_weapon_stand._in_range if is_instance_valid(_weapon_stand) else "?",
						_player.global_position.distance_to(_weapon_stand.global_position) if is_instance_valid(_weapon_stand) else -1.0])
				_check(int(root.get_node("SaveStub").data.get("coins", -1)) == 0,
					"weapon purchase charges its cost", "coins=%s" % root.get_node("SaveStub").data.get("coins", -1))
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


func _check_prop_scatter() -> void:
	var lamps := 0
	var bad_ground := 0
	for child in _stage.get_children():
		var feet = null
		var tex = null
		if child is Sprite2D and PROP_TEXES.has(child.texture):
			tex = child.texture
			# decor sprites are center-anchored; props are foot-anchored
			feet = child.global_position + Vector2(0, tex.get_height() / 2.0)
		elif child is StaticBody2D and child.get("broken") != null:
			feet = child.global_position # DestructibleProp origin = feet
		if feet == null:
			continue
		if tex == LAMP_TEX:
			lamps += 1
		for room in _stage._rooms:
			if room.bounds.has_point(feet):
				var lines: PackedStringArray = room.chunk.map.split("\n", false)
				var cx := int(floorf((feet.x - room.bounds.position.x) / 16.0))
				# walkable surface: first # from the bottom with open space above
				var surface := -1
				for y in range(lines.size() - 1, 0, -1):
					if cx < lines[y].length() and lines[y][cx] == "#" and lines[y - 1][cx] != "#":
						surface = y
						break
				if surface < 0:
					bad_ground += 1 # in a pit column
				else:
					var expect_y: float = room.bounds.position.y + surface * 16.0
					if absf(feet.y - expect_y) > 1.0:
						bad_ground += 1 # buried in a plane or floating
				break
	_check(lamps <= 2, "lamps capped per stage", "lamps=%d" % lamps)
	_check(bad_ground == 0, "every prop sits exactly on a walkable surface", "bad=%d" % bad_ground)


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
