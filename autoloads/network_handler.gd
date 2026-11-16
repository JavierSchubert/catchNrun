extends Node


const IP_ADDRESS: String = "localhost"
const PORT: int = 42069

var peer: ENetMultiplayerPeer


func start_server() -> void:
	var new_peer := ENetMultiplayerPeer.new()
	# if MAX_CLIENTS in create_server is not specified => default is 32
	var error := new_peer.create_server(PORT)
	if error != OK:
		push_error("Failed to start server on port %d: %s" % [PORT, error_string(error)])
		return

	peer = new_peer
	multiplayer.multiplayer_peer = new_peer


func start_client() -> void:
	var new_peer := ENetMultiplayerPeer.new()
	var error := new_peer.create_client(IP_ADDRESS, PORT)
	if error != OK:
		push_error("Failed to connect to %s:%d: %s" % [IP_ADDRESS, PORT, error_string(error)])
		return

	peer = new_peer
	multiplayer.multiplayer_peer = new_peer


## Create server
#var peer = ENetMultiplayerPeer.new()
#peer.create_server(PORT, MAX_CLIENTS)
#multiplayer.multiplayer_peer = peer
#
## Create client
#var peer = ENetMultiplayerPeer.new()
#peer.create_client(IP_ADDRESS, PORT)
#multiplayer.multiplayer_peer = peer
