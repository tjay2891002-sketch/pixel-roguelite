## Player SpriteFrames builder — from the set-1 fighter sheets (48px frames).
## States the AnimationPlayer does NOT drive directly (attack is frame-stepped
## by the AnimationPlayer with Call Method tracks; see placeholder_anims.gd).
## No class_name.

const FRAME := 48
const DIR := "res://assets/enemies/player/"

static var _frames: SpriteFrames


static func build() -> SpriteFrames:
	if _frames:
		return _frames
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add(frames, &"idle", DIR + "Idle.png", [0, 1, 2, 3], 8.0, true)
	_add(frames, &"run", DIR + "Walk.png", [0, 1, 2, 3, 4, 5], 12.0, true)
	# airborne / wall / ledge reuse walk + idle poses
	_add(frames, &"jump", DIR + "Walk.png", [3], 1.0, false)
	_add(frames, &"fall", DIR + "Walk.png", [5], 1.0, false)
	_add(frames, &"wall", DIR + "Idle.png", [0], 1.0, false)
	_add(frames, &"ledge", DIR + "Walk.png", [0, 1, 2], 10.0, false)
	_add(frames, &"hurt", DIR + "Hurt.png", [0, 1], 6.0, false)
	_add(frames, &"death", DIR + "Death.png", [0, 1, 2, 3, 4, 5], 10.0, false)
	# the 6-frame club swing (frame-stepped by the AnimationPlayer for combat)
	_add(frames, &"attack", DIR + "Attack.png", [0, 1, 2, 3, 4, 5], 12.0, false)
	_frames = frames
	return _frames


static func _add(frames: SpriteFrames, name: StringName, path: String, indices: Array, fps: float, loop: bool) -> void:
	var tex: Texture2D = load(path)
	frames.add_animation(name)
	frames.set_animation_loop(name, loop)
	frames.set_animation_speed(name, fps)
	for i in indices:
		var region := AtlasTexture.new()
		region.atlas = tex
		region.region = Rect2(i * FRAME, 0, FRAME, FRAME)
		frames.add_frame(name, region)
