extends Node
## SaveStub — the ONLY meta-progression seam (docs/ARCHITECTURE.md §1, §9).
##
## Persists a flat dictionary to user://save.json on run end. Future hub
## upgrades/unlocks read this; no meta systems exist yet by design.

const SAVE_PATH := "user://save.json"
## Weapon unlock pool (meta): the starter sword is always unlocked; shop
## unlocks append here and persist via flush().
const DEFAULT_UNLOCKED: Array = [&"sword"]

var data: Dictionary = {}


func _ready() -> void:
	load_data()


func load_data() -> void:
	# headless == tests: start from an EMPTY dict and never read the real
	# save — a late load_data replacing `data` mid-test was a flake source
	if DisplayServer.get_name() == "headless":
		return
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("[SaveStub] could not open save file: %s" % error_string(FileAccess.get_open_error()))
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		data = parsed
		if data.has("currency"): # legacy save key -> coins
			data["coins"] = int(data["currency"])
			data.erase("currency")


func flush() -> void:
	# tests run headless and must never touch the player's real save file
	if DisplayServer.get_name() == "headless":
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[SaveStub] could not write save file: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))


## Coins (金币) — the shop/meta money: treasure rooms + persists across
## deaths; spent at shops and on death-screen permanent unlocks.
func add_coins(amount: int) -> void:
	data["coins"] = int(data.get("coins", 0)) + amount


## Shards (魔晶) — the ENCHANT money: crate drops + boss rewards.
## Coins (above) stay the shop money; shards feed the boss-room enchant pool.
func add_shards(amount: int) -> void:
	data["shards"] = int(data.get("shards", 0)) + amount


# --- weapon unlock pool ------------------------------------------------------

func unlocked_weapons() -> Array:
	return data.get("unlocked_weapons", DEFAULT_UNLOCKED)


func is_weapon_unlocked(id: StringName) -> bool:
	return unlocked_weapons().has(id)


func unlock_weapon(id: StringName) -> void:
	if is_weapon_unlocked(id):
		return
	if not data.has("unlocked_weapons"):
		# copy the default FIRST — never mutate the const
		data["unlocked_weapons"] = DEFAULT_UNLOCKED.duplicate()
	data["unlocked_weapons"].append(id)
	flush()
