class_name BuildingPanel
extends Control
## Bottom-right build UI (mirrors the bottom-left minimap). Lets a Runner pick a structure,
## see a grid-snapped ghost preview, and place it; also shows the details of an owned,
## selected structure and exposes Upgrade / Destroy for it. The Crystal balance itself
## lives in the top-center ResourceBar, not here.
##
## Gameplay rules live in ConstructionManager / BuildingDef / Building; this node only
## presents state and forwards player intent (root README "Implementation Principle").
## Every cost, level cap and per-level value below is read from the def or the building.

const BUILD_KEYS := ["wall", "tower", "crystal_mine"]

## Icon shown on each tower pick button, indexed by BuildingDef.TowerPath. The Damage path
## borrows the melee "Damage" sword icon: StatIcons maps RANGED_DAMAGE to the attack-range
## art, which would collide with the Range button.
const PICK_ICON_STATS := [
	StatBlock.Stat.MELEE_DAMAGE,
	StatBlock.Stat.ATTACK_SPEED,
	StatBlock.Stat.CRITICAL_CHANCE,
	StatBlock.Stat.ATTACK_RANGE,
]

@onready var _info_label: Label = %InfoLabel
@onready var _content: Control = %Content
@onready var _minimize_button: Button = %MinimizeButton
@onready var _wall_button: Button = %WallButton
@onready var _tower_button: Button = %TowerButton
@onready var _mine_button: Button = %MineButton
@onready var _selected_section: Control = %SelectedSection
@onready var _selected_name: Label = %SelectedName
@onready var _selected_hp: Label = %SelectedHp
@onready var _selected_detail: Label = %SelectedDetail
@onready var _max_level_label: Label = %MaxLevelLabel
@onready var _upgrade_area: Control = %UpgradeArea
@onready var _upgrade_hint: Label = %UpgradeHint
@onready var _upgrade_button: Button = %UpgradeButton
@onready var _pick_grid: Control = %PickGrid
@onready var _pick_damage_button: Button = %PickDamageButton
@onready var _pick_speed_button: Button = %PickSpeedButton
@onready var _pick_crit_button: Button = %PickCritButton
@onready var _pick_range_button: Button = %PickRangeButton
@onready var _destroy_button: Button = %DestroyButton

var _armed_key := ""
var _ghost: BuildGhost
var _pending_building_name := ""
var _build_buttons: Dictionary = {}
var _expanded_top_offset := 0.0
var _expanded_minimum_height := 0.0
var _is_minimized := false
## 2x2 grid, ordered to match BuildingDef.TowerPath. Every tower upgrade spends the level
## cost and takes exactly one of these paths.
var _pick_buttons: Array[Button] = []


func _ready() -> void:
	add_to_group("building_ui")
	_expanded_top_offset = offset_top
	_expanded_minimum_height = custom_minimum_size.y
	_minimize_button.pressed.connect(_on_minimize_pressed)
	_build_buttons = {"wall": _wall_button, "tower": _tower_button, "crystal_mine": _mine_button}
	for key in BUILD_KEYS:
		var button: Button = _build_buttons[key]
		button.icon = BuildingIcons.icon_for(key)
		button.pressed.connect(_on_build_button_pressed.bind(key))
	_pick_buttons = [_pick_damage_button, _pick_speed_button, _pick_crit_button, _pick_range_button]
	for path in _pick_buttons.size():
		_pick_buttons[path].pressed.connect(_on_pick_pressed.bind(path))
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	_destroy_button.pressed.connect(_on_destroy_pressed)
	_selected_section.visible = false
	set_process(true)
	set_process_unhandled_input(true)


func is_armed() -> bool:
	return not _armed_key.is_empty()


func _on_minimize_pressed() -> void:
	_is_minimized = not _is_minimized
	_content.visible = not _is_minimized
	if _is_minimized:
		custom_minimum_size.y = 44.0
		offset_top = offset_bottom - 44.0
		_minimize_button.text = "Expand"
		_minimize_button.tooltip_text = "Expand building panel"
	else:
		custom_minimum_size.y = _expanded_minimum_height
		offset_top = _expanded_top_offset
		_minimize_button.text = "Minimize"
		_minimize_button.tooltip_text = "Minimize building panel"


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


func _on_pick_pressed(path: int) -> void:
	var manager := _construction_manager()
	if manager != null and not _pending_building_name.is_empty():
		manager.request_upgrade(_pending_building_name, path)


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
	_pending_building_name = building.name
	var def := building.def
	var level_suffix := " (building...)" if building.is_under_construction() and building.level < 2 else ""
	_selected_name.text = "%s — Lv %d / %d%s" % [def.display_name, building.level, def.max_level, level_suffix]
	_selected_hp.text = "HP %.0f / %.0f" % [building.health.current, building.max_health]
	var detail := _selected_detail_text(building)
	_selected_detail.visible = not detail.is_empty()
	_selected_detail.text = detail
	_refresh_upgrade_area(building)


