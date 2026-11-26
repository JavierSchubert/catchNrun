class_name SandboxControls
extends PanelContainer
## Top-right panel of the start-menu sandbox (GameManager.sandbox_mode). Lets the one local
## player hop between the Runner and the Hunter, restart the scene, or leave. Clicking a
## character in the world does the same as its button (SelectionManager follows the click).
## Pure presentation: character ownership lives in GameManager, nothing here is gameplay.

const BORDER_COLOR := Color(0.95, 0.82, 0.35, 0.55)

var _runner_button: Button
var _hunter_button: Button
var _hint: Label


func _ready() -> void:
	name = "SandboxControls"
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	## The debug "Tests" panel (sandbox_panel.gd) sits at the very top right when it exists.
	var top := 160.0 if LaunchOptions.sandbox_enabled and not OS.has_feature("web") else 12.0
	offset_left = -250.0
	offset_right = -16.0
	offset_top = top
	offset_bottom = top + 150.0
	grow_vertical = Control.GROW_DIRECTION_END
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel_style())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var title := Label.new()
	title.text = "Sandbox"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	box.add_child(title)

	var characters := HBoxContainer.new()
	characters.add_theme_constant_override("separation", 6)
	box.add_child(characters)
	_runner_button = _add_button(characters, "Runner", true)
	_hunter_button = _add_button(characters, "Hunter", true)
	_runner_button.pressed.connect(_play.bind(GameManager.SANDBOX_RUNNER_ID))
	_hunter_button.pressed.connect(_play.bind(GameManager.SANDBOX_HUNTER_ID))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	box.add_child(actions)
	var restart := _add_button(actions, "Restart", false)
	restart.tooltip_text = "Fresh sandbox: both characters respawn, buildings are removed."
	restart.pressed.connect(func() -> void:
		SoundManager.play_ui()
		GameManager.restart_sandbox()
	)
	var leave := _add_button(actions, "Exit", false)
	leave.tooltip_text = "Back to the start menu."
	leave.pressed.connect(func() -> void:
		SoundManager.play_ui()
		GameManager.exit_sandbox()
	)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_hint)


func _process(_delta: float) -> void:
	var active := GameManager.local_peer_id()
	_runner_button.set_pressed_no_signal(active == GameManager.SANDBOX_RUNNER_ID)
	_hunter_button.set_pressed_no_signal(active == GameManager.SANDBOX_HUNTER_ID)
	_runner_button.disabled = not _is_character_alive(GameManager.SANDBOX_RUNNER_ID)
	_hunter_button.disabled = not _is_character_alive(GameManager.SANDBOX_HUNTER_ID)
	if active == GameManager.SANDBOX_HUNTER_ID:
		_hint.text = "Hunter: RMB an enemy or structure to attack, A + LMB attack-move."
	else:
		_hint.text = "Runner: build with the panel bottom right, RMB a damaged structure to repair."


func _play(peer_id: int) -> void:
	SoundManager.play_ui()
	var unit := _unit_for(peer_id)
	if unit == null or not unit.is_alive():
		return
	var manager := get_tree().get_first_node_in_group("selection_manager") as SelectionManager
	if manager != null:
		## Selecting the unit makes it the active character (SelectionManager).
		manager.select_entity(unit)
	else:
		GameManager.set_sandbox_active(peer_id)
	var camera := get_viewport().get_camera_2d()
	if camera != null and camera.has_method("center_on"):
		camera.call("center_on", unit.global_position)


func _is_character_alive(peer_id: int) -> bool:
	var unit := _unit_for(peer_id)
	return unit != null and unit.is_alive()


func _unit_for(peer_id: int) -> Unit:
	for node in get_tree().get_nodes_in_group("units"):
		if node is Unit and (node as Unit).peer_id == peer_id:
			return node as Unit
	return null


func _add_button(parent: Node, text: String, toggle: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = toggle
	button.custom_minimum_size = Vector2(0, 32)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.92)
	style.border_color = BORDER_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style
