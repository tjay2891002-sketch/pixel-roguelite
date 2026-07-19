extends "res://actors/player/state_machine/state.gd"
## WallJump — push-off arc away from the wall. Air control is damped during
## the lockout so the push-off reads; after it, behaves like a normal jump
## and can re-cling to a wall (including the same one, once steered back).
##
## NOTE: unlike a normal jump there is NO jump-cut on release — wall kicks
## are fixed height. Cutting them made quick taps gut the climb (playtest
## bug: "can't climb the shaft").

var _lockout := 0.0


func enter() -> void:
	tint("#80deea")
	_lockout = player.wall_jump_lockout


func physics_update(delta: float) -> void:
	_lockout -= delta
	var input_x = player.horizontal_input()
	var accel: float = player.air_accel * (0.15 if _lockout > 0.0 else 1.0)
	player.velocity.x = move_toward(player.velocity.x, input_x * player.move_speed, accel * delta)
	if _lockout <= 0.0 and input_x != 0.0:
		player.set_facing(int(signf(input_x)))
	player.apply_gravity(delta)

	if player.try_air_jump():
		machine.change_state(&"Jump")
	elif player.can_ledge_grab():
		machine.change_state(&"LedgeClimb")
	elif _lockout <= 0.0 and player.touching_wall() and player.pushing_toward_wall():
		machine.change_state(&"WallCling")
	elif player.velocity.y >= 0.0:
		machine.change_state(&"Fall")
