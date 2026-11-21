@tool
class_name MatchMinimap
extends Control
## Bottom-left minimap: scaled map asset plus living unit pixels at relative world positions.
## Frame / texture live in minimap.tscn + minimap_frame_style.tres.

const DEFAULT_MAP_TEXTURE := preload("res://assets/sprites/maps/tiles/v3/floor.png")

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
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _apply_frame_style() -> void:
	if not is_node_ready() or _frame == null or frame_style == null:
		return
	_frame.add_theme_stylebox_override("panel", frame_style)


func _apply_map_texture() -> void:
	if not is_node_ready() or _map_rect == null:
		return
	_map_rect.texture = map_texture
