class_name BuildingPanel
extends Control
## Bottom-right build / manage UI. Layout mirrors the bottom-left minimap.
##
## Modes (HudMode):
##   UNIT_BUILD — local Runner unit selected → Wall / Tower / Mine placement
##   BUILDING_MANAGE — owned structure selected → stats + Upgrade / Destroy
## Modes are mutually exclusive. Gameplay rules stay in ConstructionManager / BuildingDef.

const BUILD_KEYS := ["wall", "tower", "crystal_mine"]
const SHORT_NAMES := {"wall": "Wall", "tower": "Tower", "crystal_mine": "Mine"}
const BUILD_HOTKEYS := {
	KEY_W: "wall",
	KEY_T: "tower",
	KEY_C: "crystal_mine",
}
const TOWER_PICK_HOTKEYS := {
	KEY_1: BuildingDef.TowerPath.RANGED_DAMAGE,
	KEY_2: BuildingDef.TowerPath.ATTACK_SPEED,
	KEY_3: BuildingDef.TowerPath.CRIT,
	KEY_4: BuildingDef.TowerPath.ATTACK_RANGE,
}

## Icon shown on each tower pick button, indexed by BuildingDef.TowerPath.
const PICK_ICON_STATS := [
	StatBlock.Stat.MELEE_DAMAGE,
	StatBlock.Stat.ATTACK_SPEED,
	StatBlock.Stat.CRITICAL_CHANCE,
	StatBlock.Stat.ATTACK_RANGE,
]

@onready var _info_label: Label = %InfoLabel
@onready var _content: Control = %Content
@onready var _minimize_button: Button = %MinimizeButton
@onready var _build_section: Control = %BuildSection
@onready var _wall_button: Button = %WallButton
@onready var _tower_button: Button = %TowerButton
@onready var _mine_button: Button = %MineButton
@onready var _wall_cost_label: Label = %WallCostLabel
@onready var _tower_cost_label: Label = %TowerCostLabel
@onready var _mine_cost_label: Label = %MineCostLabel
@onready var _wall_cost_icon: TextureRect = %WallCostIcon
@onready var _tower_cost_icon: TextureRect = %TowerCostIcon
@onready var _mine_cost_icon: TextureRect = %MineCostIcon
@onready var _selected_section: Control = %SelectedSection
@onready var _selected_icon: TextureRect = %SelectedIcon
@onready var _selected_name: Label = %SelectedName
@onready var _repair_hint_row: HBoxContainer = %RepairHintRow
@onready var _repair_hint_icon: TextureRect = %RepairHintIcon
@onready var _stat_hp: StatIconRow = %StatHp
@onready var _stat_secondary: StatIconRow = %StatSecondary
@onready var _stat_tertiary: StatIconRow = %StatTertiary
@onready var _stat_quaternary: StatIconRow = %StatQuaternary
@onready var _max_level_label: Label = %MaxLevelLabel
@onready var _upgrade_area: Control = %UpgradeArea
@onready var _upgrade_hint: Label = %UpgradeHint
@onready var _upgrade_cost_row: Control = %UpgradeCostRow
@onready var _upgrade_cost_icon: TextureRect = %UpgradeCostIcon
@onready var _upgrade_cost_label: Label = %UpgradeCostLabel
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
var _build_cost_labels: Dictionary = {}
var _expanded_top_offset := 0.0
var _expanded_minimum_height := 0.0
var _is_minimized := false
var _pick_buttons: Array[Button] = []
var _mode: HudMode.Mode = HudMode.Mode.NONE
var _tower_upgrade_hotkey_pending := false


func _ready() -> void:
	add_to_group("building_ui")
	_expanded_top_offset = offset_top
	_expanded_minimum_height = custom_minimum_size.y
	_minimize_button.pressed.connect(_on_minimize_pressed)
	_build_buttons = {"wall": _wall_button, "tower": _tower_button, "crystal_mine": _mine_button}
	_build_cost_labels = {
		"wall": _wall_cost_label,
		"tower": _tower_cost_label,
		"crystal_mine": _mine_cost_label,
	}
	var crystal_icon := BuildingIcons.crystal_icon()
	_wall_cost_icon.texture = crystal_icon
	_tower_cost_icon.texture = crystal_icon
	_mine_cost_icon.texture = crystal_icon
	_upgrade_cost_icon.texture = crystal_icon
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
	_build_section.visible = false
	_repair_hint_icon.texture = SkillIcons.icon_for(RepairSkill.DEF.id)
	_repair_hint_icon.tooltip_text = RepairSkill.DEF.display_name
	set_process(true)
	set_process_unhandled_input(true)


