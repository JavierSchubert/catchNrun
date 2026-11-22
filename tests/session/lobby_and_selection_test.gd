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
	_test_session_host_permissions()
	_test_browser_bot_request_policy()
	_test_chain_modifiers()
	_test_sandbox_action_bar()
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


func _test_session_host_permissions() -> void:
	_check(
		GameManager.is_session_host_peer(2, false, true, 2),
		"the registered client can control a dedicated-server lobby"
	)
	_check(
		not GameManager.is_session_host_peer(3, false, true, 2),
		"other clients cannot control a dedicated-server lobby"
	)
	_check(
		not GameManager.is_session_host_peer(1, true, true, 2),
		"the dedicated server is not treated as a player host"
	)
	_check(
		GameManager.is_session_host_peer(1, true, false, 1),
		"a native listen-server host keeps lobby controls"
	)


func _test_browser_bot_request_policy() -> void:
	_check(
		LaunchOptions._should_enable_sandbox(false, false, true, false, false),
		"browser release builds enable the sandbox"
	)
	_check(
		not LaunchOptions._should_enable_sandbox(false, false, true, true, false),
		"bot clients do not enable the sandbox"
	)
	_check(
		not LaunchOptions._should_enable_sandbox(false, false, true, false, true),
		"headless clients do not enable the sandbox"
	)
	_check(
		not LaunchOptions.server_mode or GameManager.test_bots_enabled,
		"dedicated servers enable browser test bots"
	)
	_check(
		GameManager.test_bot_request_error("runner", 2, 2, GameManager.Phase.LOBBY, 2, 0, true, 8).is_empty(),
		"the enabled lobby host can add a Runner bot"
	)
	_check(
		GameManager.test_bot_request_error("hunter", 2, 2, GameManager.Phase.LOBBY, 2, 0, false, 8)
			== "Test bots are disabled on this server.",
		"test bots are rejected unless the server explicitly enables them"
	)
	_check(
		GameManager.test_bot_request_error("runner", 3, 2, GameManager.Phase.LOBBY, 2, 0, true, 8)
			== "Only the lobby host can add test bots.",
		"non-host players cannot start bot processes"
	)
	_check(
		GameManager.test_bot_request_error("runner", 2, 2, GameManager.Phase.HUNTER_ACTIVE, 2, 0, true, 8)
			== "Test bots can only be added in the lobby.",
		"test bots cannot join after the lobby closes"
	)
	_check(
		GameManager.test_bot_request_error("runner", 2, 2, GameManager.Phase.LOBBY, 7, 1, true, 8)
			== "The lobby is full.",
		"pending bot processes count toward the lobby limit"
	)
	_check(
		GameManager.test_bot_request_error("admin", 2, 2, GameManager.Phase.LOBBY, 2, 0, true, 8)
			== "Unknown bot role.",
		"only known bot roles can be launched"
	)


func _test_chain_modifiers() -> void:
	var plain_click := InputEventMouseButton.new()
	var shift_click := InputEventMouseButton.new()
	shift_click.shift_pressed = true
	var ctrl_click := InputEventMouseButton.new()
	ctrl_click.ctrl_pressed = true
	_check(not SelectionManager.is_chain_modifier_held(plain_click), "plain clicks do not append chain waypoints")
	_check(SelectionManager.is_chain_modifier_held(shift_click), "Shift still appends chain waypoints")
	_check(SelectionManager.is_chain_modifier_held(ctrl_click), "Ctrl appends chain waypoints for browser users")


