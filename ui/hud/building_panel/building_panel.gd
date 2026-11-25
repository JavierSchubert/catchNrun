class_name BuildingPanel
extends Control
## Bottom-right build UI (mirrors the bottom-left minimap). Lets a Runner pick a structure,
## see a grid-snapped ghost preview, and place it; also exposes Upgrade / Destroy for an
## owned, selected structure. Gameplay rules live in ConstructionManager; this node only
## presents state and forwards player intent (root README "Implementation Principle").

const BUILD_KEYS := ["wall", "tower", "crystal_mine"]

@onready var _crystals_label: Label = %CrystalsLabel
@onready var _info_label: Label = %InfoLabel
@onready var _wall_button: Button = %WallButton
@onready var _tower_button: Button = %TowerButton
@onready var _mine_button: Button = %MineButton
@onready var _selected_section: Control = %SelectedSection
@onready var _selected_name: Label = %SelectedName
@onready var _selected_hp: Label = %SelectedHp
@onready var _upgrade_button: Button = %UpgradeButton
@onready var _destroy_button: Button = %DestroyButton

var _armed_key := ""
var _ghost: BuildGhost
var _pending_building_name := ""
var _build_buttons: Dictionary = {}


func _ready() -> void:
	add_to_group("building_ui")
	_build_buttons = {"wall": _wall_button, "tower": _tower_button, "crystal_mine": _mine_button}
	for key in BUILD_KEYS:
		var button: Button = _build_buttons[key]
		button.icon = BuildingIcons.icon_for(key)
		button.pressed.connect(_on_build_button_pressed.bind(key))
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	_destroy_button.pressed.connect(_on_destroy_pressed)
	_selected_section.visible = false
	set_process(true)
	set_process_unhandled_input(true)


func is_armed() -> bool:
	return not _armed_key.is_empty()


func _process(_delta: float) -> void:
	var show_panel := _local_is_active_runner()
	visible = show_panel
	if not show_panel:
		_disarm()
		return
	_refresh_build_buttons()
	_refresh_selected_building()
	if is_armed():
		_update_ghost()
	elif _ghost != null:
		_ghost.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_armed():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			_disarm()
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton:
		return
	var click := event as InputEventMouseButton
	if not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_RIGHT:
		_disarm()
		get_viewport().set_input_as_handled()
		return
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	if get_viewport().gui_get_hovered_control() != null:
		return
	_try_place()
	get_viewport().set_input_as_handled()


func _on_build_button_pressed(key: String) -> void:
	_armed_key = "" if _armed_key == key else key
	if not is_armed() and _ghost != null:
		_ghost.visible = false


func _on_upgrade_pressed() -> void:
	var manager := _construction_manager()
	if manager != null and not _pending_building_name.is_empty():
		manager.request_upgrade(_pending_building_name)


func _on_destroy_pressed() -> void:
	var manager := _construction_manager()
	if manager != null and not _pending_building_name.is_empty():
		manager.request_destroy(_pending_building_name)


func _disarm() -> void:
	_armed_key = ""
	if _ghost != null:
		_ghost.visible = false


func _refresh_build_buttons() -> void:
	var crystals := GameManager.crystals_for(_local_peer_id())
	_crystals_label.text = "Crystals: %d" % int(crystals)
	for key in BUILD_KEYS:
		var def := ConstructionManager.def_for(key)
		var button: Button = _build_buttons[key]
		button.button_pressed = _armed_key == key
		if def == null:
			continue
		button.text = "%s\n%d" % [def.display_name, int(def.cost_for_level(1))]
		button.disabled = crystals < def.cost_for_level(1)
	if is_armed():
		var def := ConstructionManager.def_for(_armed_key)
		_info_label.text = "Placing %s — LMB place, RMB/Esc cancel" % (def.display_name if def else _armed_key)
	else:
		_info_label.text = "Select a structure to build"


func _update_ghost() -> void:
	var manager := _construction_manager()
	var def := ConstructionManager.def_for(_armed_key)
	if manager == null or def == null:
		return
	_ensure_ghost()
	var world := _world_mouse_position()
	var anchor := manager.grid.snap_anchor_cell(world, def.footprint)
	var valid := manager.can_place_preview(_armed_key, anchor)
	_ghost.visible = true
	_ghost.set_placement(manager.grid, anchor, def.footprint, valid)


func _try_place() -> void:
	var manager := _construction_manager()
	var def := ConstructionManager.def_for(_armed_key)
	if manager == null or def == null:
		return
	var anchor := manager.grid.snap_anchor_cell(_world_mouse_position(), def.footprint)
	if not manager.can_place_preview(_armed_key, anchor):
		return
	manager.request_build(_armed_key, anchor)
	_disarm()


func _refresh_selected_building() -> void:
	var manager := get_tree().get_first_node_in_group("selection_manager") as SelectionManager
	var building: Building = null
	if manager != null and manager.selected is Building:
		var candidate := manager.selected as Building
		if candidate.def != null and candidate.owner_peer_id == _local_peer_id():
			building = candidate
	if building == null:
		_selected_section.visible = false
		_pending_building_name = ""
		return
	_selected_section.visible = true
	_destroy_button.visible = true
	_pending_building_name = building.name
	var level_suffix := " (building...)" if building.is_under_construction() and building.level < 2 else ""
	_selected_name.text = "%s — Lv %d%s" % [building.def.display_name, building.level, level_suffix]
	_selected_hp.text = "HP %.0f / %.0f" % [building.health.current, building.max_health]
	if building.can_upgrade():
		var cost := building.next_upgrade_cost()
		_upgrade_button.visible = true
		_upgrade_button.text = "Upgrade (%d)" % int(cost)
		_upgrade_button.disabled = GameManager.crystals_for(_local_peer_id()) < cost
	else:
		_upgrade_button.visible = false


func _ensure_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		return
	_ghost = BuildGhost.new()
	_ghost.name = "BuildGhost"
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	host.add_child(_ghost)


func _world_mouse_position() -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Vector2.ZERO
	return cam.get_global_mouse_position()


func _construction_manager() -> ConstructionManager:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("construction_manager") as ConstructionManager


func _local_is_active_runner() -> bool:
	var id := _local_peer_id()
	if not GameManager.players.has(id):
		return false
	if GameManager.phase != GameManager.Phase.RUNNER_PREPARATION and GameManager.phase != GameManager.Phase.HUNTER_ACTIVE:
		return false
	if GameManager.is_eliminated(id):
		return false
	var entry: Dictionary = GameManager.players[id]
	return int(entry.get("role", RoleConfig.Role.RUNNER)) == RoleConfig.Role.RUNNER


func _local_peer_id() -> int:
	if multiplayer != null and multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1
