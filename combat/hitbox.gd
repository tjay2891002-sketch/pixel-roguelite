extends Area2D
## Hitbox — the attacker's half of the damage pipeline (§3). Lives on the
## attacking actor; its collision layer/mask comes from the scene (player:
## layer 4 -> mask 7; enemy: layer 5 -> mask 6).
##
## The AnimationPlayer's Call Method tracks call activate()/deactivate() via
## the owning actor — hitbox timing can never desync from the swing animation.
##
## A rejected hit (target in post-hit grace, or rolling with i-frames) is NOT
## consumed: it stays pending and retries while the swing is active. Without
## this, a fast follow-up swing inside the target's grace window silently
## fizzles (found by tools/combat_test.gd: chain hits 2->3 got eaten).

var _hit_info: Dictionary = {}
var _already_hit: Array[Area2D] = [] # one successful hit per swing per target
var _pending: Array[Area2D] = []     # rejected hits to retry while active


func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)


func activate(hit_info: Dictionary) -> void:
	_hit_info = hit_info
	_already_hit.clear()
	_pending.clear()
	monitoring = true


func deactivate() -> void:
	monitoring = false
	_already_hit.clear()
	_pending.clear()
	_hit_info = {}


func _physics_process(_delta: float) -> void:
	if not monitoring or _pending.is_empty():
		return
	for area in _pending.duplicate():
		if not is_instance_valid(area):
			# target was freed while pending (enemy died / stage regenerated)
			_pending.erase(area)
			continue
		_try_hit(area)


func _on_area_entered(area: Area2D) -> void:
	if _already_hit.has(area) or _pending.has(area):
		return
	_try_hit(area)


## `area` is deliberately untyped: pending entries may reference freed
## objects, and a typed Area2D parameter rejects them at the call boundary.
func _try_hit(area) -> void:
	if not is_instance_valid(area) or not area.has_method(&"receive_hit"):
		return
	var info := _hit_info.duplicate()
	info[&"hit_position"] = area.global_position
	var result: int = area.receive_hit(info)
	if result != 0:
		# connected, or whiffed by i-frames — either way this swing is done
		# with that target (no retry)
		_pending.erase(area)
		_already_hit.append(area)
	elif not _pending.has(area):
		_pending.append(area) # post-hit grace: retry while the swing is active