func is_armed() -> bool:
	return not _armed_key.is_empty()


func _on_minimize_pressed() -> void:
	_is_minimized = not _is_minimized
	_apply_minimize_layout()


## Called by Match HUD after it repositions this panel so minimize state sticks.
func notify_hud_layout() -> void:
	_expanded_top_offset = offset_bottom - _expanded_minimum_height
	_apply_minimize_layout()


func _apply_minimize_layout() -> void:
	_content.visible = not _is_minimized
	if _is_minimized:
		custom_minimum_size.y = 54.0
		offset_top = offset_bottom - 54.0
		_minimize_button.text = "Expand"
		_minimize_button.tooltip_text = "Expand building panel"
	else:
		custom_minimum_size.y = _expanded_minimum_height
		offset_top = offset_bottom - _expanded_minimum_height
		_minimize_button.text = "Minimize"
		_minimize_button.tooltip_text = "Minimize building panel"


func _process(_delta: float) -> void:
	var show_panel := HudMode.is_active_runner(_local_peer_id())
	visible = show_panel
	if not show_panel:
		_disarm()
		_mode = HudMode.Mode.NONE
		return
	_refresh_mode()
	_refresh_build_buttons()
	_refresh_selected_building()
	if is_armed() and HudMode.can_build(_mode):
		_update_ghost()
	elif _ghost != null:
		_ghost.visible = false


func _refresh_mode() -> void:
	var manager := _selection_manager()
	var selected: Node = manager.selected if manager != null else null
	var next := HudMode.resolve(selected, _local_peer_id(), true)
	if next != _mode:
		_tower_upgrade_hotkey_pending = false
		if not HudMode.can_build(next):
			_disarm()
		_mode = next


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if _handle_build_hotkey(event as InputEventKey):
			return
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


func _handle_build_hotkey(key: InputEventKey) -> bool:
	if key.echo or not key.pressed:
		return false
	var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	if _tower_upgrade_hotkey_pending:
		if code == KEY_ESCAPE:
			_tower_upgrade_hotkey_pending = false
			get_viewport().set_input_as_handled()
			return true
		if TOWER_PICK_HOTKEYS.has(code):
			_on_pick_pressed(TOWER_PICK_HOTKEYS[code])
			get_viewport().set_input_as_handled()
			return true
	if code == KEY_D and HudMode.can_manage_building(_mode):
		_on_destroy_pressed()
		get_viewport().set_input_as_handled()
		return true
	if code == KEY_U and HudMode.can_manage_building(_mode):
		_on_upgrade_hotkey_pressed()
		get_viewport().set_input_as_handled()
		return true
	if not HudMode.can_build(_mode):
		return false
	if not BUILD_HOTKEYS.has(code):
		return false
	var build_key: String = BUILD_HOTKEYS[code]
	_on_build_button_pressed(build_key)
	get_viewport().set_input_as_handled()
	return true


func _on_build_button_pressed(key: String) -> void:
	if not HudMode.can_build(_mode):
		_disarm()
		return
	_armed_key = "" if _armed_key == key else key
	if not is_armed() and _ghost != null:
		_ghost.visible = false


func _on_upgrade_pressed() -> void:
	if not HudMode.can_manage_building(_mode):
		return
	_tower_upgrade_hotkey_pending = false
	var manager := _construction_manager()
	if manager == null:
		return
	for building in _managed_buildings():
		if building.can_upgrade() and not building.is_tower():
			manager.request_upgrade(building.name)


func _on_pick_pressed(path: int) -> void:
	if not HudMode.can_manage_building(_mode):
		return
	_tower_upgrade_hotkey_pending = false
	var manager := _construction_manager()
	if manager == null:
		return
	for building in _managed_buildings():
		if building.can_upgrade() and building.is_tower():
			manager.request_upgrade(building.name, path)


