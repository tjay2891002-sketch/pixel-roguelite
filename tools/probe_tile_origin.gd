extends SceneTree
## Determine whether tile collision is centered on the cell or top-left
## anchored, by raycasting onto a surface tile placed at cell (0,0).

const TILES := preload("res://level/tileset_builder.gd")


func _initialize() -> void:
	var root_node := Node2D.new()
	root.add_child(root_node)

	var layer := TileMapLayer.new()
	layer.tile_set = TILES.build()
	root_node.add_child(layer)
	layer.set_cell(Vector2i(0, 0), TILES.SURFACE, Vector2i(0, 0))

	var ray := RayCast2D.new()
	ray.position = Vector2(8, -50)
	ray.target_position = Vector2(0, 100)
	ray.collision_mask = 1
	root_node.add_child(ray)

	await physics_frame
	await physics_frame
	ray.force_raycast_update()
	if ray.is_colliding():
		print("collision top y = ", ray.get_collision_point().y)
	else:
		print("NO COLLISION (ray at x=8 over cell 0,0)")
	quit()
