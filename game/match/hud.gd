extends CanvasLayer
## HUD for the local player: health, gold, timer, shop, end screen. Built in code to keep
## the skeleton small. Swap in a real scene whenever you like.

@export var players_root: Node

var _player: Player
var _status := Label.new()
var _shop := VBoxContainer.new()
var _end_panel := VBoxContainer.new()
var _end_label := Label.new()


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var top := VBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(top)
	top.add_child(_status)
	var shop_title := Label.new()
	shop_title.text = "Shop"
	top.add_child(shop_title)
	top.add_child(_shop)

	_end_panel.set_anchors_preset(Control.PRESET_CENTER)
	_end_panel.visible = false
	_end_label.add_theme_font_size_override("font_size", 40)
	_end_panel.add_child(_end_label)
	if multiplayer.is_server():
		var back := Button.new()
		back.text = "Back to lobby"
		back.pressed.connect(GameManager.return_to_lobby)
		_end_panel.add_child(back)
	add_child(_end_panel)

	GameManager.match_ended.connect(_on_match_ended)
	players_root.child_entered_tree.connect(_on_player_added)


func _process(_delta: float) -> void:
	if _player == null:
		_status.text = "Waiting for players... %d:%02d" % _time()
		return
	_status.text = "%s | HP %d / %d | Gold %d | %d:%02d" % [
		_player.role_data.display_name,
		_player.health.current, _player.health.get_max(),
		_player.inventory.gold, _time()[0], _time()[1]]


func _time() -> Array:
	var t := int(ceil(GameManager.time_left))
	return [t / 60, t % 60]


func _on_player_added(node: Node) -> void:
	var player := node as Player
	if player and player.is_local():
		# The player's child nodes (inventory etc.) aren't ready yet, so wait for ready.
		player.ready.connect(_on_local_player_ready.bind(player), CONNECT_ONE_SHOT)


func _on_local_player_ready(player: Player) -> void:
	_player = player
	_player.inventory.changed.connect(_refresh_shop)
	_build_shop()


func _build_shop() -> void:
	for item in ItemDatabase.all_items():
		if not item.usable_by_role(_player.role):
			continue
		var button := Button.new()
		button.set_meta("item", item)
		button.focus_mode = Control.FOCUS_NONE # Keep Space for attacking.
		button.pressed.connect(_player.inventory.buy.bind(item.id))
		_shop.add_child(button)
	_refresh_shop()


func _refresh_shop() -> void:
	for button: Button in _shop.get_children():
		var item: ItemData = button.get_meta("item")
		button.text = "%s - %dg  (%s)  [%d/%d]" % [
			item.display_name, item.price, item.description,
			_player.inventory.count(item.id), item.max_stack]
		button.disabled = not _player.inventory.can_buy(item)


func _on_match_ended(hunter_won: bool) -> void:
	_end_label.text = "The Hunter wins!" if hunter_won else "The Runners escaped!"
	_end_panel.visible = true
