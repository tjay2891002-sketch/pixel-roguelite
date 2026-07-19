extends "res://actors/player/state_machine/state.gd"
## WallCling — capped slide down a wall while pushing into it.
## Jump kicks away from the wall; releasing the direction lets go.


func enter() -> void:
	tint("#ef9a9a")
	player.velocity = Vector2.ZERO


func physics_update(delta: float) -> void:
	# Slight pressure into the wall keeps WallRay colliding.
	player.velocity.x = player.facing * 5.0
	player.velocity.y = minf(player.velocity.y + player.gravity * 0.5 * delta, player.wall_slide_speed)

	if player.jump_buffer_timer > 0.0:
		player.jump_buffer_timer = 0.0
		player.velocity = Vector2(-player.facing * player.wall_jump_velocity.x, -player.wall_jump_velocity.y)
		player.set_facing(-player.facing)
		machine.change_state(&"WallJump")
	elif player.can_ledge_grab():
		# Clinging just below a ledge (or rising onto one) offers the mantle.
		machine.change_state(&"LedgeClimb")
	elif player.is_on_floor():
		machine.change_state(&"Idle")
	elif not player.touching_wall() or not player.pushing_toward_wall():
		machine.change_state(&"Fall")
