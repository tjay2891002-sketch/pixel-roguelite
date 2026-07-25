## Tileset builder — assembles a TileSet from the GothicVania tiles
## (16px). Source ids are exposed as SURFACE/FILL/WALL for room_chunk.
## Physics: every solid tile gets a full 16x16 collision polygon on layer 1.
## Preloaded as a const; intentionally NO class_name.

const SURFACE := 0
const FILL := 1
const WALL := 2

static var _tileset: TileSet


static func build() -> TileSet:
	if _tileset:
		return _tileset

	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer() # appends at index 0
	ts.set_physics_layer_collision_layer(0, 1) # layer 1: world

	_add_source(ts, SURFACE, preload("res://assets/level/tiles/tile_surface.png"))
	_add_source(ts, FILL, preload("res://assets/level/tiles/tile_fill.png"))
	_add_source(ts, WALL, preload("res://assets/level/tiles/tile_wall.png"))

	_tileset = ts
	return _tileset


static func _add_source(ts: TileSet, id: int, tex: Texture2D) -> void:
	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(16, 16)
	source.create_tile(Vector2i(0, 0))
	# register the source FIRST — TileData validates collision against the
	# TileSet's physics layers, and only sees them once the source is in.
	ts.add_source(source, id)
	var data := source.get_tile_data(Vector2i(0, 0), 0)
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
