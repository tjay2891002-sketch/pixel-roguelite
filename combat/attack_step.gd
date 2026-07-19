class_name AttackStep
extends Resource
## One swing in a weapon's attack chain (docs/ARCHITECTURE.md §3).
## Timing lives in the AnimationPlayer clip of the same name; hitbox on/off
## and the lunge are fired from that clip's Call Method tracks — never timers.
## The cancel windows below are seconds-from-clip-start and must be kept in
## sync with the placeholder clips while we're in greybox.

@export var animation := &"attack_1"
@export var damage := 8
@export var poise_damage := 8.0
@export var knockback := Vector2(60.0, -20.0) # x is away-from-attacker at runtime
@export var lunge := 90.0                     # forward velocity impulse at active start
@export var hitbox_size := Vector2(16.0, 12.0)
@export var hitbox_offset := Vector2(10.0, 0.0)

## Chaining: a buffered attack input this many seconds before the clip ends
## flows into the next step.
@export var chain_window_start := 0.12
## Roll-cancel: rolling is allowed this many seconds before the clip ends.
@export var roll_cancel_start := 0.18
