class_name SelectionManager
extends Node2D
## Local-only left-click / drag selection. Owns hover + selected state and circles.
## Does not draw the selection panel HUD.

signal selection_changed(selected: Node)

const DRAG_THRESHOLD_PX := 8.0
const CLICKABLE_GROUP := "clickable"

var selected: Node = null
var hovered: Node = null
## Armed by pressing A when a local attacker is selected; next LMB issues attack-move.
var attack_move_armed := false

var _press_screen := Vector2.ZERO
var _press_world := Vector2.ZERO
var _pressing := false
var _dragging := false
var _drag_box: DragSelectBox
var _rng := RandomNumberGenerator.new()


static func is_chain_modifier_held(event: InputEventWithModifiers = null) -> bool:
	if event != null and (event.shift_pressed or event.ctrl_pressed):
		return true
	return Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL)


func _ready() -> void:
	add_to_group("selection_manager")
	_rng.randomize()
	_drag_box = DragSelectBox.new()
	add_child(_drag_box)
	set_process_unhandled_input(true)
	set_process(true)
	_auto_select_local_unit()
	GameManager.players_changed.connect(_on_roster_changed)
	GameManager.phase_changed.connect(func(_phase: GameManager.Phase) -> void:
		if selected == null or not is_instance_valid(selected):
			_auto_select_local_unit()
	)


func notify_clickable_ready(entity: Node) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	if not entity.has_method("is_local_controllable"):
		return
	if not bool(entity.call("is_local_controllable", _local_peer_id())):
		return
	if not _is_selectable(entity):
		return
	# Prefer the local controllable unit as soon as it appears.
	_set_selected(entity)


func _process(_delta: float) -> void:
	if LaunchOptions.bot_role.is_empty() == false:
		return
	if DisplayServer.get_name() == "headless":
		return
	if _dragging:
		_drag_box.update_corner(get_global_mouse_position())
		_clear_hover()
		return
	_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if not LaunchOptions.bot_role.is_empty():
		return
	if DisplayServer.get_name() == "headless":
		return
	if event is InputEventKey:
		_handle_attack_move_key(event as InputEventKey)
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _pressing and not _dragging:
		_maybe_start_drag(event as InputEventMouseMotion)


func is_controllable_selected() -> bool:
	if selected == null or not is_instance_valid(selected):
		return false
	if selected.has_method("is_local_controllable"):
		return bool(selected.call("is_local_controllable", _local_peer_id()))
	return false


func select_entity(entity: Node) -> void:
	if entity == selected:
		_refresh_circle_states()
		return
	_set_selected(entity)


func clear_selection() -> void:
	_set_selected(null)


func _handle_attack_move_key(key: InputEventKey) -> void:
	if key.echo:
		return
	if key.keycode == KEY_ESCAPE and key.pressed and attack_move_armed:
		_disarm_attack_move()
		get_viewport().set_input_as_handled()
		return
	if key.keycode != KEY_A or not key.pressed:
		return
	if not _can_arm_attack_move():
		return
	attack_move_armed = true
	get_viewport().set_input_as_handled()


func _handle_mouse_button(click: InputEventMouseButton) -> void:
	if click.button_index == MOUSE_BUTTON_RIGHT and click.pressed and attack_move_armed:
		## Disarm only — do not consume. Unit RMB (move / attack) keeps priority.
		_disarm_attack_move()
		return
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	if _is_build_mode_armed():
		## The building UI owns LMB (placement) while a structure is armed.
		return
	if click.pressed:
		if attack_move_armed:
			_issue_armed_attack_move()
			get_viewport().set_input_as_handled()
			return
		_pressing = true
		_dragging = false
		_press_screen = click.position
		_press_world = get_global_mouse_position()
		get_viewport().set_input_as_handled()
		return
	if not _pressing:
		return
	_pressing = false
	if _dragging:
		_dragging = false
		var box := _drag_box.end()
		_apply_box_selection(box)
		get_viewport().set_input_as_handled()
		return
	_apply_point_selection(_press_world)
	get_viewport().set_input_as_handled()


func _is_build_mode_armed() -> bool:
	var ui := get_tree().get_first_node_in_group("building_ui")
	return ui != null and ui.has_method("is_armed") and bool(ui.call("is_armed"))


func _can_arm_attack_move() -> bool:
	if not is_controllable_selected():
		return false
	if selected.has_method("can_attack"):
		return bool(selected.call("can_attack"))
	return false


func _issue_armed_attack_move() -> void:
	var destination := get_global_mouse_position()
	var chain_modifier_held := is_chain_modifier_held()
	if selected == null or not is_instance_valid(selected):
		_disarm_attack_move()
		return
	if chain_modifier_held and selected.has_method("issue_attack_chain_append"):
		## Shift/Ctrl+A+LMB appends a red attack-move waypoint; stay armed for more.
		selected.call("issue_attack_chain_append", destination)
		return
	_disarm_attack_move()
	if selected.has_method("issue_attack_move"):
		selected.call("issue_attack_move", destination)


func _disarm_attack_move() -> void:
	attack_move_armed = false
	_pressing = false
	if _dragging:
		_dragging = false
		_drag_box.end()


func _maybe_start_drag(motion: InputEventMouseMotion) -> void:
	if _press_screen.distance_to(motion.position) < DRAG_THRESHOLD_PX:
		return
	_dragging = true
	_drag_box.begin(_press_world)
	_drag_box.update_corner(get_global_mouse_position())
	get_viewport().set_input_as_handled()


