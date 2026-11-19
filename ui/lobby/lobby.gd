extends Control
## Lobby screen: host or join, see who is connected, and (host only) continue to role selection.
## Built in code to keep the skeleton small.

var _name_edit := LineEdit.new()
var _address_edit := LineEdit.new()
var _status := Label.new()
var _player_list := ItemList.new()
var _connect_box := VBoxContainer.new()
var _lobby_box := VBoxContainer.new()
var _invite_button := Button.new()
var _start_button := Button.new()


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(460, 0)
	root.add_theme_constant_override("separation", 10)
	center.add_child(root)

	var title := Label.new()
	title.text = "CatchNRun"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	root.add_child(title)
	root.add_child(_status)

	_name_edit.placeholder_text = "Your name"
	_name_edit.text = GameManager.local_player_name
	if NetworkManager.steam_enabled:
		_name_edit.text = Steam.getPersonaName()
	_connect_box.add_child(_name_edit)
	var steam_button := _add_button(_connect_box, "Host with Steam (invite friends)", _on_host_steam)
	steam_button.disabled = not NetworkManager.steam_enabled
	_add_button(_connect_box, "Host local", _on_host_local)
	_address_edit.text = "127.0.0.1"
	_connect_box.add_child(_address_edit)
	_add_button(_connect_box, "Join local", _on_join_local)
	root.add_child(_connect_box)

	_player_list.custom_minimum_size = Vector2(0, 180)
	_lobby_box.add_child(_player_list)
	_invite_button.text = "Invite Steam friends"
	_invite_button.pressed.connect(NetworkManager.invite_friends)
	_lobby_box.add_child(_invite_button)
	_start_button.text = "Continue to role selection"
	_start_button.pressed.connect(GameManager.continue_to_selection)
	_lobby_box.add_child(_start_button)
	_add_button(_lobby_box, "Leave", NetworkManager.leave)
	root.add_child(_lobby_box)

	GameManager.players_changed.connect(_refresh)
	GameManager.phase_changed.connect(_on_phase_changed)
	NetworkManager.hosting_started.connect(_refresh)
	NetworkManager.joined_server.connect(_refresh)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.disconnected.connect(_refresh)
	_status.text = "" if NetworkManager.steam_enabled else "Steam is not running. Local hosting still works."
	_refresh()


func _add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
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
