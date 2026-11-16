extends Node
## MATCH RULES. The host is the only peer that changes shared state.
##
## Clients send requests (register, movement intent, skip, reset). The host checks the
## request, updates the phase / roster, and replicates the result. A match goes
## Lobby -> Runner preparation -> Hunter active. Runners spawn immediately. The Hunter
## spawns only after the preparation timer ends or the host skips it.

signal players_changed
signal phase_changed(phase: Phase)
signal player_removed(peer_id: int)
signal all_players_loaded
signal auto_host_failed(error_code: Error)

enum Phase { LOBBY, RUNNER_PREPARATION, HUNTER_ACTIVE, ENDED }

const LOBBY_SCENE := "res://ui/lobby/lobby.tscn"
const MATCH_SCENE := "res://game/match/match.tscn"
const ANY_ROLE := -1

var config: MatchConfig
var phase := Phase.LOBBY
## peer id -> {name, preferred_role, role, alive}. Role is assigned when the match starts.
var players: Dictionary = {}
var time_left := 0.0
var head_start_duration := 60.0
var local_player_name := "Player"
var local_preferred_role := ANY_ROLE

var runner_spawn_count := 0
var hunter_spawned := false
var hunter_spawned_during_preparation := false
var phases_seen: Array[String] = []
var players_at_hunter_phase: Array = []

var _loaded_peers: Dictionary = {}
var _announced_loaded := false


func _ready() -> void:
	config = load("res://src/match/match_config.tres") as MatchConfig
	if config == null:
		push_error("Match config is missing at res://src/match/match_config.tres")
		config = MatchConfig.new()
	head_start_duration = config.runner_head_start_duration
	if LaunchOptions.head_start >= 0.0:
		head_start_duration = LaunchOptions.head_start
		GameLog.info("MATCH", "head start overridden to %.1f s" % head_start_duration)
	if not LaunchOptions.player_name.is_empty():
		local_player_name = LaunchOptions.player_name
	elif LaunchOptions.host_on_start:
		local_player_name = "Host"
	if not LaunchOptions.bot_role.is_empty():
		local_player_name = LaunchOptions.bot_name

	NetworkManager.hosting_started.connect(_on_hosting_started)
	NetworkManager.joined_server.connect(_on_joined_server)
	NetworkManager.peer_left.connect(_on_peer_left)
	NetworkManager.disconnected.connect(_on_disconnected)
	_reset_state()
	if LaunchOptions.host_on_start:
		call_deferred("_auto_host")


func _process(delta: float) -> void:
	if phase != Phase.RUNNER_PREPARATION:
		return
	time_left = maxf(time_left - delta, 0.0)
	if multiplayer.is_server() and time_left <= 0.0:
		_enter_hunter_phase()


func _auto_host() -> void:
	var err: Error = NetworkManager.host_enet()
	if err != OK:
		GameLog.info("MATCH", "auto host failed: %s" % error_string(err))
		auto_host_failed.emit(err)


func is_host() -> bool:
	return multiplayer.is_server()


func required_players() -> int:
	return config.min_players if config != null else 2


func phase_label() -> String:
	return _phase_name(phase)


func role_label(role: int) -> String:
	match role:
		RoleConfig.Role.HUNTER:
			return "Hunter"
		RoleConfig.Role.RUNNER:
			return "Runner"
		_:
			return "Any"


func can_start_match() -> bool:
	return multiplayer.is_server() and phase == Phase.LOBBY and players.size() >= required_players()


func everyone_loaded() -> bool:
	if players.is_empty():
		return false
	for key in players.keys():
		if not _loaded_peers.has(int(key)):
			return false
	return true


static func sender_id(mp: MultiplayerAPI) -> int:
	## Peer that sent the current RPC. Also returns the right id when the host
	## calls an RPC on itself.
	var id := mp.get_remote_sender_id()
	return id if id != 0 else mp.get_unique_id()


func note_unit_spawned(role: int) -> void:
	if role == RoleConfig.Role.HUNTER:
		hunter_spawned = true
		if phase != Phase.HUNTER_ACTIVE:
			hunter_spawned_during_preparation = true
			GameLog.info("MATCH", "hunter spawned during preparation")
		else:
			GameLog.info("MATCH", "hunter spawned after preparation")
	else:
		runner_spawn_count += 1
		GameLog.info("MATCH", "runner spawn count is now %d" % runner_spawn_count)


# --- Lobby ---------------------------------------------------------------------------

func _on_hosting_started() -> void:
	_reset_state()
	players[1] = _new_player(local_player_name, _preferred_role())
	GameLog.info("MATCH", "host registered as %s" % local_player_name)
	players_changed.emit()
	_maybe_auto_start()


