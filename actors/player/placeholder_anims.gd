## Placeholder animation builder — builds the player's ATTACK clips on the
## AnimationPlayer. Each clip frame-steps the real fighter sprite through the
## 6-frame club swing, with Call Method tracks firing hitbox-on/lunge
## (_on_swing_active_start) and hitbox-off (hitbox_deactivate) at the active
## frames — never timers (docs §2/§3). Timings mirror data/weapons/*.tres.
## Preloaded by player.gd as a const; intentionally NO class_name.

const SWING_FRAMES := 6
const SPRITE := ^"Sprite"


static func build(anim_player: AnimationPlayer) -> void:
	var lib := AnimationLibrary.new()
	# (length, active_start, active_end) — mirrors data/weapons/sword.tres
	# cancel windows; the impact frame (2) lands at active_start.
	lib.add_animation(&"sword_1", _swing(0.35, 0.10, 0.22))
	lib.add_animation(&"sword_2", _swing(0.28, 0.07, 0.16))
	lib.add_animation(&"sword_3", _swing(0.48, 0.14, 0.26))
	# dagger steps share the same art, faster pacing
	lib.add_animation(&"dagger_1", _swing(0.24, 0.06, 0.14))
	lib.add_animation(&"dagger_2", _swing(0.20, 0.05, 0.12))
	lib.add_animation(&"dagger_3", _swing(0.30, 0.09, 0.20))
	anim_player.add_animation_library(&"", lib)


static func _swing(length: float, active_start: float, active_end: float) -> Animation:
	var anim := Animation.new()
	anim.length = length

	# lock manual stepping: stop auto-play, use the "attack" anim
	var setup := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(setup, SPRITE)
	anim.track_insert_key(setup, 0.0, {"method": &"stop", "args": []})

	var set_anim := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(set_anim, NodePath(String(SPRITE) + ":animation"))
	anim.value_track_set_update_mode(set_anim, Animation.UPDATE_DISCRETE)
	anim.track_insert_key(set_anim, 0.0, &"attack")

	# step frames: windup (0,1) before active_start, impact (2) at it,
	# follow-through (3,4,5) after
	var frames := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(frames, NodePath(String(SPRITE) + ":frame"))
	anim.value_track_set_update_mode(frames, Animation.UPDATE_DISCRETE)
	var times := _frame_times(length, active_start)
	for i in SWING_FRAMES:
		anim.track_insert_key(frames, times[i], i)

	# hitbox on + lunge at active start, off at active end (player methods)
	var calls := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(calls, ^".")
	anim.track_insert_key(calls, active_start, {"method": &"_on_swing_active_start", "args": []})
	anim.track_insert_key(calls, active_end, {"method": &"hitbox_deactivate", "args": []})
	return anim


static func _frame_times(length: float, active_start: float) -> Array:
	# frames 0,1 in windup; frame 2 (impact) at active_start; 3,4,5 after
	var t2 := active_start
	var times := [0.0, t2 * 0.5, t2]
	var span := length - t2
	for k in range(1, 4):
		times.append(t2 + span * k / 4.0)
	return times
