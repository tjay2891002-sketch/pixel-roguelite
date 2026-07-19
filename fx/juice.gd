extends Node
## Juice — the combat feel layer (docs/ARCHITECTURE.md §3): hitstop, trauma
## screen shake, hit particles, victim flash. Subscribes to EventBus.hit_landed
## and is fully decoupled: remove this node and the game plays identically,
## it just feels dead.

const HITSTOP_SCALE := 0.05
const HITSTOP_MS := 80.0
const KILL_HITSTOP_MS := 140.0
const SHAKE_TRAUMA_PER_HIT := 0.35
const SHAKE_MAX_OFFSET := 6.0
const SHAKE_DECAY := 1.6
const PARTICLE_POOL_SIZE := 3

var _trauma := 0.0
var _hitstop_until_msec := 0
var _camera: Camera2D
var _particles: Array[GPUParticles2D] = []
var _next_particle := 0
var _noise := FastNoiseLite.new()
var _noise_t := 0.0


func _ready() -> void:
	# ALWAYS: hitstop restore must keep ticking while time_scale is near zero.
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.hit_landed.connect(_on_hit_landed)
	for i in PARTICLE_POOL_SIZE:
		var burst := _make_burst()
		_particles.append(burst)
		add_child(burst)


func _process(delta: float) -> void:
	# --- hitstop restore (wall-clock: SceneTreeTimer would ignore time_scale)
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() >= _hitstop_until_msec:
		Engine.time_scale = 1.0

	# --- trauma shake: offset = noise * trauma^2, decays linearly
	if _camera == null:
		_camera = get_tree().get_first_node_in_group(&"player_camera")
	if _camera:
		_trauma = maxf(_trauma - SHAKE_DECAY * delta, 0.0)
		_noise_t += delta * 30.0
		if _trauma > 0.0:
			var magnitude := SHAKE_MAX_OFFSET * _trauma * _trauma
			_camera.offset = Vector2(
				_noise.get_noise_1d(_noise_t) * magnitude,
				_noise.get_noise_1d(_noise_t + 1000.0) * magnitude)
		else:
			_camera.offset = Vector2.ZERO


func _on_hit_landed(hit_info: Dictionary) -> void:
	# hitstop — heavier on a kill
	var victim = hit_info.get(&"victim")
	var killed := false
	if victim and victim.get_node_or_null("Health"):
		killed = victim.get_node("Health").hp <= 0
	Engine.time_scale = HITSTOP_SCALE
	_hitstop_until_msec = Time.get_ticks_msec() + (KILL_HITSTOP_MS if killed else HITSTOP_MS)

	_trauma = minf(_trauma + SHAKE_TRAUMA_PER_HIT, 1.0)

	# particle burst at the impact point
	var burst := _particles[_next_particle]
	_next_particle = (_next_particle + 1) % PARTICLE_POOL_SIZE
	burst.global_position = hit_info.get(&"hit_position", Vector2.ZERO)
	burst.restart()

	# white flash on the victim
	if victim:
		var vis = victim.get_node_or_null("Visual")
		if vis:
			vis.modulate = Color(4.0, 4.0, 4.0)
			var tween := create_tween()
			tween.tween_property(vis, "modulate", Color.WHITE, 0.12)


func _make_burst() -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = 10
	p.lifetime = 0.35
	p.one_shot = true
	p.explosiveness = 0.9
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, -1, 0)
	m.spread = 140.0
	m.initial_velocity_min = 30.0
	m.initial_velocity_max = 70.0
	m.gravity = Vector3(0, 200, 0)
	m.scale_min = 1.0
	m.scale_max = 2.0
	m.color = Color(1.0, 0.9, 0.6)
	p.process_material = m
	p.emitting = false
	return p
