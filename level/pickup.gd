extends Area2D
## Pickup — a crate drop on the floor: weapon swap / heal potion / timed
## buff (or curse) / currency cells. Visual-only Area2D; the player walks
## over it to collect. Autoloads are resolved at RUNTIME (root.get_node):
## this script rides test preload chains where autoload names don't compile.

const SFX := preload("res://fx/sfx_builder.gd")

## Where the swap-dropped old weapon lands: far enough that the collecting
## player (body 5 + pickup 5 wide) isn't touching it — no re-pickup loop.
const SWAP_DROP_OFFSET := Vector2(-16.0, 0.0)

var kind: StringName = &"cells"
var payload = null # WeaponData for weapon; int heal for potion; int for cells


func _init(p_kind: StringName = &"cells", p_payload = null) -> void:
	kind = p_kind
	payload = p_payload


func _ready() -> void:
	collision_layer = 128 # layer 8: pickup
	collision_mask = 2    # player_body
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 10)
	shape.shape = rect
	add_child(shape)
	_build_visual()
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	match kind:
		&"weapon":
			var old: WeaponData = body.weapon
			body.equip(payload)
			_play(SFX.unlock())
			# swap-drop the old weapon offset aside; its arm-delay prevents
			# an instant re-pickup loop
			if old != null:
				var swap: Area2D = get_script().new(&"weapon", old) # get_script() is Variant
				get_parent().add_child(swap)
				swap.global_position = global_position + SWAP_DROP_OFFSET
		&"potion":
			body.health.hp = mini(body.health.hp + int(payload), body.health.max_hp)
			_play(SFX.heal())
		&"rage", &"swift":
			body.apply_buff(kind)
			_play(SFX.buff())
		&"curse":
			body.apply_buff(kind)
			_play(SFX.deny())
		&"cells":
			var save = get_tree().root.get_node_or_null("SaveStub")
			if save:
				save.add_currency(int(payload))
			var bus = get_tree().root.get_node_or_null("EventBus")
			if bus:
				bus.currency_dropped.emit(int(payload), global_position)
			_play(SFX.pickup())
	queue_free()


func _play(stream: AudioStream) -> void:
	var bus = get_tree().root.get_node_or_null("AudioBus")
	if bus:
		bus.play_sfx(stream, global_position)


func _build_visual() -> void:
	match kind:
		&"weapon":
			add_child(_diamond(Color("e8eef2"), 7.0))
			var label := Label.new()
			label.text = (payload as WeaponData).display_name
			label.add_theme_font_size_override(&"font_size", 6)
			label.add_theme_color_override(&"font_color", Color("e8eef2"))
			label.position = Vector2(-16, -22)
			add_child(label)
		&"potion":
			var flask := Polygon2D.new()
			flask.polygon = PackedVector2Array([
				Vector2(-4, -6), Vector2(4, -6), Vector2(5, 4), Vector2(-5, 4)])
			flask.color = Color("e53935")
			add_child(flask)
			var neck := Polygon2D.new()
			neck.polygon = PackedVector2Array([
				Vector2(-2, -9), Vector2(2, -9), Vector2(2, -6), Vector2(-2, -6)])
			neck.color = Color("ff8a80")
			add_child(neck)
		&"rage", &"swift", &"curse":
			var color: Color = body_buff_color()
			add_child(_diamond(color, 6.0))
		&"cells":
			var cell := Polygon2D.new()
			cell.polygon = PackedVector2Array([
				Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
			cell.color = Color("ffd54a")
			add_child(cell)


func body_buff_color() -> Color:
	# mirror of player.BUFFS colors — kept local to stay autoload-free
	match kind:
		&"rage": return Color("ef5350")
		&"swift": return Color("4dd0e1")
		&"curse": return Color("ab47bc")
	return Color.WHITE


func _diamond(color: Color, r: float) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
	p.color = color
	return p
