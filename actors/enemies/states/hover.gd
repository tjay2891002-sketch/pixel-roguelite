extends "res://actors/player/state_machine/state.gd"
## Hover — the flyer's approach: drift to a hovering offset above-beside the
## target (with a gentle bob), then drop into Telegraph when close.
## 2D movement; no gravity (flying actor).

var _t := 0.0


func enter() -> void:
	tint("#b39ddb")
	_t = 0.0


func physics_update(delta: float) -> void:
	_t += delta
	if actor.target == null:
		machine.change_state(&"Patrol")
		return
	actor.face_target()
	var offset := Vector2(-actor.facing * 34.0, -34.0 + sin(_t * 2.5) * 6.0)
	var to: Vector2 = (actor.target.global_position + offset) - actor.global_position
	var desired = Vector2.ZERO if to.length() < 6.0 else to.normalized() * actor.move_speed
	actor.velocity = actor.velocity.move_toward(desired, 300.0 * delta)
	if to.length() < 44.0:
		machine.change_state(&"Telegraph")
