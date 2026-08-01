extends RefCounted
## stage_generator — critical-path-then-branches assembly (docs §5).
##
## Layout is built door-to-door: each new chunk attaches to a free connector
## of the previous main-path chunk, so connectivity is STRUCTURAL (start ->
## boss is a chain by construction). Placement is data-only (no SceneTree),
## so tools/generator_test.gd can validate hundreds of seeds headlessly.
## All randomness comes from the injected RNG — per-stage determinism.
##
## A placement is a Dictionary:
##   { scene, chunk (analyzed RoomChunk), pos (Vector2, world px),
##     role, parent (int index), via (parent's RoomConnector),
##     used: Array[RoomConnector], dead: Array[RoomConnector] }

const TILE := 16
const MAX_CANDIDATE_TRIES := 12
const MAX_TOTAL_ATTEMPTS := 200
const MAX_REGENERATIONS := 20


## Full layout for a stage. Returns [] only after repeated total failures.
static func generate(config: BiomeConfig, rng: RandomNumberGenerator) -> Array:
	for attempt in MAX_REGENERATIONS:
		var layout := _try_generate(config, rng)
		if _validate(layout, config):
			return layout
		_free_layout(layout)
	push_error("[StageGenerator] failed to produce a valid layout")
	return []


static func instantiate(layout: Array, parent: Node) -> void:
	for pl in layout:
		pl.chunk.position = pl.pos
		parent.add_child(pl.chunk)
	# after all chunks are in the tree (TileMapLayers built): seal every
	# door that didn't get a connection, so rooms stay enclosed
	for pl in layout:
		for conn in pl.chunk.connectors():
			if not pl.used.has(conn):
				pl.chunk.seal_connector(conn)


static func free_after_review(layout: Array) -> void:
	_free_layout(layout)


# --- internals ---------------------------------------------------------------

static func _try_generate(config: BiomeConfig, rng: RandomNumberGenerator) -> Array:
	var placements: Array = []
	var total_attempts := 0

	# main path, with TREASURE possibly rolling into SHOP (docs §5)
	var path: Array[int] = []
	for role in config.path_roles:
		if role == 3 and rng.randf() < config.shop_chance:
			path.append(2)
		else:
			path.append(role)

	# 1. start chunk at the origin
	var start_scene: PackedScene = _pick(config.start_chunks, rng)
	var start_chunk: RoomChunk = start_scene.instantiate()
	start_chunk.biome = config.tileset_biome # palette picked before any _build
	start_chunk.analyze()
	placements.append(_placement(start_scene, start_chunk, Vector2.ZERO, -1, null))

	# 2. walk the main path
	var step := 1
	while step < path.size():
		total_attempts += 1
		if total_attempts > MAX_TOTAL_ATTEMPTS:
			return placements
		var base: Dictionary = placements[step - 1]
		var free_conns := _free_connectors(base)
		if free_conns.is_empty():
			if step - 1 <= 0:
				return placements # exhausted the start chunk — give up
			_backtrack(placements, step - 1)
			step -= 1
			continue
		var base_conn: RoomConnector = free_conns[rng.randi() % free_conns.size()]
		if _attach(placements, base, base_conn, path[step], config, rng):
			step += 1
		else:
			base.dead.append(base_conn)

	# 3. branches off free sockets of main-path combat rooms
	for i in placements.size():
		var pl: Dictionary = placements[i]
		if pl.role != 1:
			continue
		for conn in _free_connectors(pl):
			if rng.randf() < config.branch_chance:
				_attach(placements, pl, conn, 5, config, rng)

	return placements


static func _attach(placements: Array, base: Dictionary, base_conn: RoomConnector, role: int, config: BiomeConfig, rng: RandomNumberGenerator) -> bool:
	var pool := config.pool_for(role)
	if pool.is_empty():
		return false
	var base_world: Vector2 = base.pos + base_conn.position
	for try in MAX_CANDIDATE_TRIES:
		var cand_scene: PackedScene = _pick(pool, rng)
		var cand: RoomChunk = cand_scene.instantiate()
		cand.biome = config.tileset_biome
		cand.analyze()
		var matching := cand.connectors_for(-base_conn.dir)
		if matching.is_empty():
			cand.free()
			continue
		var cand_conn: RoomConnector = matching[rng.randi() % matching.size()]
		var cand_pos: Vector2 = base_world + Vector2(base_conn.dir * TILE) - cand_conn.position
		if _overlaps(placements, cand_pos, cand.bounds().size):
			cand.free()
			continue
		var pl := _placement(cand_scene, cand, cand_pos, placements.find(base), base_conn)
		pl.used.append(cand_conn)
		base.used.append(base_conn)
		placements.append(pl)
		return true
	return false


static func _backtrack(placements: Array, index: int) -> void:
	var removed: Dictionary = placements[index]
	placements.remove_at(index)
	if removed.parent >= 0 and removed.via != null:
		var parent: Dictionary = placements[removed.parent]
		parent.used.erase(removed.via)
		parent.dead.append(removed.via) # don't immediately retry the same door
	removed.chunk.free()


static func _overlaps(placements: Array, pos: Vector2, size: Vector2) -> bool:
	var rect := Rect2(pos, size)
	for pl in placements:
		var other := Rect2(pl.pos, pl.chunk.bounds().size)
		if rect.intersects(other) and rect.intersection(other).get_area() > 1.0:
			return true
	return false


static func _validate(layout: Array, config: BiomeConfig) -> bool:
	if layout.size() < config.path_roles.size():
		return false
	var first: Dictionary = layout[0]
	if first.role != 0 or first.chunk.spawn_points(&"P").is_empty():
		return false
	# every main-path chunk reachable via the parent chain (structural, but assert)
	var main_count := 0
	var cursor := layout.size() - 1
	# last main-path placement = the one with the highest index whose parent
	# chain reaches 0 without a BRANCH link
	for i in layout.size():
		if layout[i].role != 5:
			main_count += 1
	if main_count < config.path_roles.size():
		return false
	var has_boss := false
	for pl in layout:
		if pl.role == 4:
			has_boss = true
			# boss reachable: walk parents back to 0
			var seen := {}
			cursor = layout.find(pl)
			while cursor > 0 and not seen.has(cursor):
				seen[cursor] = true
				cursor = layout[cursor].parent
			if cursor != 0:
				return false
	return has_boss


static func _free_connectors(pl: Dictionary) -> Array[RoomConnector]:
	var result: Array[RoomConnector] = []
	for conn in pl.chunk.connectors():
		if not pl.used.has(conn) and not pl.dead.has(conn):
			result.append(conn)
	return result


static func _placement(scene: PackedScene, chunk: RoomChunk, pos: Vector2, parent: int, via) -> Dictionary:
	return {
		"scene": scene,
		"chunk": chunk,
		"pos": pos,
		"role": chunk.role,
		"parent": parent,
		"via": via,
		"used": [] as Array[RoomConnector],
		"dead": [] as Array[RoomConnector],
	}


static func _pick(pool: Array, rng: RandomNumberGenerator) -> PackedScene:
	return pool[rng.randi() % pool.size()]


static func _free_layout(layout: Array) -> void:
	for pl in layout:
		pl.chunk.free()
	layout.clear()
