extends Node
## Debug panel for local multiplayer and the dedicated-server browser host.
## Hidden for bots, headless runs, and non-host browser clients.
##
## Layout: the action bar and, stacked directly below it, the status + game log panel sit
## top-left (a minimized bar pulls the log up); native tests top-right. Match HUD corners
## stay free — minimap BL, selection BC, building BR (WP-17). Every panel has a Minimize
## button, and `G` (god mode) minimizes / expands all of them at once.

const RUNNER_ICON := preload("res://assets/sprites/units/Player_1.png")
const HUNTER_ICON := preload("res://assets/sprites/units/Enemy_1.png")

## Height of a minimized panel: just its header row plus the panel margins.
const COLLAPSED_HEIGHT := 48.0
## Expanded size of the action bar / log panel inside the top-left stack.
## Keep the log compact so it does not collide with the bottom HUD strip.
const ACTION_BAR_WIDTH := 640.0
const LOG_PANEL_SIZE := Vector2(360.0, 220.0)

var _status: Label
var _state: Label
var _peers: Label
var _log_view: RichTextLabel
var _log_scroll: ScrollContainer
var _bin_edit: LineEdit
var _headless: CheckBox
var _root: Control
var _runner_button: Button
var _hunter_button: Button
var _continue_button: Button
var _skip_button: Button
var _reset_button: Button
var _is_web_client := false
var _runner_count := 0
var _hunter_count := 0
var _log_listener: Callable
## One entry per minimizable panel: panel, button, hidden nodes, expanded offsets, state.
var _collapsibles: Array[Dictionary] = []
## Flat StatModifiers applied via the sandbox Stats panel (cleared with Reset stats).
var _sandbox_stat_mods: Array[StatModifier] = []
var _stats_readout: Label


func _ready() -> void:
	if not LaunchOptions.sandbox_enabled:
		set_process(false)
		return

	_is_web_client = OS.has_feature("web")
	_status = Label.new()
	_state = Label.new()
	_peers = Label.new()
	_bin_edit = LineEdit.new()
	_headless = CheckBox.new()
	_stats_readout = Label.new()

	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_root = root

	## Top-left stack: the log lives right under the action bar and follows it when it folds.
	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stack.offset_left = 16.0
	stack.offset_top = 12.0
	stack.add_theme_constant_override("separation", 8)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stack)

	_build_action_bar(stack)
	if not _is_web_client:
		_build_tests_panel(root)
	_build_stats_panel(root)
	_build_status_panel(stack)
	_log_listener = _on_game_log_line
	GameLog.add_listener(_log_listener)
	GameManager.test_bot_request_completed.connect(_on_test_bot_request_completed)
	_seed_log_view()
	_refresh()


func _exit_tree() -> void:
	if _log_listener.is_valid():
		GameLog.remove_listener(_log_listener)


func _process(_delta: float) -> void:
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _collapsibles.is_empty() or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.physical_keycode != KEY_G:
		return
	if _root != null and not _root.visible:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	_toggle_all_collapsed()
	get_viewport().set_input_as_handled()


func _build_action_bar(stack: Control) -> void:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(ACTION_BAR_WIDTH, 0.0)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.08, 0.1, 0.92)))
	stack.add_child(bar)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	bar.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)

	var title := Label.new()
	title.text = "Sandbox"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.98, 0.9, 0.45))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)

	if not _is_web_client:
		_add_text_button(top, "Host", _host)
	_runner_button = _add_icon_button(top, "Runner", RUNNER_ICON, _add_runner)
	_hunter_button = _add_icon_button(top, "Hunter", HUNTER_ICON, _add_hunter)
	_add_text_button(top, "1H+2R", _quick_start)
	_continue_button = _add_text_button(top, "Continue", _continue_to_selection)
	_skip_button = _add_text_button(top, "Skip", _skip_preparation)
	_skip_button.tooltip_text = "Skip Runner preparation and spawn the Hunter."
	_reset_button = _add_text_button(top, "Reset", _reset_match)

	# Everything except the title folds away when minimized.
	var hidden: Array[Control] = []
	for child in top.get_children():
		if child != title:
			hidden.append(child as Control)
	var toggle := _add_toggle_button(top)

	if not _is_web_client:
		var bottom := HBoxContainer.new()
		bottom.add_theme_constant_override("separation", 8)
		col.add_child(bottom)
		hidden.append(bottom)

		_headless.text = "Headless"
		_headless.button_pressed = true
		_headless.tooltip_text = "Launch bots without a window"
		bottom.add_child(_headless)

		_bin_edit.placeholder_text = "Godot executable"
		_bin_edit.text = OS.get_executable_path()
		_bin_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom.add_child(_bin_edit)

	_register_collapsible(bar, toggle, hidden, 200.0)


