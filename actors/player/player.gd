extends CharacterBody2D
## Player — greybox movement controller (M1, pillar: movement kit).
##
## All feel knobs are exports; tune them while running level/playground.tscn.
## The flat FSM under $StateMachine reads/writes velocity and the timers here.
## Shared logic (gravity, steering, facing, jump bookkeeping) lives HERE, not
## in parent-state classes — docs/ARCHITECTURE.md §2.

signal state_changed(state_name: StringName)

@export_group("Run")
@export var move_speed := 90.0          # px/s in a 480x270 viewport
@export var ground_accel := 900.0       # near-instant to full speed = snappy
@export var ground_decel := 1400.0
@export var air_accel := 550.0
@export var air_decel := 200.0

@export_group("Jump")
@export var jump_velocity := 260.0
@export var jump_cut := 0.4             # velocity.y *= this on early release
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

@export_group("Wall")
@export var wall_slide_speed := 40.0
@export var wall_jump_velocity := Vector2(100.0, 250.0)  # gentle push-off: re-grab is quick
@export var wall_jump_lockout := 0.08   # reduced air control right after push-off

@export_group("Ledge")
@export var ledge_climb_duration := 0.28
@export var ledge_up_offset := 24.0     # fallback climb height if the top probe misses

var facing := 1
var invulnerable := false               # M2: the Hurtbox will read this for i-frames
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var air_jumps_left := 0

## state_machine is untyped on purpose (see state.gd header comment).
var state_machine

@onready var visual: Polygon2D = $Visual
@onready var wall_ray: RayCast2D = $WallRay
@onready var feet_ray: RayCast2D = $FeetRay
@onready var head_ray: RayCast2D = $HeadRay


func _ready() -> void:
	state_machine = $StateMachine


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"jump"):
		jump_buffer_timer = jump_buffer_time
	state_machine.handle_input(event)


func _physics_process(delta: float) -> void:
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	state_machine.physics_update(delta)
	move_and_slide()
	if is_on_floor():
		coyote_timer = coyote_time
		air_jumps_left = max_air_jumps


# --- Shared helpers -----------------------------------------------------------

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
