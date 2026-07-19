extends "res://actors/player/state_machine/state.gd"
## Attack — one state, parameterized by AttackStep data (docs/ARCHITECTURE.md
## §2: this is how we avoid state explosion). Reads the current step from
## player.attack_step_index, drives the AnimationPlayer, chains on buffered
## input near the end of the swing, roll-cancels near the end too.
## Hitbox on/off + lunge come from the clip's Call Method tracks.

var _t := 0.0
var _duration := 0.0
var _step: AttackStep
var _chain_buffered := false


func enter() -> void:
	tint("#f48fb1")
	_step = player.weapon.steps[player.attack_step_index]
	_t = 0.0
	_chain_buffered = false
	_configure_hitbox()
	player.anim_player.play(_step.animation)
	# Force the first evaluation NOW: without this, a freshly played clip's
	# Call Method track can be skipped on its first frame (the first swing
	# of a chain then never opens its hitbox).
	player.anim_player.advance(0.0)
	_duration = player.anim_player.get_animation(_step.animation).length
	if player.is_on_floor():
		player.velocity.x = 0.0


func exit() -> void:
	player.hitbox_deactivate()
	player.anim_player.stop()
	player.get_node("SlashArc").visible = false


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attack"):
		_chain_buffered = true


func physics_update(delta: float) -> void:
	_t += delta
	# NOTE: chain buffering is event-driven (handle_input), NOT polled here —
	# is_action_just_pressed stays true across every physics tick within one
	# frame iteration, which self-chained through the whole combo in one tap.
	if player.is_on_floor():
		player.velocity.x = move_toward(player.velocity.x, 0.0, player.ground_decel * delta)
	else:
		player.apply_gravity(delta)

	if Input.is_action_just_pressed(&"roll") and _t >= _duration - _step.roll_cancel_start:
		player.attack_step_index = 0
		machine.change_state(&"Roll")
		return

	if _chain_buffered and _t >= _duration - _step.chain_window_start:
		var next_index: int = player.attack_step_index + 1
		if next_index < player.weapon.steps.size():
			player.attack_step_index = next_index
			# Dead Cells-style: holding a direction turns the next swing.
			var input_x = player.horizontal_input()
			if input_x != 0.0:
				player.set_facing(int(signf(input_x)))
			machine.restart() # re-enter Attack with the new step (same-state
			                  # change_state would no-op and never reset _t)
		else:
			player.attack_step_index = 0
			machine.change_state(&"Run" if player.horizontal_input() != 0.0 else &"Idle")
		return

	if _t >= _duration:
		player.attack_step_index = 0
		if player.is_on_floor():
			machine.change_state(&"Run" if player.horizontal_input() != 0.0 else &"Idle")
		else:
			machine.change_state(&"Fall")


func _configure_hitbox() -> void:
	player.hitbox_shape.shape.size = _step.hitbox_size
	player.hitbox.position = Vector2(_step.hitbox_offset.x * player.facing, _step.hitbox_offset.y)
	player.current_lunge = _step.lunge
	player.current_hit_info = {
		&"damage": _step.damage,
		&"poise_damage": _step.poise_damage,
		&"knockback": Vector2(_step.knockback.x * player.facing, _step.knockback.y),
		&"attacker": player,
	}