func _build_tests_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -250.0
	panel.offset_top = 12.0
	panel.offset_right = -16.0
	panel.offset_bottom = 150.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.09, 0.12, 0.94)))
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	var title := Label.new()
	title.text = "Tests"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var toggle := _add_toggle_button(header)

	var hidden: Array[Control] = [
		_add_text_button(box, "Lobby", _test_lobby),
		_add_text_button(box, "Roles", _test_selection),
		_add_text_button(box, "Game", _test_game),
	]
	_register_collapsible(panel, toggle, hidden)


## Top-right under Tests: bump crit / lifesteal / damage on the active sandbox character
## so floating combat numbers are easy to verify without editing .tres files.
func _build_stats_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -280.0
	panel.offset_top = 168.0
	panel.offset_right = -16.0
	panel.offset_bottom = 430.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.09, 0.12, 0.94)))
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var title := Label.new()
	title.text = "Stats (active)"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var toggle := _add_toggle_button(header)

	_stats_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_readout.add_theme_font_size_override("font_size", 12)
	_stats_readout.add_theme_color_override("font_color", Color(0.78, 0.86, 0.92))
	_stats_readout.text = "Select a unit in the match"
	box.add_child(_stats_readout)

	var hidden: Array[Control] = [
		_stats_readout,
		_add_text_button(box, "Crit +25%", _sandbox_add_crit_chance),
		_add_text_button(box, "Crit dmg +50%", _sandbox_add_crit_damage),
		_add_text_button(box, "Lifesteal +25%", _sandbox_add_lifesteal_chance),
		_add_text_button(box, "LS amount +10", _sandbox_add_lifesteal_amount),
		_add_text_button(box, "Damage +15", _sandbox_add_damage),
		_add_text_button(box, "Regen +5/s", _sandbox_add_regen),
		_add_text_button(box, "XP +50", _sandbox_add_xp),
		_add_text_button(box, "Reset stats", _sandbox_clear_stat_mods),
	]
	_register_collapsible(panel, toggle, hidden)


func _build_status_panel(stack: Control) -> void:
	# Directly under the action bar; bottom-left stays free for the minimap.
	var panel := PanelContainer.new()
	panel.custom_minimum_size = LOG_PANEL_SIZE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.07, 0.09, 0.85)))
	stack.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(box)

	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_peers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var log_title := Label.new()
	log_title.text = "Game log"
	log_title.add_theme_font_size_override("font_size", 14)
	log_title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	log_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(log_title)
	var toggle := _add_toggle_button(header)

	box.add_child(_state)
	box.add_child(_peers)
	box.add_child(_status)

	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.custom_minimum_size = Vector2(0, 140)
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(_log_scroll)

	_log_view = RichTextLabel.new()
	_log_view.bbcode_enabled = false
	_log_view.fit_content = true
	_log_view.scroll_active = false
	_log_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_view.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_view.add_theme_font_size_override("normal_font_size", 12)
	_log_view.add_theme_color_override("default_color", Color(0.78, 0.86, 0.92))
	_log_scroll.add_child(_log_view)

	_register_collapsible(panel, toggle, [_state, _peers, _status, _log_scroll], 200.0)


func _add_toggle_button(parent: Node) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(84, 28)
	# No focus, so Space / Enter never re-trigger it after a click.
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button


## Makes `panel` minimizable. `hidden` are the nodes that fold away; the header (with the
## toggle button) stays. A panel inside a Container (the top-left stack) shrinks through its
## minimum size, so the panels below it move up. A free-floating panel keeps its anchor corner
## and shrinks toward it, to COLLAPSED_HEIGHT tall. Either way it becomes `collapsed_width`
## wide (or keeps its width when 0).
func _register_collapsible(
	panel: Control, button: Button, hidden: Array, collapsed_width := 0.0
) -> void:
	var entry := {
		"panel": panel,
		"button": button,
		"hidden": hidden,
		"width": collapsed_width,
		"managed": panel.get_parent() is Container,
		"min_size": panel.custom_minimum_size,
		"left": panel.offset_left,
		"top": panel.offset_top,
		"right": panel.offset_right,
		"bottom": panel.offset_bottom,
		"collapsed": false,
	}
	_collapsibles.append(entry)
	button.pressed.connect(func() -> void:
		SoundManager.play_ui()
		_set_collapsed(entry, not bool(entry["collapsed"]))
	)
	_set_collapsed(entry, false)


