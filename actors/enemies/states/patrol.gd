extends "res://actors/player/state_machine/state.gd"
## Enemy Patrol — paces between home_x ± patrol_range. Chases on detection.

var _dir := 1.0
var _stuck := 0.0
var _last_pos := Vector2.ZERO


func enter() -> void:
	tint("#a5d6a7")
	_stuck = 0.0
	_last_pos = actor.global_position


func physics_update(delta: float) -> void:
	if actor.target != null:
		resume_pursuit()
		return
	# fence the patrol to the room's walkable span (never into door planes)
	var lo = actor.home_x - actor.patrol_range
	var hi = actor.home_x + actor.patrol_range
	if actor.room_bounds.has_area():
		lo = maxf(lo, actor.room_bounds.position.x + actor.ROOM_MARGIN)
		hi = minf(hi, actor.room_bounds.end.x - actor.ROOM_MARGIN)
	if actor.global_position.x > hi:
		_dir = -1.0
	elif actor.global_position.x < lo:
		_dir = 1.0
	actor.walk(_dir, delta)
	if actor.flying:
		# descend home after disengaging: flyers kept their exit altitude
		# forever and hovered out of reach
		actor.velocity.y = clampf((actor.home_y - actor.global_position.y) * 2.0, -40.0, 40.0)
		_stuck_watchdog(delta)


## Ceiling-corner rescue: a disengaged flyer drifting home can wedge into a
## ceiling pocket where both axes stall. If it hasn't really moved for over
## a second, shove it DOWN hard and flip the walk direction until free.
func _stuck_watchdog(delta: float) -> void:
	var moved: float = actor.global_position.distance_to(_last_pos)
	_last_pos = actor.global_position
	if moved < 0.25 and (actor.global_position.y - actor.home_y) < -8.0:
		_stuck += delta
	else:
		_stuck = 0.0
	if _stuck > 1.2:
		actor.velocity.y = -90.0
		_dir = -_dir
