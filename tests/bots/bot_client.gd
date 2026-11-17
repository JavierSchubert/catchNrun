extends Node
## Drives a bot process, and writes the host report used by the smoke test.
##
## A normal launch does nothing. A bot launch (--bot=runner or --bot=hunter) joins
## localhost, accepts its role, and moves with the built-in pattern in Unit.
## --host-lifetime makes the host quit and, with --report, write what it observed.

const MAX_JOIN_ATTEMPTS := 20
const MOVE_DISTANCE := 30.0

var connected := false
var spawned := false
var moved := false
var disconnected_cleanly := false
var assigned_role := ""
var errors: Array[String] = []

var _join_attempts := 0
var _quit_started := false
var _origin := Vector2.ZERO
var _have_origin := false


func _ready() -> void:
	var is_bot := not LaunchOptions.bot_role.is_empty()
	var timed_host := LaunchOptions.host_lifetime > 0.0
	if not is_bot and not timed_host:
		set_process(false)
		return
	set_process(is_bot)
	if is_bot and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("CatchNRun bot — %s" % LaunchOptions.bot_name)
	GameManager.players_changed.connect(_remember_role)
	GameManager.phase_changed.connect(func(_phase: GameManager.Phase) -> void: _remember_role())
	if is_bot:
		NetworkManager.joined_server.connect(_on_joined)
		NetworkManager.connection_failed.connect(_on_connection_failed)
		NetworkManager.disconnected.connect(_on_disconnected)
		_try_join()
	if timed_host:
		NetworkManager.hosting_started.connect(_on_host_started)
		GameManager.auto_host_failed.connect(_on_auto_host_failed)


func _process(_delta: float) -> void:
	if not NetworkManager.is_online():
		return
	var id := multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group("units"):
		if node.name != str(id) or not node is Node2D:
			continue
		spawned = true
		var pos := (node as Node2D).global_position
		if not _have_origin:
			_origin = pos
			_have_origin = true
		elif _origin.distance_to(pos) >= MOVE_DISTANCE:
			moved = true


func _try_join() -> void:
	if _quit_started or NetworkManager.is_online():
		return
	var err: Error = NetworkManager.join_enet()
	if err != OK:
		_retry("could not start joining: %s" % error_string(err))


func _on_joined() -> void:
	connected = true
	GameLog.info("BOT", "%s connected" % LaunchOptions.bot_name)
	if LaunchOptions.bot_lifetime > 0.0:
		get_tree().create_timer(LaunchOptions.bot_lifetime).timeout.connect(_shutdown)


func _on_connection_failed() -> void:
	if _quit_started:
		return
	_retry("connection failed")


func _on_disconnected() -> void:
	if _quit_started:
		return
	errors.append("disconnected before the bot finished")
	_shutdown()


func _on_host_started() -> void:
	get_tree().create_timer(LaunchOptions.host_lifetime).timeout.connect(_shutdown)


func _on_auto_host_failed(error_code: Error) -> void:
	errors.append("auto host failed: %s" % error_string(error_code))
	_shutdown()


func _retry(reason: String) -> void:
	_join_attempts += 1
	GameLog.info("BOT", "%s (attempt %d)" % [reason, _join_attempts])
	if _join_attempts >= MAX_JOIN_ATTEMPTS:
		errors.append(reason)
		_shutdown()
		return
	get_tree().create_timer(0.5).timeout.connect(_try_join)


func _remember_role() -> void:
	if LaunchOptions.bot_role.is_empty():
		return
	if GameManager.phase == GameManager.Phase.LOBBY or GameManager.phase == GameManager.Phase.ROLE_SELECTION:
		return
	var id := multiplayer.get_unique_id()
	if id <= 0 or not GameManager.players.has(id):
		return
	assigned_role = GameManager.role_label(int(GameManager.players[id].role))


func _shutdown() -> void:
	if _quit_started:
		return
	_quit_started = true
	var report := _build_report()
	if NetworkManager.is_online():
		if not LaunchOptions.bot_role.is_empty():
			disconnected_cleanly = true
			report["disconnected_cleanly"] = true
		NetworkManager.leave()
	await get_tree().create_timer(0.3).timeout
	_write_report(report)
	var exit_code := 1
	if _succeeded(report):
		exit_code = 0
	get_tree().quit(exit_code)


func _build_report() -> Dictionary:
	var report_errors: Array = []
	report_errors.assign(errors)
	if LaunchOptions.bot_role.is_empty():
		return {
			"kind": "host",
			"phases": GameManager.phases_seen.duplicate(),
			"players_at_hunter_phase": GameManager.players_at_hunter_phase.duplicate(true),
			"runner_spawn_count": GameManager.runner_spawn_count,
			"hunter_spawned": GameManager.hunter_spawned,
			"hunter_spawned_during_preparation": GameManager.hunter_spawned_during_preparation,
			"errors": report_errors,
		}
	return {
		"kind": "bot",
		"name": LaunchOptions.bot_name,
		"requested_role": _requested_role(),
		"assigned_role": assigned_role,
		"connected": connected,
		"spawned": spawned,
		"moved": moved,
		"disconnected_cleanly": disconnected_cleanly,
		"errors": report_errors,
	}


func _requested_role() -> String:
	if LaunchOptions.bot_role == "hunter":
		return "Hunter"
	if LaunchOptions.bot_role == "runner":
		return "Runner"
	return ""


func _succeeded(report: Dictionary) -> bool:
	var report_errors: Array = report.get("errors", [])
	if not report_errors.is_empty():
		return false
	if str(report.get("kind", "")) == "host":
		var phases: Array = report.get("phases", [])
		var needed_runners := 1
		if LaunchOptions.auto_start_players > 1:
			needed_runners = LaunchOptions.auto_start_players - 1
		return phases.has("ROLE_SELECTION") \
			and phases.has("RUNNER_PREPARATION") \
			and phases.has("HUNTER_ACTIVE") \
			and bool(report.get("hunter_spawned", false)) \
			and not bool(report.get("hunter_spawned_during_preparation", true)) \
			and int(report.get("runner_spawn_count", 0)) >= needed_runners
	return bool(report.get("connected", false)) \
		and bool(report.get("spawned", false)) \
		and bool(report.get("moved", false)) \
		and bool(report.get("disconnected_cleanly", false)) \
		and str(report.get("assigned_role", "")).to_lower() == str(report.get("requested_role", "")).to_lower()


func _write_report(report: Dictionary) -> void:
	if LaunchOptions.report_path.is_empty():
		return
	var path := LaunchOptions.report_path
	var directory := path.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write report to %s" % path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	GameLog.info("BOT", "wrote report %s" % path)
