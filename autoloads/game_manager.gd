extends Node
## MATCH RULES. The server is the only peer that changes shared state.
##
## Clients send requests (register, side vote, movement intent, skip, reset). The server
## validates requests and replicates results; the session host controls lobby actions.
## Scene changes go through SceneTransitionManager.

signal players_changed
signal phase_changed(phase: Phase)
signal player_removed(peer_id: int)
signal player_eliminated(peer_id: int)
signal match_finished(winner_team: String)
signal all_players_loaded
signal auto_host_failed(error_code: Error)
signal test_bot_request_completed(success: bool, message: String)

enum Phase { LOBBY, ROLE_SELECTION, RUNNER_PREPARATION, HUNTER_ACTIVE, ENDED }

const ANY_ROLE := -1
const TEST_PLAYER_ID := 1000
const SPRITE_COUNT := 5
## Crystal income (mine ticks, Hunter damage) only replicates this often. Spends and
## roster/phase changes bypass the throttle and flush straight away.
const PLAYERS_SYNC_INTERVAL := 0.25

var resolved_hunter_id := -1
var _next_test_player_id := TEST_PLAYER_ID
var session_host_id := 0
var test_bots_enabled := false

var config: MatchConfig
var economy_config: EconomyConfig
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
var _test_bot_processes: Dictionary = {}
var _next_test_bot_number := 1
var _players_dirty := false
var _players_sync_timer := 0.0


func _ready() -> void:
	config = load("res://src/match/match_config.tres") as MatchConfig
	if config == null:
		push_error("Match config is missing at res://src/match/match_config.tres")
		config = MatchConfig.new()
	economy_config = load("res://src/economy/economy_config.tres") as EconomyConfig
	if economy_config == null:
		push_error("Economy config is missing at res://src/economy/economy_config.tres")
		economy_config = EconomyConfig.new()
	head_start_duration = config.runner_head_start_duration
	test_bots_enabled = LaunchOptions.server_mode
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
	if LaunchOptions.server_mode or LaunchOptions.host_on_start:
		call_deferred("_auto_host")


func _process(delta: float) -> void:
	_tick_players_sync(delta)
	if phase != Phase.RUNNER_PREPARATION:
		return
	time_left = maxf(time_left - delta, 0.0)
	if multiplayer.is_server() and time_left <= 0.0:
		_enter_hunter_phase()


func _auto_host() -> void:
	var err: Error = NetworkManager.start_server()
	if err != OK:
		GameLog.info("MATCH", "auto host failed: %s" % error_string(err))
		auto_host_failed.emit(err)
		if LaunchOptions.server_mode:
			get_tree().quit(1)


func is_host() -> bool:
	return is_session_host_peer(
		multiplayer.get_unique_id(),
		multiplayer.is_server(),
		NetworkManager.dedicated_server,
		session_host_id
	)


static func is_session_host_peer(peer_id: int, server_peer: bool, dedicated_server: bool, host_id: int) -> bool:
	if server_peer:
		return not dedicated_server
	return peer_id == host_id


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
	return is_host() and phase == Phase.LOBBY and players.size() >= required_players()


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


func sender_id(mp: MultiplayerAPI) -> int:
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
	if NetworkManager.dedicated_server:
		GameLog.info("MATCH", "dedicated WebSocket server started")
	else:
		players[1] = _new_player(local_player_name, ANY_ROLE)
		_set_session_host(1)
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
	var local_id := multiplayer.get_unique_id()
	if not is_host() or phase != Phase.LOBBY or not players.has(local_id):
		return
	var entry: Dictionary = players[local_id]
	entry.preferred_role = role
	players[local_id] = entry
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
	if players.size() >= NetworkManager.MAX_PLAYERS:
		GameLog.info("MATCH", "rejected peer %d because the lobby is full" % id)
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	var clean := player_name.strip_edges().left(24)
	if clean.is_empty():
		clean = "Player %d" % id
	elif clean == "Player":
		clean = "Player %d" % id
	players[id] = _new_player(clean, ANY_ROLE)
	if session_host_id == 0:
		_set_session_host(id)
	if _test_bot_processes.has(clean):
		_test_bot_processes.erase(clean)
	GameLog.info("MATCH", "registered peer %d as %s" % [id, clean])
	_sync_players.rpc(players)
	_sync_test_bot_access.rpc_id(id, LaunchOptions.server_mode)
	_maybe_auto_start()


