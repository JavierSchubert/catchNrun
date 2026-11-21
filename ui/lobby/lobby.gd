extends Control
## Lobby screen: host or join, see who is connected, and (host only) continue to role selection.

const WALLPAPER := preload("res://assets/sprites/ui/wallpaper.png")

var _name_edit := LineEdit.new()
var _address_edit := LineEdit.new()
var _status := Label.new()
var _player_list := ItemList.new()
var _connect_box := VBoxContainer.new()
var _lobby_box := VBoxContainer.new()
var _invite_button := Button.new()
var _start_button := Button.new()


func _ready() -> void:
	_build_background()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	card.add_theme_stylebox_override("panel", _card_style())
	center.add_child(card)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	card.add_child(root)

	var title := Label.new()
	title.text = "Catch & Run"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.98, 0.9, 0.45))
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Host a match or join a friend"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.82, 0.82, 0.78))
	root.add_child(subtitle)

	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	root.add_child(_status)

	_style_line_edit(_name_edit, "Your name")
	_name_edit.text = GameManager.local_player_name
	if NetworkManager.steam_enabled:
		_name_edit.text = Steam.getPersonaName()
	_connect_box.add_theme_constant_override("separation", 10)
	_connect_box.add_child(_name_edit)

	var steam_button := _add_button(_connect_box, "Host with Steam (invite friends)", _on_host_steam)
	steam_button.disabled = not NetworkManager.steam_enabled
	_add_button(_connect_box, "Host local", _on_host_local)
	_style_line_edit(_address_edit, "127.0.0.1")
	_address_edit.text = "127.0.0.1"
	_connect_box.add_child(_address_edit)
	_add_button(_connect_box, "Join local", _on_join_local)
	root.add_child(_connect_box)

	_lobby_box.add_theme_constant_override("separation", 10)
	_player_list.custom_minimum_size = Vector2(0, 200)
	_style_item_list(_player_list)
	_lobby_box.add_child(_player_list)
	_invite_button.text = "Invite Steam friends"
	_style_button(_invite_button, true)
	_invite_button.pressed.connect(func() -> void:
		SoundManager.play_ui()
		NetworkManager.invite_friends()
	)
	_lobby_box.add_child(_invite_button)
	_start_button.text = "Continue to role selection"
	_style_button(_start_button, true)
	_start_button.pressed.connect(func() -> void:
		SoundManager.play_ui()
		GameManager.continue_to_selection()
	)
	_lobby_box.add_child(_start_button)
	_add_button(_lobby_box, "Leave", NetworkManager.leave)
	root.add_child(_lobby_box)

	SettingsMenu.attach(self)
	SoundManager.play_music(SoundManager.Sound.BG_MUSIC_1)

	GameManager.players_changed.connect(_refresh)
	GameManager.phase_changed.connect(_on_phase_changed)
	NetworkManager.hosting_started.connect(_refresh)
	NetworkManager.joined_server.connect(_refresh)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.disconnected.connect(_refresh)
	_status.text = "" if NetworkManager.steam_enabled else "Steam is not running. Local hosting still works."
	_refresh()


func _build_background() -> void:
	var wallpaper := TextureRect.new()
	wallpaper.texture = WALLPAPER
	wallpaper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallpaper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wallpaper)

	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.04, 0.06, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.92)
	style.border_color = Color(0.95, 0.82, 0.35, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 28
	style.content_margin_top = 24
	style.content_margin_right = 28
	style.content_margin_bottom = 24
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 12
	return style


func _button_style(accent: bool, hovered: bool = false, pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if accent:
		style.bg_color = Color(0.85, 0.62, 0.12, 1.0 if not pressed else 0.85)
		if hovered and not pressed:
			style.bg_color = Color(0.95, 0.72, 0.2)
	else:
		style.bg_color = Color(0.16, 0.18, 0.22, 1.0 if not pressed else 0.85)
		if hovered and not pressed:
			style.bg_color = Color(0.22, 0.25, 0.3)
	style.border_color = Color(0.95, 0.82, 0.35, 0.55 if not accent else 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_top = 10
	style.content_margin_right = 14
	style.content_margin_bottom = 10
	return style


func _style_button(button: Button, accent: bool = false) -> void:
	button.add_theme_stylebox_override("normal", _button_style(accent))
	button.add_theme_stylebox_override("hover", _button_style(accent, true))
	button.add_theme_stylebox_override("pressed", _button_style(accent, false, true))
	button.add_theme_stylebox_override("disabled", _button_style(false))
	button.add_theme_color_override("font_color", Color(0.95, 0.95, 0.92))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))
	button.custom_minimum_size = Vector2(0, 40)


func _style_line_edit(edit: LineEdit, placeholder: String) -> void:
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(0, 40)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.16, 1)
	style.border_color = Color(0.45, 0.45, 0.4, 1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	edit.add_theme_stylebox_override("normal", style)
	edit.add_theme_stylebox_override("focus", style)


func _style_item_list(list: ItemList) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.14, 1)
	style.border_color = Color(0.4, 0.4, 0.35, 1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	list.add_theme_stylebox_override("panel", style)
	list.add_theme_color_override("font_color", Color(0.92, 0.92, 0.9))


func _add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	_style_button(button, text.begins_with("Host") or text.begins_with("Continue") or text == "Join local")
	button.pressed.connect(func() -> void:
		SoundManager.play_ui()
		callback.call()
	)
	parent.add_child(button)
	return button


func _apply_name() -> void:
	var player_name := _name_edit.text.strip_edges()
	GameManager.local_player_name = player_name if not player_name.is_empty() else "Player"


func _on_host_steam() -> void:
	_apply_name()
	_status.text = "Creating Steam lobby..."
	NetworkManager.host_steam()


func _on_host_local() -> void:
	_apply_name()
	var err: Error = NetworkManager.host_enet()
	if err == OK:
		_status.text = ""
	else:
		_status.text = "Could not host (is port %d in use?): %s" % [NetworkManager.ENET_PORT, error_string(err)]


func _on_join_local() -> void:
	_apply_name()
	var address := _address_edit.text.strip_edges()
	var err: Error = NetworkManager.join_enet(address)
	if err == OK:
		_status.text = "Connecting to %s..." % address
	else:
		_status.text = "Could not join: %s" % error_string(err)


func _on_connection_failed() -> void:
	_status.text = "Connection failed."
	_refresh()


func _on_phase_changed(_phase: GameManager.Phase) -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var online: bool = NetworkManager.is_online()
	_connect_box.visible = not online
	_lobby_box.visible = online
	_player_list.clear()
	for key in GameManager.players.keys():
		var id := int(key)
		var entry: Dictionary = GameManager.players[id]
		var host_tag := " (host)" if id == 1 else ""
		_player_list.add_item("%s%s" % [entry.get("name", "Player"), host_tag])
	var is_host: bool = online and multiplayer.is_server()
	_invite_button.visible = is_host and NetworkManager.lobby_id != 0
	_start_button.visible = is_host
	_start_button.disabled = not GameManager.can_continue_to_selection()
	if _start_button.disabled:
		_start_button.text = "Continue (need %d players)" % GameManager.required_players()
	else:
		_start_button.text = "Continue to role selection"
	if online and not _status.text.begins_with("Could not") and not _status.text.begins_with("Connection"):
		if is_host and NetworkManager.lobby_id == 0:
			_status.text = "Hosting on port %d" % NetworkManager.ENET_PORT
		elif is_host:
			_status.text = "Hosting"
		else:
			_status.text = "Connected"
