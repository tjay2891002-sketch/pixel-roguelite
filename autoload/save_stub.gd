extends Node
## SaveStub — the ONLY meta-progression seam (docs/ARCHITECTURE.md §1, §9).
##
## Persists a flat dictionary to user://save.json on run end. Future hub
## upgrades/unlocks read this; no meta systems exist yet by design.

const SAVE_PATH := "user://save.json"

var data: Dictionary = {}


func _ready() -> void:
	load_data()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("[SaveStub] could not open save file: %s" % error_string(FileAccess.get_open_error()))
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		data = parsed


func flush() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[SaveStub] could not write save file: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))


## Convenience for the currency seam — RunManager/EventBus call this; nothing
## spends it yet.
func add_currency(amount: int) -> void:
	data["currency"] = int(data.get("currency", 0)) + amount
