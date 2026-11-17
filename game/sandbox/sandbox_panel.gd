extends Node
## Debug panel for local multiplayer. Visible in debug builds and when launched with
## --sandbox. Hidden for bots, headless runs, and release exports.
##
## Bot buttons start another copy of this project with the Godot executable path shown
## in the panel. They do nothing until that path points at a real Godot binary.

var _status := Label.new()
var _state := Label.new()
var _peers := Label.new()
var _bin_edit := LineEdit.new()
var _headless := CheckBox.new()
var _runner_count := 0
var _hunter_count := 0


func _ready() -> void:
	if not LaunchOptions.sandbox_enabled:
		set_process(false)
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size = Vector2(380, 0)
	layer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Sandbox"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)

	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_peers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_peers.custom_minimum_size = Vector2(350, 0)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_state)
	box.add_child(_peers)
	box.add_child(_status)

	_bin_edit.placeholder_text = "Path to the Godot executable"
	_bin_edit.text = OS.get_executable_path()
	box.add_child(_bin_edit)
	_headless.text = "Launch bots headless"
	box.add_child(_headless)

	_add_button(box, "Test lobby", _test_lobby)
	_add_button(box, "Test role selection", _test_selection)
	_add_button(box, "Test game", _test_game)
	_add_button(box, "Start local host", _host)
	_add_button(box, "Start host + 1 Hunter bot + 2 Runner bots", _quick_start)
	_add_button(box, "Add Runner bot", _add_runner)
	_add_button(box, "Add Hunter bot", _add_hunter)
	_add_button(box, "Continue to role selection", _continue_to_selection)
	_add_button(box, "Skip preparation", _skip_preparation)
	_add_button(box, "Reset match", _reset_match)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _add_button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
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
	_status.text = "Hosting with 1 Hunter bot and 2 Runner bots. Continue to role selection when they appear."


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
	_status.text = "Role selection opened on its own. Add test players, then resolve the vote."


func _test_game() -> void:
	if not _can_open_scene_directly():
		return
	GameManager.prepare_game_test()
	SceneTransitionManager.transition("", SceneTransitionManager.GAME)
	_status.text = "Game opened on its own as a Runner. Use --test-role=hunter to open it as the Hunter."


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
