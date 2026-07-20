extends "res://actors/player/state_machine/state.gd"
## Enemy Idle — stands still; transitions to Chase (or Hover for flyers)
## when a target is detected (no-op for the dummy, which has neither —
## missing states are deliberate no-op transitions).


func enter() -> void:
	tint("#b0bec5")


func physics_update(delta: float) -> void:
	actor.walk(0.0, delta)
	if actor.target != null:
		machine.change_state(&"Hover" if machine.has_state(&"Hover") else &"Chase")
