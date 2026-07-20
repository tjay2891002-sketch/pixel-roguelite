extends CharacterBody2D
## Player — greybox movement + combat controller (M1 movement kit, M2 combat).
##
## All feel knobs are exports; tune them while running level/playground.tscn.
## The flat FSM under $StateMachine reads/writes velocity and the timers here.
## Shared logic (gravity, steering, facing, jump bookkeeping, hitbox control)
## lives HERE, not in parent-state classes — docs/ARCHITECTURE.md §2.

signal state_changed(state_name: StringName)

const PlaceholderAnims = preload("res://actors/player/placeholder_anims.gd")

@export_group("Run")
@export var move_speed := 90.0          # px/s in a 480x270 viewport
@export var ground_accel := 900.0       # near-instant to full speed = snappy
@export var ground_decel := 1400.0
@export var air_accel := 550.0
@export var air_decel := 200.0

@export_group("Jump")
@export var jump_velocity := 320.0
@export var jump_cut := 0.45            # velocity.y *= this on early release
@export var gravity := 900.0
@export var fall_gravity_multiplier := 1.4   # fall faster than rise = weighty
@export var max_fall_speed := 320.0
@export var coyote_time := 0.10
@export var jump_buffer_time := 0.12
@export var max_air_jumps := 1          # double jump

@export_group("Roll")
@export var roll_speed := 170.0
@export var roll_duration := 0.32
@export var roll_cancel_window := 0.10  # last N seconds can cancel into jump/move
@export var roll_iframe_tail := 0.12    # i-frames outlast the roll by this much

@export_group("Wall")
@export var wall_slide_speed := 40.0
# Small horizontal push: the player stays inside the 8px wall-ray range, so
# holding toward the wall re-grabs DURING the rise (momentum carries) instead
# of drifting out and falling back. This is what makes single-wall climbs work.
@export var wall_jump_velocity := Vector2(50.0, 250.0)
@export var wall_jump_lockout := 0.08   # reduced air control right after push-off

@export_group("Ledge")
@export var ledge_climb_duration := 0.28
@export var ledge_up_offset := 24.0     # fallback climb height if the top probe misses

@export_group("Combat")
@export var weapon: WeaponData

var facing := 1
var invulnerable := false               # true during Roll (states/tests read this)
var iframes_left := 0.0                 # combat i-frames window in game-time seconds
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var air_jumps_left := 0

## Combat scratch state — written by the Attack state, read by animation
## Call Method tracks (_on_swing_active_start / hitbox_deactivate).
var attack_step_index := 0
var current_hit_info: Dictionary = {}
var current_lunge := 0.0

## Combo memory: after a swing ends, a press within COMBO_MEMORY_MS continues
## the chain from combo_step (Dead Cells-style forgiving combos).
const COMBO_MEMORY_MS := 250
var combo_step := 0
var combo_reset_at_msec := 0

## state_machine is untyped on purpose (see state.gd header comment).
var state_machine

@onready var visual: Polygon2D = $Visual
@onready var wall_ray: RayCast2D = $WallRay
@onready var feet_ray: RayCast2D = $FeetRay
@onready var head_ray: RayCast2D = $HeadRay
@onready var anim_player: AnimationPlayer = $AnimPlayer
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var health: Node = $Health


func _ready() -> void:
	state_machine = $StateMachine
	add_to_group(&"player")
	PlaceholderAnims.build(anim_player)
	health.poise_broken.connect(_on_poise_broken)
	health.died.connect(_on_died)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"jump"):
		jump_buffer_timer = jump_buffer_time
	state_machine.handle_input(event)


func _physics_process(delta: float) -> void:
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	iframes_left = maxf(iframes_left - delta, 0.0)
	state_machine.physics_update(delta)
	move_and_slide()
	if is_on_floor():
		coyote_timer = coyote_time
		air_jumps_left = max_air_jumps


func _process(_delta: float) -> void:
	# Post-hit grace blink (roll i-frames hide the hurtbox instead).
	if health.in_grace():
		visual.modulate.a = 0.35 if (Time.get_ticks_msec() / 70) % 2 == 0 else 0.9
	else:
		visual.modulate.a = 1.0


# --- Movement helpers ---------------------------------------------------------

func horizontal_input() -> float:
	return Input.get_axis(&"move_left", &"move_right")


func apply_gravity(delta: float, multiplier := 1.0) -> void:
	velocity.y = minf(velocity.y + gravity * multiplier * delta, max_fall_speed)


## Accelerate velocity.x toward input * move_speed. States pass ground or air
## constants depending on where the player is.
func steer(input_x: float, accel: float, decel: float, delta: float) -> void:
	var rate := accel if input_x != 0.0 else decel
	velocity.x = move_toward(velocity.x, input_x * move_speed, rate * delta)
	if input_x != 0.0:
		set_facing(int(signf(input_x)))


func set_facing(dir: int) -> void:
	if dir == 0 or dir == facing:
		return
	facing = dir
	wall_ray.target_position.x = absf(wall_ray.target_position.x) * facing
	feet_ray.target_position.x = absf(feet_ray.target_position.x) * facing
	head_ray.target_position.x = absf(head_ray.target_position.x) * facing
	visual.scale.x = facing
	hitbox.position.x = absf(hitbox.position.x) * facing


## Ground/coyote jump. Consumes the buffer only if the jump actually happens.
func try_ground_jump() -> bool:
	if jump_buffer_timer <= 0.0:
		return false
	if not (is_on_floor() or coyote_timer > 0.0):
		return false
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	velocity.y = -jump_velocity
	return true


func try_air_jump() -> bool:
	if jump_buffer_timer <= 0.0 or air_jumps_left <= 0:
		return false
	jump_buffer_timer = 0.0
	air_jumps_left -= 1
	velocity.y = -jump_velocity * 0.9
	return true


## Variable jump height: called on jump release.
func cut_jump() -> void:
	if velocity.y < 0.0:
		velocity.y *= jump_cut


func touching_wall() -> bool:
	return not is_on_floor() and wall_ray.is_colliding()


func pushing_toward_wall() -> bool:
	return horizontal_input() * facing > 0.0


## Ledge = feet blocked, head clear, pushing toward the wall while airborne.
func can_ledge_grab() -> bool:
	return not is_on_floor() and pushing_toward_wall() \
		and feet_ray.is_colliding() and not head_ray.is_colliding()


func emit_state(state_name: StringName) -> void:
	state_changed.emit(state_name)


## The combat i-frame window (roll duration + tail), counted down in game
## time — deterministic under hitstop and unthrottled headless, unlike
## wall-clock timestamps.
func has_iframes() -> bool:
	return iframes_left > 0.0


# --- Combat -------------------------------------------------------------------

## Called by AnimationPlayer Call Method tracks at active-frame start.
func _on_swing_active_start() -> void:
	if is_on_floor():
		velocity.x = facing * current_lunge
	hitbox.activate(current_hit_info)


## Called by Call Method tracks at active-frame end (and by Attack.exit()).
func hitbox_deactivate() -> void:
	hitbox.deactivate()


## Which chain step a new Attack starts from: combo_step if we're inside the
## combo memory window, else 0.
func begin_attack_index() -> int:
	if combo_step > 0 and combo_step < weapon.steps.size() \
			and Time.get_ticks_msec() < combo_reset_at_msec:
		return combo_step
	return 0


func _on_poise_broken() -> void:
	combo_step = 0 # getting staggered drops the combo
	state_machine.change_state(&"Hurt")


func _on_died() -> void:
	state_machine.change_state(&"Dead")
