extends Node
## Health — shared damage pipeline component (player and enemies use this
## verbatim, docs/ARCHITECTURE.md §1). Child of a CharacterBody2D actor.
##
## take_hit flow: grace check -> damage/poise -> knockback -> signals ->
## EventBus.hit_landed. Light hits flash but don't interrupt; only a poise
## break (or death) interrupts — this is what makes combat feel fast.

signal damaged(hit_info: Dictionary)
signal poise_broken
signal died

@export var max_hp := 30
@export var max_poise := 20.0
@export var grace_time := 0.5          # post-hit invulnerability
@export var poise_regen_delay := 1.0   # seconds without damage before poise refills
@export var poise_regen_rate := 12.0

var hp: int
var poise: float
var last_hit_info: Dictionary = {}

var _grace := 0.0
var _since_hit := 0.0


func _ready() -> void:
	hp = max_hp
	poise = max_poise


func _process(delta: float) -> void:
	_grace = maxf(_grace - delta, 0.0)
	_since_hit += delta
	if _since_hit >= poise_regen_delay and poise < max_poise:
		poise = minf(poise + poise_regen_rate * delta, max_poise)


## Returns true if the hit connected. Roll i-frames are handled upstream by
## the Hurtbox (monitoring=false), so a hit arriving here is never during a roll.
func in_grace() -> bool:
	return _grace > 0.0


func take_hit(hit_info: Dictionary) -> bool:
	if _grace > 0.0 or hp <= 0:
		return false
	last_hit_info = hit_info
	var damage := int(hit_info.get(&"damage", 0))
	# victim-side multiplier (player curse debuff); absent on enemies = 1.0
	var taken_mult = get_parent().get("damage_taken_mult")
	if taken_mult != null:
		damage = int(damage * float(taken_mult))
	hp -= damage
	poise -= float(hit_info.get(&"poise_damage", 0.0))
	_grace = grace_time
	_since_hit = 0.0

	var actor := get_parent()
	if actor is CharacterBody2D:
		var resist: float = actor.get("knockback_resist") if actor.get("knockback_resist") != null else 1.0
		actor.velocity = hit_info.get(&"knockback", Vector2.ZERO) * resist

	damaged.emit(hit_info)
	EventBus.hit_landed.emit(hit_info)

	if hp <= 0:
		hp = 0
		died.emit()
		if actor.is_in_group(&"player"):
			EventBus.player_died.emit()
		else:
			EventBus.enemy_killed.emit(actor)
	elif poise <= 0.0:
		poise = max_poise
		poise_broken.emit()
	return true
