extends Area2D
## Hurtbox — the victim's half of the damage pipeline (§3). Forwards hits to
## the sibling Health node. Roll i-frames: while the owning actor has
## `invulnerable == true` this box is not monitoring, so hits can't connect.

var _health: Node


func _ready() -> void:
	_health = get_parent().get_node_or_null("Health")


func _process(_delta: float) -> void:
	var owner = get_parent()
	if owner.get("invulnerable") != null:
		var safe: bool = owner.invulnerable
		if not safe and owner.has_method(&"has_iframes"):
			safe = owner.has_iframes()
		monitoring = not safe


## Returns true if the hit connected (false = grace/i-frames; the hitbox
## keeps it pending and retries while the swing is active).
func receive_hit(hit_info: Dictionary) -> bool:
	if _health == null:
		return false
	# Belt-and-braces i-frame guard: hurtbox.monitoring lags the flag by a
	# frame (it's synced in _process), so check the flag directly too.
	var owner = get_parent()
	if owner.get("invulnerable") == true:
		return false
	if owner.has_method(&"has_iframes") and owner.has_iframes():
		return false
	hit_info[&"victim"] = get_parent()
	return _health.take_hit(hit_info)
