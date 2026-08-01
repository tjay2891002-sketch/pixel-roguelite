extends "res://actors/player/state_machine/state.gd"
## Swoop — the flyer's attack: a fast dash through the target's position,
## hitbox live for the dash, then back to Hover.

var _dir := Vector2.ZERO
var _timer := 0.0


func enter() -> void:
	tint("#e57373")
	_timer = actor.swoop_time
	if actor.target:
		_dir = (actor.target.global_position - actor.global_position).normalized()
	else:
		_dir = Vector2(actor.facing, 0.0)
	actor.velocity = _dir * actor.swoop_speed
	actor.hitbox.activate(actor.swipe_hit_info())


func exit() -> void:
	actor.hitbox.deactivate()
	actor.attack_cooldown = actor.swoop_cooldown # gate the next swoop


func physics_update(delta: float) -> void:
	_timer -= delta
	# Wall deflection check by DIRECTION: a ceiling slide preserves speed
	# (speed checks miss it) but bends the path — dot() drops hard.
	var v = actor.velocity
	if v.length() < actor.swoop_speed * 0.15 or v.normalized().dot(_dir) < 0.55:
		actor.velocity = Vector2.ZERO
		machine.change_state(&"Hover")
		return
	actor.velocity = _dir * actor.swoop_speed
	if _timer <= 0.0:
		actor.velocity *= 0.3
		machine.change_state(&"Hover")
