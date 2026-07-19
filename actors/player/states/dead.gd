extends "res://actors/player/state_machine/state.gd"
## Dead — terminal state. RunManager reloads the scene shortly after
## player_died, so this just collapses and waits.


func enter() -> void:
	tint("#616161")
	player.hitbox_deactivate()
	player.velocity = Vector2.ZERO


func physics_update(delta: float) -> void:
	player.velocity.x = 0.0
	player.apply_gravity(delta)
