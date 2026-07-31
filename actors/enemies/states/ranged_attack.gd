extends "res://actors/player/state_machine/state.gd"
## RangedAttack — the spitter's shot: fire one projectile at the target,
## then recover. The mandatory Telegraph before it gives the read.

const ProjectileScene := preload("res://actors/enemies/projectile.tscn")

var _timer := 0.0


func enter() -> void:
	tint("#80cbc4")
	_timer = actor.attack_recovery_time
	actor.velocity.x = 0.0
	var base_dir := Vector2(actor.facing, 0.0)
	if actor.target:
		base_dir = (actor.target.global_position - actor.global_position).normalized()
	# volley_count 1 = the spitter's single Ball; the boss fires a spread
	var count: int = actor.volley_count
	for i in count:
		var dir := base_dir
		if count > 1:
			dir = base_dir.rotated(lerpf(-0.35, 0.35, float(i) / (count - 1)))
		var p := ProjectileScene.instantiate()
		actor.get_parent().add_child(p)
		p.global_position = actor.global_position + Vector2(actor.facing * 10.0, -4.0)
		p.velocity = dir * actor.projectile_speed
		# the Ball sprite points right by default; only the sprite needs rotation
		if p.has_node("Sprite"):
			p.get_node("Sprite").rotation = dir.angle()
		p.hit_info = actor.swipe_hit_info()


func physics_update(delta: float) -> void:
	_timer -= delta
	actor.velocity.x = 0.0
	if _timer <= 0.0:
		resume_pursuit()
