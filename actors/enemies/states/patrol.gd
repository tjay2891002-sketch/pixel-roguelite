extends "res://actors/player/state_machine/state.gd"
## Enemy Patrol — paces between home_x ± patrol_range. Chases on detection.

var _dir := 1.0


func enter() -> void:
	tint("#a5d6a7")


func physics_update(delta: float) -> void:
	if actor.target != null:
		resume_pursuit()
		return
	if actor.global_position.x > actor.home_x + actor.patrol_range:
		_dir = -1.0
	elif actor.global_position.x < actor.home_x - actor.patrol_range:
		_dir = 1.0
	actor.walk(_dir, delta)
