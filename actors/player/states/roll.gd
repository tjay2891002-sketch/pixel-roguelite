extends "res://actors/player/state_machine/state.gd"
## Roll — fixed-speed dodge in the facing direction with i-frames.
## No gravity during the roll (Dead Cells-style float over gaps).
## The last roll_cancel_window seconds can cancel into movement or jump.

var _timer := 0.0


func enter() -> void:
	tint("#ce93d8")
	_timer = player.roll_duration
	player.invulnerable = true
	# Combat i-frames outlast the roll by roll_iframe_tail (covered by
	# Hurtbox/has_iframes); the hurtbox hides IMMEDIATELY — syncing it in
	# Hurtbox._process lags a frame and a fast swipe would still connect.
	player.iframes_until_msec = Time.get_ticks_msec() + int((player.roll_duration + player.roll_iframe_tail) * 1000.0)
	player.get_node("Hurtbox").monitoring = false
	player.velocity.x = player.facing * player.roll_speed
	player.velocity.y = 0.0


func exit() -> void:
	player.invulnerable = false
	# The hurtbox stays hidden until iframes_until_msec passes (the tail);
	# Hurtbox._process restores monitoring then.


func physics_update(delta: float) -> void:
	_timer -= delta
	player.velocity.x = player.facing * player.roll_speed
	player.velocity.y = 0.0

	if _timer <= player.roll_cancel_window:
		var input_x = player.horizontal_input()
		if input_x != 0.0:
			player.velocity.x = input_x * player.move_speed
			player.set_facing(int(signf(input_x)))
		if player.try_ground_jump() or player.try_air_jump():
			machine.change_state(&"Jump")
			return

	if _timer <= 0.0:
		if player.is_on_floor():
			machine.change_state(&"Run" if player.horizontal_input() != 0.0 else &"Idle")
		else:
			machine.change_state(&"Fall")
