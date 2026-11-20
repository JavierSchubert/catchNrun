extends Node2D
## Interactive grid building sandbox (no lobby / match required).
##   godot --path . res://tests/construction/building_grid_test.tscn
##
## Controls:
##   Move mouse — snap ghost to grid
##   LMB — place building when valid
##   1 / 2 / 3 — footprint 1x1 / 2x2 / 3x2
##   R — clear placed buildings
##   Esc — quit (when run standalone)

const CELL_SIZE := 32.0
const BUILDING_SCENE := preload("res://src/buildings/building.tscn")

var grid := BuildGrid.new(CELL_SIZE, Vector2(-640.0, -400.0), Rect2i(0, 0, 40, 25))
var validator := PlacementValidator.new(grid)
var ghost := BuildGhost.new()
var footprint := Vector2i(2, 2)
var _help: Label
var _camera: Camera2D
var _placed: Array[Building] = []


func _ready() -> void:
	_camera = Camera2D.new()
	_camera.enabled = DisplayServer.get_name() != "headless"
	add_child(_camera)
	_camera.make_current()
	_camera.zoom = Vector2(1.25, 1.25)
	_camera.position = grid.footprint_center(Vector2i(20, 12), Vector2i(1, 1))

	add_child(ghost)
	_spawn_blockers()
	_build_help()
	queue_redraw()
	set_process(true)
	set_process_unhandled_input(true)


func _process(_delta: float) -> void:
	_update_ghost()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.physical_keycode:
			KEY_1:
				footprint = Vector2i(1, 1)
			KEY_2:
				footprint = Vector2i(2, 2)
			KEY_3:
				footprint = Vector2i(3, 2)
			KEY_R:
				_clear_buildings()
			KEY_ESCAPE:
				get_tree().quit()
		_update_ghost()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_try_place()
			get_viewport().set_input_as_handled()


func _update_ghost() -> void:
	var world := get_global_mouse_position()
	var anchor := grid.snap_anchor_cell(world, footprint)
	var space := get_world_2d().direct_space_state
	var valid := validator.can_place(anchor, footprint, space)
	ghost.set_placement(grid, anchor, footprint, valid)
	if _help != null:
		_help.text = _help_text(anchor, valid)


func _try_place() -> void:
	var world := get_global_mouse_position()
	var anchor := grid.snap_anchor_cell(world, footprint)
	var space := get_world_2d().direct_space_state
	if not validator.can_place(anchor, footprint, space):
		return
	var building := BUILDING_SCENE.instantiate() as Building
	building.footprint = footprint
	building.fill_color = Color(0.3, 0.65, 0.95, 0.95)
	building.display_name = "Test Building %dx%d" % [footprint.x, footprint.y]
	add_child(building)
	building.setup(grid, anchor, footprint)
	_placed.append(building)
	# Wait one physics frame so the new collider is visible to the next query.
	await get_tree().physics_frame
	_update_ghost()


func _clear_buildings() -> void:
	for building in _placed:
		if is_instance_valid(building):
			building.queue_free()
	_placed.clear()


func _spawn_blockers() -> void:
	# Map-rim style obstacles.
	_add_blocker("Obstacle", PhysicsLayers.WORLD | PhysicsLayers.OBSTACLE, Color(0.45, 0.35, 0.25, 0.95), Vector2(96, 96), Vector2(-480, -280))
	_add_blocker("Obstacle", PhysicsLayers.WORLD | PhysicsLayers.OBSTACLE, Color(0.45, 0.35, 0.25, 0.95), Vector2(160, 64), Vector2(420, 260))

	# Stand-in unit (Hunter / Runner / NPC layer).
	_add_blocker("Unit", PhysicsLayers.WORLD | PhysicsLayers.UNIT, Color(0.3, 0.55, 1.0, 0.95), Vector2(28, 28), Vector2(-80, 40))

	# Existing building.
	var existing := BUILDING_SCENE.instantiate() as Building
	existing.fill_color = Color(0.2, 0.75, 0.55, 0.95)
	add_child(existing)
	existing.setup(grid, Vector2i(10, 8), Vector2i(2, 2))

	# Destructible prop.
	_add_blocker("Destructible", PhysicsLayers.WORLD | PhysicsLayers.DESTRUCTIBLE, Color(0.85, 0.55, 0.2, 0.95), Vector2(48, 48), Vector2(120, -60))

	# Collectible item — should NOT block placement.
	var item := Area2D.new()
	item.name = "Item"
	item.collision_layer = PhysicsLayers.WORLD | PhysicsLayers.ITEM
	item.collision_mask = 0
	item.position = Vector2(-200, 120)
	var item_shape := CollisionShape2D.new()
	var item_circle := CircleShape2D.new()
	item_circle.radius = 10.0
	item_shape.shape = item_circle
	item.add_child(item_shape)
	var item_visual := Polygon2D.new()
	item_visual.color = Color(0.95, 0.85, 0.2, 0.95)
	item_visual.polygon = PackedVector2Array([
		Vector2(0, -10), Vector2(8, 6), Vector2(-8, 6),
	])
	item.add_child(item_visual)
	add_child(item)


func _add_blocker(label: String, layer: int, color: Color, size: Vector2, pos: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = label
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var visual := Polygon2D.new()
	var half := size * 0.5
	visual.color = color
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	body.add_child(visual)
	add_child(body)


func _build_help() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_help = Label.new()
	_help.position = Vector2(16, 16)
	_help.add_theme_font_size_override("font_size", 16)
	layer.add_child(_help)


func _help_text(anchor: Vector2i, valid: bool) -> String:
	return "\n".join([
		"Building grid test",
		"Footprint %dx%d | anchor %s | %s" % [footprint.x, footprint.y, anchor, "VALID" if valid else "BLOCKED"],
		"LMB place | 1=1x1  2=2x2  3=3x2 | R clear buildings | Esc quit",
		"Brown=obstacle  Blue=unit  Teal=building  Orange=destructible  Yellow=item (non-blocking)",
	])


func _draw() -> void:
	var color := Color(1, 1, 1, 0.08)
	for x in range(grid.bounds_cells.position.x, grid.bounds_cells.end.x + 1):
		var a := grid.cell_to_world_top_left(Vector2i(x, grid.bounds_cells.position.y))
		var b := grid.cell_to_world_top_left(Vector2i(x, grid.bounds_cells.end.y))
		draw_line(a, b, color, 1.0)
	for y in range(grid.bounds_cells.position.y, grid.bounds_cells.end.y + 1):
		var a := grid.cell_to_world_top_left(Vector2i(grid.bounds_cells.position.x, y))
		var b := grid.cell_to_world_top_left(Vector2i(grid.bounds_cells.end.x, y))
		draw_line(a, b, color, 1.0)
	var bounds := Rect2(
		grid.cell_to_world_top_left(grid.bounds_cells.position),
		Vector2(grid.bounds_cells.size) * grid.cell_size
	)
	draw_rect(bounds, Color(0.4, 0.75, 1.0, 0.35), false, 2.0)