func _test_sandbox_action_bar() -> void:
	var root := Control.new()
	add_child(root)
	var sandbox := Node.new()
	sandbox.set_script(load("res://game/sandbox/sandbox_panel.gd"))
	add_child(sandbox)
	_check(
		sandbox.call("_should_show_web_panel", true, true, true),
		"browser sandbox is visible to the dedicated-server lobby host"
	)
	_check(
		not sandbox.call("_should_show_web_panel", true, true, false),
		"browser sandbox is hidden from other players"
	)
	_check(
		not sandbox.call("_should_show_web_panel", true, false, true),
		"browser sandbox requires a dedicated server"
	)
	sandbox.set("_headless", CheckBox.new())
	sandbox.set("_bin_edit", LineEdit.new())
	sandbox.call("_build_action_bar", root)
	var runner_button := _button_with_text(root, "Runner")
	var hunter_button := _button_with_text(root, "Hunter")
	_check(runner_button != null and runner_button.icon != null, "sandbox shows a Runner example icon")
	_check(hunter_button != null and hunter_button.icon != null, "sandbox shows a Hunter example icon")
	_check(_button_with_text(root, "Skip") != null, "sandbox has a preparation-skip button")
	root.free()
	sandbox.free()


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
		var collision := unit.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var collision_circle := collision.shape as CircleShape2D if collision != null else null
		_check(
			sprite != null and health_bar != null
				and is_equal_approx(sprite.scale.x, 0.24)
				and is_equal_approx(150.0 * sprite.scale.x, health_bar.custom_minimum_size.x * health_bar.scale.x),
			"%s scales the sprite down and matches the health bar width" % scene_path
		)
		_check(
			sprite != null and collision_circle != null
				and is_equal_approx(collision_circle.radius, 16.0)
				and collision_circle.radius * 2.0 < 150.0 * sprite.scale.x,
			"%s uses a circular collision shape slightly smaller than the sprite" % scene_path
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
	var arena := match_root.get_node_or_null("ArenaPlateau")
	var floor_layer := arena.get_node_or_null("FloorLayer") as TileMapLayer if arena != null else null
	var overlay_layer := arena.get_node_or_null("OverlayLayer") as TileMapLayer if arena != null else null
	var camera := match_root.get_node_or_null("MatchCamera") as Camera2D
	var camera_script := load("res://game/camera/match_camera.gd") as Script
	var default_camera := Camera2D.new()
	default_camera.set_script(camera_script)
	_check(
		arena != null and floor_layer != null and overlay_layer != null,
		"the match scene uses the painted lava TileMap arena"
	)
	_check(
		floor_layer != null and floor_layer.tile_set != null
			and str(floor_layer.tile_set.resource_path).ends_with("tiles/v3/tileset.tres"),
		"the arena FloorLayer uses the lava (v3) TileSet"
	)
	_check(
		PlateauMap.world_bounds().is_equal_approx(Unit.MAP_BOUNDS),
		"movement bounds match the plateau map size"
	)
	var spawns := PlateauMap.runner_spawn_positions()
	_check(spawns.size() == 4, "plateau map exposes four elevated runner spawns")
	var spawn_root := match_root.get_node_or_null("SpawnPoints")
	_check(spawn_root != null, "match scene has spawn points")
	if spawn_root != null:
		for i in 4:
			var marker := spawn_root.get_node_or_null("RunnerSpawn%d" % (i + 1)) as Node2D
			_check(
				marker != null and marker.position.is_equal_approx(spawns[i]),
				"runner spawn %d sits on an elevated base" % (i + 1)
			)
	_check(
		camera != null and is_equal_approx(camera.zoom_factor, float(default_camera.get("zoom_factor")))
			and camera.bounds == Unit.MAP_BOUNDS,
		"the match camera uses the configurable script zoom factor without a scene override"
	)
	if camera != null:
		camera.zoom_factor = 2.0
		_check(camera.zoom.is_equal_approx(Vector2(2.0, 2.0)), "changing zoom_factor updates camera zoom")
		camera.zoom_factor = 1.0
		_check(camera.zoom.is_equal_approx(Vector2.ONE), "a zoom factor of 1 resets the camera zoom")

	add_child(default_camera)
	default_camera.bounds = Rect2(-1000.0, -500.0, 2000.0, 1000.0)
	default_camera.bound_padding = 100.0
	default_camera.zoom = Vector2.ONE
	default_camera.global_position = Vector2(-10000.0, 10000.0)
	default_camera._clamp_to_bounds()
	var viewport_size := default_camera.get_viewport().get_visible_rect().size
	var half_view := viewport_size * 0.5
	var expected := Vector2(
		clampf(-10000.0, -1000.0 + half_view.x - 100.0, 1000.0 - half_view.x + 100.0),
		clampf(10000.0, -500.0 + half_view.y - 100.0, 500.0 - half_view.y + 100.0)
	)
	_check(
		default_camera.global_position.is_equal_approx(expected),
		"the match camera clamps with a screen-pixel edge offset"
	)
	default_camera.free()
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
	var resolved_hunter := GameManager.resolved_hunter_id
	_check(resolved_hunter == 3 or resolved_hunter == 4, "resolving the vote picks one of the Hunter requests")
	if not GameManager.players.has(resolved_hunter):
		_fail("resolving the vote assigns an existing player as Hunter")
		selection.queue_free()
		return
	_check(int(GameManager.players[resolved_hunter].role) == RoleConfig.Role.HUNTER, "the resolved player is assigned to the Hunter team")
	var hunter_count := 0
	for key in GameManager.players.keys():
		if int(GameManager.players[key].role) == RoleConfig.Role.HUNTER:
			hunter_count += 1
		else:
			_check(int(GameManager.players[key].role) == RoleConfig.Role.RUNNER, "every non-selected player is assigned to Runners")
	_check(hunter_count == 1, "the vote assigns exactly one Hunter")
	GameManager.resolved_hunter_id = -1
	GameManager._sync_players(GameManager.players)
	_check(
		GameManager.resolved_hunter_id == resolved_hunter,
		"the resolved Hunter is recovered from the synchronized roles"
	)

	var reroll_rng := RandomNumberGenerator.new()
	var reroll_seed := 1
	while true:
		reroll_rng.seed = reroll_seed
		if GameManager.choose_hunter_id(GameManager.players, reroll_rng) != resolved_hunter:
			break
		reroll_seed += 1
	GameManager._assign_roles(reroll_rng)
	_check(
		GameManager.resolved_hunter_id == resolved_hunter,
		"starting after resolving does not choose a different Hunter"
	)
	await get_tree().process_frame
	await get_tree().process_frame
	columns = _selection_columns(selection)
	if columns.size() == 3:
		var hunter_name := str(GameManager.players[resolved_hunter].name)
		_check(_column_names(columns[2]).has(hunter_name), "the resolved Hunter appears in the Hunter team")
		for key in GameManager.players.keys():
			if int(key) != resolved_hunter:
				_check(
					_column_names(columns[0]).has(str(GameManager.players[key].name)),
					"all other players appear in the Runner team"
				)
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


func _button_with_text(root: Node, text: String) -> Button:
	for node in _walk(root):
		if node is Button and (node as Button).text == text:
			return node as Button
	return null


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
