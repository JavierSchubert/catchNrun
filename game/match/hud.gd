extends CanvasLayer
## Match HUD: phase status, selection panel, and minimap.
## Bottom chrome is laid out at runtime so panels do not overlap across resolutions.

const SANDBOX_CONTROLS := preload("res://game/match/sandbox_controls.gd")

const MARGIN := 16.0
const GAP := 12.0
const MINIMAP_SIZE := Vector2(220.0, 146.0)
const SEEK_SIZE := Vector2(120.0, 150.0)
## Includes in-panel skill slot (LoL-style) so Seek no longer sits beside the strip.
const SELECTION_SIZE := Vector2(640.0, 200.0)
const BUILDING_SIZE := Vector2(420.0, 600.0)
const UPGRADE_SIZE := Vector2(430.0, 250.0)
const STATUS_TOP := 72.0
const STATUS_HEIGHT := 56.0
const RESOURCE_CLEARANCE := 280.0

@onready var _root: Control = %Root
@onready var _status: Label = %Status
@onready var _selection_panel: SelectionPanel = %SelectionPanel
@onready var _minimap: MatchMinimap = %Minimap
@onready var _building_panel: Control = %BuildingPanel
@onready var _hunter_seek_panel: Control = %HunterSeekPanel
@onready var _hunter_upgrade_panel: Control = %HunterUpgradePanel
@onready var _resource_bar: Control = %ResourceBar

var _winner := ""
var _layout_signature := ""


func _ready() -> void:
	SettingsMenu.attach(_root)
	SoundManager.ensure_music()
	if GameManager.sandbox_mode:
		_root.add_child(SANDBOX_CONTROLS.new())
	GameManager.match_finished.connect(_on_match_finished)
	GameManager.phase_changed.connect(_on_phase_changed)
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	_nest_seek_into_selection()
	_layout_chrome(true)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()
	## Layout only when role / upgrade visibility / size signature changes.
	_layout_chrome(false)


func _nest_seek_into_selection() -> void:
	if _hunter_seek_panel == null or _selection_panel == null:
		return
	var slot := _selection_panel.get_node_or_null("%SkillSlot") as Control
	if slot == null:
		return
	if _hunter_seek_panel.get_parent() != slot:
		_hunter_seek_panel.reparent(slot)
	_hunter_seek_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hunter_seek_panel.offset_left = 0.0
	_hunter_seek_panel.offset_top = 0.0
	_hunter_seek_panel.offset_right = 0.0
	_hunter_seek_panel.offset_bottom = 0.0
	_hunter_seek_panel.custom_minimum_size = SEEK_SIZE
	slot.visible = _local_role() == RoleConfig.Role.HUNTER


func _on_viewport_size_changed() -> void:
	_layout_chrome(true)


func _on_match_finished(winner_team: String) -> void:
	_winner = winner_team


func _on_phase_changed(phase: GameManager.Phase) -> void:
	if phase == GameManager.Phase.LOBBY or phase == GameManager.Phase.ROLE_SELECTION:
		_winner = ""
	_layout_chrome(true)


func _refresh() -> void:
	var timer := ""
	if GameManager.phase == GameManager.Phase.RUNNER_PREPARATION:
		var secs := int(ceil(GameManager.time_left))
		timer = " | preparation %d:%02d" % [secs / 60, secs % 60]
	elif GameManager.phase == GameManager.Phase.HUNTER_ACTIVE:
		timer = " | hunter is in the match"
	elif GameManager.phase == GameManager.Phase.ENDED:
		timer = " | match over"
	var controls := "LMB select | RMB command own unit | C centers on you"
	if GameManager.sandbox_mode:
		controls = "Click a character to play it | RMB command | C centers on it"
	if LaunchOptions.sandbox_enabled:
		controls += " | G toggles the debug panels"
	var lines := [
		"%s%s" % [GameManager.phase_label(), timer],
		_local_unit_text(),
		controls,
	]
	if not _winner.is_empty():
		lines.append("%s team wins" % _winner.capitalize())
	_status.text = "\n".join(lines)
	_refresh_selection_panel()


func _refresh_selection_panel() -> void:
	if _selection_panel == null:
		return
	var manager := SelectionQueries.manager(get_tree())
	if manager == null:
		_selection_panel.bind_selection(null, false)
		return
	_selection_panel.bind_selection(manager.selected, manager.is_controllable_selected())