func _on_joined_server() -> void:
	GameLog.info("MATCH", "joined, registering as %s" % local_player_name)
	_register.rpc_id(1, local_player_name, _preferred_role())


func _preferred_role() -> int:
	if LaunchOptions.bot_role == "hunter":
		return RoleConfig.Role.HUNTER
	if LaunchOptions.bot_role == "runner":
		return RoleConfig.Role.RUNNER
	return local_preferred_role


## Updates the local preference. If this peer is already hosting the lobby, the roster is updated too.
func set_preferred_role(role: int) -> void:
	local_preferred_role = role
	if not multiplayer.is_server() or phase != Phase.LOBBY or not players.has(1):
		return
	var entry: Dictionary = players[1]
	entry.preferred_role = role
	players[1] = entry
	_sync_players.rpc(players)


@rpc("any_peer", "reliable")
func _register(player_name: String, preferred_role: int) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if phase != Phase.LOBBY:
		GameLog.info("MATCH", "rejected peer %d because the match has already started" % id)
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	var clean := player_name.strip_edges().left(24)
	if clean.is_empty():
		clean = "Player %d" % id
	players[id] = _new_player(clean, preferred_role)
	GameLog.info("MATCH", "registered peer %d as %s (prefers %s)" % [id, clean, role_label(preferred_role)])
	_sync_players.rpc(players)
	_maybe_auto_start()


@rpc("authority", "call_local", "reliable")
func _sync_players(raw_players: Dictionary) -> void:
	players = _normalize_players(raw_players)
	players_changed.emit()


func _maybe_auto_start() -> void:
	var needed := LaunchOptions.auto_start_players
	if needed <= 0 or not multiplayer.is_server() or phase != Phase.LOBBY:
		return
	if players.size() >= needed and players.size() >= required_players():
		GameLog.info("MATCH", "auto-starting with %d players" % players.size())
		start_match()


func _on_peer_left(peer_id: int) -> void:
	if not multiplayer.is_server() or not players.has(peer_id):
		return
	players.erase(peer_id)
	_loaded_peers.erase(peer_id)
	GameLog.info("MATCH", "removed peer %d from the roster" % peer_id)
	_sync_players.rpc(players)
	player_removed.emit(peer_id)
	_check_all_loaded()


func _on_disconnected() -> void:
	_reset_state()
	players_changed.emit()
	call_deferred("_change_scene", LOBBY_SCENE)


# --- Match flow ----------------------------------------------------------------------

func start_match() -> void:
	if not can_start_match():
		return
	var hunter_id := _pick_hunter()
	for key in players.keys():
		var id := int(key)
		var entry: Dictionary = players[id]
		entry.role = RoleConfig.Role.HUNTER if id == hunter_id else RoleConfig.Role.RUNNER
		entry.alive = true
		players[id] = entry
		GameLog.info("MATCH", "peer %d %s -> %s" % [id, entry.name, role_label(int(entry.role))])
	_begin_preparation.rpc(players, head_start_duration)


func _pick_hunter() -> int:
	var requested: Array[int] = []
	for key in players.keys():
		var id := int(key)
		if int(players[id].preferred_role) == RoleConfig.Role.HUNTER:
			requested.append(id)
	if requested.is_empty():
		var lowest := 2147483647
		for key in players.keys():
			lowest = mini(lowest, int(key))
		GameLog.info("MATCH", "no hunter was requested; peer %d becomes the hunter" % lowest)
		return lowest
	if requested.size() > 1:
		GameLog.info("MATCH", "several peers requested hunter; using peer %d" % requested[0])
	return requested[0]


@rpc("authority", "call_local", "reliable")
func _begin_preparation(raw_players: Dictionary, duration: float) -> void:
	players = _normalize_players(raw_players)
	time_left = duration
	_loaded_peers.clear()
	_announced_loaded = false
	runner_spawn_count = 0
	hunter_spawned = false
	hunter_spawned_during_preparation = false
	players_at_hunter_phase.clear()
	_set_phase(Phase.RUNNER_PREPARATION)
	players_changed.emit()
	GameLog.info("MATCH", "runner preparation started (%.1f s)" % duration)
	call_deferred("_change_scene", MATCH_SCENE)


func request_skip_preparation() -> void:
	if multiplayer.is_server():
		_request_skip_preparation()
	else:
		_request_skip_preparation.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_skip_preparation() -> void:
	if not multiplayer.is_server() or sender_id(multiplayer) != 1:
		return
	if phase != Phase.RUNNER_PREPARATION:
		return
	GameLog.info("MATCH", "host skipped runner preparation")
	time_left = 0.0
	_enter_hunter_phase()