func _set_session_host(peer_id: int) -> void:
	session_host_id = peer_id
	if NetworkManager.is_online() and multiplayer.is_server():
		_sync_session_host.rpc(peer_id, NetworkManager.dedicated_server)


@rpc("authority", "call_local", "reliable")
func _sync_session_host(peer_id: int, is_dedicated_server: bool) -> void:
	session_host_id = peer_id
	NetworkManager.dedicated_server = is_dedicated_server
	players_changed.emit()


@rpc("authority", "reliable")
func _sync_test_bot_access(enabled: bool) -> void:
	test_bots_enabled = enabled
	players_changed.emit()


func request_test_bot(role: String) -> void:
	if not NetworkManager.dedicated_server or multiplayer.is_server():
		return
	_request_add_test_bot.rpc_id(1, role)


@rpc("any_peer", "reliable")
func _request_add_test_bot(role: String) -> void:
	if not multiplayer.is_server():
		return
	var requester_id := sender_id(multiplayer)
	_prune_test_bot_processes()
	var error_message := test_bot_request_error(
		role,
		requester_id,
		session_host_id,
		phase,
		players.size(),
		_test_bot_processes.size(),
		LaunchOptions.server_mode,
		NetworkManager.MAX_PLAYERS
	)
	if not error_message.is_empty():
		GameLog.info("BOT", "rejected test bot request from peer %d: %s" % [requester_id, error_message])
		_test_bot_request_result.rpc_id(requester_id, false, error_message)
		return

	var role_name := "Hunter" if role == "hunter" else "Runner"
	var bot_name := "Test %s %d" % [role_name, _next_test_bot_number]
	var args := PackedStringArray(["--headless"])
	if OS.has_feature("editor"):
		args.append("--path")
		args.append(ProjectSettings.globalize_path("res://"))
	args.append("--")
	args.append("--bot=%s" % role)
	args.append("--bot-name=%s" % bot_name)
	var pid := OS.create_process(OS.get_executable_path(), args)
	if pid <= 0:
		var message := "Could not start %s. Check the game server executable." % bot_name
		GameLog.info("BOT", message)
		_test_bot_request_result.rpc_id(requester_id, false, message)
		return
	_test_bot_processes[bot_name] = pid
	_next_test_bot_number += 1
	GameLog.info("BOT", "started %s as a %s (pid %d)" % [bot_name, role_name, pid])
	_test_bot_request_result.rpc_id(requester_id, true, "Started %s." % bot_name)


@rpc("authority", "reliable")
func _test_bot_request_result(success: bool, message: String) -> void:
	test_bot_request_completed.emit(success, message)


func _prune_test_bot_processes() -> void:
	for bot_name in _test_bot_processes.keys():
		if not OS.is_process_running(int(_test_bot_processes[bot_name])):
			_test_bot_processes.erase(bot_name)


static func test_bot_request_error(
	role: String,
	requester_id: int,
	host_id: int,
	current_phase: int,
	player_count: int,
	pending_bot_count: int,
	enabled: bool,
	max_players: int
) -> String:
	if not enabled:
		return "Test bots are disabled on this server."
	if requester_id != host_id:
		return "Only the lobby host can add test bots."
	if current_phase != Phase.LOBBY:
		return "Test bots can only be added in the lobby."
	if role != "runner" and role != "hunter":
		return "Unknown bot role."
	if player_count + pending_bot_count >= max_players:
		return "The lobby is full."
	return ""


@rpc("authority", "call_local", "reliable")
func _sync_players(raw_players: Dictionary) -> void:
	## A full roster just went out / came in, so nothing is left pending.
	_clear_players_dirty()
	players = _normalize_players(raw_players)
	resolved_hunter_id = _find_assigned_hunter(players)
	players_changed.emit()


static func _find_assigned_hunter(roster: Dictionary) -> int:
	for key in roster.keys():
		var id := int(key)
		if int(roster[id].get("role", RoleConfig.Role.RUNNER)) == RoleConfig.Role.HUNTER:
			return id
	return -1


func _maybe_auto_start() -> void:
	var needed := LaunchOptions.auto_start_players
	if needed <= 0 or not multiplayer.is_server() or phase != Phase.LOBBY:
		return
	if players.size() >= needed and players.size() >= required_players():
		GameLog.info("MATCH", "lobby is full (%d players); opening role selection" % players.size())
		_advance_to_selection()


