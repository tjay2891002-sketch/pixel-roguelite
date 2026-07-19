## Placeholder animation builder — crude greybox attack clips, built in code
## so they're version-controllable and trivially replaced by real art later.
##
## Each clip's Call Method track fires _on_swing_active_start() (hitbox on +
## lunge) and hitbox_deactivate() at the active frames — the architecture's
## "hitboxes from animation Call Method tracks, never timers" rule (§2/§3).
## Preloaded by player.gd as a const; intentionally NO class_name.

const SLASH_ROT_START := -1.2
const SLASH_ROT_END := 1.2


static func build(anim_player: AnimationPlayer) -> void:
	var lib := AnimationLibrary.new()
	# (length, active_start, active_end) — mirrors data/weapons/sword.tres
	# cancel windows; keep in sync while in greybox.
	lib.add_animation(&"attack_1", _swing(0.35, 0.10, 0.22))
	lib.add_animation(&"attack_2", _swing(0.30, 0.08, 0.18))
	lib.add_animation(&"attack_3", _swing(0.45, 0.14, 0.26))
	anim_player.add_animation_library(&"", lib)


static func _swing(length: float, active_start: float, active_end: float) -> Animation:
	var anim := Animation.new()
	anim.length = length

	# Slash arc sweeps across the body during the active frames.
	var rot := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rot, ^"SlashArc:rotation")
	anim.track_insert_key(rot, 0.0, SLASH_ROT_START)
	anim.track_insert_key(rot, active_end, SLASH_ROT_END)
	anim.track_insert_key(rot, length, SLASH_ROT_END)

	var vis := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(vis, ^"SlashArc:visible")
	anim.value_track_set_update_mode(vis, Animation.UPDATE_DISCRETE)
	anim.track_insert_key(vis, 0.0, true)
	anim.track_insert_key(vis, active_end + 0.03, false)

	var calls := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(calls, ^".")
	anim.track_insert_key(calls, active_start, {"method": &"_on_swing_active_start", "args": []})
	anim.track_insert_key(calls, active_end, {"method": &"hitbox_deactivate", "args": []})
	return anim
