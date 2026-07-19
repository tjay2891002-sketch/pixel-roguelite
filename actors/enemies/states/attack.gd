extends "res://actors/player/state_machine/state.gd"
## Enemy Attack — brief active window with the hitbox live, then recovery.
## Greybox enemies drive this with explicit timers in the state (the
## no-timers rule applies to animation-synced player weapon swings).

var _phase := 0 # 0 = active, 1 = recovery
var _timer := 0.0


func enter() -> void:
	tint("#e57373")
	_phase = 0
	_timer = actor.attack_active_time
	actor.velocity.x = actor.facing * 40.0 # small forward hop
	actor.hitbox.activate(actor.swipe_hit_info())


func exit() -> void:
	actor.hitbox.deactivate()


func physics_update(delta: float) -> void:
	_timer -= delta
	if _phase == 0:
		if _timer <= 0.0:
			_phase = 1
			_timer = actor.attack_recovery_time
			actor.hitbox.deactivate()
			actor.velocity.x = 0.0
	elif _timer <= 0.0:
		machine.change_state(&"Chase" if actor.target != null else &"Patrol")
