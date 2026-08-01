extends SceneTree
## Headless spring test (P2):
##   A) a falling player bounces high off the mushroom spring, with air
##      jumps refreshed and the boing anim playing
##   B) a player RISING through it is not re-bounced
## Run: godot --headless --path <project> --script res://tools/spring_test.gd

const Spring := preload("res://level/spring.gd")

var _frame := 0
var _player
var _spring
var _bounced := false
var _failures: Array[String] = []


func _initialize() -> void:
	var scene: PackedScene = load("res://level/playground.tscn")
	root.add_child(scene.instantiate())
	_player = root.get_node("Playground/Player")
	_spring = Spring.new()
	root.get_node("Playground").add_child(_spring)
	_spring.global_position = Vector2(170, 150) # floor top on the first strip


func _physics_process(_delta: float) -> bool:
	_frame += 1
	if _player != null and _player.velocity.y < -400.0:
		_bounced = true
	match _frame:
		3:
			# drop the player onto the spring cap
			_player.global_position = Vector2(170, 110)
			_player.velocity = Vector2.ZERO
		25:
			_check(_bounced, "falling onto the spring bounces hard (vy < -400)", "")
			_check(_player.air_jumps_left == _player.max_air_jumps, "bounce refreshes air jumps", "")
			var anim: StringName = _spring.get_node("Sprite").animation
			_check(anim == &"boing", "boing anim plays on bounce", "anim=%s" % anim)
		26:
			# mid-air rise through the cap: no double-bounce
			_bounced = false
			_player.global_position = Vector2(170, 144)
			_player.velocity = Vector2(0, -200) # rising
		40:
			_check(not _bounced, "rising through the spring does not bounce", "")
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
		print("SPRING TEST: all checks passed")
	else:
		printerr("SPRING TEST: %d check(s) failed" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
