class_name WorldFogOverlay
extends Node2D
## World-space fog of war for the local player's team (docs/vision.README.md §4, §10).
##
## One sprite covers the whole map. Its texture holds one byte per vision cell, built from
## VisionSystem's explored / visible masks: unexplored is opaque dark, previously seen is
## dimmed, currently visible is clear. It draws above units, buildings and ghosts (but below
## floating numbers and HUD), so fogged entities are darkened with the ground under them.
##
## Presentation only. It never decides what is hidden; the entity presenter and ghost layer
## do that. With fog disabled or no VisionSystem the overlay hides itself.

const FOG_SHADER := preload("res://src/vision/fog_overlay.gdshader")

## Fog opacity of never-explored cells. 1.0 = fully opaque.
@export_range(0.0, 1.0, 0.01) var unexplored_alpha := 1.0
## Fog opacity of cells that were seen once but are not visible now.
@export_range(0.0, 1.0, 0.01) var previously_seen_alpha := 0.6
@export var fog_color := Color(0.015, 0.02, 0.035, 1.0)
## Above Unit (1), move markers / chain (4-5) and projectiles (6); below FloatingNumber (20).
@export var fog_z_index := 10

var _vision: VisionSystem
var _sprite: Sprite2D
var _image: Image
var _texture: ImageTexture
var _bytes := PackedByteArray()
var _grid := Vector2i.ZERO


func _ready() -> void:
	z_index = fog_z_index
	_sprite = Sprite2D.new()
	_sprite.name = "FogSprite"
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var fog_material := ShaderMaterial.new()
	fog_material.shader = FOG_SHADER
	fog_material.set_shader_parameter("fog_color", fog_color)
	_sprite.material = fog_material
	add_child(_sprite)
	_bind_vision()


func _exit_tree() -> void:
	_unbind_vision()


## Alpha byte (0-255) the overlay uses for a vision state. Public for tests / tuning.
func alpha_byte(state: VisionKnowledge.State) -> int:
	match state:
		VisionKnowledge.State.UNEXPLORED:
			return roundi(unexplored_alpha * 255.0)
		VisionKnowledge.State.PREVIOUSLY_SEEN:
			return roundi(previously_seen_alpha * 255.0)
		_:
			return 0


func _bind_vision() -> void:
	_vision = VisionSystem.find_in(get_tree())
	if _vision == null:
		visible = false
		return
	_vision.vision_updated.connect(_rebuild_texture)
	_vision.fog_enabled_changed.connect(_on_fog_enabled_changed)
	_on_fog_enabled_changed(_vision.fog_enabled)


func _unbind_vision() -> void:
	if _vision != null and is_instance_valid(_vision):
		if _vision.vision_updated.is_connected(_rebuild_texture):
			_vision.vision_updated.disconnect(_rebuild_texture)
		if _vision.fog_enabled_changed.is_connected(_on_fog_enabled_changed):
			_vision.fog_enabled_changed.disconnect(_on_fog_enabled_changed)
	_vision = null


func _on_fog_enabled_changed(enabled: bool) -> void:
	visible = enabled
	if enabled:
		_rebuild_texture()


func _rebuild_texture() -> void:
	if _vision == null or not is_instance_valid(_vision) or _vision.knowledge == null:
		return
	var grid := _vision.grid_size()
	var visible_cells := _vision.visible_mask()
	var explored_cells := _vision.explored_mask()
	var count := grid.x * grid.y
	if count <= 0 or visible_cells.size() != count or explored_cells.size() != count:
		return
	if _bytes.size() != count:
		_bytes.resize(count)
	var unexplored := alpha_byte(VisionKnowledge.State.UNEXPLORED)
	var seen := alpha_byte(VisionKnowledge.State.PREVIOUSLY_SEEN)
	for i in count:
		if visible_cells[i] != 0:
			_bytes[i] = 0
		elif explored_cells[i] != 0:
			_bytes[i] = seen
		else:
			_bytes[i] = unexplored
	_image = Image.create_from_data(grid.x, grid.y, false, Image.FORMAT_R8, _bytes)
	if _texture == null or grid != _grid:
		_texture = ImageTexture.create_from_image(_image)
		_grid = grid
		_sprite.texture = _texture
	else:
		_texture.update(_image)
	## One texel per vision cell, laid over the map bounds.
	var edge := _vision.cell_edge()
	_sprite.position = _vision.world_bounds().position
	_sprite.scale = Vector2(edge, edge)
