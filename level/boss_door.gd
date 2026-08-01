extends Area2D
## BossDoor — the next-stage portal hugging the boss room's right wall.
## Ornate arch + inner glow (dim while the boss lives, GOLD once cleared).
## Entering needs a confirm (F): no more forced teleports while grabbing
## the reward burst. The advance/deny decision stays on the stage
## (_on_boss_door_entered) — tests call it directly.

const ArchTex := preload("res://assets/ui/ornate_arch.png")
const SFX := preload("res://fx/sfx_builder.gd")

var room: Dictionary = {}
var _stage: Node = null
var _in_range := false
var _prompt: Label
var _glow: Polygon2D


func _ready() -> void:
	collision_layer = 256 # trigger
	collision_mask = 2    # player_body
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	shape.position = Vector2(0, -18.0)
	add_child(shape)

	_glow = Polygon2D.new()
	_glow.name = &"Glow"
	_glow.polygon = PackedVector2Array([
		Vector2(-9, 0), Vector2(-9, -24), Vector2(-5, -32), Vector2(5, -32),
		Vector2(9, -24), Vector2(9, 0)])
	_glow.color = Color("2a4a3a") # sealed: dim teal
	add_child(_glow)

	var arch := Sprite2D.new()
	arch.texture = ArchTex
	arch.scale = Vector2(0.5, 0.5) # 64x82 -> 32x41
	arch.position = Vector2(0, -20.0)
	add_child(arch)

	_prompt = Label.new()
	_prompt.add_theme_font_size_override(&"font_size", 7)
	_prompt.add_theme_color_override(&"font_color", Color("ffd54a"))
	_prompt.position = Vector2(-18, -52)
	_prompt.visible = false
	add_child(_prompt)

	body_entered.connect(_on_proximity.bind(true))
	body_exited.connect(_on_proximity.bind(false))


func _process(_delta: float) -> void:
	if _in_range:
		_prompt.text = "[F] Enter" if room.get("cleared", false) else "Sealed"


func _on_proximity(body: Node2D, entered: bool) -> void:
	if not body.is_in_group(&"player"):
		return
	_in_range = entered
	_prompt.visible = entered


func _unhandled_input(event: InputEvent) -> void:
	if _in_range and event.is_action_pressed(&"interact") and _stage:
		get_viewport().set_input_as_handled()
		_stage._on_boss_door_entered(self, room)
