extends CharacterBody2D
## Enemy base — greybox enemy actor (docs/ARCHITECTURE.md §4).
## Detection is dumb on purpose: a DetectionZone radius, walk toward the
## player, telegraphed swipe. The dummy reuses this script with no
## DetectionZone/Hitbox and a trimmed state set (missing states = no-op
## transitions).

signal state_changed(state_name: StringName)

@export var move_speed := 30.0
@export var patrol_range := 40.0
@export var attack_range := 16.0
@export var telegraph_time := 0.50
@export var attack_active_time := 0.12
@export var attack_recovery_time := 0.4
@export var swipe_damage := 6
@export var swipe_poise_damage := 10.0
@export var swipe_knockback := Vector2(80, -30)
@export var gravity := 900.0
@export var flying := false            # flyers skip gravity entirely
@export var knockback_resist := 1.0    # heavy: 0.25 — Health multiplies knockback by this
@export var projectile_speed := 90.0   # spitter / boss volley
@export var volley_count := 1          # boss: 3-ball spread
@export var swoop_speed := 220.0       # flyer
@export var swoop_time := 0.35         # flyer
@export var swoop_cooldown := 1.2      # flyer: seconds between swoops
## Hunters: once aggroed they never let go — kill or be killed. Keeps
## disengage-prone flyers from ever entering the corner-wedging patrol.
@export var persistent_target := false
@export var xp_value := 5              # RunManager XP on kill (dummy: 0)
@export var attack_state := &"Attack"  # state entered after Telegraph (spitter: RangedAttack, flyer: Swoop)
@export var aim_mode := &""            # telegraph warning: "shot" (aim line) | "dash" (path preview) | "" (none)

## Cooldown gate for attack states (flyer's swoop sets this on exit).
var attack_cooldown := 0.0

var facing := -1
var home_x := 0.0
var home_y := 0.0 # flyers descend back to this altitude after disengaging
var target: Node2D = null # detected player
## Hard confinement: the stage sets this at spawn so enemies can never leave
## their room (patrol/chase/knockback all respect it). Empty = unconfined.
var room_bounds := Rect2()

## Confinement margin: wall tile (16) + lock-blocker intrusion (24). An
## enemy clamped closer than this ends up INSIDE the red door blocker.
const ROOM_MARGIN := 28.0

## state_machine is untyped on purpose (same convention as the player).
var state_machine

## Telegraph warning line (aim/preview), built for every enemy; hidden unless
## the archetype's aim_mode uses it.
var aim_line: Line2D

## Visual: Polygon2D "Visual" (greybox) or AnimatedSprite2D "Sprite" (art).
## Resolved in _ready with a fallback so both scene styles share this script.
var visual

const RAT_ANIMS = preload("res://actors/enemies/rat_anims.gd")
const SPITTER_ANIMS = preload("res://actors/enemies/spitter_anims.gd")
const HEAVY_ANIMS = preload("res://actors/enemies/heavy_anims.gd")
const EAGLE_ANIMS = preload("res://actors/enemies/eagle_anims.gd")
const REDCAP_ANIMS = preload("res://actors/enemies/redcap_anims.gd")
const WITCH_ANIMS = preload("res://actors/enemies/witch_anims.gd")
const SLUG_ANIMS = preload("res://actors/enemies/slug_anims.gd")
const DRONE_ANIMS = preload("res://actors/enemies/drone_anims.gd")
const PIRANHA_ANIMS = preload("res://actors/enemies/piranha_anims.gd")

@export var sprite_set := &"" # "rat" | "spitter" | "heavy" | "eagle" | "" (greybox)

@onready var hitbox: Area2D = get_node_or_null("Hitbox")
@onready var health: Node = $Health
@onready var detection: Area2D = get_node_or_null("DetectionZone")
@onready var hp_label: Label = $HpLabel


func _ready() -> void:
	state_machine = $StateMachine
	home_x = global_position.x
	home_y = global_position.y
	add_to_group(&"enemy")
	visual = get_node_or_null("Visual")
	if visual == null:
		visual = get_node_or_null("Sprite")
	if visual is AnimatedSprite2D:
		visual.sprite_frames = _build_sprite_set()
		state_changed.connect(_on_state_sprite_anim)
	# facing data starts at -1 but flip_h defaults false: sync the art at
	# birth (a never-walking mob would otherwise stay back-facing forever)
	if visual is AnimatedSprite2D:
		visual.flip_h = (facing == -1)
	elif visual:
		visual.scale.x = facing
	aim_line = Line2D.new()
	aim_line.name = "AimLine"
	aim_line.width = 1.0
	aim_line.default_color = Color(1.0, 0.35, 0.25, 0.6)
	aim_line.visible = false
	add_child(aim_line)
	if hitbox:
		hitbox.position.x = absf(hitbox.position.x) * facing
	var pivot := get_node_or_null("SlashPivot")
	if pivot:
		pivot.scale.x = facing
	if detection:
		detection.body_entered.connect(_on_detection_entered)
		detection.body_exited.connect(_on_detection_exited)
	health.poise_broken.connect(_on_poise_broken)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	state_machine.physics_update(delta)
	_separate_from_player() # never stack on the player's head (head-stand jam)
	if not flying:
		velocity.y = minf(velocity.y + gravity * delta, 320.0)
	move_and_slide()
	if room_bounds.has_area():
		global_position.x = clampf(global_position.x, room_bounds.position.x + ROOM_MARGIN, room_bounds.end.x - ROOM_MARGIN)
		global_position.y = clampf(global_position.y, room_bounds.position.y + 12.0, room_bounds.end.y - 10.0)


