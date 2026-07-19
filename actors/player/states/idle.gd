extends "res://actors/player/state_machine/state.gd"
## Idle — grounded, no input. Decelerates to a stop.


func enter() -> void:
	tint("#eceff1")


func physics_update(delta: float) -> void:
	player.steer(0.0, player.ground_accel, player.ground_decel, delta)
	player.apply_gravity(delta)

	if player.try_ground_jump():
		machine.change_state(&"Jump")
	elif not player.is_on_floor():
		machine.change_state(&"Fall")
	elif Input.is_action_just_pressed(&"attack"):
		player.attack_step_index = 0
		machine.change_state(&"Attack")
	elif Input.is_action_just_pressed(&"roll"):
		machine.change_state(&"Roll")
	elif player.horizontal_input() != 0.0:
		machine.change_state(&"Run")
