extends Node
## TRANSPORT LAYER: handles how peers connect to each other. It has no gameplay code.
##
## - Steam (host_steam): for playing with friends over the internet. Friends-only lobby,
##   invites through the Steam overlay, and traffic goes through Steam's relay, so nobody
##   needs to forward ports.
## - ENet (host_enet / join_enet): for local testing with several game instances on one PC.
##
## Both set `multiplayer.multiplayer_peer`. Gameplay code only uses Godot's high-level
## multiplayer API (RPCs, MultiplayerSpawner/Synchronizer), so it works the same with
## either transport. The host is always peer id 1.

signal hosting_started
signal joined_server
signal connection_failed
signal disconnected
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

const MAX_PLAYERS := 8
const ENET_PORT := 7777

var steam_enabled := false
var lobby_id := 0


func _ready() -> void:
	multiplayer.peer_connected.connect(peer_joined.emit)
	multiplayer.peer_disconnected.connect(peer_left.emit)
	multiplayer.connected_to_server.connect(joined_server.emit)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	steam_enabled = Steam.isSteamRunning()
	if steam_enabled:
		Steam.initRelayNetworkAccess()
		Steam.lobby_created.connect(_on_lobby_created)
		Steam.lobby_joined.connect(_on_lobby_joined)
		Steam.join_requested.connect(_on_join_requested)


func _process(_delta: float) -> void:
	if steam_enabled:
		Steam.run_callbacks()


func is_online() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


# --- Steam ---------------------------------------------------------------------------

func host_steam() -> void:
	# Emits lobby_created and then lobby_joined.
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, MAX_PLAYERS)


func invite_friends() -> void:
	if lobby_id != 0:
		Steam.activateGameOverlayInviteDialog(lobby_id)


func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	if result != Steam.RESULT_OK:
		connection_failed.emit()
		return
	lobby_id = new_lobby_id
	var peer := SteamMultiplayerPeer.new()
	peer.server_relay = true
	peer.create_host()
	multiplayer.multiplayer_peer = peer
	hosting_started.emit()


func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		connection_failed.emit()
		return
	lobby_id = joined_lobby_id
	var lobby_owner := Steam.getLobbyOwner(joined_lobby_id)
	if lobby_owner == Steam.getSteamID():
		return # We created this lobby, so we are already hosting.
	var peer := SteamMultiplayerPeer.new()
	peer.server_relay = true
	peer.create_client(lobby_owner)
	multiplayer.multiplayer_peer = peer


func _on_join_requested(requested_lobby_id: int, _friend_id: int) -> void:
	# The player accepted an invite or clicked "Join game" in Steam.
	Steam.joinLobby(requested_lobby_id)


# --- ENet (local testing) ------------------------------------------------------------

func host_enet(port := ENET_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	hosting_started.emit()
	return OK


func join_enet(address := "127.0.0.1", port := ENET_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


# --- Shared --------------------------------------------------------------------------

func leave() -> void:
	if lobby_id != 0:
		Steam.leaveLobby(lobby_id)
		lobby_id = 0
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	disconnected.emit()


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	leave()
