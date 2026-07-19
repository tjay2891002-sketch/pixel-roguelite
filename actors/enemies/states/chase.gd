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
	else:
		actor.walk(signf(dx), delta)
