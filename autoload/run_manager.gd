extends Node
## RunManager — run lifecycle: seed, biome sequence, stage loading, death/restart.
##
## M1 scope: seed plumbing + start_run only. Stage generation arrives in M3;
## until then start_run just loads the greybox playground.

var run_seed: int = 0
var biome_index: int = 0

## Run-scoped progression (resets in start_run; survives stage regenerates,
## which don't reload the scene). Level feeds player damage/max_hp.
var level := 1
var xp := 0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)


## Starts a new run. Pass 0 for a random seed.
func start_run(seed: int = 0) -> void:
	run_seed = seed if seed != 0 else randi()
	biome_index = 0
	level = 1
	xp = 0
	_rng.seed = run_seed
	print("[RunManager] run started, seed=%d" % run_seed)


## XP to go from `level` to the next. Gentle early curve: first levels come
## from a handful of kills.
func xp_needed() -> int:
	return 15 + (level - 1) * 10


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		EventBus.leveled_up.emit(level)


## Run-RNG float for gameplay rolls (crate drops). Deterministic per run in
## roll ORDER — combat order isn't seeded, so drops aren't either; fine.
func roll_float() -> float:
	return _rng.randf()


## Deterministic RNG for a stage — any stage reproduces in isolation
## (docs/ARCHITECTURE.md §5: "seed 81244, stage 2" must replay identically).
func stage_rng(stage: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(run_seed) ^ hash(stage * 2654435761)
	return rng


func _on_player_died() -> void:
	# M5: the stage shows the death screen and reloads on input; we just
	# persist the run's currency.
	SaveStub.flush()
