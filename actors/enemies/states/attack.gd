extends "res://actors/player/state_machine/state.gd"
## Enemy Attack — brief active window with the hitbox live, then recovery.
## The swipe arc sweeps across the strike (active + a little follow-through).
## Greybox enemies drive this with explicit timers in the state (the
## no-timers rule applies to animation-synced player weapon swings).

const SWIPE_DURATION := 0.25 # visual sweep length (active is only 0.12s)

var _phase := 0 # 0 = active, 1 = recovery
var _timer := 0.0
var _swipe_t := 0.0
var _arc


func enter() -> void:
	tint("#e57373")
	_phase = 0
	_timer = actor.attack_active_time
	_swipe_t = 0.0
	actor.velocity.x = actor.facing * 40.0 # small forward hop
	actor.hitbox.activate(actor.swipe_hit_info())
	_arc = actor.get_node_or_null("SlashPivot/SlashArc")
	if _arc:
		_arc.rotation = -1.2
		_arc.modulate.a = 1.0
		_arc.visible = true


func exit() -> void:
	actor.hitbox.deactivate()
	if _arc:
		_arc.visible = false
		_arc = null


func physics_update(delta: float) -> void:
	_timer -= delta
	_swipe_t += delta
	if _arc:
		_arc.rotation = lerpf(-1.2, 1.2, clampf(_swipe_t / SWIPE_DURATION, 0.0, 1.0))
	if _phase == 0:
		if _timer <= 0.0:
			_phase = 1
			_timer = actor.attack_recovery_time
			actor.hitbox.deactivate()
			actor.velocity.x = 0.0
	elif _timer <= 0.0:
		machine.change_state(&"Chase" if actor.target != null else &"Patrol")
