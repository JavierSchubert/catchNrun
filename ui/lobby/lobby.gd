extends Control
## Lobby screen: host or join through WebSockets, see who is connected, and continue.
## Shell layout + StyleBoxes live in lobby.tscn / ui/styles/*.tres.

@onready var _name_edit: LineEdit = %NameEdit
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _status: Label = %Status
@onready var _player_list: ItemList = %PlayerList
@onready var _connect_box: VBoxContainer = %ConnectBox
@onready var _lobby_box: VBoxContainer = %LobbyBox
@onready var _start_button: Button = %StartButton
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _leave_button: Button = %LeaveButton
var _web_client := false


func _ready() -> void:
	_name_edit.text = GameManager.local_player_name
	_host_button.pressed.connect(_on_host_local)
	_join_button.pressed.connect(_on_join_local)
	_leave_button.pressed.connect(func() -> void:
		SoundManager.play_ui()
		NetworkManager.leave()
	)
	_start_button.pressed.connect(func() -> void:
		SoundManager.play_ui()
		GameManager.continue_to_selection()
	)

	SettingsMenu.attach(self)
	SoundManager.ensure_music()
	_web_client = OS.has_feature("web")
	if _web_client:
		_host_button.hide()
		_address_edit.hide()
		_join_button.text = "Connect"

	GameManager.players_changed.connect(_refresh)
	GameManager.phase_changed.connect(_on_phase_changed)
	NetworkManager.hosting_started.connect(_refresh)
	NetworkManager.joined_server.connect(_refresh)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.disconnected.connect(_refresh)
	_status.text = "Connect to the game server." if _web_client else ""
	_refresh()


func _apply_name() -> void:
	var player_name := _name_edit.text.strip_edges()
	GameManager.local_player_name = player_name if not player_name.is_empty() else "Player"


func _on_host_local() -> void:
	SoundManager.play_ui()
	_apply_name()
	var err: Error = NetworkManager.start_server()
	if err == OK:
		_status.text = ""
	else:
		_status.text = "Could not host (is port %d in use?): %s" % [NetworkManager.PORT, error_string(err)]


func _on_join_local() -> void:
	SoundManager.play_ui()
	_apply_name()
	var address := _address_edit.text.strip_edges()
	var err: Error
	if _web_client:
		err = NetworkManager.connect_web_client()
		address = "game server"
	else:
		err = NetworkManager.join_server(address)
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
	var host_id := GameManager.session_host_id
	if host_id == 0 and not online:
		host_id = 1
	for key in GameManager.players.keys():
		var id := int(key)
		var entry: Dictionary = GameManager.players[id]
		var host_tag := " (host)" if id == host_id else ""
		_player_list.add_item("%s%s" % [entry.get("name", "Player"), host_tag])
	var is_host: bool = online and GameManager.is_host()
	_start_button.visible = is_host
	_start_button.disabled = not GameManager.can_continue_to_selection()
	if _start_button.disabled:
		_start_button.text = "Continue (need %d players)" % GameManager.required_players()
	else:
		_start_button.text = "Continue to role selection"
	if online and not _status.text.begins_with("Could not") and not _status.text.begins_with("Connection"):
		if is_host:
			_status.text = "Lobby host" if NetworkManager.dedicated_server else "Hosting WebSocket on port %d" % NetworkManager.PORT
		else:
			_status.text = "Connected"
