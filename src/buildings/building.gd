class_name Building
extends StaticBody2D
## Grid-placed structure. Footprint cells define the rectangular hitbox.


@export var footprint := Vector2i(1, 1)
@export var display_name := "Building"
@export var fill_color := Color(0.35, 0.7, 0.95, 0.9)

var anchor_cell := Vector2i.ZERO
var grid: BuildGrid

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	collision_layer = PhysicsLayers.WORLD | PhysicsLayers.BUILDING
	collision_mask = 0
	add_to_group("buildings")
	add_to_group("clickable")
	_apply_footprint_visual()


func setup(p_grid: BuildGrid, p_anchor: Vector2i, p_footprint: Vector2i = Vector2i.ZERO) -> void:
	grid = p_grid
	anchor_cell = p_anchor
	if p_footprint != Vector2i.ZERO:
		footprint = BuildGrid.positive_footprint(p_footprint)
	if grid != null:
		global_position = grid.footprint_center(anchor_cell, footprint)
	_apply_footprint_visual()


func is_clickable() -> bool:
	return true


func is_player_character() -> bool:
	return false


func selection_hit_radius() -> float:
	var size_cells := BuildGrid.positive_footprint(footprint)
	var cell := grid.cell_size if grid != null else 32.0
	return maxf(size_cells.x, size_cells.y) * cell * 0.55


func _apply_footprint_visual() -> void:
	var size_cells := BuildGrid.positive_footprint(footprint)
	var cell := grid.cell_size if grid != null else 32.0
	var pixel_size := Vector2(size_cells) * cell
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)
	var rect := RectangleShape2D.new()
	rect.size = pixel_size
	collision_shape.shape = rect
	collision_shape.position = Vector2.ZERO

	if visual == null:
		visual = get_node_or_null("Visual") as Polygon2D
	if visual == null:
		visual = Polygon2D.new()
		visual.name = "Visual"
		add_child(visual)
		move_child(visual, 0)
	var half := pixel_size * 0.5
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	visual.color = fill_color
