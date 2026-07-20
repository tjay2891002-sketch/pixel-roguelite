extends "res://actors/player/state_machine/state.gd"
## Enemy Telegraph — MANDATORY readable windup before every attack
## (docs/ARCHITECTURE.md §4: this is what makes encounters fair).
## Fixed duration, red flash, no movement — plus the swipe arc shown dim in
## its wound-up pose, so the incoming direction is readable too.

var _timer := 0.0


func enter() -> void:
	_timer = actor.telegraph_time
	actor.velocity.x = 0.0
	actor.face_target()
	var arc = actor.get_node_or_null("SlashPivot/SlashArc")
	if arc:
		arc.rotation = -1.2
		arc.modulate.a = 0.35
		arc.visible = true


func exit() -> void:
	actor.visual.modulate = Color.WHITE
	var arc = actor.get_node_or_null("SlashPivot/SlashArc")
	if arc:
		arc.visible = false


func physics_update(delta: float) -> void:
	_timer -= delta
	actor.velocity.x = 0.0
	# red blink — readable even in greybox
	actor.visual.modulate = Color(1.0, 0.4, 0.4) if int(_timer * 12.0) % 2 == 0 else Color.WHITE
	if _timer <= 0.0:
		machine.change_state(actor.attack_state)
