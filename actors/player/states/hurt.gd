extends "res://actors/player/state_machine/state.gd"
## Hurt — entered ONLY on poise break (light hits flash but don't interrupt,
## docs/ARCHITECTURE.md §3). Knockback velocity was already applied by
## Health.take_hit. Brief lockout, then control returns.

var _timer := 0.0


func enter() -> void:
	tint("#e57373")
	_timer = 0.3


func physics_update(delta: float) -> void:
	_timer -= delta
	player.velocity.x = move_toward(player.velocity.x, 0.0, player.air_decel * delta)
	player.apply_gravity(delta)
	if _timer <= 0.0:
		if player.is_on_floor():
			machine.change_state(&"Run" if player.horizontal_input() != 0.0 else &"Idle")
		else:
			machine.change_state(&"Fall")