func _process(_delta: float) -> void:
	hp_label.text = str(health.hp)


func set_facing(dir: int) -> void:
	if dir == 0 or dir == facing:
		return
	facing = dir
	if visual is AnimatedSprite2D:
		visual.flip_h = (facing == -1) # base rat art faces right
	else:
		visual.scale.x = facing
	if hitbox:
		hitbox.position.x = absf(hitbox.position.x) * facing
	var pivot := get_node_or_null("SlashPivot")
	if pivot:
		pivot.scale.x = facing


## SpriteActors: state machine drives the animation (greybox actors tint
## instead — see state.gd's tint()).
func _on_state_sprite_anim(state_name: StringName) -> void:
	match state_name:
		&"Idle": visual.play(&"idle")
		&"Patrol", &"Chase": visual.play(&"run" if move_speed > 0.0 else &"idle") # stationary mobs (piranha) stand idle, not mouth-flap run
		&"Hover": visual.play(&"idle") # flyers idle-hover while approaching
		&"Telegraph": visual.play(&"attack", 0.4)
		&"Attack", &"RangedAttack", &"Swoop": visual.play(&"attack", 2.0)
		&"Stagger": visual.play(&"hurt")
		&"Dead": visual.play(&"death")


func _build_sprite_set() -> SpriteFrames:
	match sprite_set:
		&"rat": return RAT_ANIMS.build()
		&"spitter": return SPITTER_ANIMS.build()
		&"heavy": return HEAVY_ANIMS.build()
		&"eagle": return EAGLE_ANIMS.build()
		&"redcap": return REDCAP_ANIMS.build()
		&"witch": return WITCH_ANIMS.build()
		&"slug": return SLUG_ANIMS.build()
		&"drone": return DRONE_ANIMS.build()
		&"piranha": return PIRANHA_ANIMS.build()
	return null


func face_target() -> void:
	if target:
		set_facing(signi(int(target.global_position.x - global_position.x)))


## Overlap separation: when a body lands ON the player (swoop drop, knockback
## toss), the two bodies wedge — the player can't move and its swings pass
## under the rider's hurtbox. While truly overlapping, override the state's
## velocity with a sideways shove so the enemy slides off beside the player.
## Only the enemy is pushed: the player keeps full control.
func _separate_from_player() -> void:
	var p = get_tree().get_first_node_in_group(&"player")
	if p == null:
		return
	var dx = global_position.x - p.global_position.x
	var dy = global_position.y - p.global_position.y
	if absf(dx) < 9.0 and dy > -26.0 and dy < 10.0:
		velocity.x = (1.0 if dx >= 0.0 else -1.0) * maxf(move_speed, 50.0)


func target_distance_x() -> float:
	if target == null:
		return INF
	return absf(target.global_position.x - global_position.x)


func walk(dir: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, dir * move_speed, 400.0 * delta)
	if dir != 0.0:
		set_facing(int(signf(dir)))


func swipe_hit_info() -> Dictionary:
	return {
		&"damage": swipe_damage,
		&"poise_damage": swipe_poise_damage,
		&"knockback": Vector2(swipe_knockback.x * facing, swipe_knockback.y),
		&"attacker": self,
	}


func emit_state(state_name: StringName) -> void:
	state_changed.emit(state_name)


## Show/update the telegraph warning line (points are LOCAL to this enemy).
func update_aim_line(points: PackedVector2Array) -> void:
	aim_line.points = points
	aim_line.visible = true


func hide_aim_line() -> void:
	aim_line.visible = false


func _on_detection_entered(body: Node2D) -> void:
	target = body
	face_target() # turn to the player the instant they're spotted


func _on_detection_exited(_body: Node2D) -> void:
	if persistent_target and target != null:
		return # hunters never let go once aggroed
	target = null


func _on_poise_broken() -> void:
	state_machine.change_state(&"Stagger")


func _on_died() -> void:
	state_machine.change_state(&"Dead")
