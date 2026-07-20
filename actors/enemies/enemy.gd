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
@export var telegraph_time := 0.40
@export var attack_active_time := 0.12
@export var attack_recovery_time := 0.4
@export var swipe_damage := 6
@export var swipe_poise_damage := 10.0
@export var swipe_knockback := Vector2(80, -30)
@export var gravity := 900.0

var facing := -1
var home_x := 0.0
var target: Node2D = null # detected player

## state_machine is untyped on purpose (same convention as the player).
var state_machine

@onready var visual: Polygon2D = $Visual
@onready var hitbox: Area2D = get_node_or_null("Hitbox")
@onready var health: Node = $Health
@onready var detection: Area2D = get_node_or_null("DetectionZone")
@onready var hp_label: Label = $HpLabel


func _ready() -> void:
	state_machine = $StateMachine
	home_x = global_position.x
	add_to_group(&"enemy")
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
	state_machine.physics_update(delta)
	velocity.y = minf(velocity.y + gravity * delta, 320.0)
	move_and_slide()


func _process(_delta: float) -> void:
	hp_label.text = str(health.hp)


func set_facing(dir: int) -> void:
	if dir == 0 or dir == facing:
		return
	facing = dir
	visual.scale.x = facing
	if hitbox:
		hitbox.position.x = absf(hitbox.position.x) * facing
	var pivot := get_node_or_null("SlashPivot")
	if pivot:
		pivot.scale.x = facing


func face_target() -> void:
	if target:
		set_facing(signi(int(target.global_position.x - global_position.x)))


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


func _on_detection_entered(body: Node2D) -> void:
	target = body


func _on_detection_exited(_body: Node2D) -> void:
	target = null


func _on_poise_broken() -> void:
	state_machine.change_state(&"Stagger")


func _on_died() -> void:
	state_machine.change_state(&"Dead")