func _set_collapsed(entry: Dictionary, collapsed: bool) -> void:
	entry["collapsed"] = collapsed
	var panel: Control = entry["panel"]
	var button: Button = entry["button"]
	for node in entry["hidden"]:
		(node as Control).visible = not collapsed
	var width: float = entry["width"]
	if bool(entry["managed"]):
		var min_size: Vector2 = entry["min_size"]
		if collapsed:
			panel.custom_minimum_size = Vector2(width if width > 0.0 else min_size.x, 0.0)
		else:
			panel.custom_minimum_size = min_size
		panel.reset_size()
		button.text = "Expand" if collapsed else "Minimize"
		button.tooltip_text = "%s panel (G toggles all)" % ("Expand" if collapsed else "Minimize")
		return
	panel.offset_left = entry["left"]
	panel.offset_top = entry["top"]
	panel.offset_right = entry["right"]
	panel.offset_bottom = entry["bottom"]
	if collapsed:
		if panel.anchor_top >= 1.0:
			panel.offset_top = panel.offset_bottom - COLLAPSED_HEIGHT
		else:
			panel.offset_bottom = panel.offset_top + COLLAPSED_HEIGHT
		if width > 0.0:
			if panel.anchor_left >= 1.0:
				panel.offset_left = panel.offset_right - width
			else:
				panel.offset_right = panel.offset_left + width
	button.text = "Expand" if collapsed else "Minimize"
	button.tooltip_text = "%s panel (G toggles all)" % ("Expand" if collapsed else "Minimize")


## `G` (god mode): if anything is open, minimize everything; otherwise expand everything.
func _toggle_all_collapsed() -> void:
	var any_open := false
	for entry in _collapsibles:
		if not bool(entry["collapsed"]):
			any_open = true
			break
	for entry in _collapsibles:
		_set_collapsed(entry, any_open)


func _panel_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color(0.95, 0.82, 0.35, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style


func _add_text_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 32)
	button.pressed.connect(func() -> void:
		SoundManager.play_ui()
		callback.call()
	)
	parent.add_child(button)
	return button


func _active_sandbox_unit() -> Unit:
	if not GameManager.sandbox_mode:
		return null
	var peer := GameManager.local_peer_id()
	for node in get_tree().get_nodes_in_group("units"):
		if not node is Unit:
			continue
		var unit := node as Unit
		if unit.peer_id == peer and unit.is_alive():
			return unit
	return null


func _sandbox_add_flat(stat: StatBlock.Stat, value: float, label: String) -> void:
	var unit := _active_sandbox_unit()
	if unit == null:
		_status.text = "No active sandbox unit to buff."
		return
	var modifier := StatModifier.new()
	modifier.kind = StatModifier.Kind.FLAT
	modifier.scope = StatModifier.Scope.ONE_STAT
	modifier.stat = stat
	modifier.value = value
	unit.stats.add_modifier(modifier)
	_sandbox_stat_mods.append(modifier)
	_status.text = "Sandbox: %s on %s" % [label, unit.name_label.text if unit.name_label else str(unit.peer_id)]
	_refresh_stats_readout()


func _sandbox_add_crit_chance() -> void:
	_sandbox_add_flat(StatBlock.Stat.CRITICAL_CHANCE, 0.25, "Crit chance +25%")


func _sandbox_add_crit_damage() -> void:
	_sandbox_add_flat(StatBlock.Stat.CRITICAL_DAMAGE_MULTIPLIER, 0.5, "Crit damage +50%")


func _sandbox_add_lifesteal_chance() -> void:
	_sandbox_add_flat(StatBlock.Stat.LIFESTEAL_CHANCE, 0.25, "Lifesteal chance +25%")


func _sandbox_add_lifesteal_amount() -> void:
	_sandbox_add_flat(StatBlock.Stat.LIFESTEAL_AMOUNT, 10.0, "Lifesteal amount +10")


func _sandbox_add_damage() -> void:
	_sandbox_add_flat(StatBlock.Stat.MELEE_DAMAGE, 15.0, "Melee damage +15")


func _sandbox_add_regen() -> void:
	_sandbox_add_flat(StatBlock.Stat.HEALTH_REGENERATION, 5.0, "Regen +5/s")