func _apply_point_selection(world_pos: Vector2) -> void:
	var hits := _entities_at_point(world_pos)
	if hits.is_empty():
		clear_selection()
		return
	var picked := SelectionResolver.pick(hits, _local_peer_id(), _rng)
	_set_selected(picked)


func _apply_box_selection(box: Rect2) -> void:
	if box.size.x < 2.0 and box.size.y < 2.0:
		_apply_point_selection(_press_world)
		return
	var hits := _entities_in_rect(box)
	if hits.is_empty():
		clear_selection()
		return
	var picked := SelectionResolver.pick(hits, _local_peer_id(), _rng)
	_set_selected(picked)


func _update_hover() -> void:
	var world_pos := get_global_mouse_position()
	var hits := _entities_at_point(world_pos)
	var next: Node = null
	if not hits.is_empty():
		# Nearest hit avoids flicker when several hitboxes overlap under the cursor.
		next = _nearest_entity(hits, world_pos)
	if next == hovered:
		return
	_set_hovered(next)


func _clear_hover() -> void:
	_set_hovered(null)


func _set_hovered(entity: Node) -> void:
	if hovered != null and is_instance_valid(hovered) and hovered.has_method("set_selection_hover"):
		hovered.call("set_selection_hover", false)
	hovered = entity
	if hovered != null and hovered.has_method("set_selection_hover"):
		hovered.call("set_selection_hover", true)


func _set_selected(entity: Node) -> void:
	if selected != null and is_instance_valid(selected) and selected.has_method("set_selection_selected"):
		selected.call("set_selection_selected", false)
	_follow_sandbox_character(entity)
	selected = entity
	if selected != null and selected.has_method("set_selection_selected"):
		selected.call("set_selection_selected", true)
	_disarm_attack_move()
	_refresh_circle_states()
	selection_changed.emit(selected)


## Sandbox: selecting one of the two test characters also hands the controls to it, so the
## HUD, build panel and RMB commands all follow the selection. Foreign entities keep the
## current character.
func _follow_sandbox_character(entity: Node) -> void:
	if not GameManager.sandbox_mode or not entity is Unit:
		return
	var unit := entity as Unit
	if not GameManager.is_sandbox_character(unit.peer_id) or not unit.is_alive():
		return
	if unit.peer_id == GameManager.local_peer_id():
		return
	GameManager.set_sandbox_active(unit.peer_id)
	## Own / enemy ring colours are relative to the character in play.
	for node in get_tree().get_nodes_in_group(CLICKABLE_GROUP):
		if node != entity and node.has_method("refresh_selection_visual"):
			node.call("refresh_selection_visual")


func _refresh_circle_states() -> void:
	if selected != null and is_instance_valid(selected) and selected.has_method("refresh_selection_visual"):
		selected.call("refresh_selection_visual")
	if hovered != null and is_instance_valid(hovered) and hovered != selected \
			and hovered.has_method("refresh_selection_visual"):
		hovered.call("refresh_selection_visual")


func _entities_at_point(world_pos: Vector2) -> Array:
	var hits: Array = []
	for node in get_tree().get_nodes_in_group(CLICKABLE_GROUP):
		if not _is_selectable(node):
			continue
		var radius := _hit_radius(node)
		if world_pos.distance_to((node as Node2D).global_position) <= radius:
			hits.append(node)
	return hits


func _entities_in_rect(box: Rect2) -> Array:
	var hits: Array = []
	for node in get_tree().get_nodes_in_group(CLICKABLE_GROUP):
		if not _is_selectable(node):
			continue
		var pos := (node as Node2D).global_position
		var radius := _hit_radius(node)
		var entity_rect := Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
		if box.intersects(entity_rect):
			hits.append(node)
	return hits


func _is_selectable(node: Node) -> bool:
	if node == null or not is_instance_valid(node) or not node is Node2D:
		return false
	if node.has_method("is_alive") and not bool(node.call("is_alive")):
		return false
	if node.has_method("is_clickable"):
		return bool(node.call("is_clickable"))
	return true


func _hit_radius(node: Node) -> float:
	if node.has_method("selection_hit_radius"):
		return float(node.call("selection_hit_radius"))
	return 24.0


func _nearest_entity(candidates: Array, world_pos: Vector2) -> Node:
	var best: Node = null
	var best_distance := INF
	for candidate in candidates:
		if candidate == null or not candidate is Node2D:
			continue
		var distance := world_pos.distance_to((candidate as Node2D).global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate as Node
	return best


func _local_peer_id() -> int:
	return GameManager.local_peer_id()


func _auto_select_local_unit() -> void:
	var local_id := _local_peer_id()
	for node in get_tree().get_nodes_in_group(CLICKABLE_GROUP):
		if not _is_selectable(node):
			continue
		if node.has_method("is_local_controllable") and bool(node.call("is_local_controllable", local_id)):
			_set_selected(node)
			return


func _on_roster_changed() -> void:
	if selected != null and is_instance_valid(selected):
		if selected.has_method("is_alive") and not bool(selected.call("is_alive")):
			clear_selection()
			_auto_select_local_unit()
		else:
			if selected.has_method("refresh_selection_visual"):
				selected.call("refresh_selection_visual")
		return
	_auto_select_local_unit()
