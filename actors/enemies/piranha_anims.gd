## Piranha-plant SpriteFrames builder — Sunny Land sheets (61x45 frames):
## shoot (4f) drives idle/run/attack, hurt (8f) doubles as death.
## No class_name.

const FRAME_W := 61
const FRAME_H := 45

static var _frames: SpriteFrames


static func build() -> SpriteFrames:
	if _frames:
		return _frames
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add(frames, &"idle", preload("res://assets/enemies/piranha/shoot.png"), 2, 3.0, true)
	_add(frames, &"run", preload("res://assets/enemies/piranha/shoot.png"), 4, 6.0, true)
	_add(frames, &"attack", preload("res://assets/enemies/piranha/shoot.png"), 4, 12.0, false)
	_add(frames, &"hurt", preload("res://assets/enemies/piranha/hurt.png"), 8, 10.0, false)
	_add(frames, &"death", preload("res://assets/enemies/piranha/hurt.png"), 8, 6.0, false)
	_frames = frames
	return _frames


static func _add(frames: SpriteFrames, name: StringName, tex: Texture2D, count: int, fps: float, loop: bool) -> void:
	frames.add_animation(name)
	frames.set_animation_loop(name, loop)
	frames.set_animation_speed(name, fps)
	for i in count:
		var region := AtlasTexture.new()
		region.atlas = tex
		region.region = Rect2(i * FRAME_W, 0, FRAME_W, FRAME_H)
		frames.add_frame(name, region)