func _enter_hunter_phase() -> void:
	if not multiplayer.is_server() or phase != Phase.RUNNER_PREPARATION:
		return
	GameLog.info("MATCH", "runner preparation ended")
	_apply_phase.rpc(Phase.HUNTER_ACTIVE)


@rpc("authority", "call_local", "reliable")
func _apply_phase(new_phase: int) -> void:
	if new_phase == Phase.HUNTER_ACTIVE:
		time_left = 0.0
	_set_phase(new_phase)


## Each peer calls this once its match scene is ready. The host waits until every
## roster peer has reported, then the match scene spawns units.
@rpc("any_peer", "reliable")
func report_scene_ready() -> void:
	if not multiplayer.is_server():
		return
	var id := sender_id(multiplayer)
	if not players.has(id):
		GameLog.info("MATCH", "ignoring scene-ready from unknown peer %d" % id)
		return
	_loaded_peers[id] = true
	GameLog.info("MATCH", "peer %d scene ready (%d/%d)" % [id, _loaded_peers.size(), players.size()])
	_check_all_loaded()


func _check_all_loaded() -> void:
	if phase == Phase.LOBBY or phase == Phase.ENDED or _announced_loaded:
		return
	if not everyone_loaded():
		return
	_announced_loaded = true
	GameLog.info("MATCH", "all players have loaded the match")
	all_players_loaded.emit()


func reset_match() -> void:
	if multiplayer.is_server():
		_reset_to_lobby.rpc()


@rpc("authority", "call_local", "reliable")
func _reset_to_lobby() -> void:
	for key in players.keys():
		var entry: Dictionary = players[key]
		entry.alive = true
		entry.role = RoleConfig.Role.RUNNER
		players[key] = entry
	time_left = 0.0
	_loaded_peers.clear()
	_announced_loaded = false
	_set_phase(Phase.LOBBY)
	players_changed.emit()
	GameLog.info("MATCH", "match reset to the lobby")
	call_deferred("_change_scene", LOBBY_SCENE)


# --- Helpers -------------------------------------------------------------------------

func _new_player(player_name: String, preferred_role: int) -> Dictionary:
	return {
		"name": player_name,
		"preferred_role": preferred_role,
		"role": RoleConfig.Role.RUNNER,
		"alive": true,
	}


func _normalize_players(raw_players: Dictionary) -> Dictionary:
	var normalized := {}
	for key in raw_players.keys():
		var id := int(key)
		var entry: Dictionary = raw_players[key]
		normalized[id] = {
			"name": str(entry.get("name", "Player %d" % id)),
			"preferred_role": int(entry.get("preferred_role", ANY_ROLE)),
			"role": int(entry.get("role", RoleConfig.Role.RUNNER)),
			"alive": bool(entry.get("alive", true)),
		}
	return normalized


func _set_phase(new_phase: int) -> void:
	phase = new_phase as Phase
	if new_phase == Phase.HUNTER_ACTIVE and players_at_hunter_phase.is_empty():
		players_at_hunter_phase = _roster()
	var label := _phase_name(phase)
	if phases_seen.is_empty() or phases_seen[phases_seen.size() - 1] != label:
		phases_seen.append(label)
		GameLog.info("MATCH", "phase -> %s" % label)
	phase_changed.emit(phase)


func _roster() -> Array:
	var listed: Array = []
	for key in players.keys():
		var id := int(key)
		var entry: Dictionary = players[id]
		listed.append({
			"id": id,
			"name": str(entry.get("name", "")),
			"role": role_label(int(entry.get("role", ANY_ROLE))),
		})
	return listed


func _phase_name(value: int) -> String:
	match value:
		Phase.LOBBY:
			return "LOBBY"
		Phase.RUNNER_PREPARATION:
			return "RUNNER_PREPARATION"
		Phase.HUNTER_ACTIVE:
			return "HUNTER_ACTIVE"
		Phase.ENDED:
			return "ENDED"
		_:
			return "UNKNOWN"


func _reset_state() -> void:
	phase = Phase.LOBBY
	players.clear()
	_loaded_peers.clear()
	_announced_loaded = false
	time_left = 0.0
	runner_spawn_count = 0
	hunter_spawned = false
	hunter_spawned_during_preparation = false
	phases_seen.clear()
	players_at_hunter_phase.clear()
	_set_phase(Phase.LOBBY)


func _change_scene(path: String) -> void:
	var current := get_tree().current_scene
	if current != null and current.scene_file_path == path:
		return
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Could not open %s: %s" % [path, error_string(err)])
