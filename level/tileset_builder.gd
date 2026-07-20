## Placeholder tileset builder — a code-built greybox TileSet so chunks can
## use real TileMapLayers from day one (docs §5: TileMapLayer, never the
## deprecated TileMap). No art assets required; the atlas is generated.
## Preloaded as a const; intentionally NO class_name.

const TILE_SIZE := 16
const SOLID := Vector2i(0, 0)
const WALL := Vector2i(1, 0)
const ACCENT := Vector2i(2, 0)

static var _tileset: TileSet


static func build() -> TileSet:
	if _tileset:
		return _tileset

	var img := Image.create(TILE_SIZE * 3, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, TILE_SIZE, TILE_SIZE), Color("8b9bb4"))  # solid floor
	img.fill_rect(Rect2i(TILE_SIZE, 0, TILE_SIZE, TILE_SIZE), Color("5a6988")) # wall
	img.fill_rect(Rect2i(TILE_SIZE * 2, 0, TILE_SIZE, TILE_SIZE), Color("c0ca33")) # accent
	var tex := ImageTexture.create_from_image(img)

	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for i in 3:
		source.create_tile(Vector2i(i, 0))

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1) # layer 1: world
	ts.add_source(source, 0)

	# full-tile collision on solid + wall (tile-local coords are CENTERED)
	for coords in [SOLID, WALL]:
		var data := source.get_tile_data(coords, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))

	_tileset = ts
	return _tileset
