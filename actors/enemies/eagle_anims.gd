## Eagle SpriteFrames builder — from the Sunny Land eagle sheets (40x41 frames).
## Only dive-attack (2f) + hurt (6f) exist; idle/run reuse the dive-attack
## frames (slow = hover, fast = fly), death reuses hurt. No class_name.

const FRAME_W := 40
const FRAME_H := 41

static var _frames: SpriteFrames


static func build() -> SpriteFrames:
	if _frames:
		return _frames
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add(frames, &"idle", preload("res://assets/enemies/eagle/attack.png"), 2, 4.0, true)
	_add(frames, &"run", preload("res://assets/enemies/eagle/attack.png"), 2, 6.0, true)
	_add(frames, &"attack", preload("res://assets/enemies/eagle/attack.png"), 2, 8.0, false)
	_add(frames, &"hurt", preload("res://assets/enemies/eagle/hurt.png"), 6, 8.0, false)
	_add(frames, &"death", preload("res://assets/enemies/eagle/hurt.png"), 6, 6.0, false)
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