func _on_peer_left(peer_id: int) -> void:
	if not multiplayer.is_server() or not players.has(peer_id):
		return
	players.erase(peer_id)
	_loaded_peers.erase(peer_id)
	if session_host_id == peer_id:
		var remaining_ids: Array[int] = []
		for key in players.keys():
			remaining_ids.append(int(key))
		remaining_ids.sort()
		_set_session_host(remaining_ids[0] if not remaining_ids.is_empty() else 0)
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
	if NetworkManager.dedicated_server and not multiplayer.is_server():
		if can_continue_to_selection():
			_request_continue_to_selection.rpc_id(1)
		return
	if not can_continue_to_selection():
		return
	_advance_to_selection()


func _advance_to_selection() -> void:
	if not multiplayer.is_server() or phase != Phase.LOBBY or players.size() < required_players():
		return
	if NetworkManager.is_online():
		_enter_selection.rpc()
	else:
		_enter_selection()
	SceneTransitionManager.transition(SceneTransitionManager.LOBBY, SceneTransitionManager.ROLE_SELECTION)


@rpc("any_peer", "reliable")
func _request_continue_to_selection() -> void:
	if not multiplayer.is_server() or sender_id(multiplayer) != session_host_id:
		return
	_advance_to_selection()


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
	_apply_side(GameManager.sender_id(multiplayer), role)


func _apply_side(peer_id: int, role: int) -> void:
	if not players.has(peer_id):
		return
	if role != RoleConfig.Role.HUNTER and role != RoleConfig.Role.RUNNER:
		return
	for key in players.keys():
		var assigned_entry: Dictionary = players[key]
		assigned_entry.role = RoleConfig.Role.RUNNER
		players[key] = assigned_entry
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
	_apply_sprite(GameManager.sender_id(multiplayer), sprite_index)


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
	if NetworkManager.dedicated_server and not multiplayer.is_server():
		if is_host() and phase == Phase.ROLE_SELECTION:
			_request_resolve_roles.rpc_id(1)
		return
	if NetworkManager.is_online() and not multiplayer.is_server():
		return
	_resolve_roles_authoritatively()


func _resolve_roles_authoritatively() -> void:
	if not multiplayer.is_server() or phase != Phase.ROLE_SELECTION or players.is_empty():
		return
	_assign_roles()
	if NetworkManager.is_online():
		_sync_players.rpc(players)
	else:
		players_changed.emit()


@rpc("any_peer", "reliable")
func _request_resolve_roles() -> void:
	if not multiplayer.is_server() or sender_id(multiplayer) != session_host_id:
		return
	_resolve_roles_authoritatively()


func start_game_from_selection() -> void:
	if NetworkManager.dedicated_server and not multiplayer.is_server():
		if is_host() and phase == Phase.ROLE_SELECTION:
			_request_start_game.rpc_id(1)
		return
	if phase != Phase.ROLE_SELECTION:
		return
	if NetworkManager.is_online() and not multiplayer.is_server():
		return
	_start_game_authoritatively()


func _start_game_authoritatively() -> void:
	if not multiplayer.is_server() or phase != Phase.ROLE_SELECTION:
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


@rpc("any_peer", "reliable")
func _request_start_game() -> void:
	if not multiplayer.is_server() or sender_id(multiplayer) != session_host_id:
		return
	_start_game_authoritatively()


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


func _assign_roles(rng: RandomNumberGenerator = null) -> void:
	var hunter_id := resolved_hunter_id
	if not players.has(hunter_id) \
	or int(players[hunter_id].get("role", RoleConfig.Role.RUNNER)) != RoleConfig.Role.HUNTER:
		hunter_id = choose_hunter_id(players, rng)
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
	for key in players.keys():
		var entry: Dictionary = players[key]
		entry["crystals"] = _starting_crystals()
		players[key] = entry
	resolved_hunter_id = _find_assigned_hunter(players)
	time_left = duration
	_loaded_peers.clear()
	_announced_loaded = false
	runner_spawn_count = 0
	hunter_spawned = false
	hunter_spawned_during_preparation = false
	players_at_hunter_phase.clear()
	_clear_players_dirty()
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
	if not multiplayer.is_server() or GameManager.sender_id(multiplayer) != session_host_id:
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
	var id := GameManager.sender_id(multiplayer)
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
	if NetworkManager.dedicated_server and not multiplayer.is_server():
		if is_host():
			_request_reset_match.rpc_id(1)
		return
	if NetworkManager.is_online() and multiplayer != null and not multiplayer.is_server():
		return
	## Reset state first, then defer the scene change so units stop processing
	## before MultiplayerAPI / tree teardown (avoids null multiplayer.is_server crashes).
	if NetworkManager.is_online() and multiplayer != null:
		_reset_to_lobby.rpc()
	else:
		_reset_to_lobby_local()
	SceneTransitionManager.call_deferred("force_open", SceneTransitionManager.LOBBY)


