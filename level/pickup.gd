extends Area2D
## Pickup — a crate drop on the floor. Shards collect on contact; the CURSE
## also fires on contact (it's the smash-a-crate landmine — opt-in would
## make it toothless). Everything else (weapon/potion/rage/swift) waits for
## a confirm: walk up and press interact (F) — a potion left on the floor
## can be saved for when you're actually hurt.
## Autoloads are resolved at RUNTIME (root.get_node): this script rides
## test preload chains where autoload names don't compile. Physics-flush
## note: pickups are only ever spawned via DEFERRED calls (crate break and
## swap-drop both fire inside physics signals), so _ready never runs mid-flush.

const SFX := preload("res://fx/sfx_builder.gd")
const Drops := preload("res://level/drops.gd")
const PotionTex := preload("res://assets/ui/icon_potion.png")
const GameFont := preload("res://fx/game_font.gd")

## Where the swap-dropped old weapon lands: far enough that the collecting
## player (body 5 + pickup 5 wide) isn't touching it — no re-pickup loop.
const SWAP_DROP_OFFSET := Vector2(-16.0, 0.0)

## Kinds that require the interact (F) confirm; the rest collect on contact.
const F_KINDS := [&"weapon", &"potion", &"rage", &"swift"]

## Weapon pickups are DUAL-purpose: tap F = equip/swap, LONG-PRESS F =
## dismantle into shards (the spare-weapon sink).
const DISMANTLE_HOLD := 0.45

var kind: StringName = &"shards"
var payload = null # WeaponData for weapon; int heal for potion; int for shards

var _player_near := false
var _prompt: Label = null # "[F] ..." hint over confirm pickups
var _prompt_text := ""
var _holding := false   # weapon: F currently held
var _hold_t := 0.0


func _init(p_kind: StringName = &"shards", p_payload = null) -> void:
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
	if kind in F_KINDS:
		body_entered.connect(_on_proximity.bind(true))
		body_exited.connect(_on_proximity.bind(false))
	else:
		body_entered.connect(_on_body_entered)


## Contact collection (shards / curse — the landmine).
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_collect(body)


## Confirm-pickup proximity: show the [F] prompt; collection is on interact.
func _on_proximity(body: Node2D, entered: bool) -> void:
	if not body.is_in_group(&"player"):
		return
	_player_near = entered
	if _prompt:
		_prompt.visible = entered
	if not entered:
		_cancel_hold()


func _unhandled_input(event: InputEvent) -> void:
	if not (kind in F_KINDS and _player_near):
		return
	if event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled() # one pickup/stand per press
		if kind == &"weapon":
			# dual-purpose: hold to dismantle, release early to equip
			_holding = true
			_hold_t = 0.0
		else:
			_collect(get_tree().get_first_node_in_group(&"player"))
	elif event.is_action_released(&"interact") and kind == &"weapon" and _holding:
		get_viewport().set_input_as_handled()
		_cancel_hold()
		_collect(get_tree().get_first_node_in_group(&"player")) # tap = equip


func _physics_process(delta: float) -> void:
	# game-time ticks (not idle real-time): deterministic under hitstop
	if _holding:
		_hold_t += delta
		if _hold_t >= DISMANTLE_HOLD:
			_cancel_hold()
			_dismantle()
		elif _prompt:
			_prompt.text = "分解中…"


func _cancel_hold() -> void:
	_holding = false
	_hold_t = 0.0
	if _prompt and not _prompt_text.is_empty():
		_prompt.text = _prompt_text


## Long-press payoff: crush the weapon into shards (value = half its unlock
## cost, min 4). The player keeps whatever they're holding.
func _dismantle() -> void:
	var save = get_tree().root.get_node_or_null("SaveStub")
	if save:
		save.add_shards(_dismantle_value(payload))
	_play(SFX.kill()) # crunch
	queue_free()


func _dismantle_value(w: WeaponData) -> int:
	for entry in Drops.WEAPON_POOL:
		if (entry[&"data"] as WeaponData).id == w.id:
			return maxi(4, int(entry[&"cost"]) / 2)
	return 4


func _collect(player) -> void:
	if player == null:
		return
	match kind:
		&"weapon":
			var old: WeaponData = player.weapon
			player.equip(payload)
			_play(SFX.unlock())
			if old != null:
				# deferred: we may be inside a physics input flush; also this
				# pickup is about to be freed, so the spawn must be owned by
				# the living class
				Drops.spawn.call_deferred(get_parent(), &"weapon", global_position + SWAP_DROP_OFFSET, old)
		&"potion":
			player.health.hp = mini(player.health.hp + int(payload), player.health.max_hp)
			_play(SFX.heal())
		&"rage", &"swift":
			player.apply_buff(kind)
			_play(SFX.buff())
		&"curse":
			player.apply_buff(kind)
			_play(SFX.deny())
		&"shards":
			var save = get_tree().root.get_node_or_null("SaveStub")
			if save:
				save.add_shards(int(payload))
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
			GameFont.apply(label)
			label.add_theme_font_size_override(&"font_size", 7)
			label.add_theme_color_override(&"font_color", Color("e8eef2"))
			label.position = Vector2(-16, -22)
			add_child(label)
			_make_prompt("[F] 装备 · 长按分解+%d" % _dismantle_value(payload))
		&"potion":
			add_child(_bottle(Color.WHITE)) # untinted = heal
			_make_prompt("[F] 治疗")
		&"rage", &"swift", &"curse":
			# buff potions: the flask tinted per effect
			add_child(_bottle(_buff_color()))
			if kind != &"curse":
				_make_prompt("[F] " + ("狂暴" if kind == &"rage" else "疾速"))
		&"shards":
			# light-crystal diamond — reads "special currency", not a buff
			add_child(_diamond(Color("80d8ff"), 4.5))


func _make_prompt(text: String) -> void:
	_prompt = Label.new()
	_prompt_text = text
	_prompt.text = text
	GameFont.apply(_prompt)
	_prompt.add_theme_font_size_override(&"font_size", 8)
	_prompt.add_theme_color_override(&"font_color", Color("ffd54a"))
	# longer weapon prompt (equip + dismantle) needs more left room
	_prompt.position = Vector2(-38.0 if kind == &"weapon" else -10.0, -34)
	_prompt.visible = false
	add_child(_prompt)


func _buff_color() -> Color:
	# mirror of player.BUFFS colors — kept local to stay autoload-free
	match kind:
		&"rage": return Color("ef5350")
		&"swift": return Color("4dd0e1")
		&"curse": return Color("ab47bc")
	return Color.WHITE


## Potion-bottle sprite (heal/buff pickups share the flask; tint separates).
func _bottle(tint: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = PotionTex
	s.modulate = tint
	s.position = Vector2(0, -6)
	return s


func _diamond(color: Color, r: float) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
	p.color = color
	return p
