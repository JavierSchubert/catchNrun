class_name PlacementValidator
extends RefCounted
## Validates a grid footprint against build bounds and blocker physics layers.


var grid: BuildGrid
var blocker_mask := PhysicsLayers.BUILD_BLOCKERS


func _init(p_grid: BuildGrid = null) -> void:
	grid = p_grid if p_grid != null else BuildGrid.new()


func can_place(anchor_cell: Vector2i, footprint: Vector2i, space: PhysicsDirectSpaceState2D, exclude: Array[RID] = []) -> bool:
	if grid == null:
		return false
	if not grid.contains_footprint(anchor_cell, footprint):
		return false
	if space == null:
		return true
	return not _overlaps_blockers(anchor_cell, footprint, space, exclude)


func _overlaps_blockers(
	anchor_cell: Vector2i,
	footprint: Vector2i,
	space: PhysicsDirectSpaceState2D,
	exclude: Array[RID]
) -> bool:
	var rect := grid.footprint_world_rect(anchor_cell, footprint)
	# Slight inset avoids touching adjacent colliders that only share an edge.
	var inset := 0.5
	var query_size := Vector2(maxf(rect.size.x - inset * 2.0, 1.0), maxf(rect.size.y - inset * 2.0, 1.0))
	var shape := RectangleShape2D.new()
	shape.size = query_size

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, rect.get_center())
	params.collision_mask = blocker_mask
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.exclude = exclude

	var hits := space.intersect_shape(params, 8)
	return not hits.is_empty()
