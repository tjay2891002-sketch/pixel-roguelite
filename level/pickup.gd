extends Area2D
## Pickup — a crate drop on the floor. Potions/buffs/cells collect on
## contact; WEAPONS need a confirm: walk up and press interact (F) — the
## held weapon swap-drops beside you (far enough to not re-trigger).
## Autoloads are resolved at RUNTIME (root.get_node): this script rides
## test preload chains where autoload names don't compile. Physics-flush
## note: pickups are only ever spawned via DEFERRED calls (crate break and
## swap-drop both fire inside physics signals), so _ready never runs mid-flush.

const SFX := preload("res://fx/sfx_builder.gd")
const Drops := preload("res://level/drops.gd")

## Where the swap-dropped old weapon lands: far enough that the collecting
## player (body 5 + pickup 5 wide) isn't touching it — no re-pickup loop.
const SWAP_DROP_OFFSET := Vector2(-16.0, 0.0)

var kind: StringName = &"cells"
var payload = null # WeaponData for weapon; int heal for potion; int for cells

var _player_near := false
var _prompt: Label = null # "[F]" hint over weapon pickups


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
	if kind == &"weapon":
		body_entered.connect(_on_proximity.bind(true))
		body_exited.connect(_on_proximity.bind(false))
	else:
		body_entered.connect(_on_body_entered)


## Contact collection (potion / buff / curse / cells).
func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	match kind:
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


## Weapon proximity: show the [F] prompt; the swap happens on interact.
func _on_proximity(body: Node2D, entered: bool) -> void:
	if not body.is_in_group(&"player"):
		return
	_player_near = entered
	if _prompt:
		_prompt.visible = entered


func _unhandled_input(event: InputEvent) -> void:
	if kind == &"weapon" and _player_near and event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled() # one swap per press
		_swap_with(get_tree().get_first_node_in_group(&"player"))


func _swap_with(player) -> void:
	if player == null:
		return
	var old: WeaponData = player.weapon
	player.equip(payload)
	_play(SFX.unlock())
	if old != null:
		# deferred: we're inside a physics input flush; also this pickup is
		# about to be freed, so the spawn must be owned by the living class
		Drops.spawn.call_deferred(get_parent(), &"weapon", global_position + SWAP_DROP_OFFSET, old)
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
			_prompt = Label.new()
			_prompt.text = "[F]"
			_prompt.add_theme_font_size_override(&"font_size", 7)
			_prompt.add_theme_color_override(&"font_color", Color("ffd54a"))
			_prompt.position = Vector2(-5, -34)
			_prompt.visible = false
			add_child(_prompt)
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
			add_child(_diamond(_buff_color(), 6.0))
		&"cells":
			var cell := Polygon2D.new()
			cell.polygon = PackedVector2Array([
				Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
			cell.color = Color("ffd54a")
			add_child(cell)


func _buff_color() -> Color:
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
