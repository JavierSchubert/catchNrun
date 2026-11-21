class_name PlateauMap
extends RefCounted
## Meta for the painted space TileMap arena (see game/maps/arena_space.tscn).
## Tile painting lives in the editor on FloorLayer / OverlayLayer.

const TILE := 128.0
const COLS := 60
const ROWS := 40


static func world_bounds() -> Rect2:
	var size := Vector2(COLS, ROWS) * TILE
	return Rect2(-size * 0.5, size)


static func cell_to_world(cell: Vector2i) -> Vector2:
	return world_bounds().position + (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


## Runner spawn centers on the four elevated corner bases (NW, NE, SW, SE).
static func runner_spawn_positions() -> Array[Vector2]:
	return [
		cell_to_world(Vector2i(9, 7)),
		cell_to_world(Vector2i(50, 7)),
		cell_to_world(Vector2i(9, 32)),
		cell_to_world(Vector2i(50, 32)),
	]


static func hunter_spawn_position() -> Vector2:
	return Vector2.ZERO
