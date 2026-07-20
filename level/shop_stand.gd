extends Area2D
## ShopStand — a one-time purchase stand (M5 light economy). Walk up and
## press move_up to buy: heal restores HP, dagger equips the weapon
## (data-driven: player.weapon just swaps the WeaponData resource).

const SFX := preload("res://fx/sfx_builder.gd")
const Dagger := preload("res://data/weapons/dagger.tres")

@export var offer := &"heal"
@export var cost := 10
@export var stand_text := "Heal 10HP"

var _in_range := false


func _ready() -> void:
	add_to_group(&"shop_stand")
	$Label.text = "%s [%dc]" % [stand_text, cost]
	body_entered.connect(func(_b): _in_range = true)
	body_exited.connect(func(_b): _in_range = false)


func _unhandled_input(event: InputEvent) -> void:
	if _in_range and event.is_action_pressed(&"move_up"):
		_try_buy()


func _try_buy() -> void:
	var cells := int(SaveStub.data.get("currency", 0))
	if cells < cost:
		AudioBus.play_sfx(SFX.deny(), global_position)
		return
	var player := get_tree().get_first_node_in_group(&"player")
	if offer == &"heal":
		player.health.hp = mini(player.health.hp + 10, player.health.max_hp)
	elif offer == &"dagger":
		player.set("weapon", Dagger)
	SaveStub.data["currency"] = cells - cost
	EventBus.currency_dropped.emit(-cost, global_position)
	AudioBus.play_sfx(SFX.pickup(), global_position)
	queue_free()