func _on_destroy_pressed() -> void:
	if not HudMode.can_manage_building(_mode):
		return
	_tower_upgrade_hotkey_pending = false
	var manager := _construction_manager()
	if manager == null:
		return
	var names: Array[String] = []
	for building in _managed_buildings():
		names.append(building.name)
	for building_name in names:
		manager.request_destroy(building_name)
	_pending_building_name = ""
	_selected_section.visible = false


func _disarm() -> void:
	_armed_key = ""
	_tower_upgrade_hotkey_pending = false
	if _ghost != null:
		_ghost.visible = false


func _on_upgrade_hotkey_pressed() -> void:
	var buildings := _managed_buildings()
	if buildings.is_empty():
		return
	var building := buildings[0]
	if not building.is_tower():
		_on_upgrade_pressed()
		return
	if not building.can_upgrade():
		return
	if GameManager.crystals_for(_local_peer_id()) < building.next_upgrade_cost():
		return
	_tower_upgrade_hotkey_pending = true
	_upgrade_hint.text = "Choose a path: 1 Damage, 2 Speed, 3 Crit, 4 Range (Esc cancels)"


func _refresh_build_buttons() -> void:
	var can_place := HudMode.can_build(_mode)
	_build_section.visible = can_place
	if not can_place:
		for key in BUILD_KEYS:
			var button: Button = _build_buttons[key]
			button.button_pressed = false
			button.disabled = true
		if HudMode.can_manage_building(_mode):
			_info_label.text = "Manage selected: U upgrade, D destroy"
		else:
			_info_label.text = "Select your Runner to build"
		return
	var crystals := GameManager.crystals_for(_local_peer_id())
	var construction := _construction_manager()
	for key in BUILD_KEYS:
		var def := ConstructionManager.def_for(key)
		var button: Button = _build_buttons[key]
		button.button_pressed = _armed_key == key
		button.icon = BuildingIcons.icon_for(key)
		if def == null:
			button.disabled = true
			continue
		var short_name: String = SHORT_NAMES.get(key, def.display_name)
		var hotkey := _hotkey_label_for(key)
		var cost := int(def.cost_for_level(1))
		button.text = "%s [%s]" % [short_name, hotkey]
		var cost_label: Label = _build_cost_labels[key]
		cost_label.text = str(cost)
		button.tooltip_text = "Build %s [%s]" % [def.display_name, hotkey]
		var blocked_by_mine_cap: bool = key == "crystal_mine" and construction != null \
				and construction.owns_crystal_mine(_local_peer_id())
		if blocked_by_mine_cap:
			button.disabled = true
			button.tooltip_text = "Only one Crystal Mine allowed per player"
			if _armed_key == "crystal_mine":
				_disarm()
		else:
			button.disabled = crystals < cost
	if is_armed():
		var def := ConstructionManager.def_for(_armed_key)
		_info_label.text = "Placing %s — LMB place, Shift+LMB chain, RMB/Esc cancel" % (
			def.display_name if def else _armed_key
		)
	else:
		_info_label.text = "Select a structure to build — W Wall, T Tower, C Mine"


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
	if not HudMode.can_build(_mode):
		_disarm()
		return
	var manager := _construction_manager()
	var def := ConstructionManager.def_for(_armed_key)
	if manager == null or def == null:
		return
	var anchor := manager.grid.snap_anchor_cell(_world_mouse_position(), def.footprint)
	if not manager.can_place_preview(_armed_key, anchor):
		return
	manager.request_build(_armed_key, anchor)
	## Shift/Ctrl+LMB keeps placement armed so you can chain buildings like move waypoints.
	if SelectionManager.is_chain_modifier_held():
		return
	_disarm()


