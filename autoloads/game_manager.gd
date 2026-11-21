extends Node
## MATCH RULES. The host is the only peer that changes shared state.
##
## Clients send requests (register, side vote, movement intent, skip, reset). The host
## checks the request and replicates the result. A session goes Lobby -> Role selection
## -> Runner preparation -> Hunter active. Scene changes go through SceneTransitionManager.

signal players_changed
signal phase_changed(phase: Phase)
signal player_removed(peer_id: int)
signal player_eliminated(peer_id: int)
signal match_finished(winner_team: String)
signal all_players_loaded
signal auto_host_failed(error_code: Error)

enum Phase { LOBBY, ROLE_SELECTION, RUNNER_PREPARATION, HUNTER_ACTIVE, ENDED }

const ANY_ROLE := -1
const TEST_PLAYER_ID := 1000
const SPRITE_COUNT := 5

var resolved_hunter_id := -1
var _next_test_player_id := TEST_PLAYER_ID

var config: MatchConfig
var phase := Phase.LOBBY
## peer id -> {name, preferred_role, role, sprite_index, alive}. Role is assigned when the match starts.
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


func can_continue_to_selection() -> bool:
	return multiplayer.is_server() and phase == Phase.LOBBY and players.size() >= required_players()


func everyone_loaded() -> bool:
	if players.is_empty():
		return false
	for key in players.keys():
		if not _loaded_peers.has(int(key)):
			return false
	return true


func is_eliminated(peer_id: int) -> bool:
	if not players.has(peer_id):
		return false
	return not bool(players[peer_id].get("alive", true))


func living_runner_ids() -> Array[int]:
	var ids: Array[int] = []
	for key in players.keys():
		var id := int(key)
		var entry: Dictionary = players[id]
		if int(entry.get("role", RoleConfig.Role.RUNNER)) != RoleConfig.Role.RUNNER:
			continue
		if bool(entry.get("alive", true)):
			ids.append(id)
	return ids


func living_hunter_ids() -> Array[int]:
	var ids: Array[int] = []
	for key in players.keys():
		var id := int(key)
		var entry: Dictionary = players[id]
		if int(entry.get("role", RoleConfig.Role.RUNNER)) != RoleConfig.Role.HUNTER:
			continue
		if bool(entry.get("alive", true)):
			ids.append(id)
	return ids


## Host marks a player defeated. Dead Runners become observers; the match ends when
## every Runner is down or the Hunter falls.
func eliminate_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if phase != Phase.RUNNER_PREPARATION and phase != Phase.HUNTER_ACTIVE:
		return
	if not players.has(peer_id) or is_eliminated(peer_id):
		return
	var entry: Dictionary = players[peer_id]
	entry.alive = false
	players[peer_id] = entry
	GameLog.info("MATCH", "peer %d eliminated (%s)" % [peer_id, role_label(int(entry.role))])
	_sync_players.rpc(players)
	player_eliminated.emit(peer_id)
	_check_match_end()


func _check_match_end() -> void:
	if not multiplayer.is_server():
		return
	if phase != Phase.HUNTER_ACTIVE and phase != Phase.RUNNER_PREPARATION:
		return
	if living_runner_ids().is_empty():
		_finish_match.rpc("hunter")
	elif living_hunter_ids().is_empty():
		_finish_match.rpc("runner")


@rpc("authority", "call_local", "reliable")
func _finish_match(winner_team: String) -> void:
	_set_phase(Phase.ENDED)
	GameLog.info("MATCH", "match finished — %s team wins" % winner_team)
	match_finished.emit(winner_team)


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
	players[1] = _new_player(local_player_name, ANY_ROLE)
	GameLog.info("MATCH", "host registered as %s" % local_player_name)
	players_changed.emit()
	_maybe_auto_start()


func _on_joined_server() -> void:
	GameLog.info("MATCH", "joined, registering as %s" % local_player_name)
	_register.rpc_id(1, local_player_name, ANY_ROLE)


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
func _register(player_name: String, _preferred_role: int) -> void:
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
	players[id] = _new_player(clean, ANY_ROLE)
	GameLog.info("MATCH", "registered peer %d as %s" % [id, clean])
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
		GameLog.info("MATCH", "lobby is full (%d players); opening role selection" % players.size())
		continue_to_selection()


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
	SceneTransitionManager.transition("", SceneTransitionManager.LOBBY)


# --- Match flow ----------------------------------------------------------------------

