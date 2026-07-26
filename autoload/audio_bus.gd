extends Node
## AudioBus — pooled positional SFX + looping music. Pooling avoids allocation
## spikes when many one-shot sounds fire on the same frame (docs §1).
##
## Music: a single looping track on the "Music" bus, started at launch and
## kept playing across stages/reloads.

const POOL_SIZE := 16
const BGM := preload("res://assets/audio/bgm_village.ogg")

var _pool: Array[AudioStreamPlayer2D] = []
var _next := 0


func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer2D.new()
		player.bus = &"SFX"
		add_child(player)
		_pool.append(player)
	_start_music()


func _start_music() -> void:
	var music := AudioStreamPlayer.new()
	music.bus = &"Music"
	music.stream = BGM
	music.volume_db = -9.0 # sit under the SFX
	add_child(music)
	music.play()
	# loop manually (can't set .loop on a const; re-play when it finishes)
	music.finished.connect(music.play)


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
