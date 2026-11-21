extends Camera2D
## Free match camera. Edge scrolling moves the view.
## C always centers on the local player's own unit (never on a foreign selection).
## Dead local players keep this camera as observers.
##
## Bound padding lets the view scroll a bit past the map edge so map corners are never
## glued to screen corners — units at the map edge stay inset and readable.

@export var edge_margin := 300.0
@export var camera_speed := 900.0
@export var bounds := Unit.MAP_BOUNDS
## How far the map edge sits inside the viewport when the camera is fully scrolled.
## This value is in screen pixels and remains consistent at every zoom level.
## Larger = more empty space beyond the map, units stay farther from screen corners.
@export var bound_padding := 360.0
@export_range(0.25, 8.0, 0.05) var zoom_factor := 1.0:
	set(value):
		zoom_factor = maxf(value, 0.01)
		zoom = Vector2.ONE * zoom_factor

var _follow_peer_id := -1


func _ready() -> void:
	zoom = Vector2.ONE * zoom_factor
	enabled = LaunchOptions.bot_role.is_empty() and DisplayServer.get_name() != "headless"
	if enabled:
		make_current()
	_follow_peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	GameManager.players_changed.connect(_on_roster_changed)
	GameManager.phase_changed.connect(func(_phase: GameManager.Phase) -> void: _on_roster_changed())
	## Initial center only — kills / roster updates must not yank a free camera back.
	_snap_to_local_unit()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_C:
			# Ignore current selection — always the local controllable unit.
			_snap_to_local_unit()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not enabled:
		return
	var direction := _edge_direction()
	if direction != Vector2.ZERO:
		global_position += direction * camera_speed * delta
		_clamp_to_bounds()


func center_on(world_pos: Vector2) -> void:
	global_position = world_pos
	_clamp_to_bounds()


func _edge_direction() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2.ZERO
	var size := viewport.get_visible_rect().size
	var mouse := viewport.get_mouse_position()
	# Ignore when the cursor is outside the window.
	if mouse.x < 0.0 or mouse.y < 0.0 or mouse.x > size.x or mouse.y > size.y:
		return Vector2.ZERO
	# Settings dock, minimap, sandbox bar, etc. — no edge scroll while over UI.
	if viewport.gui_get_hovered_control() != null:
		return Vector2.ZERO

	var direction := Vector2.ZERO
	if mouse.x <= edge_margin:
		direction.x -= 1.0
	elif mouse.x >= size.x - edge_margin:
		direction.x += 1.0
	if mouse.y <= edge_margin:
		direction.y -= 1.0
	elif mouse.y >= size.y - edge_margin:
		direction.y += 1.0
	return direction.normalized()


func _on_roster_changed() -> void:
	## Keep tracking who we are; never auto-recenter on eliminations or roster noise.
	## Explicit recenter: C key, minimap click, or the initial _ready snap.
	_follow_peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1


func _snap_to_local_unit() -> void:
	var unit := _local_unit()
	if unit == null:
		return
	global_position = unit.global_position
	_clamp_to_bounds()


func _local_unit() -> Node2D:
	## Own player only — never the currently selected foreign entity.
	var id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	for node in get_tree().get_nodes_in_group("units"):
		if node is Unit and (node as Unit).peer_id == id:
			var unit := node as Unit
			if not unit.is_alive():
				return null
			return unit
		if node.name == str(id) and node is Node2D:
			if node.has_method("is_alive") and not bool(node.call("is_alive")):
				return null
			return node as Node2D
	return null


func _clamp_to_bounds() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return

	var viewport_size := viewport.get_visible_rect().size
	var zoom_x := absf(zoom.x)
	var zoom_y := absf(zoom.y)
	if zoom_x <= 0.001 or zoom_y <= 0.001:
		return

	var half_view := Vector2(viewport_size.x / zoom_x, viewport_size.y / zoom_y) * 0.5
	var pad := maxf(bound_padding, 0.0)
	var pad_world := Vector2(pad / zoom_x, pad / zoom_y)

	# Allow the view to cross the map edge, but keep the edge inset by bound_padding
	# on screen. If the view is wider than the map, center it on the map.
	var min_center := bounds.position + half_view - pad_world
	var max_center := bounds.end - half_view + pad_world

	if min_center.x > max_center.x:
		global_position.x = bounds.get_center().x
	else:
		global_position.x = clampf(global_position.x, min_center.x, max_center.x)
	if min_center.y > max_center.y:
		global_position.y = bounds.get_center().y
	else:
		global_position.y = clampf(global_position.y, min_center.y, max_center.y)
