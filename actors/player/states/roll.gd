extends "res://actors/player/state_machine/state.gd"
## Roll (dash) — fixed-speed dodge in the facing direction with i-frames.
## No gravity during the roll (Dead Cells-style float over gaps).
## The last roll_cancel_window seconds can cancel into movement or jump.
## Visual: a forward lean into the dash (not a tumble — reads as a lunge).

const SFX := preload("res://fx/sfx_builder.gd")

const LEAN := 0.4 # radians (~23°) of forward tilt during the dash

var _timer := 0.0


func enter() -> void:
	tint("#ce93d8")
	AudioBus.play_sfx(SFX.roll(), player.global_position)
	_timer = player.roll_duration
	player.invulnerable = true
	# Combat i-frames outlast the roll by roll_iframe_tail (covered by
	# Hurtbox/has_iframes); the hurtbox hides IMMEDIATELY — syncing it in
	# Hurtbox._process lags a frame and a fast swipe would still connect.
	player.iframes_left = player.roll_duration + player.roll_iframe_tail
	player.get_node("Hurtbox").monitoring = false
	player.velocity.x = player.facing * player.roll_speed
	player.velocity.y = 0.0
	player.visual.rotation = player.facing * LEAN
	player.visual.play(&"run", 1.5)


func exit() -> void:
	player.invulnerable = false
	player.visual.rotation = 0.0
	# The hurtbox stays hidden until iframes_left runs out (the tail);
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
