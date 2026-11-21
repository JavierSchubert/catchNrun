extends Node
## TRANSPORT LAYER: handles how peers connect to each other. It has no gameplay code.
##
## ENet (host_enet / join_enet) for local and LAN sessions. Sets
## `multiplayer.multiplayer_peer`. Gameplay code only uses Godot's high-level
## multiplayer API (RPCs, MultiplayerSpawner/Synchronizer). The host is always peer id 1.

signal hosting_started
signal joined_server
signal connection_failed
signal disconnected
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

const MAX_PLAYERS := 8
const ENET_PORT := 7777


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(joined_server.emit)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_online() -> bool:
	return not (multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func host_enet(port := ENET_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		GameLog.info("NET", "could not host on port %d: %s" % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	GameLog.info("NET", "hosting on port %d (max %d players)" % [port, MAX_PLAYERS])
	hosting_started.emit()
	return OK


func join_enet(address := "127.0.0.1", port := ENET_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		GameLog.info("NET", "could not connect to %s:%d: %s" % [address, port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	GameLog.info("NET", "connecting to %s:%d" % [address, port])
	return OK


func leave() -> void:
	if is_online():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	GameLog.info("NET", "left the session")
	disconnected.emit()


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


func _on_server_disconnected() -> void:
	GameLog.info("NET", "server closed the connection")
	leave()
