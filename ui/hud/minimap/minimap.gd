class_name MatchMinimap
extends Control
## Bottom-left minimap: scaled map asset plus living unit pixels at relative world positions.

const DEFAULT_MAP_TEXTURE := preload("res://assets/sprites/maps/tiles/v3/floor.png")

@export var map_bounds := Unit.MAP_BOUNDS
@export var map_texture: Texture2D = DEFAULT_MAP_TEXTURE

var _map_rect: TextureRect
var _dots: _UnitDotsOverlay


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(220.0, 146.0)
	clip_contents = true

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.06, 0.9)
	style.border_color = Color(1, 1, 1, 0.18)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)

	_map_rect = TextureRect.new()
	_map_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
	_map_rect.texture = map_texture
	_map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_rect.modulate = Color(1, 1, 1, 0.92)
	add_child(_map_rect)

	_dots = _UnitDotsOverlay.new()
	_dots.map_bounds = map_bounds
	_dots.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dots)


func _process(_delta: float) -> void:
	if _dots != null:
		_dots.map_bounds = map_bounds
		_dots.queue_redraw()


class _UnitDotsOverlay extends Control:
	const DOT_SIZE := 4.0
	var map_bounds := Unit.MAP_BOUNDS

	func _draw() -> void:
		var local_id := 1
		var tree := get_tree()
		if tree != null and multiplayer.has_multiplayer_peer():
			local_id = multiplayer.get_unique_id()
		var inset := 3.0
		var draw_size := size - Vector2(inset * 2.0, inset * 2.0)
		if draw_size.x <= 1.0 or draw_size.y <= 1.0 or tree == null:
			return
		for node in tree.get_nodes_in_group("units"):
			if not node is Unit:
				continue
			var unit := node as Unit
			if not unit.is_alive():
				continue
			var point := _world_to_minimap(unit.global_position, inset, draw_size)
			var color := unit.selection_affinity_color(local_id)
			var half := DOT_SIZE * 0.5
			draw_rect(Rect2(point - Vector2(half, half), Vector2(DOT_SIZE, DOT_SIZE)), color, true)

	func _world_to_minimap(world_pos: Vector2, inset: float, draw_size: Vector2) -> Vector2:
		var u := 0.5
		var v := 0.5
		if map_bounds.size.x > 0.0:
			u = (world_pos.x - map_bounds.position.x) / map_bounds.size.x
		if map_bounds.size.y > 0.0:
			v = (world_pos.y - map_bounds.position.y) / map_bounds.size.y
		u = clampf(u, 0.0, 1.0)
		v = clampf(v, 0.0, 1.0)
		return Vector2(inset + u * draw_size.x, inset + v * draw_size.y)