func continue_to_selection() -> void:
	if not can_continue_to_selection():
		return
	if NetworkManager.is_online():
		_enter_selection.rpc()
	else:
		_set_phase(Phase.ROLE_SELECTION)
	SceneTransitionManager.transition(SceneTransitionManager.LOBBY, SceneTransitionManager.ROLE_SELECTION)


@rpc("authority", "call_local", "reliable")
func _enter_selection() -> void:
	resolved_hunter_id = -1
	_set_phase(Phase.ROLE_SELECTION)
	GameLog.info("MATCH", "role selection opened")


func request_side(role: int) -> void:
	request_side_for(multiplayer.get_unique_id(), role)


func request_side_for(peer_id: int, role: int) -> void:
	if phase != Phase.ROLE_SELECTION:
		return
	var own_id := multiplayer.get_unique_id()
	var test_player := not NetworkManager.is_online() and peer_id >= TEST_PLAYER_ID
	if peer_id != own_id and not test_player:
		return
	if not test_player and not multiplayer.is_server():
		_request_side.rpc_id(1, role)
		return
	_apply_side(peer_id, role)


@rpc("any_peer", "reliable")
func _request_side(role: int) -> void:
	if not multiplayer.is_server() or phase != Phase.ROLE_SELECTION:
		return
	_apply_side(sender_id(multiplayer), role)


func _apply_side(peer_id: int, role: int) -> void:
	if not players.has(peer_id):
		return
	if role != RoleConfig.Role.HUNTER and role != RoleConfig.Role.RUNNER:
		return
	var entry: Dictionary = players[peer_id]
	entry.preferred_role = role
	players[peer_id] = entry
	resolved_hunter_id = -1
	GameLog.info("MATCH", "peer %d requested %s" % [peer_id, role_label(role)])
	if NetworkManager.is_online():
		_sync_players.rpc(players)
	else:
		players_changed.emit()
	_maybe_auto_resolve()


func set_sprite_for(peer_id: int, sprite_index: int) -> void:
	if phase != Phase.ROLE_SELECTION or sprite_index < 0 or sprite_index >= SPRITE_COUNT:
		return
	var test_player := not NetworkManager.is_online() and peer_id >= TEST_PLAYER_ID
	if peer_id != multiplayer.get_unique_id() and not test_player:
		return
	if not test_player and not multiplayer.is_server():
		_request_sprite.rpc_id(1, sprite_index)
		return
	_apply_sprite(peer_id, sprite_index)


@rpc("any_peer", "reliable")
func _request_sprite(sprite_index: int) -> void:
	if not multiplayer.is_server() or phase != Phase.ROLE_SELECTION:
		return
	_apply_sprite(sender_id(multiplayer), sprite_index)


func _apply_sprite(peer_id: int, sprite_index: int) -> void:
	if not players.has(peer_id) or sprite_index < 0 or sprite_index >= SPRITE_COUNT:
		return
	var entry: Dictionary = players[peer_id]
	entry.sprite_index = sprite_index
	players[peer_id] = entry
	if NetworkManager.is_online():
		_sync_players.rpc(players)
	else:
		players_changed.emit()


func add_test_player() -> void:
	if NetworkManager.is_online():
		return
	var id := _next_test_player_id
	_next_test_player_id += 1
	players[id] = _new_player("Tester %d" % (id - TEST_PLAYER_ID + 1), ANY_ROLE)
	players_changed.emit()


func resolve_roles() -> void:
	if phase != Phase.ROLE_SELECTION or players.is_empty():
		return
	if NetworkManager.is_online() and not multiplayer.is_server():
		return
	_assign_roles()
	if NetworkManager.is_online():
		_sync_players.rpc(players)
	else:
		players_changed.emit()


func start_game_from_selection() -> void:
	if phase != Phase.ROLE_SELECTION:
		return
	if NetworkManager.is_online() and not multiplayer.is_server():
		return
	_drop_test_players()
	if players.is_empty():
		return
	_assign_roles()
	if NetworkManager.is_online():
		_begin_preparation.rpc(players, head_start_duration)
	else:
		_apply_preparation(players, head_start_duration)
	SceneTransitionManager.transition(SceneTransitionManager.ROLE_SELECTION, SceneTransitionManager.GAME)


func _maybe_auto_resolve() -> void:
	if LaunchOptions.auto_start_players <= 0 or not multiplayer.is_server() or phase != Phase.ROLE_SELECTION:
		return
	for key in players.keys():
		var preference := int(players[key].preferred_role)
		if preference != RoleConfig.Role.HUNTER and preference != RoleConfig.Role.RUNNER:
			return
	GameLog.info("MATCH", "every player has chosen a side")
	start_game_from_selection()


