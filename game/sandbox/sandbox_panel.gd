extends Node
## Debug panel for local multiplayer. Visible in debug builds and when launched with
## --sandbox. Hidden for bots, headless runs, and release exports.
##
## Top bar: host / bot actions with runner & hunter samples.
## Top-right: scene test shortcuts. Headless is on by default.

const RUNNER_ICON := preload("res://assets/sprites/units/Player_1.png")
const HUNTER_ICON := preload("res://assets/sprites/units/Enemy_1.png")

var _status: Label
var _state: Label
var _peers: Label
var _bin_edit: LineEdit
var _headless: CheckBox
var _runner_count := 0
var _hunter_count := 0


func _ready() -> void:
	if not LaunchOptions.sandbox_enabled:
		set_process(false)
		return

	_status = Label.new()
	_state = Label.new()
	_peers = Label.new()
	_bin_edit = LineEdit.new()
	_headless = CheckBox.new()

	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_build_action_bar(root)
	_build_tests_panel(root)
	_build_status_panel(root)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _build_action_bar(root: Control) -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 16.0
	bar.offset_top = 12.0
	bar.offset_right = -320.0
	bar.offset_bottom = 108.0
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.08, 0.1, 0.92)))
	root.add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)

	var title := Label.new()
	title.text = "Sandbox"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.98, 0.9, 0.45))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)

	_add_text_button(row, "Host", _host)
	_add_icon_button(row, "Add Runner", RUNNER_ICON, _add_runner)
	_add_icon_button(row, "Add Hunter", HUNTER_ICON, _add_hunter)
	_add_text_button(row, "Quick 1H+2R", _quick_start)
	_add_text_button(row, "Continue", _continue_to_selection)
	_add_text_button(row, "Skip prep", _skip_preparation)
	_add_text_button(row, "Reset", _reset_match)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_headless.text = "Headless"
	_headless.button_pressed = true
	_headless.tooltip_text = "Launch bots without a window"
	row.add_child(_headless)

	_bin_edit.placeholder_text = "Godot executable"
	_bin_edit.text = OS.get_executable_path()
	_bin_edit.custom_minimum_size = Vector2(220, 0)
	_bin_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bin_edit.size_flags_stretch_ratio = 0.6
	row.add_child(_bin_edit)


func _build_tests_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -300.0
	panel.offset_top = 12.0
	panel.offset_right = -16.0
	panel.offset_bottom = 168.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.09, 0.12, 0.94)))
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Tests"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	box.add_child(title)

	_add_text_button(box, "Test lobby", _test_lobby)
	_add_text_button(box, "Test role selection", _test_selection)
	_add_text_button(box, "Test game", _test_game)


func _build_status_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 16.0
	panel.offset_top = -150.0
	panel.offset_right = 420.0
	panel.offset_bottom = -16.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.07, 0.09, 0.85)))
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_peers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	box.add_child(_state)
	box.add_child(_peers)
	box.add_child(_status)


func _panel_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color(0.95, 0.82, 0.35, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	return style


func _add_text_button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 36)
	button.pressed.connect(func() -> void:
		SoundManager.play_ui()
		callback.call()
	)
	parent.add_child(button)