func _layout_chrome(force: bool) -> void:
	if _root == null:
		return
	var view := _root.get_viewport_rect().size
	if view.x < 32.0 or view.y < 32.0:
		return

	var is_runner := _local_role() == RoleConfig.Role.RUNNER
	var is_hunter := _local_role() == RoleConfig.Role.HUNTER
	var upgrade_visible := _hunter_upgrade_panel != null and _hunter_upgrade_panel.visible
	var signature := "%dx%d|%s|%s|%s" % [
		int(view.x),
		int(view.y),
		str(is_runner),
		str(is_hunter),
		str(upgrade_visible),
	]
	if not force and signature == _layout_signature:
		return
	_layout_signature = signature

	var reserve_building := is_runner
	var bottom := view.y - MARGIN
	var left_bound := MARGIN + MINIMAP_SIZE.x + GAP
	var right_bound := view.x - MARGIN
	if reserve_building:
		right_bound -= BUILDING_SIZE.x + GAP

	var middle := maxf(right_bound - left_bound, 0.0)
	## Selection strip owns the Seek skill slot internally (no side overlap).
	var selection_width := clampf(middle, 0.0, SELECTION_SIZE.x)
	var cluster_left := left_bound + maxf((middle - selection_width) * 0.5, 0.0)
	var bottom_inset := MARGIN

	_place_anchored(
		_minimap,
		Control.PRESET_BOTTOM_LEFT,
		MARGIN,
		MARGIN + MINIMAP_SIZE.x,
		bottom_inset + MINIMAP_SIZE.y,
		bottom_inset,
		MINIMAP_SIZE
	)
	_place_anchored(
		_selection_panel,
		Control.PRESET_BOTTOM_LEFT,
		cluster_left,
		cluster_left + selection_width,
		bottom_inset + SELECTION_SIZE.y,
		bottom_inset,
		Vector2(selection_width, SELECTION_SIZE.y)
	)
	var skill_slot := _selection_panel.get_node_or_null("%SkillSlot") as Control
	if skill_slot != null:
		skill_slot.visible = is_hunter
		if _hunter_seek_panel != null and _hunter_seek_panel.get_parent() != skill_slot:
			_nest_seek_into_selection()

	if _building_panel != null:
		_place_anchored(
			_building_panel,
			Control.PRESET_BOTTOM_RIGHT,
			-(MARGIN + BUILDING_SIZE.x),
			-MARGIN,
			bottom_inset + BUILDING_SIZE.y,
			bottom_inset,
			BUILDING_SIZE
		)
		if _building_panel.has_method("notify_hud_layout"):
			_building_panel.call("notify_hud_layout")

	if _hunter_upgrade_panel != null:
		## Above the bottom selection band so Seek / Selection stay clickable.
		var upgrade_inset := bottom_inset + SELECTION_SIZE.y + GAP
		_place_anchored(
			_hunter_upgrade_panel,
			Control.PRESET_BOTTOM_RIGHT,
			-(MARGIN + UPGRADE_SIZE.x),
			-MARGIN,
			upgrade_inset + UPGRADE_SIZE.y,
			upgrade_inset,
			UPGRADE_SIZE
		)

	_layout_status(reserve_building, is_hunter or upgrade_visible)
	if _resource_bar != null:
		_resource_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_resource_bar.offset_left = -RESOURCE_CLEARANCE * 0.5
		_resource_bar.offset_right = RESOURCE_CLEARANCE * 0.5
		_resource_bar.offset_top = 16.0
		_resource_bar.offset_bottom = 64.0


func _layout_status(clear_building: bool, clear_upgrade: bool) -> void:
	if _status == null:
		return
	var left := RESOURCE_CLEARANCE
	var right_clear := RESOURCE_CLEARANCE
	if clear_building:
		right_clear = maxf(right_clear, BUILDING_SIZE.x + MARGIN + GAP)
	if clear_upgrade:
		right_clear = maxf(right_clear, UPGRADE_SIZE.x + MARGIN + GAP)
	_status.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status.offset_left = left
	_status.offset_right = -right_clear
	_status.offset_top = STATUS_TOP
	_status.offset_bottom = STATUS_TOP + STATUS_HEIGHT


func _place_anchored(
	control: Control,
	preset: Control.LayoutPreset,
	left: float,
	right: float,
	top: float,
	bottom: float,
	size: Vector2
) -> void:
	if control == null:
		return
	control.set_anchors_preset(preset)
	control.offset_left = left
	control.offset_right = right
	control.offset_top = -top
	control.offset_bottom = -bottom
	control.custom_minimum_size = size


func _local_role() -> int:
	var id := GameManager.local_peer_id()
	if not GameManager.players.has(id):
		return GameManager.ANY_ROLE
	return int(GameManager.players[id].get("role", GameManager.ANY_ROLE))


func _local_unit_text() -> String:
	var id := GameManager.local_peer_id()
	if not GameManager.players.has(id):
		return "Waiting for the roster"
	var entry: Dictionary = GameManager.players[id]
	var role_id := int(entry.get("role", GameManager.ANY_ROLE))
	var role_name := GameManager.role_label(role_id)
	var player_name := str(entry.get("name", "Player"))
	if GameManager.is_eliminated(id):
		return "%s — %s eliminated (observing)" % [player_name, role_name]
	var unit := SelectionQueries.unit_for_peer(get_tree(), id, false)
	if unit != null:
		var maximum := unit.stats.final_value(StatBlock.Stat.MAX_HEALTH)
		return "%s — %s | HP %.0f / %.0f" % [player_name, role_name, unit.health.current, maximum]
	if role_id == RoleConfig.Role.HUNTER and GameManager.phase == GameManager.Phase.RUNNER_PREPARATION:
		return "%s — Hunter, waiting for preparation to end" % player_name
	return "%s — %s, waiting to spawn" % [player_name, role_name]
