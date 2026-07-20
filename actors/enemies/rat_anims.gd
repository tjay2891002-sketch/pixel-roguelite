## Rat SpriteFrames builder — builds the rat's animation set from the
## outlined sprite sheets (32x32 frames). Preloaded by enemy.gd for
## AnimatedSprite2D actors; intentionally NO class_name.

const FRAME := 32

static var _frames: SpriteFrames


static func build() -> SpriteFrames:
	if _frames:
		return _frames
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add(frames, &"idle", preload("res://assets/enemies/rat/rat-idle-outline.png"), 6, 10.0, true)
	_add(frames, &"run", preload("res://assets/enemies/rat/rat-run-outline.png"), 6, 12.0, true)
	_add(frames, &"attack", preload("res://assets/enemies/rat/rat-attack-outline.png"), 6, 12.0, false)
	_add(frames, &"hurt", preload("res://assets/enemies/rat/rat-hurt-outline.png"), 1, 1.0, false)
	_add(frames, &"death", preload("res://assets/enemies/rat/rat-death-outline.png"), 6, 10.0, false)
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
