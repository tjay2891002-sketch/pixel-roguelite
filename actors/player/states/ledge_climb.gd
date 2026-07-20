extends "res://actors/player/state_machine/state.gd"
## LedgeClimb — locked climb: lerp up and over the ledge, then hand control
## back. The landing point is MEASURED (downward probe ray finds the ledge
## top) and VALIDATED (body-sized overlap check) — grabbing the underside of
## a thin wall segment (e.g. a door frame) can never wedge the player inside
## geometry; it simply falls.

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t := 0.0


func enter() -> void:
	tint("#fff176")
	_t = 0.0
	_from = player.global_position

	var shape = player.get_node("CollisionShape2D").shape
	var half = shape.size * 0.5
	var space = player.get_world_2d().direct_space_state

	# Probe straight down from just past the face at head height — for a real
	# ledge this starts in empty space above the ledge top.
	var probe_from := _from + Vector2(player.facing * 10.0, -10.0)
	var query := PhysicsRayQueryParameters2D.create(probe_from, probe_from + Vector2(0.0, 24.0), 1)
	var hit = space.intersect_ray(query)
	if hit.is_empty():
		# no surface found (probe started inside a thin wall/overhang, or the
		# face has no standable top) — not a climbable ledge
		machine.change_state(&"Fall")
		return

	var face_x = player.feet_ray.get_collision_point().x
	_to = Vector2(face_x + player.facing * (half.x + 1.0), hit.position.y - half.y)
	if _target_blocked(space, half, _to):
		# the landing spot is inside geometry (door-frame underside, sealed
		# border walls) — reject the climb instead of wedging the player
		machine.change_state(&"Fall")
		return
	player.velocity = Vector2.ZERO


func physics_update(delta: float) -> void:
	_t += delta / player.ledge_climb_duration
	# Direct position set bypasses collision on purpose — a short locked
	# animation, standard practice for mantle moves.
	player.global_position = _from.lerp(_to, clampf(_t, 0.0, 1.0))
	player.velocity = Vector2.ZERO
	if _t >= 1.0:
		machine.change_state(&"Idle")


## Body-sized overlap test at the candidate landing spot (slightly shrunk:
## the spot intentionally sits 1px clear of the face).
func _target_blocked(space, half: Vector2, center: Vector2) -> bool:
	var rect := RectangleShape2D.new()
	rect.size = half * 2.0 - Vector2(1.0, 1.0)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = rect
	params.transform = Transform2D(0.0, center)
	params.collision_mask = 1
	return not space.intersect_shape(params, 1).is_empty()
