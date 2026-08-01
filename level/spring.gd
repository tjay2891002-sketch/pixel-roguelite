extends Area2D
## Spring — the Sunny Land mushroom springboard. A falling player who
## touches it bounces high (higher than a double jump) and gets air jumps
## back. Pure mobility toy: no damage, no interaction needed.
## AudioBus is resolved at runtime: this script rides test preload chains,
## where autoload names don't compile.

const SFX := preload("res://fx/sfx_builder.gd")
const SHEET := preload("res://assets/level/spring/spring.png")

const BOUNCE := 520.0 # jump_velocity is 320; this reaches ~9 tiles
const FRAME := 50

var _sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group(&"spring")
	collision_layer = 0
	collision_mask = 2 # player_body
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 16)
	shape.shape = rect
	shape.position = Vector2(0, -8) # trigger cap sits above the stem
	add_child(shape)

	_sprite = AnimatedSprite2D.new()
	_sprite.name = &"Sprite"
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add(frames, &"idle", 1, 1.0, true)
	_add(frames, &"boing", 7, 16.0, false)
	_sprite.sprite_frames = frames
	_sprite.position = Vector2(0, -25) # 50px frame, feet at the origin
	_sprite.play(&"idle")
	add_child(_sprite)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	if body.velocity.y < 0.0:
		return # rising through it — no bounce
	body.velocity.y = -BOUNCE
	body.air_jumps_left = body.max_air_jumps # bounce refreshes the double jump
	_sprite.play(&"boing")
	var bus = get_tree().root.get_node_or_null("AudioBus")
	if bus:
		bus.play_sfx(SFX.spring(), global_position)


func _add(frames: SpriteFrames, name: StringName, count: int, fps: float, loop: bool) -> void:
	frames.add_animation(name)
	frames.set_animation_loop(name, loop)
	frames.set_animation_speed(name, fps)
	for i in count:
		var region := AtlasTexture.new()
		region.atlas = SHEET
		region.region = Rect2(i * FRAME, 0, FRAME, FRAME)
		frames.add_frame(name, region)
