extends SceneTree
## One-off probe: is the biome config loading pools, and do chunk maps parse?
const GreyboxBiome := preload("res://data/biomes/greybox.tres")


func _initialize() -> void:
	print("pool sizes: start=%d combat=%d shop=%d treasure=%d boss=%d branch=%d" % [
		GreyboxBiome.start_chunks.size(), GreyboxBiome.combat_chunks.size(),
		GreyboxBiome.shop_chunks.size(), GreyboxBiome.treasure_chunks.size(),
		GreyboxBiome.boss_chunks.size(), GreyboxBiome.branch_chunks.size()])
	for pool in [GreyboxBiome.start_chunks, GreyboxBiome.combat_chunks]:
		for scene in pool:
			var chunk: RoomChunk = scene.instantiate()
			chunk.analyze()
			var conn_desc := []
			for c in chunk.connectors():
				conn_desc.append("%s@%s dir=%s" % [c.name, c.position, c.dir])
			print("%s role=%d size=%s conns=%d: %s" % [
				chunk.name, chunk.role, chunk.cell_size(), chunk.connectors().size(), conn_desc])
			var p_spawns := chunk.spawn_points(&"P")
			print("  P spawns: %d, E spawns: %d" % [p_spawns.size(), chunk.spawn_points(&"E").size()])
			print("  map first 40 chars: [", chunk.map.substr(0, 40), "]")
			chunk.free()
	quit()
