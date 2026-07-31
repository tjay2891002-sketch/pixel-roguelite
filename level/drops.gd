## Drop table + pickup spawning for smashed props. Static, autoload-free
## (runtime lookups only) so test --script preload chains can include it.
## Weights are rolled on RunManager's run RNG when available.

const Pickup := preload("res://level/pickup.gd")

const WEAPON_POOL := [
	preload("res://data/weapons/sword.tres"),
	preload("res://data/weapons/dagger.tres"),
	preload("res://data/weapons/axe.tres"),
]

## [kind, weight] — potion payload is a fraction of max hp, resolved on spawn.
const TABLE := [
	[&"weapon", 15],
	[&"potion", 25],
	[&"rage", 20],
	[&"swift", 20],
	[&"cells", 15],
	[&"curse", 5],
]

## Tests flip this off so prop-break coverage stays deterministic.
static var auto_drops_enabled := true


## Roll the table and spawn the winning pickup at pos. `parent` is the stage.
static func roll_crate_drop(parent: Node, pos: Vector2) -> void:
	if not auto_drops_enabled:
		return
	var total := 0
	for entry in TABLE:
		total += entry[1]
	var roll := _rng_float(parent) * total
	var kind: StringName = &"cells"
	for entry in TABLE:
		roll -= entry[1]
		if roll < 0.0:
			kind = entry[0]
			break
	spawn(parent, kind, pos)


## Spawn a specific pickup (tests drive this directly).
static func spawn(parent: Node, kind: StringName, pos: Vector2) -> Area2D:
	var payload = null
	match kind:
		&"weapon":
			payload = _pick_weapon(parent)
			if payload == null:
			# pool exhausted (shouldn't happen with 3 weapons) -> cells
				kind = &"cells"
				payload = 4
		&"potion":
			payload = _potion_amount(parent)
		&"cells":
			payload = 4
	var p: Area2D = Pickup.new(kind, payload)
	parent.add_child(p)
	p.global_position = pos
	return p


## A weapon the player isn't currently holding.
static func _pick_weapon(parent: Node):
	var player := parent.get_tree().get_first_node_in_group(&"player")
	var held: StringName = &"" if player == null else player.weapon.id
	var options: Array = []
	for w in WEAPON_POOL:
		if w.id != held:
			options.append(w)
	if options.is_empty():
		return null
	return options[int(_rng_float(parent) * options.size()) % options.size()]


static func _potion_amount(parent: Node) -> int:
	var player := parent.get_tree().get_first_node_in_group(&"player")
	var max_hp = 30 if player == null else player.health.max_hp # untyped: Variant
	return maxi(1, int(round(max_hp * 0.3)))


static func _rng_float(parent: Node) -> float:
	var rm = parent.get_tree().root.get_node_or_null("RunManager")
	if rm:
		return rm.roll_float()
	return randf()