## Type-specific line under the HP readout.
func _selected_detail_text(building: Building) -> String:
	var def := building.def
	match def.kind:
		BuildingDef.Kind.WALL:
			if building.max_shield > 0.0:
				return "Shield %.0f / %.0f" % [building.shield.current, building.max_shield]
			return "Shield unlocks at Lv %d" % def.shield_unlock_level
		BuildingDef.Kind.CRYSTAL_MINE:
			if def.mine_interval <= 0.0:
				return ""
			var output := def.mine_output_for_level(building.level)
			return "%s crystals / %ss" % [_short_number(output), _short_number(def.mine_interval)]
		BuildingDef.Kind.TOWER:
			## Live values straight off the tower's StatSheet, plus the build it was given.
			var stats := building.stats
			return "DMG %s | Range %s | %s atk/s | Crit %s%%\n%s" % [
				_short_number(stats.final_value(StatBlock.Stat.RANGED_DAMAGE)),
				_short_number(stats.final_value(StatBlock.Stat.ATTACK_RANGE)),
				_short_number(stats.final_value(StatBlock.Stat.ATTACK_SPEED)),
				_short_number(stats.final_value(StatBlock.Stat.CRITICAL_CHANCE) * 100.0),
				_tower_picks_text(building),
			]
	return ""


## "Dmg 3 · Spd 1 · Crit 0 · Rng 2" — the paths the owner has taken so far.
func _tower_picks_text(building: Building) -> String:
	return "Dmg %d · Spd %d · Crit %d · Rng %d" % [
		building.tower_pick_count(BuildingDef.TowerPath.RANGED_DAMAGE),
		building.tower_pick_count(BuildingDef.TowerPath.ATTACK_SPEED),
		building.tower_pick_count(BuildingDef.TowerPath.CRIT),
		building.tower_pick_count(BuildingDef.TowerPath.ATTACK_RANGE),
	]


## Swaps the upgrade slot by structure kind: a single Upgrade button for Wall / Crystal
## Mine, the 2x2 pick grid for a Tower, and nothing at all once the def's cap is reached.
func _refresh_upgrade_area(building: Building) -> void:
	var def := building.def
	var at_max_level := building.level >= def.max_level
	_max_level_label.visible = at_max_level
	_upgrade_area.visible = not at_max_level
	if at_max_level:
		return
	var is_tower := def.kind == BuildingDef.Kind.TOWER
	var cost := building.next_upgrade_cost()
	var affordable := GameManager.crystals_for(_local_peer_id()) >= cost
	_upgrade_button.visible = not is_tower
	_pick_grid.visible = is_tower
	_upgrade_hint.visible = is_tower
	if is_tower:
		## Every tower level raises max HP on its own; the player picks what else it gains.
		if building.state == Building.State.UPGRADING:
			_upgrade_hint.text = "Upgrading to Lv %d…" % (building.level + 1)
		else:
			_upgrade_hint.text = "Upgrade to Lv %d for %d — pick one stat path:" % [
				building.level + 1,
				int(cost),
			]
		var can_pick := building.can_upgrade() and affordable
		for path in _pick_buttons.size():
			var pick_button := _pick_buttons[path]
			pick_button.icon = StatIcons.icon(PICK_ICON_STATS[path])
			pick_button.text = "%s\n%d" % [_pick_grant_short(def, path), int(cost)]
			pick_button.tooltip_text = "%s — %d Crystals" % [_pick_grant_long(def, path), int(cost)]
			pick_button.disabled = not can_pick
		return
	if building.state == Building.State.UPGRADING:
		_upgrade_button.text = "Upgrading to Lv %d…" % (building.level + 1)
	else:
		_upgrade_button.text = "Upgrade (%d)" % int(cost)
	_upgrade_button.disabled = not building.can_upgrade() or not affordable


## Button caption. Every number comes from the def, never from a literal here.
func _pick_grant_short(def: BuildingDef, path: int) -> String:
	match path:
		BuildingDef.TowerPath.RANGED_DAMAGE:
			return "+%s%% Damage" % _short_number(def.tower_damage_per_pick * 100.0)
		BuildingDef.TowerPath.ATTACK_SPEED:
			return "+%s%% Speed" % _short_number(def.tower_attack_speed_per_pick * 100.0)
		BuildingDef.TowerPath.CRIT:
			return "+%s%% Crit" % _short_number(def.tower_crit_chance_per_pick * 100.0)
		BuildingDef.TowerPath.ATTACK_RANGE:
			return "+%s%% Range" % _short_number(def.tower_range_per_pick * 100.0)
	return ""


## Tooltip. The Crit path grants both halves of the critical hit, so spell them out.
func _pick_grant_long(def: BuildingDef, path: int) -> String:
	match path:
		BuildingDef.TowerPath.RANGED_DAMAGE:
			return "+%s%% Ranged Damage" % _short_number(def.tower_damage_per_pick * 100.0)
		BuildingDef.TowerPath.ATTACK_SPEED:
			return "+%s%% Attack Speed" % _short_number(def.tower_attack_speed_per_pick * 100.0)
		BuildingDef.TowerPath.CRIT:
			return "+%s%% Crit Chance and +%s%% Crit Damage" % [
				_short_number(def.tower_crit_chance_per_pick * 100.0),
				_short_number(def.tower_crit_damage_per_pick * 100.0),
			]
		BuildingDef.TowerPath.ATTACK_RANGE:
			return "+%s%% Attack Range" % _short_number(def.tower_range_per_pick * 100.0)
	return ""


func _short_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % int(roundf(value))
	return "%.1f" % value


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
