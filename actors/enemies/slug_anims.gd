## Slug SpriteFrames builder — from the Sunny Land Poo Goo sheets (32x21
## frames): move (6f) does idle/run/attack duty by speed; hurt sheet (7f)
## doubles as the death anim. No class_name.

const FRAME_W := 32
const FRAME_H := 21

static var _frames: SpriteFrames


static func build() -> SpriteFrames:
	if _frames:
		return _frames
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add(frames, &"idle", preload("res://assets/enemies/slug/move.png"), 2, 3.0, true)
	_add(frames, &"run", preload("res://assets/enemies/slug/move.png"), 6, 8.0, true)
	_add(frames, &"attack", preload("res://assets/enemies/slug/move.png"), 6, 14.0, false)
	_add(frames, &"hurt", preload("res://assets/enemies/slug/hurt.png"), 7, 10.0, false)
	_add(frames, &"death", preload("res://assets/enemies/slug/hurt.png"), 7, 5.0, false)
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
