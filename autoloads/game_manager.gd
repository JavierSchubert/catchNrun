extends Node
## MATCH RULES and shared state: players, roles, phase, timer, win conditions.
##
## The host (peer 1) is the only peer that decides anything. Clients send requests
## through RPCs to peer 1. The host checks each request, applies it, and sends the
## result back to everyone. Clients never change shared state themselves.

signal players_changed
signal match_ended(hunter_won: bool)
signal all_players_loaded ## Host only: every peer has loaded the match scene.

enum Phase { LOBBY, IN_MATCH, ENDED }

const LOBBY_SCENE := "res://ui/lobby/lobby.tscn"
const MATCH_SCENE := "res://game/match/match.tscn"
const MATCH_DURATION := 180.0
const MIN_PLAYERS := 2

var phase := Phase.LOBBY
## peer_id -> { "name": String, "role": RoleData.Role, "alive": bool }
var players: Dictionary = {}
var time_left := 0.0
var local_player_name := "Player"

var _loaded_peers: Dictionary = {}


func _ready() -> void:
	NetworkManager.hosting_started.connect(_on_hosting_started)
	NetworkManager.joined_server.connect(_on_joined_server)
	NetworkManager.peer_left.connect(_on_peer_left)
	NetworkManager.disconnected.connect(_on_disconnected)


func _process(delta: float) -> void:
	if phase != Phase.IN_MATCH:
		return
	time_left = maxf(time_left - delta, 0.0) # Every peer counts down for the HUD...
	if multiplayer.is_server() and time_left <= 0.0:
		_end_match(false) # ...but only the host ends the match. Runners survived.


func is_host() -> bool:
	return multiplayer.is_server()


static func sender_id(mp: MultiplayerAPI) -> int:
	## Peer that sent the current RPC. Also returns the right id when the host
	## calls an RPC on itself (call_local).
	var id := mp.get_remote_sender_id()
	return id if id != 0 else mp.get_unique_id()


# --- Lobby ---------------------------------------------------------------------------

func _on_hosting_started() -> void:
	_reset()
	players[1] = _new_player_entry(local_player_name)
	players_changed.emit()


func _on_joined_server() -> void:
	_register.rpc_id(1, local_player_name)


@rpc("any_peer", "reliable")
func _register(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if phase != Phase.LOBBY:
		multiplayer.multiplayer_peer.disconnect_peer(id) # No joining while a match is running.
		return
	players[id] = _new_player_entry(player_name.strip_edges().left(24))
	_sync_players.rpc(players)


@rpc("authority", "call_local", "reliable")
func _sync_players(new_players: Dictionary) -> void:
	players = new_players
	players_changed.emit()


func _on_peer_left(peer_id: int) -> void:
	if not multiplayer.is_server() or not players.has(peer_id):
		return
	players.erase(peer_id)
	_sync_players.rpc(players)
	if phase == Phase.IN_MATCH:
		_check_all_loaded()
		_check_win()


func _on_disconnected() -> void:
	_reset()
	get_tree().change_scene_to_file(LOBBY_SCENE)


# --- Match flow ----------------------------------------------------------------------

func can_start_match() -> bool:
	return multiplayer.is_server() and phase == Phase.LOBBY and players.size() >= MIN_PLAYERS


func start_match() -> void:
	if not can_start_match():
		return
	var hunter_id: int = players.keys().pick_random()
	for id: int in players:
		players[id].role = RoleData.Role.HUNTER if id == hunter_id else RoleData.Role.RUNNER
		players[id].alive = true
	_begin_match.rpc(players, MATCH_DURATION)


@rpc("authority", "call_local", "reliable")
func _begin_match(new_players: Dictionary, duration: float) -> void:
	players = new_players
	time_left = duration
	phase = Phase.IN_MATCH
	_loaded_peers.clear()
	players_changed.emit()
	get_tree().change_scene_to_file(MATCH_SCENE)


## Each peer calls this once its match scene is ready. The host waits for all peers
## before spawning anything; spawns sent earlier would reach clients that have no
## spawner node yet.
@rpc("any_peer", "call_local", "reliable")
func report_scene_ready() -> void:
	if not multiplayer.is_server():
		return
	_loaded_peers[sender_id(multiplayer)] = true
	_check_all_loaded()


func _check_all_loaded() -> void:
	if _loaded_peers.has(-1):
		return # Already emitted.
	for id: int in players:
		if not _loaded_peers.has(id):
			return
	_loaded_peers[-1] = true
	all_players_loaded.emit()


func server_report_death(peer_id: int) -> void:
	if not multiplayer.is_server() or phase != Phase.IN_MATCH or not players.has(peer_id):
		return
	players[peer_id].alive = false
	_sync_players.rpc(players)
	_check_win()


func _check_win() -> void:
	var hunter_alive := false
	var runners_alive := 0
	for p: Dictionary in players.values():
		if not p.alive:
			continue
		if p.role == RoleData.Role.HUNTER:
			hunter_alive = true
		else:
			runners_alive += 1
	if not hunter_alive:
		_end_match(false)
	elif runners_alive == 0:
		_end_match(true)


func _end_match(hunter_won: bool) -> void:
	if phase != Phase.IN_MATCH:
		return
	_announce_end.rpc(hunter_won)


@rpc("authority", "call_local", "reliable")
func _announce_end(hunter_won: bool) -> void:
	phase = Phase.ENDED
	match_ended.emit(hunter_won)


func return_to_lobby() -> void:
	if multiplayer.is_server():
		_go_to_lobby.rpc()


@rpc("authority", "call_local", "reliable")
func _go_to_lobby() -> void:
	phase = Phase.LOBBY
	for p: Dictionary in players.values():
		p.alive = true
	get_tree().change_scene_to_file(LOBBY_SCENE)


# --- Helpers -------------------------------------------------------------------------

func _new_player_entry(player_name: String) -> Dictionary:
	return {"name": player_name, "role": RoleData.Role.RUNNER, "alive": true}


func _reset() -> void:
	phase = Phase.LOBBY
	players.clear()
	_loaded_peers.clear()
	time_left = 0.0
	players_changed.emit()
