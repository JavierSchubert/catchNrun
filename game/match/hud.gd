extends CanvasLayer
## Match HUD: phase status, selection panel, and minimap.

var _status := Label.new()
var _selection_panel: SelectionPanel
var _minimap: MatchMinimap
var _winner := ""


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_font_size_override("font_size", 18)
	_status.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_status.offset_left = 16.0
	_status.offset_top = 16.0
	_status.offset_right = 420.0
	_status.offset_bottom = 120.0
	root.add_child(_status)

	_minimap = MatchMinimap.new()
	_minimap.name = "Minimap"
	_minimap.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_minimap.offset_left = 16.0
	_minimap.offset_top = -162.0
	_minimap.offset_right = 236.0
	_minimap.offset_bottom = -16.0
	root.add_child(_minimap)

	_selection_panel = SelectionPanel.new()
	_selection_panel.name = "SelectionPanel"
	_selection_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_selection_panel.offset_left = -210.0
	_selection_panel.offset_top = -120.0
	_selection_panel.offset_right = 210.0
	_selection_panel.offset_bottom = -16.0
	root.add_child(_selection_panel)

	SettingsMenu.attach(root)
	SoundManager.ensure_music()

	GameManager.match_finished.connect(_on_match_finished)
	GameManager.phase_changed.connect(_on_phase_changed)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _on_match_finished(winner_team: String) -> void:
	_winner = winner_team


func _on_phase_changed(phase: GameManager.Phase) -> void:
	if phase == GameManager.Phase.LOBBY or phase == GameManager.Phase.ROLE_SELECTION:
		_winner = ""


func _refresh() -> void:
	var timer := ""
	if GameManager.phase == GameManager.Phase.RUNNER_PREPARATION:
		var secs := int(ceil(GameManager.time_left))
		timer = " | preparation %d:%02d" % [secs / 60, secs % 60]
	elif GameManager.phase == GameManager.Phase.HUNTER_ACTIVE:
		timer = " | hunter is in the match"
	elif GameManager.phase == GameManager.Phase.ENDED:
		timer = " | match over"
	var lines := [
		"%s%s" % [GameManager.phase_label(), timer],
		_local_unit_text(),
		"LMB select | RMB command own unit | C centers on you",
	]
	if not _winner.is_empty():
		lines.append("%s team wins" % _winner.capitalize())
	_status.text = "\n".join(lines)
	_refresh_selection_panel()


func _refresh_selection_panel() -> void:
	if _selection_panel == null:
		return
	var manager := get_tree().get_first_node_in_group("selection_manager") as SelectionManager
	if manager == null:
		_selection_panel.bind_selection(null, false)
		return
	_selection_panel.bind_selection(manager.selected, manager.is_controllable_selected())


func _local_unit_text() -> String:
	var id := multiplayer.get_unique_id()
	if not GameManager.players.has(id):
		return "Waiting for the roster"
	var entry: Dictionary = GameManager.players[id]
	var role_id := int(entry.get("role", GameManager.ANY_ROLE))
	var role_name := GameManager.role_label(role_id)
	var player_name := str(entry.get("name", "Player"))
	if GameManager.is_eliminated(id):
		return "%s — %s eliminated (observing)" % [player_name, role_name]
	for node in get_tree().get_nodes_in_group("units"):
		if node.name != str(id) or not node is Unit:
			continue
		var unit := node as Unit
		var maximum := unit.stats.final_value(StatBlock.Stat.MAX_HEALTH)
		return "%s — %s | HP %.0f / %.0f" % [player_name, role_name, unit.health.current, maximum]
	if role_id == RoleConfig.Role.HUNTER and GameManager.phase == GameManager.Phase.RUNNER_PREPARATION:
		return "%s — Hunter, waiting for preparation to end" % player_name
	return "%s — %s, waiting to spawn" % [player_name, role_name]
