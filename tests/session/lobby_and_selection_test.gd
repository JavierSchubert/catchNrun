extends Node
## Checks the lobby and the role-selection rules without opening a multiplayer game.
## Run with the project so autoloads exist:
##   godot --headless --path . res://tests/session/lobby_and_selection_test.tscn

const LOBBY_SCENE := "res://ui/lobby/lobby.tscn"
const SELECTION_SCENE := "res://ui/role_selection/role_selection.tscn"

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	await _run()


func _run() -> void:
	_test_hunter_choice()
	await _test_lobby()
	await _test_role_selection()
	if _failures.is_empty():
		print("PASS: lobby and role selection")
		get_tree().quit(0)
	else:
		print("FAIL: %d check(s)" % _failures.size())
		for failure in _failures:
			print(" - %s" % failure)
		get_tree().quit(1)


func _test_hunter_choice() -> void:
	_check(GameManager.choose_hunter_id({}) == -1, "an empty roster has no hunter")
	var only_hunter := {
		1: _entry("Ada", RoleConfig.Role.RUNNER),
		4: _entry("Bo", RoleConfig.Role.HUNTER),
	}
	var rng := RandomNumberGenerator.new()
	for seed_value in range(1, 11):
		rng.seed = seed_value
		var chosen := GameManager.choose_hunter_id(only_hunter, rng)
		_check(chosen == 4, "the only Hunter request wins (seed %d)" % seed_value)
	rng.seed = 7
	var first := GameManager.choose_hunter_id(only_hunter, rng)
	rng.seed = 7
	var second := GameManager.choose_hunter_id(only_hunter, rng)
	_check(first == second, "the same seed chooses the same hunter")

	var several := {
		2: _entry("Hunter A", RoleConfig.Role.HUNTER),
		3: _entry("Runner", RoleConfig.Role.RUNNER),
		4: _entry("Hunter B", RoleConfig.Role.HUNTER),
	}
	var seen := {}
	for seed_value in range(1, 41):
		rng.seed = seed_value
		var picked := GameManager.choose_hunter_id(several, rng)
		_check(picked == 2 or picked == 4, "a Runner is not chosen while Hunters requested (seed %d)" % seed_value)
		seen[picked] = true
	_check(seen.has(2) and seen.has(4), "several Hunter requests can select either candidate")

	var nobody := {
		1: _entry("Ada", GameManager.ANY_ROLE),
		2: _entry("Bo", RoleConfig.Role.RUNNER),
		3: _entry("Cia", RoleConfig.Role.RUNNER),
	}
	var anybody := {}
	for seed_value in range(1, 41):
		rng.seed = seed_value
		var picked_any := GameManager.choose_hunter_id(nobody, rng)
		_check(picked_any == 1 or picked_any == 2 or picked_any == 3, "with no Hunter request the choice stays in the roster")
		anybody[picked_any] = true
	_check(anybody.size() >= 2, "with no Hunter request more than one player can be chosen")


func _test_lobby() -> void:
	GameManager.prepare_lobby_test()
	var lobby := (load(LOBBY_SCENE) as PackedScene).instantiate()
	add_child(lobby)
	await get_tree().process_frame

	var buttons := _button_texts(lobby)
	_check(buttons.has("Host local"), "lobby can host locally")
	_check(buttons.has("Join local"), "lobby can join locally")
	_check(buttons.has("Continue (need %d players)" % GameManager.required_players()), "lobby asks for enough players before continuing")
	_check(not buttons.has("Join Runners") and not buttons.has("Join Hunter"), "lobby does not choose roles")

	GameManager.players[1] = _entry("Ada", GameManager.ANY_ROLE)
	GameManager.players[2] = _entry("Bo", GameManager.ANY_ROLE)
	GameManager.players_changed.emit()
	await get_tree().process_frame

	var listed := _list_texts(lobby)
	_check(listed.has("Ada (host)"), "lobby lists the host by name")
	_check(listed.has("Bo"), "lobby lists the other player by name")
	_check(not _contains_role_word(listed), "lobby list does not show roles")
	_check(GameManager.can_continue_to_selection(), "two players can continue to role selection")
	_check(int(GameManager.players[1].preferred_role) == GameManager.ANY_ROLE, "the host has not chosen a side")
	_check(GameManager.resolved_hunter_id < 0, "lobby has not resolved a hunter")

	var scene_before := get_tree().current_scene.scene_file_path
	GameManager.continue_to_selection()
	await get_tree().process_frame
	_check(GameManager.phase == GameManager.Phase.ROLE_SELECTION, "continue opens role selection")
	_check(get_tree().current_scene.scene_file_path == scene_before, "a transition from the wrong scene stays put")
	_check(GameManager.resolved_hunter_id < 0, "continuing does not assign the hunter yet")
	lobby.free()


