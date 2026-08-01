## Procedural SFX builder — tiny synthesized AudioStreamWAVs, no assets.
## Everything is generated once and cached. Preloaded as a const; no class_name.

const RATE := 22050
const HIT_SOUND := preload("res://assets/audio/sfx_hit.ogg")
const KILL_SOUND := preload("res://assets/audio/sfx_kill.ogg")
# one whoosh per combo step (split from freesound "Whoosh Triple")
const SWING_SOUNDS := [
	preload("res://assets/audio/sfx_swing_1.ogg"),
	preload("res://assets/audio/sfx_swing_2.ogg"),
	preload("res://assets/audio/sfx_swing_3.ogg"),
]

static var _cache := {}


static func swing(step: int = 0) -> AudioStream: return SWING_SOUNDS[clampi(step, 0, SWING_SOUNDS.size() - 1)]
static func hit() -> AudioStream: return HIT_SOUND
static func kill() -> AudioStream: return KILL_SOUND
static func roll() -> AudioStreamWAV: return _cached(&"roll", _noise(0.07, 0.35))
static func pickup() -> AudioStreamWAV: return _cached(&"pickup", _tone(660.0, 990.0, 0.1, 0.5))
static func jump() -> AudioStreamWAV: return _cached(&"jump", _tone(250.0, 450.0, 0.08, 0.4))
static func unlock() -> AudioStreamWAV: return _cached(&"unlock", _tone(150.0, 80.0, 0.12, 0.5))
static func death() -> AudioStreamWAV: return _cached(&"death", _tone(200.0, 50.0, 0.5, 0.6))
static func deny() -> AudioStreamWAV: return _cached(&"deny", _tone(120.0, 90.0, 0.1, 0.5))
static func heal() -> AudioStreamWAV: return _cached(&"heal", _tone(520.0, 780.0, 0.14, 0.45))
static func buff() -> AudioStreamWAV: return _cached(&"buff", _tone(440.0, 660.0, 0.12, 0.4))
static func levelup() -> AudioStreamWAV: return _cached(&"levelup", _tone(660.0, 1320.0, 0.2, 0.45))
static func roar() -> AudioStreamWAV: return _cached(&"roar", _tone(90.0, 55.0, 0.35, 0.6))
static func spring() -> AudioStreamWAV: return _cached(&"spring", _tone(180.0, 620.0, 0.14, 0.5))


static func _cached(key: StringName, stream: AudioStreamWAV) -> AudioStreamWAV:
	if not _cache.has(key):
		_cache[key] = stream
	return _cache[key]


static func _noise(duration: float, volume: float) -> AudioStreamWAV:
	var frames := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(frames)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234567
	for i in frames:
		var t := float(i) / frames
		var env := (1.0 - t) * (1.0 - t)
		var s: float = rng.randf_range(-1.0, 1.0) * volume * env
		data[i] = int(clampf(s * 127.0, -127.0, 127.0)) & 0xFF
	return _make(data)


static func _tone(freq_a: float, freq_b: float, duration: float, volume: float) -> AudioStreamWAV:
	var frames := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(frames)
	var phase := 0.0
	for i in frames:
		var t := float(i) / frames
		phase += lerpf(freq_a, freq_b, t) / RATE * TAU
		var env := (1.0 - t) * (1.0 - t)
		var s: float = sin(phase) * volume * env
		data[i] = int(clampf(s * 127.0, -127.0, 127.0)) & 0xFF
	return _make(data)


static func _make(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
