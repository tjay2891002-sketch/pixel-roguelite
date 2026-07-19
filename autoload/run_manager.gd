extends Node
## RunManager — run lifecycle: seed, biome sequence, stage loading, death/restart.
##
## M1 scope: seed plumbing + start_run only. Stage generation arrives in M3;
## until then start_run just loads the greybox playground.

var run_seed: int = 0
var biome_index: int = 0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)


## Starts a new run. Pass 0 for a random seed.
func start_run(seed: int = 0) -> void:
	run_seed = seed if seed != 0 else randi()
	biome_index = 0
	_rng.seed = run_seed
	print("[RunManager] run started, seed=%d" % run_seed)


## Deterministic RNG for a stage — any stage reproduces in isolation
## (docs/ARCHITECTURE.md §5: "seed 81244, stage 2" must replay identically).
func stage_rng(stage: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(run_seed) ^ hash(stage * 2654435761)
	return rng


func _on_player_died() -> void:
	# M5: death screen -> new run. For now just restart the current scene.
	SaveStub.flush()
	get_tree().reload_current_scene()
