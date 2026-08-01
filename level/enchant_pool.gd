extends Area2D
## EnchantPool — appears in the boss room after the clear. Walk up and press
## interact (F): spends shards (魔晶, the crate/boss currency) to enchant the
## HELD weapon — +12% damage per rank, max 5, cost 10+5*rank. Enchants are
## per weapon id and run-scoped (RunManager).
## Autoloads are referenced directly: this script is only ever reached via
## scene loads (stage), never through test --script preload chains.

const SFX := preload("res://fx/sfx_builder.gd")
const GameFont := preload("res://fx/game_font.gd")

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
	# live prompt: rank/cost change after each purchase
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	var rank := RunManager.enchant_rank(player.weapon.id)
	if rank >= RunManager.ENCHANT_MAX_RANK:
		_prompt.text = "已满级"
	else:
		_prompt.text = "[F] 附魔 %s +%d（%d 魔晶）" % [
			player.weapon.display_name, rank + 1, RunManager.enchant_cost(player.weapon.id)]


func _on_proximity(body: Node2D, entered: bool) -> void:
	if not body.is_in_group(&"player"):
		return
	_in_range = entered
	_prompt.visible = entered


func _unhandled_input(event: InputEvent) -> void:
	if _in_range and event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		_try_enchant()


func _try_enchant() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	var id: StringName = player.weapon.id
	var rank := RunManager.enchant_rank(id)
	if rank >= RunManager.ENCHANT_MAX_RANK:
		AudioBus.play_sfx(SFX.deny(), global_position)
		return
	var cost := RunManager.enchant_cost(id)
	var shards := int(SaveStub.data.get("shards", 0))
	if shards < cost:
		AudioBus.play_sfx(SFX.deny(), global_position)
		return
	SaveStub.data["shards"] = shards - cost
	RunManager.add_enchant(id)
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
	_prompt.position = Vector2(-52, -30)
	_prompt.visible = false
	add_child(_prompt)
