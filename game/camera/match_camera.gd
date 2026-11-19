extends Camera2D
## Free match camera. Edge scrolling moves the view. C centers on the local unit
## while that unit is alive. Dead local players keep this camera as observers.

@export var edge_margin := 150.0
@export var camera_speed := 900.0
@export var bounds := Rect2(Vector2(-1100, -700), Vector2(2200, 1400))

var _follow_peer_id := -1


func _ready() -> void:
	enabled = LaunchOptions.bot_role.is_empty() and DisplayServer.get_name() != "headless"
	make_current()
	_follow_peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	GameManager.players_changed.connect(_on_roster_changed)
	GameManager.phase_changed.connect(func(_phase: GameManager.Phase) -> void: _on_roster_changed())
	_snap_to_local_unit()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_C:
			_snap_to_local_unit()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not enabled:
		return
	var direction := _edge_direction()
	if direction != Vector2.ZERO:
		global_position += direction * camera_speed * delta
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
	_follow_peer_id = multiplayer.get_unique_id()
	if GameManager.is_eliminated(_follow_peer_id):
		return
	_snap_to_local_unit()


func _snap_to_local_unit() -> void:
	var unit := _local_unit()
	if unit == null:
		return
	global_position = unit.global_position
	_clamp_to_bounds()


func _local_unit() -> Node2D:
	var id := multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group("units"):
		if node.name == str(id) and node is Node2D:
			if node.has_method("is_alive") and not bool(node.call("is_alive")):
				return null
			return node as Node2D
	return null


func _clamp_to_bounds() -> void:
	global_position.x = clampf(global_position.x, bounds.position.x, bounds.end.x)
	global_position.y = clampf(global_position.y, bounds.position.y, bounds.end.y)
