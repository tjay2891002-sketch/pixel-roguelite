extends "res://actors/player/state_machine/state.gd"
## Hover — the flyer's approach: drift to a hovering offset above-beside the
## target (with a gentle bob), then drop into Telegraph when close.
## The hover point is clamped inside the room so corners/ceilings can't
## trap the flyer; a watchdog forces the attack if it still can't progress —
## measured by ACTUAL movement (a wedged flyer commands full velocity into
## the wall, so watching velocity never fires).

var _t := 0.0
var _stuck := 0.0
var _last_pos := Vector2.ZERO


func enter() -> void:
	tint("#b39ddb")
	_t = 0.0
	_stuck = 0.0
	_last_pos = actor.global_position


func physics_update(delta: float) -> void:
	_t += delta
	if actor.target == null:
		machine.change_state(&"Patrol")
		return
	actor.face_target()
	var offset := Vector2(-actor.facing * 34.0, -34.0 + sin(_t * 2.5) * 6.0)
	var target_pos: Vector2 = actor.target.global_position + offset
	if actor.room_bounds.has_area():
		var inner = actor.room_bounds.grow(-actor.ROOM_MARGIN)
		target_pos = target_pos.clamp(inner.position, inner.end - Vector2(1, 1))
	var to: Vector2 = target_pos - actor.global_position
	var desired = Vector2.ZERO if to.length() < 6.0 else to.normalized() * actor.move_speed
	actor.velocity = actor.velocity.move_toward(desired, 300.0 * delta)

	# watchdog: wedged in a corner with no real progress -> attack anyway
	var moved: float = actor.global_position.distance_to(_last_pos)
	_last_pos = actor.global_position
	if to.length() > 30.0 and moved < 0.3:
		_stuck += delta
	else:
		_stuck = 0.0
	if _stuck > 1.0:
		machine.change_state(&"Telegraph")
	elif to.length() < 44.0 and actor.attack_cooldown <= 0.0:
		machine.change_state(&"Telegraph")
