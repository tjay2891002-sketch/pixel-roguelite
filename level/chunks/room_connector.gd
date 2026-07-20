class_name RoomConnector
extends Marker2D
## A door socket on a room chunk's edge (docs §5). Created by RoomChunk's
## map parser at cells marked ^ v < >. Doors are uniformly 2 tiles tall at
## floor level in the greybox biome, so no width matching is needed (the
## doc's door-width concept is reserved for later biomes).

var dir := Vector2i.ZERO # outward direction of this door (unit vector)


static func dir_from_char(c: String) -> Vector2i:
	match c:
		"^": return Vector2i(0, -1)
		"v": return Vector2i(0, 1)
		"<": return Vector2i(-1, 0)
		">": return Vector2i(1, 0)
	return Vector2i.ZERO
