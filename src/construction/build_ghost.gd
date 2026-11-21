class_name BuildGhost
extends Node2D
## Visual footprint preview snapped to the build grid.


var grid: BuildGrid
var footprint := Vector2i(1, 1)
var anchor_cell := Vector2i.ZERO
var valid := true


func _ready() -> void:
	z_index = 10


func set_placement(p_grid: BuildGrid, p_anchor: Vector2i, p_footprint: Vector2i, p_valid: bool) -> void:
	grid = p_grid
	anchor_cell = p_anchor
	footprint = BuildGrid.positive_footprint(p_footprint)
	valid = p_valid
	if grid != null:
		global_position = grid.footprint_center(anchor_cell, footprint)
	queue_redraw()


func _draw() -> void:
	if grid == null:
		return
	var rect := grid.footprint_world_rect(anchor_cell, footprint)
	var local_rect := Rect2(rect.position - global_position, rect.size)
	var fill := Color(0.25, 0.9, 0.4, 0.28) if valid else Color(0.95, 0.25, 0.25, 0.32)
	var border := Color(0.35, 1.0, 0.5, 0.95) if valid else Color(1.0, 0.35, 0.35, 0.95)
	draw_rect(local_rect, fill, true)
	draw_rect(local_rect, border, false, 2.0)
