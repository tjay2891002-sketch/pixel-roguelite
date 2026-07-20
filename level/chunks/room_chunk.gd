class_name RoomChunk
extends Node2D
## RoomChunk — a hand-authored room "chunk" (docs §5: the fundamental unit of
## procedural assembly). Authored as an ASCII map instead of painted tile
## data: reviewable in diffs, and generation can run HEADLESS because
## analyze() needs no SceneTree.
##
## Map legend:
##   #  solid (floor/wall tile)      ,  accent tile
##   ^ v < >  door connector (TOP cell of a 2-tall floor-level door;
##            the cell below must be open)
##   E  enemy spawn    P  player start    T  treasure    B  boss door
##
## Convention: chunks are fully walled rectangles; every door char sits on a
## border cell. Chunks connect door-to-door, so every jump inside a chunk is
## guaranteed makeable — unfairness is structurally impossible (docs §5).

enum Role { START, COMBAT, SHOP, TREASURE, BOSS, BRANCH }

const TILES = preload("res://level/tileset_builder.gd")
const TILE_SIZE := 16

@export var role: Role = Role.COMBAT
@export var biome := &"greybox"
@export var difficulty_budget := 2
@export_multiline var map := ""

var _connectors: Array[RoomConnector] = []
var _spawns := {} # StringName -> Array[Marker2D]
var _size := Vector2i.ZERO
var _analyzed := false


func _ready() -> void:
	_build()


# --- Headless-safe data pass (no SceneTree, no child nodes) ------------------

func analyze() -> void:
	if _analyzed:
		return
	_analyzed = true
	var w := 0
	var lines := map.split("\n", false)
	for y in lines.size():
		var line := lines[y]
		w = maxi(w, line.length())
		for x in line.length():
			var c := line[x]
			match c:
				"^", "v", "<", ">":
					var connector := RoomConnector.new()
					connector.name = "Connector_" + c
					connector.dir = RoomConnector.dir_from_char(c)
					connector.position = Vector2((x + 0.5) * TILE_SIZE, (y + 0.5) * TILE_SIZE)
					add_child(connector) # safe on detached nodes; frees cascade
					_connectors.append(connector)
				"E", "P", "T", "B":
					var kind := StringName(c)
					if not _spawns.has(kind):
						_spawns[kind] = []
					var marker := Marker2D.new()
					marker.name = "Spawn_" + c
					marker.position = Vector2((x + 0.5) * TILE_SIZE, (y + 0.5) * TILE_SIZE)
					add_child(marker)
					_spawns[kind].append(marker)
	_size = Vector2i(w, lines.size())


func connectors() -> Array[RoomConnector]:
	analyze()
	return _connectors


func connectors_for(dir: Vector2i) -> Array[RoomConnector]:
	var result: Array[RoomConnector] = []
	for c in connectors():
		if c.dir == dir:
			result.append(c)
	return result


func spawn_points(kind: StringName) -> Array:
	analyze()
	return _spawns.get(kind, [])


func cell_size() -> Vector2i:
	analyze()
	return _size


## Bounds in LOCAL pixels.
func bounds() -> Rect2:
	analyze()
	return Rect2(Vector2.ZERO, Vector2(_size * TILE_SIZE))


# --- Visual build (runs when the chunk enters the tree) ----------------------

func _build() -> void:
	analyze()
	if get_node_or_null("TileMapLayer") != null:
		return
	var layer := TileMapLayer.new()
	layer.name = "TileMapLayer"
	layer.tile_set = TILES.build()
	# tiles sit behind actors
	layer.z_index = -1
	add_child(layer)
	var lines := map.split("\n", false)
	for y in lines.size():
		var line := lines[y]
		for x in line.length():
			match line[x]:
				"#":
					layer.set_cell(Vector2i(x, y), 0, TILES.SOLID)
				",":
					layer.set_cell(Vector2i(x, y), 0, TILES.ACCENT)


## Generation-time: seal an unused door so the room stays enclosed.
## Doors are 3 tiles tall (marked cell + 2 open below) — seal all three.
func seal_connector(connector: RoomConnector) -> void:
	var layer := get_node_or_null("TileMapLayer")
	if layer == null:
		return
	var cell := Vector2i(connector.position / TILE_SIZE)
	for i in 3:
		layer.set_cell(cell + Vector2i(0, i), 0, TILES.WALL)
