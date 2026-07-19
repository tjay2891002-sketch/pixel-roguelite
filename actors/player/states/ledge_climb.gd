extends "res://actors/player/state_machine/state.gd"
## LedgeClimb — locked climb: lerp up and over the ledge, then hand control
## back. The landing point is measured, not guessed: a short downward probe
## ray just past the face finds the ledge top, so the climb ends flush with
## the surface (no floaty hop). M3 may re-snap this to the tile grid.

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t := 0.0


func enter() -> void:
	tint("#fff176")
	_t = 0.0
	_from = player.global_position

	var shape = player.get_node("CollisionShape2D").shape
	var half = shape.size * 0.5

	# Probe straight down from just past the face at head height — the grab
	# condition (head ray clear) guarantees this starts in empty space above
	# the ledge top.
	var space = player.get_world_2d().direct_space_state
	var probe_from := _from + Vector2(player.facing * 10.0, -10.0)
	var query := PhysicsRayQueryParameters2D.create(probe_from, probe_from + Vector2(0.0, 24.0), 1)
	var hit = space.intersect_ray(query)

	var top_y = hit.position.y if not hit.is_empty() else _from.y - player.ledge_up_offset
	var face_x = player.feet_ray.get_collision_point().x
	_to = Vector2(face_x + player.facing * (half.x + 1.0), top_y - half.y)
	player.velocity = Vector2.ZERO


func physics_update(delta: float) -> void:
	_t += delta / player.ledge_climb_duration
	# Direct position set bypasses collision on purpose — a short locked
	# animation, standard practice for mantle moves.
	player.global_position = _from.lerp(_to, clampf(_t, 0.0, 1.0))
	player.velocity = Vector2.ZERO
	if _t >= 1.0:
		machine.change_state(&"Idle")
