class_name BuildGrid
extends RefCounted
## Axis-aligned build grid. Footprint cells map 1:1 to the building hitbox rectangle.


var cell_size := 32.0
var origin := Vector2.ZERO
var bounds_cells := Rect2i(-40, -25, 80, 50)


func _init(p_cell_size := 32.0, p_origin := Vector2.ZERO, p_bounds_cells := Rect2i(-40, -25, 80, 50)) -> void:
	cell_size = maxf(p_cell_size, 1.0)
	origin = p_origin
	bounds_cells = p_bounds_cells


func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local := world_pos - origin
	return Vector2i(floori(local.x / cell_size), floori(local.y / cell_size))


func cell_to_world_top_left(cell: Vector2i) -> Vector2:
	return origin + Vector2(cell) * cell_size


func cell_to_world_center(cell: Vector2i) -> Vector2:
	return cell_to_world_top_left(cell) + Vector2(cell_size, cell_size) * 0.5


func footprint_world_rect(anchor_cell: Vector2i, footprint: Vector2i) -> Rect2:
	var size_cells := positive_footprint(footprint)
	return Rect2(cell_to_world_top_left(anchor_cell), Vector2(size_cells) * cell_size)


func footprint_center(anchor_cell: Vector2i, footprint: Vector2i) -> Vector2:
	return footprint_world_rect(anchor_cell, footprint).get_center()


func snap_anchor_cell(world_pos: Vector2, footprint: Vector2i) -> Vector2i:
	## Snaps so the footprint is centered near the cursor, then locked to integer cells.
	var size_cells := positive_footprint(footprint)
	var half_world := Vector2(size_cells) * cell_size * 0.5
	return world_to_cell(world_pos - half_world)


func contains_footprint(anchor_cell: Vector2i, footprint: Vector2i) -> bool:
	var size_cells := positive_footprint(footprint)
	var covered := Rect2i(anchor_cell, size_cells)
	return bounds_cells.encloses(covered)


func cells_in_footprint(anchor_cell: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var size_cells := positive_footprint(footprint)
	var cells: Array[Vector2i] = []
	for y in size_cells.y:
		for x in size_cells.x:
			cells.append(anchor_cell + Vector2i(x, y))
	return cells


static func positive_footprint(footprint: Vector2i) -> Vector2i:
	return Vector2i(maxi(footprint.x, 1), maxi(footprint.y, 1))
