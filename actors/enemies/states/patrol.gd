extends "res://actors/player/state_machine/state.gd"
## Enemy Patrol — paces between home_x ± patrol_range. Chases on detection.

var _dir := 1.0


func enter() -> void:
	tint("#a5d6a7")


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