func _test_role_selection() -> void:
	GameManager.local_player_name = "Ada"
	GameManager.prepare_selection_test()
	GameManager.players[2] = _entry("Bo", RoleConfig.Role.RUNNER)
	GameManager.players[3] = _entry("Hunter A", RoleConfig.Role.HUNTER)
	GameManager.players[4] = _entry("Hunter B", RoleConfig.Role.HUNTER)
	var selection := (load(SELECTION_SCENE) as PackedScene).instantiate()
	add_child(selection)
	GameManager.players_changed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var columns := _selection_columns(selection)
	_check(columns.size() == 3, "role selection has three columns")
	if columns.size() == 3:
		_check(_heading(columns[0]) == "Runners", "the left column is Runners")
		_check(_heading(columns[1]) == "Waiting", "the middle column is for players who have not chosen")
		_check(_heading(columns[2]) == "Hunter", "the right column is the Hunter")
		_check(_column_names(columns[0]).has("Bo"), "a Runner request is on the left")
		_check(_column_names(columns[2]).has("Hunter A"), "a Hunter request is on the right")
		_check(_column_names(columns[2]).has("Hunter B"), "every Hunter request is on the right")
		_check(_column_names(columns[1]).has("Ada (you)"), "a player who has not chosen waits in the middle")

	var actions := _button_texts(selection)
	_check(actions.has("Join Runners") and actions.has("Join Hunter"), "a player can join either side")
	_check(actions.has("Resolve vote") and actions.has("Start game"), "the host can resolve the vote and start")

	GameManager.request_side(RoleConfig.Role.RUNNER)
	await get_tree().process_frame
	columns = _selection_columns(selection)
	if columns.size() == 3:
		_check(_column_names(columns[0]).has("Ada (you)"), "joining Runners moves the local player left")
		_check(not _column_names(columns[1]).has("Ada (you)"), "joining Runners leaves the waiting column")

	GameManager.resolve_roles()
	_check(GameManager.resolved_hunter_id == 3 or GameManager.resolved_hunter_id == 4, "resolving the vote picks one of the Hunter requests")
	_check(int(GameManager.players[1].role) == RoleConfig.Role.RUNNER, "a Runner stays a Runner after the vote")
	_check(int(GameManager.players[2].role) == RoleConfig.Role.RUNNER, "the other Runner stays a Runner")
	var hunter_count := 0
	for key in GameManager.players.keys():
		if int(GameManager.players[key].role) == RoleConfig.Role.HUNTER:
			hunter_count += 1
	_check(hunter_count == 1, "the vote assigns exactly one Hunter")
	selection.queue_free()


func _entry(player_name: String, preferred_role: int) -> Dictionary:
	return {
		"name": player_name,
		"preferred_role": preferred_role,
		"role": RoleConfig.Role.RUNNER,
		"alive": true,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		print("failed: %s" % message)


func _button_texts(root: Node) -> PackedStringArray:
	var texts := PackedStringArray()
	for node in _walk(root):
		if node is Button:
			texts.append((node as Button).text)
	return texts


func _list_texts(root: Node) -> PackedStringArray:
	var texts := PackedStringArray()
	for node in _walk(root):
		if node is ItemList:
			var list := node as ItemList
			for index in list.item_count:
				texts.append(list.get_item_text(index))
	return texts


func _contains_role_word(texts: PackedStringArray) -> bool:
	for text in texts:
		if text.contains("Hunter") or text.contains("Runner"):
			return true
	return false


func _selection_columns(root: Node) -> Array[Node]:
	var columns: Array[Node] = []
	for node in _walk(root):
		if node is HBoxContainer and node.get_child_count() == 3 and node.get_child(0) is PanelContainer:
			for child in node.get_children():
				columns.append(child)
			return columns
	return columns


func _heading(panel: Node) -> String:
	var label := panel.get_child(0).get_child(0) as Label
	return label.text if label != null else ""


func _column_names(panel: Node) -> PackedStringArray:
	var names := PackedStringArray()
	var list := panel.get_child(0).get_child(1)
	for row in list.get_children():
		var label := row.get_child(0) as Label
		if label != null:
			names.append(label.text)
	return names


func _walk(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		found.append(child)
		found.append_array(_walk(child))
	return found