@rpc("any_peer", "reliable")
func _request_reset_match() -> void:
	if not multiplayer.is_server() or sender_id(multiplayer) != session_host_id:
		return
	reset_match()


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
		"crystals": _starting_crystals(),
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
			"crystals": float(entry.get("crystals", _starting_crystals())),
		}
	return normalized


func _starting_crystals() -> float:
	return economy_config.starting_crystals if economy_config != null else 0.0


## --- Economy (docs/economy.README.md) -------------------------------------------------

func crystals_for(peer_id: int) -> float:
	if not players.has(peer_id):
		return 0.0
	return float(players[peer_id].get("crystals", 0.0))


## Host-only. Returns false (and spends nothing) when the player cannot afford `amount`.
func try_spend_crystals(peer_id: int, amount: float) -> bool:
	if not multiplayer.is_server() or amount < 0.0 or not players.has(peer_id):
		return false
	if amount == 0.0:
		return true
	var entry: Dictionary = players[peer_id]
	var current := float(entry.get("crystals", 0.0))
	if current < amount:
		return false
	entry["crystals"] = current - amount
	players[peer_id] = entry
	## Spending is replicated immediately so the build UI never shows stale affordability.
	_flush_players()
	return true


func grant_crystals(peer_id: int, amount: float) -> void:
	if not multiplayer.is_server() or amount <= 0.0 or not players.has(peer_id):
		return
	var entry: Dictionary = players[peer_id]
	entry["crystals"] = float(entry.get("crystals", 0.0)) + amount
	players[peer_id] = entry
	_mark_players_dirty()


## Host-only. Turns damage the Hunter actually applied into Crystal income. The
## damage -> Crystal rate lives here, not at the combat call site (docs/economy.README.md §3.1).
func award_damage_crystals(peer_id: int, applied_damage: float) -> void:
	if not multiplayer.is_server() or applied_damage <= 0.0:
		return
	var rate := economy_config.hunter_crystals_per_damage if economy_config != null else 0.0
	if rate <= 0.0:
		return
	grant_crystals(peer_id, applied_damage * rate)


# --- Roster replication throttle ------------------------------------------------------
#
# Income arrives in a steady trickle (every mine pays out on its mine_interval, the
# Hunter earns on every hit). A full roster RPC per grant would be a storm, so
# grants only raise a dirty flag and _process coalesces them into one reliable
# _sync_players at most every PLAYERS_SYNC_INTERVAL seconds.

func _mark_players_dirty() -> void:
	_players_dirty = true


func _tick_players_sync(delta: float) -> void:
	if not _players_dirty:
		return
	_players_sync_timer += delta
	if _players_sync_timer >= PLAYERS_SYNC_INTERVAL:
		_flush_players()


## Sends the roster now and drops any pending dirty state.
func _flush_players() -> void:
	_clear_players_dirty()
	_broadcast_players()


func _flush_players_if_dirty() -> void:
	if _players_dirty:
		_flush_players()


## Called when the roster has just been replicated or replaced by some other path.
func _clear_players_dirty() -> void:
	_players_dirty = false
	_players_sync_timer = 0.0


func _broadcast_players() -> void:
	if NetworkManager.is_online():
		_sync_players.rpc(players)
	else:
		players_changed.emit()


func _set_phase(new_phase: int) -> void:
	## Make sure the phase change never lands on clients ahead of pending Crystal income.
	_flush_players_if_dirty()
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
	_clear_players_dirty()
	session_host_id = 0
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
	session_host_id = 1


func prepare_selection_test() -> void:
	_reset_state()
	session_host_id = 1
	players[1] = _new_player(local_player_name, ANY_ROLE)
	_set_phase(Phase.ROLE_SELECTION)
	players_changed.emit()


func prepare_game_test() -> void:
	_reset_state()
	session_host_id = 1
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
