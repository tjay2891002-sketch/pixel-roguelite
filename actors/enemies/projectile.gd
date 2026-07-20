extends Area2D
## Projectile — a straight-flying enemy shot (collision layer 10:
## "projectile", mask = world + player_hurtbox). Carries a hit_info dict
## through the same receive_hit contract as melee hitboxes: connected hits
## fire EventBus.hit_landed (juice), i-frame dodges whiff it. Dies on any
## contact or on timeout.

var velocity := Vector2.ZERO
var hit_info: Dictionary = {}
var lifetime := 2.5


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(lifetime).timeout
	queue_free()


func _physics_process(delta: float) -> void:
	global_position += velocity * delta


func _on_area_entered(area: Area2D) -> void:
	if not area.has_method(&"receive_hit"):
		return
	var info := hit_info.duplicate()
	info[&"hit_position"] = area.global_position
	area.receive_hit(info)
	queue_free() # any contact ends the shot (hit, dodge, or grace)


func _on_body_entered(_body: Node2D) -> void:
	queue_free() # wall
