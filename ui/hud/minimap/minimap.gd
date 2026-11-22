@tool
class_name MatchMinimap
extends Control
## Bottom-left minimap: scaled map asset plus living unit pixels at relative world positions.
## Frame / texture live in minimap.tscn + minimap_frame_style.tres.
## LMB recenters the camera. RMB issues a move. A-armed LMB issues attack-move.

const DEFAULT_MAP_TEXTURE := preload("res://assets/sprites/maps/tiles/v3/floor.png")
const MAP_INSET := 3.0

@export var map_bounds: Rect2 = Unit.MAP_BOUNDS
@export var map_texture: Texture2D = DEFAULT_MAP_TEXTURE:
	set(value):
		map_texture = value
		_apply_map_texture()

@export var frame_style: StyleBoxFlat:
	set(value):
		frame_style = value
		_apply_frame_style()

@onready var _frame: Panel = %Frame
@onready var _map_rect: TextureRect = %MapRect
@onready var _dots: Control = %Dots


func _ready() -> void:
	## Capture clicks so commands / camera jump work and edge-scroll stays off.
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_apply_frame_style()
	_apply_map_texture()
	if Engine.is_editor_hint():
		set_process(false)
		return
	set_process(true)


func _process(_delta: float) -> void:
	if _dots != null:
		_dots.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not event is InputEventMouseButton:
		return
	var click := event as InputEventMouseButton
	if not click.pressed:
		return
	var world := minimap_to_world(click.position)
	match click.button_index:
		MOUSE_BUTTON_RIGHT:
			var shift_held := click.shift_pressed or Input.is_key_pressed(KEY_SHIFT)
			if shift_held:
				_issue_chain_append_to(world)
			else:
				_issue_move_to(world)
			accept_event()
		MOUSE_BUTTON_LEFT:
			if _attack_move_armed():
				var shift_held := click.shift_pressed or Input.is_key_pressed(KEY_SHIFT)
				if shift_held:
					_issue_attack_chain_append_to(world)
				else:
					_issue_attack_move_to(world)
			else:
				_recenter_camera(world)
			accept_event()


func draw_area_size() -> Vector2:
	return size - Vector2(MAP_INSET * 2.0, MAP_INSET * 2.0)


func world_to_minimap(world_pos: Vector2) -> Vector2:
	var draw_size := draw_area_size()
	var u := 0.5
	var v := 0.5
	if map_bounds.size.x > 0.0:
		u = (world_pos.x - map_bounds.position.x) / map_bounds.size.x
	if map_bounds.size.y > 0.0:
		v = (world_pos.y - map_bounds.position.y) / map_bounds.size.y
	u = clampf(u, 0.0, 1.0)
	v = clampf(v, 0.0, 1.0)
	return Vector2(MAP_INSET + u * draw_size.x, MAP_INSET + v * draw_size.y)


func minimap_to_world(minimap_pos: Vector2) -> Vector2:
	var draw_size := draw_area_size()
	if draw_size.x <= 1.0 or draw_size.y <= 1.0:
		return map_bounds.get_center()
	var u := clampf((minimap_pos.x - MAP_INSET) / draw_size.x, 0.0, 1.0)
	var v := clampf((minimap_pos.y - MAP_INSET) / draw_size.y, 0.0, 1.0)
	return Vector2(
		map_bounds.position.x + u * map_bounds.size.x,
		map_bounds.position.y + v * map_bounds.size.y
	)


func _recenter_camera(world: Vector2) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	if camera.has_method("center_on"):
		camera.call("center_on", world)
	else:
		camera.global_position = world


func _attack_move_armed() -> bool:
	var manager := SelectionManager.find_in_tree(get_tree())
	return manager != null and manager.attack_move_armed


func _issue_move_to(world: Vector2) -> void:
	_issue_on_selected(&"issue_move", world, true)


func _issue_chain_append_to(world: Vector2) -> void:
	_issue_on_selected(&"issue_chain_append", world, true)


func _issue_attack_move_to(world: Vector2) -> void:
	_issue_on_selected(&"issue_attack_move", world, true)


func _issue_attack_chain_append_to(world: Vector2) -> void:
	## Keep attack-move armed so more Shift+A clicks can append.
	_issue_on_selected(&"issue_attack_chain_append", world, false)


func _issue_on_selected(method: StringName, world: Vector2, disarm_attack_move: bool) -> void:
	var manager := SelectionManager.find_in_tree(get_tree())
	if disarm_attack_move and manager != null:
		manager.clear_attack_move_arm()
	if manager == null or not manager.is_controllable_selected():
		return
	var unit := manager.selected
	if unit != null and unit.has_method(method):
		unit.call(method, world)


func _apply_frame_style() -> void:
	if not is_node_ready() or _frame == null or frame_style == null:
		return
	_frame.add_theme_stylebox_override("panel", frame_style)


func _apply_map_texture() -> void:
	if not is_node_ready() or _map_rect == null:
		return
	_map_rect.texture = map_texture
