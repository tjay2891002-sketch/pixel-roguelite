## Placeholder animation builder — crude greybox attack clips, built in code
## so they're version-controllable and trivially replaced by real art later.
##
## Each chain step is VISUALLY DISTINCT (docs §3 wants data-driven steps;
## greybox proves the variety pipeline): sword = slash / reverse / thrust,
## dagger = faster lighter variants. Call Method tracks fire
## _on_swing_active_start() (hitbox on + lunge) and hitbox_deactivate() at
## the active frames — never timers. Timings mirror data/weapons/*.tres.
## Preloaded by player.gd as a const; intentionally NO class_name.

const ARC_PATH := ^"SlashPivot/SlashArc"


static func build(anim_player: AnimationPlayer) -> void:
	var lib := AnimationLibrary.new()
	# (length, active_start, active_end) — mirrors data/weapons/*.tres
	lib.add_animation(&"sword_1", _slash(0.35, 0.10, 0.22, -1.2, 1.2, Color(0.95, 0.95, 1.0, 0.75)))
	lib.add_animation(&"sword_2", _slash(0.28, 0.07, 0.16, 1.2, -1.2, Color(0.85, 1.0, 0.9, 0.75)))
	lib.add_animation(&"sword_3", _thrust(0.48, 0.16, 0.28, Color(1.0, 0.85, 0.6, 0.85)))
	lib.add_animation(&"dagger_1", _slash(0.24, 0.06, 0.14, -1.2, 1.2, Color(0.75, 0.9, 1.0, 0.7)))
	lib.add_animation(&"dagger_2", _slash(0.20, 0.05, 0.12, 1.2, -1.2, Color(0.85, 0.95, 1.0, 0.7)))
	lib.add_animation(&"dagger_3", _thrust(0.30, 0.09, 0.20, Color(1.0, 0.95, 0.7, 0.8)))
	anim_player.add_animation_library(&"", lib)


## Shared track skeleton: color, visibility window, hitbox call tracks.
static func _base(length: float, active_start: float, active_end: float, color: Color) -> Animation:
	var anim := Animation.new()
	anim.length = length

	var mod := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(mod, NodePath(String(ARC_PATH) + ":modulate"))
	anim.track_insert_key(mod, 0.0, color)

	var vis := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(vis, NodePath(String(ARC_PATH) + ":visible"))
	anim.value_track_set_update_mode(vis, Animation.UPDATE_DISCRETE)
	anim.track_insert_key(vis, 0.0, true)
	anim.track_insert_key(vis, active_end + 0.03, false)

	var calls := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(calls, ^".")
	anim.track_insert_key(calls, active_start, {"method": &"_on_swing_active_start", "args": []})
	anim.track_insert_key(calls, active_end, {"method": &"hitbox_deactivate", "args": []})
	return anim


## Steps 1 & 2: the arc sweeps across the body (opposite directions).
static func _slash(length: float, active_start: float, active_end: float, rot_from: float, rot_to: float, color: Color) -> Animation:
	var anim := _base(length, active_start, active_end, color)
	var rot := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rot, NodePath(String(ARC_PATH) + ":rotation"))
	anim.track_insert_key(rot, 0.0, rot_from)
	anim.track_insert_key(rot, active_end, rot_to)
	anim.track_insert_key(rot, length, rot_to)
	var pos := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(pos, NodePath(String(ARC_PATH) + ":position"))
	anim.track_insert_key(pos, 0.0, Vector2.ZERO)
	return anim


## Step 3: the arc holds still and stabs forward.
static func _thrust(length: float, active_start: float, active_end: float, color: Color) -> Animation:
	var anim := _base(length, active_start, active_end, color)
	var rot := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rot, NodePath(String(ARC_PATH) + ":rotation"))
	anim.track_insert_key(rot, 0.0, 0.0)
	var pos := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(pos, NodePath(String(ARC_PATH) + ":position"))
	anim.track_insert_key(pos, 0.0, Vector2(-4, 0))
	anim.track_insert_key(pos, active_start, Vector2(-4, 0))
	anim.track_insert_key(pos, active_end, Vector2(14, 0))
	anim.track_insert_key(pos, length, Vector2(14, 0))
	return anim