func _sandbox_add_xp() -> void:
	var unit := _active_sandbox_unit()
	if unit == null:
		_status.text = "No active sandbox unit for XP."
		return
	if unit.role() != RoleConfig.Role.HUNTER:
		_status.text = "Only the Hunter earns XP (Runners stay Lv 1, full violet ring)."
		return
	unit.grant_xp(50.0)
	_status.text = "Sandbox: +50 XP → Lv %d (%.0f / %.0f)" % [
		unit.level,
		unit.xp,
		XpProgress.xp_to_next(unit.level),
	]
	_refresh_stats_readout()


func _sandbox_clear_stat_mods() -> void:
	var unit := _active_sandbox_unit()
	if unit != null:
		for modifier in _sandbox_stat_mods:
			if modifier != null:
				unit.stats.remove_modifier(modifier)
	## Also strip mods that may have been left on the other sandbox character.
	for node in get_tree().get_nodes_in_group("units"):
		if not node is Unit:
			continue
		var other := node as Unit
		if not GameManager.is_sandbox_character(other.peer_id):
			continue
		for modifier in _sandbox_stat_mods:
			if modifier != null:
				other.stats.remove_modifier(modifier)
	_sandbox_stat_mods.clear()
	_status.text = "Sandbox stat modifiers cleared."
	_refresh_stats_readout()


func _refresh_stats_readout() -> void:
	if _stats_readout == null:
		return
	var unit := _active_sandbox_unit()
	if unit == null or unit.stats == null:
		_stats_readout.text = "No active unit — enter the match and select Runner/Hunter"
		return
	var sheet := unit.stats
	_stats_readout.text = "Lv %d | XP %.0f / %.0f\nDMG %.0f | Crit %.0f%% ×%.1f\nLS %.0f%% +%.0f | Regen %.1f" % [
		unit.level,
		unit.xp,
		XpProgress.xp_to_next(unit.level),
		sheet.final_value(StatBlock.Stat.MELEE_DAMAGE),
		sheet.final_value(StatBlock.Stat.CRITICAL_CHANCE) * 100.0,
		sheet.final_value(StatBlock.Stat.CRITICAL_DAMAGE_MULTIPLIER),
		sheet.final_value(StatBlock.Stat.LIFESTEAL_CHANCE) * 100.0,
		sheet.final_value(StatBlock.Stat.LIFESTEAL_AMOUNT),
		sheet.final_value(StatBlock.Stat.HEALTH_REGENERATION),
	]


