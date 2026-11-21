class_name DragSelectBox
extends Node2D
## Transparent world-space rectangle shown while the player drag-selects.

const FILL := Color(0.35, 0.7, 1.0, 0.12)
const BORDER := Color(0.45, 0.8, 1.0, 0.55)
const BORDER_WIDTH := 1.5

var _rect := Rect2()


func _ready() -> void:
	z_index = 20
	visible = false


func begin(world_pos: Vector2) -> void:
	_rect = Rect2(world_pos, Vector2.ZERO)
	visible = true
	queue_redraw()


func update_corner(world_pos: Vector2) -> void:
	_rect.size = world_pos - _rect.position
	queue_redraw()


func end() -> Rect2:
	visible = false
	queue_redraw()
	return _rect.abs()


func is_active() -> bool:
	return visible


func _draw() -> void:
	if not visible:
		return
	var abs_rect := _rect.abs()
	draw_rect(abs_rect, FILL, true)
	draw_rect(abs_rect, BORDER, false, BORDER_WIDTH)
