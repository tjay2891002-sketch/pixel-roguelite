extends Node
## PropHealth — the breakable prop's end of the damage pipeline. Deliberately
## NOT the shared combat/health.gd: a prop is not an enemy, so no
## enemy_killed (that signal drives combat-room door locks), no poise, no
## post-hit grace — one solid hit breaks it. Still emits EventBus.hit_landed
## so the smash gets full juice (hitstop, crunch, particles, flash).

signal broke

@export var max_hp := 1

var hp: int


func _ready() -> void:
	hp = max_hp


func take_hit(hit_info: Dictionary) -> bool:
	if hp <= 0:
		return false
	hp = maxi(hp - int(hit_info.get(&"damage", 0)), 0)
	# Runtime lookup, not the autoload name: this script also compiles
	# through --script test main loops, where autoloads don't resolve.
	var bus := get_tree().root.get_node_or_null("EventBus")
	if bus:
		bus.hit_landed.emit(hit_info)
	if hp <= 0:
		broke.emit()
	return true
