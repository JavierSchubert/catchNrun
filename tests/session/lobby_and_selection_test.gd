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
	_test_sprite_sync_data()
	_test_health_bar()
	_test_match_presentation()
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


func _test_sprite_sync_data() -> void:
	var normalized := GameManager._normalize_players({
		1: {"name": "Ada", "sprite_index": 3},
		2: {"name": "Bo"},
	})
	_check(int(normalized[1].sprite_index) == 3, "sprite selection survives roster synchronization")
	_check(int(normalized[2].sprite_index) == 0, "missing sprite selection gets the default")
	_check(
		Unit.sprite_texture(2, RoleConfig.Role.RUNNER).resource_path.ends_with("Player_3.png"),
		"Runner sprite indices use Player assets"
	)
	_check(
		Unit.sprite_texture(2, RoleConfig.Role.HUNTER).resource_path.ends_with("Enemy_3.png"),
		"Hunter sprite indices use Enemy assets"
	)


func _test_health_bar() -> void:
	var health_bar_scene := load("res://ui/hud/health_bar/health_bar.tscn") as PackedScene
	if health_bar_scene == null:
		_fail("the health bar scene loads")
		return
	var health_bar := health_bar_scene.instantiate() as HealthBar
	if health_bar == null:
		_fail("the health bar scene uses its HealthBar script")
		return
	add_child(health_bar)

	var health := HealthComponent.new()
	health.health_changed.connect(health_bar.update_for_health)
	health.setup(100.0)
	health.take_damage(25.0, 100.0)
	_check(is_equal_approx(health_bar.progress_bar.value, 0.75), "health changes update the bar")
	_check(health_bar.health_label.text == "75", "health changes update the visible amount")
	var fill_style := health_bar.progress_bar.get_theme_stylebox("fill") as StyleBoxFlat
	_check(fill_style != null and fill_style.bg_color.a > 0.0, "the health bar keeps its visible fill style")
	health.free()
	health_bar.free()


func _test_match_presentation() -> void:
	GameManager.players[1] = _entry("Runner", RoleConfig.Role.RUNNER)
	GameManager.players[1].sprite_index = 2
	GameManager.players[2] = _entry("Hunter", RoleConfig.Role.HUNTER)
	GameManager.players[2].sprite_index = 4
	var scene_paths := [
		"res://src/units/runner/runner.tscn",
		"res://src/units/hunter/hunter.tscn",
	]
	var peer_ids := [1, 2]
	var expected_sprites := ["Player_3.png", "Enemy_5.png"]
	for index in scene_paths.size():
		var scene_path: String = scene_paths[index]
		var unit_scene := load(scene_path) as PackedScene
		if unit_scene == null:
			_fail("%s loads" % scene_path)
			continue
		var unit := unit_scene.instantiate()
		unit.name = str(peer_ids[index])
		add_child(unit)
		_check(unit.get_node_or_null("HealthBar") is HealthBar, "%s includes a health bar" % scene_path)
		var sprite := unit.get_node_or_null("Sprite") as Sprite2D
		var health_bar := unit.get_node_or_null("HealthBar") as HealthBar
		_check(
			sprite != null and health_bar != null
				and is_equal_approx(sprite.scale.x, 0.24)
				and is_equal_approx(150.0 * sprite.scale.x, health_bar.custom_minimum_size.x * health_bar.scale.x),
			"%s scales the sprite down and matches the health bar width" % scene_path
		)
		_check(
			sprite != null and sprite.texture.resource_path.ends_with(expected_sprites[index]),
			"%s displays the selected role sprite" % scene_path
		)
		_check(
			health_bar != null and is_equal_approx(health_bar.progress_bar.value, 1.0),
			"%s initializes a visible full health bar" % scene_path
		)
		if index == 0:
			unit.global_position = Unit.MAP_BOUNDS.end + Vector2(200.0, 100.0)
			unit._clamp_to_map()
			_check(
				unit.global_position.is_equal_approx(Unit.MAP_BOUNDS.end - Vector2.ONE * Unit.MAP_INSET),
				"units stay inside the map boundary"
			)
		unit.free()

	var match_scene := load("res://game/match/match.tscn") as PackedScene
	if match_scene == null:
		_fail("the match scene loads")
		return
	var match_root := match_scene.instantiate()
	var background := match_root.get_node_or_null("Background") as Sprite2D
	var camera := match_root.get_node_or_null("MatchCamera") as Camera2D
	var map_world_size := Vector2.ZERO
	if background != null and background.texture != null:
		map_world_size = Vector2(background.texture.get_size()) * background.scale
	_check(
		background != null and background.texture.resource_path.ends_with("assets/sprites/maps/lava.png"),
		"the match scene uses the lava map"
	)
	_check(
		background != null and background.scale.is_equal_approx(Vector2(1.5625, 1.5625)),
		"the lava map is scaled to the match area"
	)
	_check(
		map_world_size.is_equal_approx(Unit.MAP_BOUNDS.size),
		"movement bounds match the rendered map size"
	)
	_check(
		camera != null and camera.zoom.is_equal_approx(Vector2(1.25, 1.25))
			and camera.bounds == Unit.MAP_BOUNDS,
		"the camera zooms in and keeps its view inside the map"
	)
	match_root.free()


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

	var sprite_selector := selection.find_child("SpriteSelector_1", true, false) as HBoxContainer
	_check(sprite_selector != null, "the local player can choose a sprite")
	if sprite_selector != null:
		var sprite_option := sprite_selector.get_node_or_null("SpriteOption3") as TextureButton
		_check(sprite_option != null and not sprite_option.disabled, "the local sprite options are enabled")
		if sprite_option != null:
			sprite_option.pressed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			_check(int(GameManager.players[1].sprite_index) == 2, "choosing a sprite updates the local roster entry")

	GameManager.request_side(RoleConfig.Role.HUNTER)
	await get_tree().process_frame
	await get_tree().process_frame
	sprite_selector = selection.find_child("SpriteSelector_1", true, false) as HBoxContainer
	if sprite_selector != null:
		var hunter_option := sprite_selector.get_node_or_null("SpriteOption3") as TextureButton
		_check(
			hunter_option != null and hunter_option.texture_normal.resource_path.ends_with("Enemy_3.png"),
			"the Hunter sprite selector shows Enemy assets"
		)
	GameManager.request_side(RoleConfig.Role.RUNNER)
	await get_tree().process_frame
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
		"sprite_index": 0,
		"alive": true,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		print("failed: %s" % message)


func _fail(message: String) -> void:
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
