extends "res://actors/player/state_machine/state.gd"
## Enemy Idle — stands still; transitions to Chase when a target is detected
## (no-op for the dummy, which has no Chase state — by design).


func enter() -> void:
	tint("#b0bec5")


func physics_update(delta: float) -> void:
	actor.walk(0.0, delta)
	if actor.target != null:
		machine.change_state(&"Chase")
