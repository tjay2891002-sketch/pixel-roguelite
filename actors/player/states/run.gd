extends "res://actors/player/state_machine/state.gd"
## Run — grounded with horizontal input.


func enter() -> void:
	tint("#90caf9")


func physics_update(delta: float) -> void:
	var input_x = player.horizontal_input()
	player.steer(input_x, player.ground_accel, player.ground_decel, delta)
	player.apply_gravity(delta)

	if player.try_ground_jump():
		machine.change_state(&"Jump")
	elif not player.is_on_floor():
		machine.change_state(&"Fall")
	elif Input.is_action_just_pressed(&"roll"):
		machine.change_state(&"Roll")
	elif input_x == 0.0 and absf(player.velocity.x) < 5.0:
		machine.change_state(&"Idle")
