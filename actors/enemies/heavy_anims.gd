## Heavy SpriteFrames builder — from the set-2 sheets (48px frames).
## attack has 9 frames (the big slam). No class_name.

const FRAME := 48

static var _frames: SpriteFrames


static func build() -> SpriteFrames:
	if _frames:
		return _frames
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add(frames, &"idle", preload("res://assets/enemies/heavy/Idle.png"), 4, 8.0, true)
	_add(frames, &"run", preload("res://assets/enemies/heavy/Walk.png"), 6, 10.0, true)
	_add(frames, &"attack", preload("res://assets/enemies/heavy/Attack.png"), 9, 12.0, false)
	_add(frames, &"hurt", preload("res://assets/enemies/heavy/Hurt.png"), 2, 1.0, false)
	_add(frames, &"death", preload("res://assets/enemies/heavy/Death.png"), 6, 10.0, false)
	_frames = frames
	return _frames


static func _add(frames: SpriteFrames, name: StringName, tex: Texture2D, count: int, fps: float, loop: bool) -> void:
	frames.add_animation(name)
	frames.set_animation_loop(name, loop)
	frames.set_animation_speed(name, fps)
	for i in count:
		var region := AtlasTexture.new()
		region.atlas = tex
		region.region = Rect2(i * FRAME, 0, FRAME, FRAME)
		frames.add_frame(name, region)
