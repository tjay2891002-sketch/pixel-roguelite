extends "res://actors/player/state_machine/state.gd"
## Enemy Stagger — forced interrupt on poise break (§4): vulnerability
## window, then back to business. Knockback was applied by Health.take_hit.

var _timer := 0.0


func enter() -> void:
	tint("#fff176")
	_timer = 0.6
	if actor.hitbox:
		actor.hitbox.deactivate()
	# hide the swipe arc if the stagger interrupted a telegraph/strike
	var arc = actor.get_node_or_null("SlashPivot/SlashArc")
	if arc:
		arc.visible = false


func physics_update(delta: float) -> void:
	_timer -= delta
	actor.velocity.x = move_toward(actor.velocity.x, 0.0, 300.0 * delta)
	if _timer <= 0.0:
		machine.change_state(&"Chase" if actor.target != null else &"Patrol")
