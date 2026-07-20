extends SceneTree
## Headless enemy-variety test (M4):
##   spitter: detects, telegraphs, fires a projectile that damages the player
##   flyer:   reaches Hover -> Telegraph -> Swoop
##   heavy:   one full sword chain does NOT stagger it (poise 80), and its
##            knockback is reduced by knockback_resist
## Run: godot --headless --path <project> --script res://tools/enemy_test.gd
##
## NOTE: scenes are load()ed at runtime, NOT preloaded — const preloads
## compile scene scripts before autoloads register, which breaks any script
## referencing an autoload by name (e.g. health.gd -> EventBus).

var _frame := 0
var _player
var _spitter
var _flyer
var _heavy
var _projectile
var _saw_hover := false
var _saw_flyer_telegraph := false
var _saw_swoop := false
var _saw_flyer_aim := false
var _failures: Array[String] = []


func _initialize() -> void:
	var arena := Node2D.new()
	arena.name = "Arena"
	root.add_child(arena)

	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	floor_body.position = Vector2(250, 175)
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(700, 50)
	floor_shape.shape = rect
	floor_body.add_child(floor_shape)
	arena.add_child(floor_body)

	_player = load("res://actors/player/player.tscn").instantiate()
	arena.add_child(_player)
	_player.global_position = Vector2(100, 139)

	_spitter = load("res://actors/enemies/spitter.tscn").instantiate()
	arena.add_child(_spitter)
	_spitter.global_position = Vector2(160, 139)


func _physics_process(_delta: float) -> bool:
	_frame += 1

	# track projectile + flyer states
	if _projectile == null:
		_projectile = _find_projectile()
	if _flyer != null:
		var fs: StringName = _flyer.state_machine.current.name
		if fs == &"Hover": _saw_hover = true
		if fs == &"Telegraph":
			_saw_flyer_telegraph = true
			if _flyer.get_node("AimLine").visible:
				_saw_flyer_aim = true
		if fs == &"Swoop": _saw_swoop = true

	match _frame:
		12:
			_check(_spitter.state_machine.current.name == &"Telegraph",
				"spitter telegraphs when player in range", "state=%s" % _spitter.state_machine.current.name)
			_check(_spitter.get_node("AimLine").visible, "spitter shows aim line during telegraph", "")
		50:
			_check(_projectile != null, "spitter fires a projectile", "")
			if _projectile:
				_check(_projectile.velocity.x < 0.0, "projectile travels toward the player", "vx=%s" % _projectile.velocity.x)
		90:
			_check(_player.health.hp == 25, "projectile hits for 5 (30->25)", "hp=%d" % _player.health.hp)
		92:
			# re-seat the player: the projectile's knockback moved them, and
			# the flyer's detection must not hinge on that drift
			_player.global_position = Vector2(120, 139)
			_player.velocity = Vector2.ZERO
			_flyer = load("res://actors/enemies/flyer.tscn").instantiate()
			root.get_node("Arena").add_child(_flyer)
			_flyer.global_position = Vector2(150, 100)
		150:
			_check(_saw_hover, "flyer hovers toward the player", "")
			_check(_saw_flyer_telegraph, "flyer telegraphs", "")
			_check(_saw_flyer_aim, "flyer shows swoop path preview during telegraph", "")
			_check(_saw_swoop, "flyer swoops", "")
		152:
			# poise-break the flyer: it must return to Hover, not stick in Stagger
			_flyer.health.take_hit({
				&"damage": 1, &"poise_damage": 12.0,
				&"knockback": Vector2.ZERO, &"attacker": _player})
		154:
			_check(_flyer.state_machine.current.name == &"Stagger", "flyer staggers on poise break", "state=%s" % _flyer.state_machine.current.name)
		200:
			_check(_flyer.state_machine.current.name == &"Hover", "flyer returns to Hover after stagger", "state=%s" % _flyer.state_machine.current.name)
		202:
			_heavy = load("res://actors/enemies/heavy.tscn").instantiate()
			root.get_node("Arena").add_child(_heavy)
			_heavy.global_position = Vector2(200, 139)
		205:
			_hit_heavy(8, 8.0)
		206:
			_check(_heavy.velocity.x < 20.0 and _heavy.velocity.x > 0.0,
				"heavy knockback reduced by resist", "vx=%.1f (normal would be ~53)" % _heavy.velocity.x)
		216:
			_hit_heavy(9, 8.0)
		227:
			_hit_heavy(12, 14.0)
		235:
			_check(_heavy.health.hp == 31, "heavy takes chain damage (60->31)", "hp=%d" % _heavy.health.hp)
			_check(_heavy.state_machine.current.name != &"Stagger",
				"one chain does NOT stagger the heavy (poise 80)", "state=%s" % _heavy.state_machine.current.name)
			_finish()
	return false


func _hit_heavy(damage: int, poise: float) -> void:
	_heavy.health.take_hit({
		&"damage": damage, &"poise_damage": poise,
		&"knockback": Vector2(60, -20), &"attacker": _player})


func _find_projectile():
	for child in root.get_node("Arena").get_children():
		if child.name == "Projectile":
			return child
	return null


func _check(condition: bool, what: String, detail := "") -> void:
	if condition:
		print("PASS: %s" % what)
	else:
		var message := "FAIL: %s (%s) [frame %d]" % [what, detail, _frame]
		_failures.append(message)
		printerr(message)


func _finish() -> void:
	if _failures.is_empty():
		print("ENEMY TEST: all checks passed")
	else:
		printerr("ENEMY TEST: %d check(s) failed" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
