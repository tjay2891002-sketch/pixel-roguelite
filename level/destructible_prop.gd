extends StaticBody2D
## DestructibleProp — a crate/barrel planted on a room floor. Solid to the
## PLAYER only (prop_body layer; enemy AI has no obstacle avoidance, so
## enemies walk through instead of jamming on furniture). One hit — or a
## roll straight through — breaks it, and the break blasts nearby ENEMIES
## (the player's incentive to smash furniture). Reuses the combat pipeline:
## combat/hurtbox.gd so player swings connect, prop_health.gd for the break.
## Origin is at the FEET: the stage plants the node on the floor line.

const HurtboxScript := preload("res://combat/hurtbox.gd")
const PropHealthScript := preload("res://level/prop_health.gd")
const Drops := preload("res://level/drops.gd")

const BLAST_RADIUS := 30.0
const BLAST_DAMAGE := 12
const BLAST_POISE := 8.0
const BLAST_KNOCKBACK := Vector2(170.0, -110.0)
const ROLL_ZONE_MARGIN := 8.0 # break fires before the rolling body bonks

var broken := false

var _tex: Texture2D
var _health: Node


func _init(texture: Texture2D = null) -> void:
	_tex = texture


func _ready() -> void:
	if _tex == null:
		push_error("DestructibleProp needs a texture")
		return
	collision_layer = 1024 # layer 11 prop_body: in the player's mask only
	collision_mask = 0
	var size := _tex.get_size()
	var center := Vector2(0.0, -size.y / 2.0)

	var vis := Sprite2D.new()
	vis.name = &"Visual" # juice.gd flashes this child on hit
	vis.texture = _tex
	vis.position = center
	add_child(vis)

	var body_shape := CollisionShape2D.new()
	body_shape.name = &"Body"
	var body_rect := RectangleShape2D.new()
	body_rect.size = size
	body_shape.shape = body_rect
	body_shape.position = center
	add_child(body_shape)

	# NOTE: Health must enter the tree BEFORE the Hurtbox — hurtbox._ready
	# looks up the sibling "Health" node on sight.
	_health = PropHealthScript.new()
	_health.name = &"Health"
	_health.broke.connect(_on_broke)
	add_child(_health)

	var hurtbox: Area2D = HurtboxScript.new()
	hurtbox.name = &"Hurtbox"
	hurtbox.collision_layer = 64 # enemy_hurtbox: player swings (mask 64) connect
	hurtbox.collision_mask = 0
	var hurt_shape := CollisionShape2D.new()
	var hurt_rect := RectangleShape2D.new()
	hurt_rect.size = size
	hurt_shape.shape = hurt_rect
	hurt_shape.position = center
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)

	var roll_zone := Area2D.new()
	roll_zone.name = &"RollZone"
	roll_zone.collision_layer = 0
	roll_zone.collision_mask = 2 # player_body
	var roll_shape := CollisionShape2D.new()
	var roll_rect := RectangleShape2D.new()
	roll_rect.size = Vector2(size.x + ROLL_ZONE_MARGIN * 2.0, size.y)
	roll_shape.shape = roll_rect
	roll_shape.position = center
	roll_zone.add_child(roll_shape)
	add_child(roll_zone)


func _physics_process(_delta: float) -> void:
	if broken:
		return
	# Polled (not body_entered): a player already leaning on the prop who
	# THEN rolls gets no enter event — overlap + i-frames is the real test.
	for body in $RollZone.get_overlapping_bodies():
		if body.get("invulnerable") == true:
			_health.take_hit({
				&"damage": 1,
				&"attacker": body,
				&"hit_position": global_position + Vector2(0.0, -_tex.get_size().y / 2.0),
			})
			return


func _on_broke() -> void:
	if broken:
		return
	broken = true
	$Visual.visible = false
	$Body.set_deferred(&"disabled", true)
	$Hurtbox.set_deferred(&"monitoring", false)
	$RollZone.set_deferred(&"monitoring", false)
	_debris()
	# deferred: _on_broke runs inside a physics signal — adding the pickup's
	# collision shapes mid-flush errors ("Can't change this state...")
	Drops.roll_crate_drop.call_deferred(get_parent(), global_position + Vector2(0.0, -8.0))
	call_deferred(&"_blast")


## Wood-chip burst at the wreck (juice.gd's pooled hit burst already fired
## on hit_landed; this one is prop-colored and lingers a touch longer).
func _debris() -> void:
	var p := GPUParticles2D.new()
	p.amount = 8
	p.lifetime = 0.45
	p.one_shot = true
	p.explosiveness = 0.9
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, -1, 0)
	m.spread = 120.0
	m.initial_velocity_min = 40.0
	m.initial_velocity_max = 90.0
	m.gravity = Vector3(0, 300, 0)
	m.scale_min = 1.0
	m.scale_max = 2.0
	m.color = Color(0.55, 0.38, 0.22)
	p.process_material = m
	p.position = Vector2(0.0, -_tex.get_size().y / 2.0)
	add_child(p)
	p.emitting = true


## Deferred out of the physics callback: direct_space_state is locked while
## the hit signal is being dispatched.
func _blast() -> void:
	var circle := CircleShape2D.new()
	circle.radius = BLAST_RADIUS
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = circle
	params.transform = Transform2D(0.0, global_position + Vector2(0.0, -_tex.get_size().y / 2.0))
	params.collision_mask = 64 # enemy_hurtbox — the blast never hurts the player
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hits := get_world_2d().direct_space_state.intersect_shape(params, 8)
	for hit in hits:
		var area: Object = hit.collider
		if area == $Hurtbox or not is_instance_valid(area) or not area.has_method(&"receive_hit"):
			continue
		var away := signf(area.global_position.x - global_position.x)
		if away == 0.0:
			away = 1.0
		area.receive_hit({
			&"damage": BLAST_DAMAGE,
			&"poise_damage": BLAST_POISE,
			&"knockback": Vector2(BLAST_KNOCKBACK.x * away, BLAST_KNOCKBACK.y),
			&"attacker": self,
			&"hit_position": area.global_position,
		})
