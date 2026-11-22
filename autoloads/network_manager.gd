extends Node
## TRANSPORT LAYER: handles how peers connect to each other. It has no gameplay code.
##
## A Godot server owns the high-level multiplayer API. Native clients can also host
## locally; web clients connect to the game-owned server.

signal hosting_started
signal joined_server
signal connection_failed
signal disconnected
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

const PORT := 9082
const MAX_PLAYERS := 8

var dedicated_server := false
var _auto_reconnect := false
var _server_endpoint := ""
var _retry_timer := 0.0


func _ready() -> void:
	dedicated_server = LaunchOptions.server_mode
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	if not _auto_reconnect or is_online():
		return
	var peer := multiplayer.multiplayer_peer
	if peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		return
	_retry_timer -= delta
	if _retry_timer <= 0.0:
		_connect_client(_server_endpoint)


func is_online() -> bool:
	return not (multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func start_server() -> Error:
	if is_online():
		GameLog.info("NET", "cannot host while a multiplayer peer is already active")
		return ERR_ALREADY_IN_USE
	var peer := WebSocketMultiplayerPeer.new()
	peer.handshake_timeout = 15.0
	var bind_address := OS.get_environment("CATCHNRUN_SERVER_BIND")
	if bind_address.is_empty():
		bind_address = "0.0.0.0"
	var error := peer.create_server(PORT, bind_address)
	if error != OK:
		GameLog.info("NET", "could not host WebSocket server on port %d: %s" % [PORT, error_string(error)])
		return error
	multiplayer.multiplayer_peer = peer
	GameLog.info("NET", "WebSocket server listening on %s:%d" % [bind_address, PORT])
	hosting_started.emit()
	return OK


func join_server(address := "127.0.0.1", port := PORT) -> Error:
	_auto_reconnect = false
	if address.strip_edges().is_empty():
		GameLog.info("NET", "cannot connect with an empty server address")
		return ERR_INVALID_PARAMETER
	var endpoint := address
	if not endpoint.begins_with("ws://") and not endpoint.begins_with("wss://"):
		endpoint = "ws://%s:%d" % [address, port]
	return _connect_client(endpoint)


func connect_web_client() -> Error:
	_server_endpoint = str(ProjectSettings.get_setting("network/server_url", ""))
	if _server_endpoint.is_empty():
		var location = JavaScriptBridge.get_interface("window").location
		var scheme := "wss" if str(location.protocol) == "https:" else "ws"
		var hostname := str(location.hostname)
		if hostname.contains(":") and not hostname.begins_with("["):
			hostname = "[%s]" % hostname
		_server_endpoint = "%s://%s:%d" % [scheme, hostname, PORT]
	_auto_reconnect = true
	_retry_timer = 0.0
	return _connect_client(_server_endpoint)


func leave() -> void:
	_auto_reconnect = false
	if is_online():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	dedicated_server = LaunchOptions.server_mode
	GameLog.info("NET", "left the session")
	disconnected.emit()


func _connect_client(endpoint: String) -> Error:
	_retry_timer = 3.0
	if is_online():
		multiplayer.multiplayer_peer.close()
	var peer := WebSocketMultiplayerPeer.new()
	peer.handshake_timeout = 15.0
	var error := peer.create_client(endpoint)
	if error != OK:
		GameLog.info("NET", "could not connect to %s: %s" % [endpoint, error_string(error)])
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		if not _auto_reconnect:
			connection_failed.emit()
		return error
	multiplayer.multiplayer_peer = peer
	GameLog.info("NET", "connecting to %s" % endpoint)
	return OK


func _on_connected_to_server() -> void:
	joined_server.emit()


func _on_peer_connected(peer_id: int) -> void:
	GameLog.info("NET", "peer %d connected" % peer_id)
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	GameLog.info("NET", "peer %d disconnected" % peer_id)
	peer_left.emit(peer_id)


func _on_connection_failed() -> void:
	GameLog.info("NET", "connection failed")
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connection_failed.emit()
	if _auto_reconnect:
		_retry_timer = 2.0


func _on_server_disconnected() -> void:
	GameLog.info("NET", "server closed the connection")
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	disconnected.emit()
	if _auto_reconnect:
		_retry_timer = 2.0
