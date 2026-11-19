extends CanvasLayer
## Match HUD. Shows phase, timer, local role/health, and observer state.

var _status := Label.new()
var _winner := ""


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_font_size_override("font_size", 20)
	margin.add_child(_status)
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
		"Edge scroll camera | C centers on you",
	]
	if not _winner.is_empty():
		lines.append("%s team wins" % _winner.capitalize())
	_status.text = "\n".join(lines)


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
