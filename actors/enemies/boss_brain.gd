extends Node
## BossBrain — child component driving a boss's two phases (components over
## new state subclasses, docs §4). Phase 1: the scene's baseline pattern.
## Phase 2 at <=50% hp: ENRAGE — speed/telegraph multipliers, red tint +
## roar. The enrage's attack pattern is per-boss data:
##   enrage_volley_count > 0  -> pure volleys at that count (witch)
##   elif enrage_alternate    -> alternate melee / volley (gatekeeper)
##   else                     -> pure melee, just faster (redcap)

const SFX := preload("res://fx/sfx_builder.gd")

@export var bar_name := "BOSS"
@export var enrage_speed_mult := 1.8
@export var enrage_telegraph_mult := 0.65
@export var enrage_volley_count := 0
@export var enrage_alternate := true

var _boss # untyped, same convention as state.gd
var _phase := 1
var _volley_next := false


func _ready() -> void:
	_boss = get_parent()
	# children are ready BEFORE the parent: enemy.gd's @onready `health` var
	# isn't assigned yet — grab the node directly instead
	_boss.get_node("Health").damaged.connect(_on_damaged)
	_boss.state_changed.connect(_on_state_changed)


func _on_damaged(_info: Dictionary) -> void:
	if _phase == 1 and _boss.health.hp > 0 and _boss.health.hp <= _boss.health.max_hp / 2:
		_phase = 2
		_boss.move_speed *= enrage_speed_mult
		_boss.telegraph_time *= enrage_telegraph_mult
		_boss.attack_recovery_time *= 0.6
		if _boss.visual:
			_boss.visual.modulate = Color(1.0, 0.55, 0.5)
		if enrage_volley_count > 0:
			_boss.volley_count = enrage_volley_count
			_boss.attack_state = &"RangedAttack"
		AudioBus.play_sfx(SFX.roar(), _boss.global_position)


func _on_state_changed(state_name: StringName) -> void:
	# back on the hunt after a recovery -> arm the NEXT attack type
	if _phase == 2 and enrage_alternate and enrage_volley_count == 0 and state_name == &"Chase":
		_volley_next = not _volley_next
		_boss.attack_state = &"RangedAttack" if _volley_next else &"Attack"
