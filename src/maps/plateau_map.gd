class_name PlateauMap
extends RefCounted
## Meta for the lava-image placeholder arena (see game/maps/arena_plateau.tscn).
## FloorLayer and OverlayLayer remain available for future TileMap art.

const TILE := 128.0
const COLS := 60
const ROWS := 40
## Default ring used when placing players near map center (see Match.spawn_ring_radius).
const SPAWN_RING_RADIUS := 160.0


static func world_bounds() -> Rect2:
	var size := Vector2(COLS, ROWS) * TILE
	return Rect2(-size * 0.5, size)


static func cell_to_world(cell: Vector2i) -> Vector2:
	return world_bounds().position + (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


static func spawn_center() -> Vector2:
	return world_bounds().get_center()


## Evenly spaced positions on a ring around map center (no stacking).
static func spawn_ring_positions(count: int, radius: float = SPAWN_RING_RADIUS) -> Array[Vector2]:
	var center := spawn_center()
	var result: Array[Vector2] = []
	var n := maxi(count, 1)
	if n == 1:
		result.append(center)
		return result
	for slot in n:
		var angle := TAU * float(slot) / float(n) - PI * 0.5
		result.append(center + Vector2.from_angle(angle) * radius)
	return result


static func runner_spawn_positions() -> Array[Vector2]:
	return spawn_ring_positions(4)


static func hunter_spawn_position() -> Vector2:
	return spawn_center()