func _drop_test_players() -> void:
	if NetworkManager.is_online():
		return
	for key in players.keys():
		if int(key) >= TEST_PLAYER_ID:
			players.erase(int(key))
	if resolved_hunter_id >= TEST_PLAYER_ID:
		resolved_hunter_id = -1


func _assign_roles() -> void:
	var hunter_id := choose_hunter_id(players)
	resolved_hunter_id = hunter_id
	for key in players.keys():
		var id := int(key)
		var entry: Dictionary = players[id]
		entry.role = RoleConfig.Role.HUNTER if id == hunter_id else RoleConfig.Role.RUNNER
		entry.alive = true
		players[id] = entry
		GameLog.info("MATCH", "peer %d %s -> %s" % [id, entry.name, role_label(int(entry.role))])


static func choose_hunter_id(roster: Dictionary, rng: RandomNumberGenerator = null) -> int:
	var requested: Array[int] = []
	var everyone: Array[int] = []
	for key in roster.keys():
		var id := int(key)
		everyone.append(id)
		if int(roster[id].preferred_role) == RoleConfig.Role.HUNTER:
			requested.append(id)
	var pool: Array[int] = requested if not requested.is_empty() else everyone
	if pool.is_empty():
		return -1
	var roll := randi() if rng == null else rng.randi()
	var chosen: int = pool[roll % pool.size()]
	GameLog.info("MATCH", "hunter candidates %s; chose peer %d" % [pool, chosen])
	return chosen


func _apply_preparation(raw_players: Dictionary, duration: float) -> void:
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


@rpc("authority", "call_local", "reliable")
func _begin_preparation(raw_players: Dictionary, duration: float) -> void:
	_apply_preparation(raw_players, duration)


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
	if phase == Phase.LOBBY or phase == Phase.ROLE_SELECTION or phase == Phase.ENDED or _announced_loaded:
		return
	if not everyone_loaded():
		return
	_announced_loaded = true
	GameLog.info("MATCH", "all players have loaded the match")
	all_players_loaded.emit()


func reset_match() -> void:
	if NetworkManager.is_online() and not multiplayer.is_server():
		return
	if NetworkManager.is_online():
		_reset_to_lobby.rpc()
		SceneTransitionManager.force_open(SceneTransitionManager.LOBBY)
	else:
		_reset_to_lobby_local()
		SceneTransitionManager.force_open(SceneTransitionManager.LOBBY)


@rpc("authority", "call_local", "reliable")
func _reset_to_lobby() -> void:
	_reset_to_lobby_local()


func _reset_to_lobby_local() -> void:
	for key in players.keys():
		var entry: Dictionary = players[key]
		entry.alive = true
		entry.role = RoleConfig.Role.RUNNER
		entry.preferred_role = ANY_ROLE
		players[key] = entry
	resolved_hunter_id = -1
	time_left = 0.0
	_loaded_peers.clear()
	_announced_loaded = false
	runner_spawn_count = 0
	hunter_spawned = false
	hunter_spawned_during_preparation = false
	_set_phase(Phase.LOBBY)
	players_changed.emit()
	GameLog.info("MATCH", "match reset to the lobby")


# --- Helpers -------------------------------------------------------------------------

func _new_player(player_name: String, preferred_role: int) -> Dictionary:
	return {
		"name": player_name,
		"preferred_role": preferred_role,
		"role": RoleConfig.Role.RUNNER,
		"sprite_index": 0,
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
			"sprite_index": clampi(int(entry.get("sprite_index", 0)), 0, SPRITE_COUNT - 1),
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
		Phase.ROLE_SELECTION:
			return "ROLE_SELECTION"
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
	resolved_hunter_id = -1
	_set_phase(Phase.LOBBY)


func prepare_lobby_test() -> void:
	_reset_state()


func prepare_selection_test() -> void:
	_reset_state()
	players[1] = _new_player(local_player_name, ANY_ROLE)
	_set_phase(Phase.ROLE_SELECTION)
	players_changed.emit()


func prepare_game_test() -> void:
	_reset_state()
	var role := RoleConfig.Role.RUNNER
	if LaunchOptions.test_role == "hunter":
		role = RoleConfig.Role.HUNTER
	var entry := _new_player(local_player_name, role)
	entry.role = role
	players[1] = entry
	resolved_hunter_id = 1 if role == RoleConfig.Role.HUNTER else -1
	time_left = head_start_duration
	_set_phase(Phase.RUNNER_PREPARATION)
	players_changed.emit()
