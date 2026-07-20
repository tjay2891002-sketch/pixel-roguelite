extends "res://actors/player/state_machine/state.gd"
## Enemy Dead — corpse fades and frees. Drops arrive in M5.

var _timer := 0.0


func enter() -> void:
	tint("#424242")
	_timer = 0.6
	actor.velocity = Vector2.ZERO
	actor.collision_layer = 0
	if actor.hitbox:
		actor.hitbox.deactivate()
	if actor.has_node("Hurtbox"):
		actor.get_node("Hurtbox").monitoring = false
	var arc = actor.get_node_or_null("SlashPivot/SlashArc")
	if arc:
		arc.visible = false


func physics_update(delta: float) -> void:
	_timer -= delta
	actor.visual.modulate.a = clampf(_timer / 0.6, 0.0, 1.0)
	if _timer <= 0.0:
		actor.queue_free()
