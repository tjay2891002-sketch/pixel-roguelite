extends Area2D
## ShopStand — a one-time purchase stand (M5 light economy). Walk up and
## press interact (F) to buy. Offers: heal restores HP; weapon permanently
## UNLOCKS the weapon (SaveStub meta pool — unlocks are what crate drops
## roll from) and equips it on the spot.
## Visual: crate base + floating offer icon (potion=heal, dagger=weapon) + cost.

const SFX := preload("res://fx/sfx_builder.gd")
const IconPotion := preload("res://assets/ui/icon_potion.png")
const IconDagger := preload("res://assets/ui/icon_dagger.png")

@export var offer := &"heal"
@export var cost := 10
@export var stand_text := "Heal 10HP"

var weapon: WeaponData = null # set by the stage for offer == &"weapon"

var _in_range := false


func _ready() -> void:
	add_to_group(&"shop_stand")
	$Cost.text = "%d" % cost
	$Cost.add_theme_color_override(&"font_color", Color("ffd54a")) # gold = coin price
	$Icon.texture = IconPotion if offer == &"heal" else IconDagger
	body_entered.connect(func(_b): _in_range = true)
	body_exited.connect(func(_b): _in_range = false)


func _unhandled_input(event: InputEvent) -> void:
	if _in_range and event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled() # one stand/pickup per press
		_try_buy()


func _try_buy() -> void:
	var cells := int(SaveStub.data.get("currency", 0))
	if cells < cost:
		AudioBus.play_sfx(SFX.deny(), global_position)
		return
	var player := get_tree().get_first_node_in_group(&"player")
	if offer == &"heal":
		player.health.hp = mini(player.health.hp + 10, player.health.max_hp)
	elif offer == &"weapon" and weapon != null:
		SaveStub.unlock_weapon(weapon.id)
		player.equip(weapon)
	else:
		return
	SaveStub.data["currency"] = cells - cost
	EventBus.currency_dropped.emit(-cost, global_position)
	AudioBus.play_sfx(SFX.pickup(), global_position)
	queue_free()
