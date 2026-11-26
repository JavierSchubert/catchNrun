extends Node
## The only code that changes the current session scene.
##
## The caller passes the scene players are leaving and the scene they are opening.
## An empty `from` opens a scene directly so it can be tested on its own.

signal scene_changed(from_path: String, to_path: String)

const LOBBY := "res://ui/lobby/lobby.tscn"
const ROLE_SELECTION := "res://ui/role_selection/role_selection.tscn"
const GAME := "res://game/match/match.tscn"


func _ready() -> void:
	if LaunchOptions.open_scene.is_empty() or LaunchOptions.host_on_start or not LaunchOptions.bot_role.is_empty():
		return
	call_deferred("_open_requested_scene")


func transition(from_path: String, to_path: String) -> void:
	if from_path.is_empty() or not NetworkManager.is_online():
		_open(from_path, to_path)
		return
	if multiplayer.is_server():
		_open_everywhere.rpc(from_path, to_path)


func force_open(to_path: String) -> void:
	## Open a scene on every peer, ignoring the current-path guard.
	## Used by match reset so a stuck / mismatched from-path cannot block return to lobby.
	if not NetworkManager.is_online():
		_open("", to_path)
		return
	if multiplayer.is_server():
		_force_open_everywhere.rpc(to_path)


func current_scene_path() -> String:
	var current := get_tree().current_scene
	if current == null:
		return ""
	return current.scene_file_path


@rpc("authority", "call_local", "reliable")
func _open_everywhere(from_path: String, to_path: String) -> void:
	_open(from_path, to_path)


@rpc("authority", "call_local", "reliable")
func _force_open_everywhere(to_path: String) -> void:
	_open("", to_path)


func _open(from_path: String, to_path: String) -> void:
	var current := current_scene_path()
	if not from_path.is_empty() and current != from_path:
		GameLog.info("SCENE", "ignored transition from %s to %s; current scene is %s" % [from_path, to_path, current])
		return
	if current == to_path:
		GameLog.info("SCENE", "already at %s" % to_path)
		scene_changed.emit(from_path, to_path)
		return
	var err: Error = get_tree().change_scene_to_file(to_path)
	if err != OK:
		push_error("Could not open %s: %s" % [to_path, error_string(err)])
		return
	var origin := from_path if not from_path.is_empty() else "(direct)"
	GameLog.info("SCENE", "transition %s -> %s" % [origin, to_path])
	scene_changed.emit(from_path, to_path)


func _open_requested_scene() -> void:
	match LaunchOptions.open_scene:
		"lobby":
			GameManager.prepare_lobby_test()
			transition("", LOBBY)
		"selection":
			GameManager.prepare_selection_test()
			transition("", ROLE_SELECTION)
		"game":
			GameManager.prepare_game_test()
			transition("", GAME)
		"sandbox":
			GameManager.prepare_sandbox()
			transition("", GAME)
		_:
			push_error("Unknown --scene '%s' (use lobby, selection, game, or sandbox)." % LaunchOptions.open_scene)