func _add_icon_button(parent: Node, label: String, icon: Texture2D, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.icon = icon
	button.expand_icon = true
	button.custom_minimum_size = Vector2(108, 40)
	button.add_theme_constant_override("icon_max_width", 28)
	button.pressed.connect(func() -> void:
		SoundManager.play_ui()
		callback.call()
	)
	parent.add_child(button)
	return button


func _host() -> void:
	var err: Error = NetworkManager.start_server()
	if err == OK:
		_status.text = "Hosting WebSocket on port %d." % NetworkManager.PORT
	else:
		_status.text = "Could not host: %s" % error_string(err)


func _quick_start() -> void:
	if _is_web_client:
		if not _can_launch_web_bot():
			return
		if GameManager.players.size() + 3 > NetworkManager.MAX_PLAYERS:
			_status.text = "Not enough lobby slots for 1 Hunter and 2 Runner bots."
			return
		_launch_bot("hunter", "Hunter")
		_launch_bot("runner", "Runner 1")
		_launch_bot("runner", "Runner 2")
		_status.text = "Starting 1 Hunter and 2 Runner bots."
		return
	if NetworkManager.is_online() and not multiplayer.is_server():
		_status.text = "Leave the current game before starting a scenario."
		return
	if GameManager.phase != GameManager.Phase.LOBBY:
		_status.text = "Reset the match before starting a new scenario."
		return
	if not NetworkManager.is_online():
		var err: Error = NetworkManager.start_server()
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
	if not NetworkManager.is_online() or not GameManager.is_host():
		_status.text = "Only the host can open role selection."
		return
	GameManager.continue_to_selection()
	if GameManager.phase == GameManager.Phase.LOBBY:
		_status.text = "Need %d players in the lobby." % GameManager.required_players()
	else:
		_status.text = "Role selection opened."


func _skip_preparation() -> void:
	if not NetworkManager.is_online() or not GameManager.is_host():
		_status.text = "Only the host can skip preparation."
		return
	if GameManager.phase != GameManager.Phase.RUNNER_PREPARATION:
		_status.text = "Preparation is not running."
		return
	GameManager.request_skip_preparation()
	_status.text = "Skipping preparation."


func _reset_match() -> void:
	if NetworkManager.is_online() and not GameManager.is_host():
		_status.text = "Only the host can reset the match."
		return
	_runner_count = 0
	_hunter_count = 0
	GameManager.reset_match()
	_status.text = "Match reset."


func _seed_log_view() -> void:
	if _log_view == null:
		return
	_log_view.clear()
	for line in GameLog.history:
		_log_view.append_text(line + "\n")
	_scroll_log_to_end()


func _on_game_log_line(line: String) -> void:
	if _log_view == null:
		return
	_log_view.append_text(line + "\n")
	_scroll_log_to_end()


func _on_test_bot_request_completed(success: bool, message: String) -> void:
	_status.text = message
	var color := Color(0.75, 0.85, 0.95) if success else Color(1.0, 0.62, 0.55)
	_status.add_theme_color_override("font_color", color)


func _scroll_log_to_end() -> void:
	if _log_scroll == null:
		return
	await get_tree().process_frame
	if _log_scroll != null:
		_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


func _launch_bot(role: String, bot_name: String) -> bool:
	if _is_web_client:
		if not _can_launch_web_bot():
			return false
		GameManager.request_test_bot(role)
		_status.text = "Requesting %s bot." % role.capitalize()
		return true
	var bin := _bin_edit.text.strip_edges().trim_prefix("\"").trim_suffix("\"")
	if bin.is_empty():
		_status.text = "Set the Godot executable path before launching bots."
		return false
	var args := PackedStringArray()
	if _headless.button_pressed:
		args.append("--headless")
	if _is_godot_editor_binary(bin):
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


func _can_launch_web_bot() -> bool:
	if not NetworkManager.dedicated_server or not GameManager.is_host():
		_status.text = "Only the dedicated-server lobby host can add bots."
		return false
	if not GameManager.test_bots_enabled:
		_status.text = "Bot controls are not available on this server."
		return false
	if GameManager.phase != GameManager.Phase.LOBBY:
		_status.text = "Bots can only be added in the lobby."
		return false
	if GameManager.players.size() >= NetworkManager.MAX_PLAYERS:
		_status.text = "The lobby is full."
		return false
	return true


func _is_godot_editor_binary(bin: String) -> bool:
	var bin_dir := bin.get_base_dir()
	var bin_name := bin.get_file().to_lower()

	var dir := DirAccess.open(bin_dir)
	if dir != null:
		for file_name in dir.get_files():
			if file_name.to_lower().ends_with(".pck"):
				return false

	if not OS.has_feature("editor") and bin == OS.get_executable_path():
		return false

	if "godot" in bin_name:
		return true

	var project_dir := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	bin_dir = bin_dir.trim_suffix("/").trim_suffix("\\")
	if bin_dir == project_dir:
		return FileAccess.file_exists(bin_dir.path_join("project.godot"))

	return false


func _refresh() -> void:
	if _is_web_client:
		var is_host := _should_show_web_panel(
			NetworkManager.is_online(),
			NetworkManager.dedicated_server,
			GameManager.is_host()
		)
		_root.visible = is_host
		_runner_button.disabled = (
			not GameManager.test_bots_enabled
			or GameManager.phase != GameManager.Phase.LOBBY
			or GameManager.players.size() >= NetworkManager.MAX_PLAYERS
		)
		_hunter_button.disabled = _runner_button.disabled
		_continue_button.disabled = not GameManager.can_continue_to_selection()
		_skip_button.disabled = not is_host or GameManager.phase != GameManager.Phase.RUNNER_PREPARATION
		_reset_button.disabled = not is_host
	var seconds := int(ceil(GameManager.time_left))
	var timer := ""
	if GameManager.phase == GameManager.Phase.RUNNER_PREPARATION:
		timer = " (%d:%02d)" % [seconds / 60, seconds % 60]
	_state.text = "State: %s%s" % [GameManager.phase_label(), timer]
	_peers.text = _peer_block()
	_refresh_stats_readout()


func _should_show_web_panel(is_online: bool, is_dedicated_server: bool, is_host: bool) -> bool:
	return is_online and is_dedicated_server and is_host


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
		var who := "host" if id == GameManager.session_host_id else "client"
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
