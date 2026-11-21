extends Control
## Role vote. Runners are on the left and the Hunter is on the right.
## Shell layout + StyleBoxes live in role_selection.tscn / ui/styles/*.tres.
## Dynamic player rows and action buttons are still filled from code.

@export var button_style: StyleBoxFlat
@export var button_hover_style: StyleBoxFlat

@onready var _result: Label = %Result
@onready var _runner_box: VBoxContainer = %RunnerBox
@onready var _hunter_box: VBoxContainer = %HunterBox
@onready var _waiting_box: VBoxContainer = %WaitingBox
@onready var _actions: HBoxContainer = %Actions

var _start_button: Button
var _rebuild_queued := false


func _ready() -> void:
	_add_button(_actions, "Join Runners", func() -> void: GameManager.request_side(RoleConfig.Role.RUNNER))
	_add_button(_actions, "Join Hunter", func() -> void: GameManager.request_side(RoleConfig.Role.HUNTER))
	if not NetworkManager.is_online():
		_add_button(_actions, "Add test player", func() -> void: GameManager.add_test_player())
	if not NetworkManager.is_online() or multiplayer.is_server():
		_add_button(_actions, "Resolve vote", func() -> void: GameManager.resolve_roles())
		_start_button = _add_button(_actions, "Start game", func() -> void: GameManager.start_game_from_selection())

	SettingsMenu.attach(self)
	SoundManager.ensure_music()

	GameManager.players_changed.connect(_queue_rebuild)
	GameManager.phase_changed.connect(func(_phase: GameManager.Phase) -> void: _queue_rebuild())
	_vote_for_automated_peer()
	_queue_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_rebuild")


func _add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	if button_style != null:
		button.add_theme_stylebox_override("normal", button_style)
		button.add_theme_stylebox_override("pressed", button_style)
	if button_hover_style != null:
		button.add_theme_stylebox_override("hover", button_hover_style)
	button.pressed.connect(func() -> void:
		SoundManager.play_ui()
		callback.call()
	)
	parent.add_child(button)
	return button


func _vote_for_automated_peer() -> void:
	if LaunchOptions.bot_role == "hunter":
		GameManager.request_side(RoleConfig.Role.HUNTER)
	elif LaunchOptions.bot_role == "runner":
		GameManager.request_side(RoleConfig.Role.RUNNER)
	elif LaunchOptions.auto_start_players > 0 and multiplayer.is_server():
		GameManager.request_side(RoleConfig.Role.RUNNER)


func _rebuild() -> void:
	_rebuild_queued = false
	if not is_inside_tree():
		return
	_clear(_runner_box)
	_clear(_hunter_box)
	_clear(_waiting_box)
	for key in GameManager.players.keys():
		var id := int(key)
		var entry: Dictionary = GameManager.players[id]
		var preference := int(entry.get("preferred_role", GameManager.ANY_ROLE))
		var row := _player_row(
			id,
			str(entry.get("name", "Player")),
			preference,
			int(entry.get("sprite_index", 0))
		)
		if preference == RoleConfig.Role.HUNTER:
			_hunter_box.add_child(row)
		elif preference == RoleConfig.Role.RUNNER:
			_runner_box.add_child(row)
		else:
			_waiting_box.add_child(row)
	if GameManager.resolved_hunter_id >= 0 and GameManager.players.has(GameManager.resolved_hunter_id):
		var hunter: Dictionary = GameManager.players[GameManager.resolved_hunter_id]
		_result.text = "Hunter: %s" % str(hunter.get("name", "Player"))
	else:
		_result.text = "The host resolves the vote. Several Hunter requests are decided at random."
	if _start_button != null:
		_start_button.disabled = NetworkManager.is_online() and not multiplayer.is_server()


func _player_row(peer_id: int, player_name: String, preferred_role: int, sprite_index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	var suffix := " (you)" if peer_id == multiplayer.get_unique_id() else ""
	label.text = player_name + suffix
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var sprite_role := RoleConfig.Role.HUNTER if preferred_role == RoleConfig.Role.HUNTER else RoleConfig.Role.RUNNER
	var can_choose_sprite := peer_id == multiplayer.get_unique_id() \
		or (not NetworkManager.is_online() and peer_id >= GameManager.TEST_PLAYER_ID)
	var sprite_selector := HBoxContainer.new()
	sprite_selector.name = "SpriteSelector_%d" % peer_id
	sprite_selector.add_theme_constant_override("separation", 2)
	for index in GameManager.SPRITE_COUNT:
		var sprite_button := TextureButton.new()
		sprite_button.name = "SpriteOption%d" % (index + 1)
		sprite_button.custom_minimum_size = Vector2(32, 32)
		sprite_button.ignore_texture_size = true
		sprite_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		sprite_button.texture_normal = Unit.sprite_texture(index, sprite_role)
		sprite_button.texture_pressed = sprite_button.texture_normal
		sprite_button.disabled = not can_choose_sprite
		sprite_button.modulate = Color(1.0, 0.8, 0.45) if index == sprite_index else Color.WHITE
		sprite_button.tooltip_text = "%s %d" % [
			"Hunter" if sprite_role == RoleConfig.Role.HUNTER else "Runner",
			index + 1,
		]
		sprite_button.pressed.connect(GameManager.set_sprite_for.bind(peer_id, index))
		sprite_selector.add_child(sprite_button)
	row.add_child(sprite_selector)

	if not NetworkManager.is_online() and peer_id >= GameManager.TEST_PLAYER_ID:
		_add_button(row, "Runners", _set_test_side.bind(peer_id, RoleConfig.Role.RUNNER))
		_add_button(row, "Hunter", _set_test_side.bind(peer_id, RoleConfig.Role.HUNTER))
	return row


func _set_test_side(peer_id: int, role: int) -> void:
	GameManager.request_side_for(peer_id, role)


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.free()
