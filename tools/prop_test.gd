extends SceneTree
## Headless prop test (destructible crates/barrels):
##   A) an intact crate is SOLID to the player (walk into it -> blocked)
##   B) rolling through the crate breaks it and the player passes through
##      (roll starts from CONTACT — no body_entered event, the poll must fire)
##   C) a sword swing breaks a crate; the blast damages a nearby enemy,
##      and the prop's destruction emits NO enemy_killed (that signal drives
##      combat-room door locks — a smash must never touch it)
## Run: godot --headless --path <project> --script res://tools/prop_test.gd

const DestructibleProp := preload("res://level/destructible_prop.gd")
const CRATE_TEX := preload("res://assets/level/tiles/prop_crate.png")

var _frame := 0
var _player
var _dummy
var _crate_a
var _crate_b
var _killed_count := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var scene: PackedScene = load("res://level/playground.tscn")
	root.add_child(scene.instantiate())
	_player = root.get_node("Playground/Player")
	var bus = root.get_node("EventBus")
	bus.enemy_killed.connect(func(_e): _killed_count += 1)
	# crate A on the first floor strip (floor top y=150, spans x=-40..200)
	_crate_a = DestructibleProp.new(CRATE_TEX)
	root.get_node("Playground").add_child(_crate_a)
	_crate_a.global_position = Vector2(165, 150)


func _physics_process(_delta: float) -> bool:
	_frame += 1
	match _frame:
		# --- A: crate blocks
		2:
			# park the dummy clear of crate A's blast AND the roll path
			_dummy = root.get_node("Playground/Dummy")
			_dummy.global_position = Vector2(60, 139)
			_dummy.velocity = Vector2.ZERO
			_teleport(Vector2(130, 139))
			_player.set_facing(1)
			_press(&"move_right") # held: walk straight into the crate
		30:
			_check(_player.global_position.x < 145.0, "intact crate blocks the player", "x=%.1f" % _player.global_position.x)
			_release(&"move_right")
			_tap(&"roll") # roll through, starting from contact
		# --- B: roll-break + pass-through
		45:
			_check(_crate_a.broken, "roll-through breaks the crate", "")
			_check(_player.global_position.x > 150.0, "player passes through the wreck", "x=%.1f" % _player.global_position.x)
			_check(_dummy.health.hp == 40, "crate A blast spares the out-of-range dummy", "hp=%d" % _dummy.health.hp)
		# --- C: swing-break + enemy blast
		47:
			_dummy.global_position = Vector2(118, 139)
			_dummy.velocity = Vector2.ZERO
			_crate_b = DestructibleProp.new(CRATE_TEX)
			root.get_node("Playground").add_child(_crate_b)
			_crate_b.global_position = Vector2(100, 150)
			_teleport(Vector2(70, 139))
			_player.set_facing(1)
		50:
			_tap(&"attack")
		64:
			_check(_crate_b.broken, "sword swing breaks the crate", "")
			_check(_dummy.health.hp == 28, "blast deals 12 to the dummy (40->28)", "hp=%d" % _dummy.health.hp)
			_check(_killed_count == 0, "prop break emits no enemy_killed", "count=%d" % _killed_count)
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
		print("PROP TEST: all checks passed")
	else:
		printerr("PROP TEST: %d check(s) failed" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
