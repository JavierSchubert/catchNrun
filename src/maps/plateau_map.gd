class_name PlateauMap
extends RefCounted
## Meta for the painted plateau TileMap arena (see game/maps/arena_plateau.tscn).
## Tile painting lives in the editor on FloorLayer / OverlayLayer.

const TILE := 128.0
const COLS := 30
const ROWS := 20


static func world_bounds() -> Rect2:
	var size := Vector2(COLS, ROWS) * TILE
	return Rect2(-size * 0.5, size)


static func cell_to_world(cell: Vector2i) -> Vector2:
	return world_bounds().position + (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


## Runner spawn centers on the four elevated bases (NW, NE, SW, SE).
static func runner_spawn_positions() -> Array[Vector2]:
	return [
		cell_to_world(Vector2i(4, 4)),
		cell_to_world(Vector2i(24, 4)),
		cell_to_world(Vector2i(4, 15)),
		cell_to_world(Vector2i(24, 15)),
	]


static func hunter_spawn_position() -> Vector2:
	return Vector2.ZERO