func _refresh_selected_building() -> void:
	if not HudMode.can_manage_building(_mode):
		_selected_section.visible = false
		_pending_building_name = ""
		return
	var buildings := _managed_buildings()
	if buildings.is_empty():
		_selected_section.visible = false
		_pending_building_name = ""
		return
	var building := buildings[0]
	if building.def == null:
		_selected_section.visible = false
		_pending_building_name = ""
		return
	if _pending_building_name != building.name:
		_tower_upgrade_hotkey_pending = false
	_selected_section.visible = true
	_repair_hint_row.visible = _has_repairable_building(buildings)
	_pending_building_name = building.name
	var def := building.def
	var level_suffix := " (building...)" if building.is_under_construction() and building.level < 2 else ""
	if buildings.size() > 1:
		_selected_name.text = "%s ×%d — Lv %d / %d%s" % [
			def.display_name,
			buildings.size(),
			building.level,
			def.max_level,
			level_suffix,
		]
	else:
		_selected_name.text = "%s — Lv %d / %d%s" % [
			def.display_name,
			building.level,
			def.max_level,
			level_suffix,
		]
	_selected_icon.texture = BuildingIcons.icon_for_def(def, building.level)
	_bind_building_stat_rows(building)
	_refresh_upgrade_area(building)
	var group_count := buildings.size()
	_destroy_button.text = "Destroy [D]" if group_count <= 1 else "Destroy all [D]"
	_destroy_button.tooltip_text = "Destroy selected structure(s) (D)"


func _has_repairable_building(buildings: Array[Building]) -> bool:
	for building in buildings:
		if building.state != Building.State.UNDER_CONSTRUCTION and building.is_damaged():
			return true
	return false


func _bind_building_stat_rows(building: Building) -> void:
	var def := building.def
	var hp_text := "%.0f / %.0f" % [building.health.current, building.max_health]
	_stat_hp.bind_text(StatIcons.icon(StatBlock.Stat.MAX_HEALTH), hp_text, "Health")
	match def.kind:
		BuildingDef.Kind.WALL:
			_stat_tertiary.clear_row()
			_stat_quaternary.clear_row()
			_stat_tertiary.visible = false
			_stat_quaternary.visible = false
			_stat_secondary.visible = true
			if building.max_shield > 0.0:
				var shield_text := "%.0f / %.0f" % [building.shield.current, building.max_shield]
				_stat_secondary.bind_text(
					StatIcons.icon(StatBlock.Stat.DEFENSE),
					shield_text,
					"Shield",
				)
			else:
				_stat_secondary.bind_text(
					StatIcons.icon(StatBlock.Stat.DEFENSE),
					"Shield at Lv %d" % def.shield_unlock_level,
					"Shield",
				)
		BuildingDef.Kind.CRYSTAL_MINE:
			_stat_tertiary.clear_row()
			_stat_quaternary.clear_row()
			_stat_tertiary.visible = false
			_stat_quaternary.visible = false
			_stat_secondary.visible = true
			var output := def.mine_output_for_level(building.level)
			var rate := "%s / %ss" % [
				StatIcons.short_number(output),
				StatIcons.short_number(def.mine_interval),
			]
			_stat_secondary.bind_text(BuildingIcons.crystal_icon(), rate, "Crystal output")
		BuildingDef.Kind.TOWER:
			_stat_secondary.visible = true
			_stat_tertiary.visible = true
			_stat_quaternary.visible = true
			var stats := building.stats
			## Live tower damage is RANGED_DAMAGE; icon reuses the melee sword (same as pick UI).
			_stat_secondary.bind_text(
				StatIcons.icon(StatBlock.Stat.MELEE_DAMAGE),
				StatIcons.format_value(stats, StatBlock.Stat.RANGED_DAMAGE),
				"Damage",
			)
			_stat_tertiary.bind_stat(stats, StatBlock.Stat.ATTACK_SPEED)
			_stat_quaternary.bind_stat(stats, StatBlock.Stat.ATTACK_RANGE)
		_:
			_stat_secondary.visible = false
			_stat_tertiary.visible = false
			_stat_quaternary.visible = false


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
	_upgrade_cost_row.visible = building.state != Building.State.UPGRADING
	_upgrade_cost_label.text = str(int(cost))
	_upgrade_button.visible = not is_tower
	_pick_grid.visible = is_tower
	_upgrade_hint.visible = is_tower
	if is_tower:
		if building.state == Building.State.UPGRADING:
			_upgrade_hint.text = "Upgrading to Lv %d…" % (building.level + 1)
			_tower_upgrade_hotkey_pending = false
		elif _tower_upgrade_hotkey_pending:
			_upgrade_hint.text = "Choose a path: 1 Damage, 2 Speed, 3 Crit, 4 Range (Esc cancels)"
		else:
			_upgrade_hint.text = "Upgrade to Lv %d — U, then 1–4 to choose:" % [
				building.level + 1,
			]
		var can_pick := building.can_upgrade() and affordable
		for path in _pick_buttons.size():
			var pick_button := _pick_buttons[path]
			pick_button.icon = StatIcons.icon(PICK_ICON_STATS[path])
			pick_button.text = "%d: %s" % [path + 1, _pick_grant_short(def, path)]
			pick_button.tooltip_text = _pick_grant_long(def, path)
			pick_button.disabled = not can_pick
		return
	_upgrade_button.icon = _upgrade_icon_for(def.kind)
	if building.state == Building.State.UPGRADING:
		_upgrade_button.text = "Upgrading to Lv %d…" % (building.level + 1)
	elif _managed_buildings().size() > 1:
		_upgrade_button.text = "Upgrade all [U]"
	else:
		_upgrade_button.text = "Upgrade [U]"
	_upgrade_button.tooltip_text = _upgrade_tooltip_for(def.kind)
	_upgrade_button.disabled = not building.can_upgrade() or not affordable


