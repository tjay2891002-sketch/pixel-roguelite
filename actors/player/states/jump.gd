extends "res://actors/player/state_machine/state.gd"
## Jump — ascending. The jump impulse is applied by the player's
## try_ground_jump()/try_air_jump() BEFORE the transition into this state;
## enter() only handles presentation.

const SFX := preload("res://fx/sfx_builder.gd")


func enter() -> void:
	tint("#a5d6a7")
	AudioBus.play_sfx(SFX.jump(), player.global_position)


func handle_input(event: InputEvent) -> void:
	if event.is_action_released(&"jump"):
		player.cut_jump()


func physics_update(delta: float) -> void:
	var input_x = player.horizontal_input()
	player.steer(input_x, player.air_accel, player.air_decel, delta)
	player.apply_gravity(delta)

	if player.try_air_jump():
		pass # double jump: impulse applied, stay in Jump
	elif Input.is_action_just_pressed(&"attack"):
		player.attack_step_index = player.begin_attack_index()
		machine.change_state(&"Attack")
	elif Input.is_action_just_pressed(&"roll"):
		machine.change_state(&"Roll")
	elif player.can_ledge_grab():
		machine.change_state(&"LedgeClimb")
	elif player.touching_wall() and player.pushing_toward_wall():
		machine.change_state(&"WallCling")
	elif player.velocity.y >= 0.0:
		machine.change_state(&"Fall")