func _add_icon_button(parent: Node, label: String, icon: Texture2D, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.icon = icon
	button.expand_icon = true
	button.custom_minimum_size = Vector2(140, 56)
	button.add_theme_constant_override("icon_max_width", 40)
	button.pressed.connect(func() -> void:
		SoundManager.play_ui()
		callback.call()
	)
	parent.add_child(button)


func _host() -> void:
	var err: Error = NetworkManager.host_enet()
	if err == OK:
		_status.text = "Hosting on port %d." % NetworkManager.ENET_PORT
	else:
		_status.text = "Could not host: %s" % error_string(err)


func _quick_start() -> void:
	if NetworkManager.is_online() and not multiplayer.is_server():
		_status.text = "Leave the current game before starting a scenario."
		return
	if GameManager.phase != GameManager.Phase.LOBBY:
		_status.text = "Reset the match before starting a new scenario."
		return
	if not NetworkManager.is_online():
		var err: Error = NetworkManager.host_enet()
		if err != OK:
			_status.text = "Could not host: %s" % error_string(err)
			return
	if not _launch_bot("hunter", "Hunter"):
		return
	if not _launch_bot("runner", "Runner 1"):
		return
	if not _launch_bot("runner", "Runner 2"):
		return
	_hunter_count = 1
	_runner_count = 2
	_status.text = "Hosting with 1 Hunter bot and 2 Runner bots. Continue when they appear."


func _add_runner() -> void:
	_runner_count += 1
	if not _launch_bot("runner", "Runner %d" % _runner_count):
		_runner_count -= 1


func _add_hunter() -> void:
	_hunter_count += 1
	if not _launch_bot("hunter", "Hunter %d" % _hunter_count):
		_hunter_count -= 1


func _test_lobby() -> void:
	if not _can_open_scene_directly():
		return
	GameManager.prepare_lobby_test()
	SceneTransitionManager.transition("", SceneTransitionManager.LOBBY)
	_status.text = "Lobby opened on its own."


func _test_selection() -> void:
	if not _can_open_scene_directly():
		return
	GameManager.prepare_selection_test()
	SceneTransitionManager.transition("", SceneTransitionManager.ROLE_SELECTION)
	_status.text = "Role selection opened on its own."


func _test_game() -> void:
	if not _can_open_scene_directly():
		return
	GameManager.prepare_game_test()
	SceneTransitionManager.transition("", SceneTransitionManager.GAME)
	_status.text = "Game opened on its own as a Runner."


func _can_open_scene_directly() -> bool:
	if NetworkManager.is_online():
		_status.text = "Leave the session before opening a scene on its own."
		return false
	return true


func _continue_to_selection() -> void:
	if not NetworkManager.is_online() or not multiplayer.is_server():
		_status.text = "Only the host can open role selection."
		return
	GameManager.continue_to_selection()
	if GameManager.phase == GameManager.Phase.LOBBY:
		_status.text = "Need %d players in the lobby." % GameManager.required_players()
	else:
		_status.text = "Role selection opened."


func _skip_preparation() -> void:
	if not NetworkManager.is_online() or not multiplayer.is_server():
		_status.text = "Only the host can skip preparation."
		return
	if GameManager.phase != GameManager.Phase.RUNNER_PREPARATION:
		_status.text = "Preparation is not running."
		return
	GameManager.request_skip_preparation()
	_status.text = "Skipping preparation."


func _reset_match() -> void:
	if not NetworkManager.is_online() or not multiplayer.is_server():
		_status.text = "Only the host can reset the match."
		return
	GameManager.reset_match()
	_status.text = "Match reset."


func _launch_bot(role: String, bot_name: String) -> bool:
	var bin := _bin_edit.text.strip_edges().trim_prefix("\"").trim_suffix("\"")
	if bin.is_empty():
		_status.text = "Set the Godot executable path before launching bots."
		return false
	var args := PackedStringArray()
	if _headless.button_pressed:
		args.append("--headless")
	args.append("--path")
	args.append(ProjectSettings.globalize_path("res://"))
	args.append("--")
	args.append("--bot=%s" % role)
	args.append("--bot-name=%s" % bot_name)
	var pid := OS.create_process(bin, args)
	if pid <= 0:
		_status.text = "Could not start %s. Check the Godot path." % bot_name
		return false
	GameLog.info("SANDBOX", "started %s as %s (pid %d)" % [bot_name, role, pid])
	_status.text = "Started %s." % bot_name
	return true


func _refresh() -> void:
	var seconds := int(ceil(GameManager.time_left))
	var timer := ""
	if GameManager.phase == GameManager.Phase.RUNNER_PREPARATION:
		timer = " (%d:%02d)" % [seconds / 60, seconds % 60]
	_state.text = "State: %s%s" % [GameManager.phase_label(), timer]
	_peers.text = _peer_block()


func _peer_block() -> String:
	var lines: PackedStringArray = PackedStringArray()
	if not NetworkManager.is_online():
		lines.append("Peers: offline")
	else:
		var ids: Array[int] = [multiplayer.get_unique_id()]
		for peer_id in multiplayer.get_peers():
			ids.append(int(peer_id))
		ids.sort()
		lines.append("Peers: %s" % str(ids))
	for key in GameManager.players.keys():
		var id := int(key)
		var entry: Dictionary = GameManager.players[id]
		var who := "host" if id == 1 else "client"
		var player_name := str(entry.get("name", "Player"))
		if GameManager.phase == GameManager.Phase.ROLE_SELECTION:
			var preference := GameManager.role_label(int(entry.get("preferred_role", GameManager.ANY_ROLE)))
			lines.append("%d %s %s — prefers %s" % [id, who, player_name, preference])
		elif GameManager.phase == GameManager.Phase.LOBBY:
			lines.append("%d %s %s" % [id, who, player_name])
		else:
			var role_name := GameManager.role_label(int(entry.get("role", GameManager.ANY_ROLE)))
			lines.append("%d %s %s — %s" % [id, who, player_name, role_name])
	return "\n".join(lines)
