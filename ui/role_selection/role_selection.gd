extends Control
## Role vote. Runners are on the left and the Hunter is on the right.
## The host resolves the vote. Several Hunter requests are decided at random.

var _result := Label.new()
var _runner_box := VBoxContainer.new()
var _hunter_box := VBoxContainer.new()
var _waiting_box := VBoxContainer.new()
var _start_button := Button.new()
var _rebuild_queued := false


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := Label.new()
	title.text = "Choose a side"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)

	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_result)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	root.add_child(columns)
	columns.add_child(_side_panel("Runners", Color(0.16, 0.28, 0.48), _runner_box))
	columns.add_child(_side_panel("Waiting", Color(0.2, 0.2, 0.2), _waiting_box))
	columns.add_child(_side_panel("Hunter", Color(0.45, 0.16, 0.16), _hunter_box))

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	root.add_child(actions)
	_add_button(actions, "Join Runners", func() -> void: GameManager.request_side(RoleConfig.Role.RUNNER))
	_add_button(actions, "Join Hunter", func() -> void: GameManager.request_side(RoleConfig.Role.HUNTER))
	if not NetworkManager.is_online():
		_add_button(actions, "Add test player", func() -> void: GameManager.add_test_player())
	if not NetworkManager.is_online() or multiplayer.is_server():
		_add_button(actions, "Resolve vote", func() -> void: GameManager.resolve_roles())
		_start_button = _add_button(actions, "Start game", func() -> void: GameManager.start_game_from_selection())

	GameManager.players_changed.connect(_queue_rebuild)
	GameManager.phase_changed.connect(func(_phase: GameManager.Phase) -> void: _queue_rebuild())
	_vote_for_automated_peer()
	_queue_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_rebuild")


func _side_panel(heading: String, color: Color, list_box: VBoxContainer) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.self_modulate = color
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var label := Label.new()
	label.text = heading
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	box.add_child(label)
	list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(list_box)
	return panel


func _add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _vote_for_automated_peer() -> void:
	if LaunchOptions.bot_role == "hunter":
		GameManager.request_side(RoleConfig.Role.HUNTER)
	elif LaunchOptions.bot_role == "runner":
		GameManager.request_side(RoleConfig.Role.RUNNER)
	elif LaunchOptions.auto_start_players > 0 and multiplayer.is_server():
		GameManager.request_side(RoleConfig.Role.RUNNER)


func _rebuild() -> void:
	_rebuild_queued = false
	if not is_inside_tree():
		return
	_clear(_runner_box)
	_clear(_hunter_box)
	_clear(_waiting_box)
	for key in GameManager.players.keys():
		var id := int(key)
		var entry: Dictionary = GameManager.players[id]
		var preference := int(entry.get("preferred_role", GameManager.ANY_ROLE))
		var row := _player_row(id, str(entry.get("name", "Player")))
		if preference == RoleConfig.Role.HUNTER:
			_hunter_box.add_child(row)
		elif preference == RoleConfig.Role.RUNNER:
			_runner_box.add_child(row)
		else:
			_waiting_box.add_child(row)
	if GameManager.resolved_hunter_id >= 0 and GameManager.players.has(GameManager.resolved_hunter_id):
		var hunter: Dictionary = GameManager.players[GameManager.resolved_hunter_id]
		_result.text = "Hunter: %s" % str(hunter.get("name", "Player"))
	else:
		_result.text = "The host resolves the vote. Several Hunter requests are decided at random."
	_start_button.disabled = NetworkManager.is_online() and not multiplayer.is_server()


func _player_row(peer_id: int, player_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	var suffix := " (you)" if peer_id == multiplayer.get_unique_id() else ""
	label.text = player_name + suffix
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if not NetworkManager.is_online() and peer_id >= GameManager.TEST_PLAYER_ID:
		_add_button(row, "Runners", _set_test_side.bind(peer_id, RoleConfig.Role.RUNNER))
		_add_button(row, "Hunter", _set_test_side.bind(peer_id, RoleConfig.Role.HUNTER))
	return row


func _set_test_side(peer_id: int, role: int) -> void:
	GameManager.request_side_for(peer_id, role)


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.free()
