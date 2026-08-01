extends Area2D
## EnchantPool — appears in the boss room after the clear. Walk up and press
## 1/2/3 to buy a rank with shards (魔晶): atk speed / lifesteal / move speed.
## Cost scales with TOTAL ranks (10 + 8·total), so every buy prices the next
## one higher — that's the build tradeoff. Run-scoped (RunManager).
## Autoloads are referenced directly: this script is only ever reached via
## scene loads (stage), never through test --script preload chains.

const SFX := preload("res://fx/sfx_builder.gd")
const GameFont := preload("res://fx/game_font.gd")

const TRACK_LABELS := {&"atk_speed": "攻速", &"lifesteal": "吸血", &"move_speed": "移速"}
const TRACK_KEYS := [49, 50, 51] # KEY_1..KEY_3

var _in_range := false
var _prompt: Label


func _ready() -> void:
	add_to_group(&"enchant_pool")
	collision_layer = 128 # pickup layer: interactables
	collision_mask = 2    # player_body
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	_build_visual()
	body_entered.connect(_on_proximity.bind(true))
	body_exited.connect(_on_proximity.bind(false))


func _process(_delta: float) -> void:
	if not _in_range:
		return
	# live prompt: ranks/cost change after each purchase
	var cost := RunManager.enchant_cost()
	var lines: Array[String] = []
	for i in RunManager.ENCHANT_TRACKS.size():
		var track: StringName = RunManager.ENCHANT_TRACKS[i]
		var rank := RunManager.enchant_rank(track)
		if rank >= RunManager.ENCHANT_MAX_RANK:
			lines.append("[%d] %s 已满级" % [i + 1, TRACK_LABELS[track]])
		else:
			lines.append("[%d] %s Lv%d → %d 魔晶" % [i + 1, TRACK_LABELS[track], rank, cost])
	_prompt.text = "\n".join(lines)


func _on_proximity(body: Node2D, entered: bool) -> void:
	if not body.is_in_group(&"player"):
		return
	_in_range = entered
	_prompt.visible = entered


func _unhandled_input(event: InputEvent) -> void:
	if not _in_range or not (event is InputEventKey and event.pressed):
		return
	var idx := int(event.physical_keycode) - TRACK_KEYS[0]
	if idx < 0 or idx >= RunManager.ENCHANT_TRACKS.size():
		return
	get_viewport().set_input_as_handled()
	_try_enchant(RunManager.ENCHANT_TRACKS[idx])


func _try_enchant(track: StringName) -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	if RunManager.enchant_rank(track) >= RunManager.ENCHANT_MAX_RANK:
		AudioBus.play_sfx(SFX.deny(), global_position)
		return
	var cost := RunManager.enchant_cost()
	var shards := int(SaveStub.data.get("shards", 0))
	if shards < cost:
		AudioBus.play_sfx(SFX.deny(), global_position)
		return
	SaveStub.data["shards"] = shards - cost
	RunManager.add_enchant(track)
	player.apply_enchants()
	AudioBus.play_sfx(SFX.buff(), global_position)
	# white flash on the pool so the spend reads
	modulate = Color(3.0, 3.0, 3.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.25)


func _build_visual() -> void:
	# glowing pool: dark basin + bright core, cyan like the shards
	var basin := Polygon2D.new()
	basin.polygon = PackedVector2Array([
		Vector2(-16, 0), Vector2(-11, -5), Vector2(11, -5), Vector2(16, 0),
		Vector2(11, 4), Vector2(-11, 4)])
	basin.color = Color("0e3a4a")
	add_child(basin)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(-11, -1), Vector2(-7, -4), Vector2(7, -4), Vector2(11, -1),
		Vector2(7, 2), Vector2(-7, 2)])
	core.color = Color("80d8ff")
	add_child(core)
	# always-on caption so the pool reads from across the room
	var caption := Label.new()
	caption.text = "附魔池"
	GameFont.apply(caption)
	caption.add_theme_font_size_override(&"font_size", 7)
	caption.add_theme_color_override(&"font_color", Color("80d8ff", 0.65))
	caption.position = Vector2(-12, -16)
	add_child(caption)
	_prompt = Label.new()
	GameFont.apply(_prompt)
	_prompt.add_theme_font_size_override(&"font_size", 8)
	_prompt.add_theme_color_override(&"font_color", Color("80d8ff"))
	_prompt.position = Vector2(-34, -56)
	_prompt.visible = false
	add_child(_prompt)
