extends Node
## AudioBus — pooled positional SFX + music. Pooling avoids allocation spikes
## when many one-shot sounds fire on the same frame (docs/ARCHITECTURE.md §1).
##
## M1 scope: SFX pool only; music + buses wired in M5.

const POOL_SIZE := 16

var _pool: Array[AudioStreamPlayer2D] = []
var _next := 0


func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer2D.new()
		player.bus = &"SFX"
		add_child(player)
		_pool.append(player)


## Play a one-shot at a world position. Steals the oldest player if the pool
## is exhausted — acceptable for SFX, never allocate at runtime.
func play_sfx(stream: AudioStream, world_position: Vector2, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var player := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stop()
	player.stream = stream
	player.global_position = world_position
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()
