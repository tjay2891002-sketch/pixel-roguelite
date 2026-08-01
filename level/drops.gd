## Drop table + pickup spawning for smashed props. Static, autoload-free
## (runtime lookups only) so test --script preload chains can include it.
## Weights are rolled on RunManager's run RNG when available.
## pickup.gd is loaded at RUNTIME (not preloaded): pickup.gd preloads THIS
## script for the deferred swap-spawn — a preload both ways would cycle.

## The weapon pool: data + unlock cost (sword is the free starter). Only
## UNLOCKED weapons drop (SaveStub); the shop sells the unlocks.
const WEAPON_POOL := [
	{&"data": preload("res://data/weapons/sword.tres"), &"cost": 0},
	{&"data": preload("res://data/weapons/dagger.tres"), &"cost": 15},
	{&"data": preload("res://data/weapons/spear.tres"), &"cost": 20},
	{&"data": preload("res://data/weapons/greatsword.tres"), &"cost": 25},
	{&"data": preload("res://data/weapons/axe.tres"), &"cost": 25},
	{&"data": preload("res://data/weapons/hammer.tres"), &"cost": 30},
]

## [kind, weight] — potion payload is a fraction of max hp, resolved on spawn.
## coins are NOT here on purpose: crate rolls pay SHARDS (the enchant
## money); coins come from treasure rooms and feed the shop.
const TABLE := [
	[&"weapon", 15],
	[&"potion", 25],
	[&"rage", 20],
	[&"swift", 20],
	[&"shards", 15],
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
	var kind: StringName = &"shards"
	for entry in TABLE:
		roll -= entry[1]
		if roll < 0.0:
			kind = entry[0]
			break
	spawn(parent, kind, pos)


## Spawn a specific pickup (tests drive this directly; an explicit payload
## skips the table-driven resolution — the weapon swap-drop uses that).
static func spawn(parent: Node, kind: StringName, pos: Vector2, payload = null) -> Area2D:
	if payload == null:
		match kind:
			&"weapon":
				payload = _pick_weapon(parent)
				if payload == null:
				# pool exhausted -> shards fallback
					kind = &"shards"
					payload = 4
			&"potion":
				payload = _potion_amount(parent)
			&"shards":
				payload = 4
	var p: Area2D = load("res://level/pickup.gd").new(kind, payload)
	parent.add_child(p)
	p.global_position = pos
	return p


## A weapon the player isn't currently holding, from the UNLOCKED pool
## (SaveStub). Returns null when nothing qualifies (caller falls back).
static func _pick_weapon(parent: Node):
	var player := parent.get_tree().get_first_node_in_group(&"player")
	var held: StringName = &"" if player == null else player.weapon.id
	var save = parent.get_tree().root.get_node_or_null("SaveStub")
	var options: Array = []
	for entry in WEAPON_POOL:
		var w = entry[&"data"]
		if w.id == held:
			continue
		if save and not save.is_weapon_unlocked(w.id):
			continue
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


## Boss kill reward line: weapon, potion, two shard piles — spaced 20px
## starting at pos (the stage picks a FLOOR spot clear of the pool/door);
## spawns are deferred (the kill signal fires inside the physics flush).
static func spawn_boss_reward(parent: Node, pos: Vector2) -> void:
	spawn.call_deferred(parent, &"weapon", pos)
	spawn.call_deferred(parent, &"potion", pos + Vector2(20.0, 0.0))
	spawn.call_deferred(parent, &"shards", pos + Vector2(40.0, 0.0), 10)
	spawn.call_deferred(parent, &"shards", pos + Vector2(56.0, 0.0), 10)
