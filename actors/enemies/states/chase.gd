extends "res://actors/player/state_machine/state.gd"
## Enemy Chase — closes to attack range, then telegraphs. Loses interest
## when the target leaves the DetectionZone.


func enter() -> void:
	tint("#ffb74d")


func physics_update(delta: float) -> void:
	if actor.target == null:
		machine.change_state(&"Patrol")
		return
	var dx: float = actor.target.global_position.x - actor.global_position.x
	if absf(dx) <= actor.attack_range:
		machine.change_state(&"Telegraph")
		return
	var dir := signf(dx)
	# chase right up to the walkable edge, never into a door plane — a
	# lock blocker appearing over a chasing enemy traps it in the red wall
	if actor.room_bounds.has_area():
		var lo = actor.room_bounds.position.x + actor.ROOM_MARGIN
		var hi = actor.room_bounds.end.x - actor.ROOM_MARGIN
		if (dir > 0.0 and actor.global_position.x >= hi) or (dir < 0.0 and actor.global_position.x <= lo):
			actor.walk(0.0, delta) # wait at the fence, facing the target
			return
	actor.walk(dir, delta)
