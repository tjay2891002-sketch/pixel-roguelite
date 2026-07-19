extends "res://actors/player/state_machine/state.gd"
## Fall — descending, with extra gravity for weight. Coyote jumps and
## air jumps are both legal here.


func enter() -> void:
	tint("#ffcc80")


func physics_update(delta: float) -> void:
	var input_x = player.horizontal_input()
	player.steer(input_x, player.air_accel, player.air_decel, delta)
	player.apply_gravity(delta, player.fall_gravity_multiplier)

	if player.try_ground_jump():
		machine.change_state(&"Jump") # coyote-time jump
	elif player.try_air_jump():
		machine.change_state(&"Jump") # double jump
	elif Input.is_action_just_pressed(&"roll"):
		machine.change_state(&"Roll")
	elif player.can_ledge_grab():
		machine.change_state(&"LedgeClimb")
	elif player.touching_wall() and player.pushing_toward_wall():
		machine.change_state(&"WallCling")
	elif player.is_on_floor():
		machine.change_state(&"Run" if input_x != 0.0 else &"Idle")