func _hotkey_label_for(key: String) -> String:
	match key:
		"wall":
			return "W"
		"tower":
			return "T"
		"crystal_mine":
			return "C"
	return ""


func _managed_buildings() -> Array[Building]:
	var manager := _selection_manager()
	if manager == null:
		return []
	var buildings := manager.selected_buildings()
	var owned: Array[Building] = []
	var local_id := _local_peer_id()
	for building in buildings:
		if building.def != null and building.owner_peer_id == local_id:
			owned.append(building)
	return owned


func _upgrade_icon_for(kind: BuildingDef.Kind) -> Texture2D:
	match kind:
		BuildingDef.Kind.WALL:
			return StatIcons.icon(StatBlock.Stat.MAX_HEALTH)
		BuildingDef.Kind.CRYSTAL_MINE:
			return BuildingIcons.crystal_icon()
		_:
			return StatIcons.icon(StatBlock.Stat.MELEE_DAMAGE)


func _upgrade_tooltip_for(kind: BuildingDef.Kind) -> String:
	match kind:
		BuildingDef.Kind.WALL:
			return "Raise wall HP (and shield from Lv 15)"
		BuildingDef.Kind.CRYSTAL_MINE:
			return "Double crystal output"
		_:
			return "Upgrade"


func _pick_grant_short(def: BuildingDef, path: int) -> String:
	match path:
		BuildingDef.TowerPath.RANGED_DAMAGE:
			return "+%s%% Dmg" % StatIcons.short_number(def.tower_damage_per_pick * 100.0)
		BuildingDef.TowerPath.ATTACK_SPEED:
			return "+%s%% Spd" % StatIcons.short_number(def.tower_attack_speed_per_pick * 100.0)
		BuildingDef.TowerPath.CRIT:
			return "+%s%% Crit" % StatIcons.short_number(def.tower_crit_chance_per_pick * 100.0)
		BuildingDef.TowerPath.ATTACK_RANGE:
			return "+%s%% Rng" % StatIcons.short_number(def.tower_range_per_pick * 100.0)
	return ""


func _pick_grant_long(def: BuildingDef, path: int) -> String:
	match path:
		BuildingDef.TowerPath.RANGED_DAMAGE:
			return "+%s%% Ranged Damage" % StatIcons.short_number(def.tower_damage_per_pick * 100.0)
		BuildingDef.TowerPath.ATTACK_SPEED:
			return "+%s%% Attack Speed" % StatIcons.short_number(def.tower_attack_speed_per_pick * 100.0)
		BuildingDef.TowerPath.CRIT:
			return "+%s%% Crit Chance and +%s%% Crit Damage" % [
				StatIcons.short_number(def.tower_crit_chance_per_pick * 100.0),
				StatIcons.short_number(def.tower_crit_damage_per_pick * 100.0),
			]
		BuildingDef.TowerPath.ATTACK_RANGE:
			return "+%s%% Attack Range" % StatIcons.short_number(def.tower_range_per_pick * 100.0)
	return ""


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


func _selection_manager() -> SelectionManager:
	return SelectionQueries.manager(get_tree())


func _local_peer_id() -> int:
	return GameManager.local_peer_id()
