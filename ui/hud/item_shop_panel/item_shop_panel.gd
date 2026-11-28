class_name ItemShopPanel
extends Control
## Modal shop: Hunter upgrades (buy) + inventory grid (sell). Opened via RMB on ItemShop.

const AFFORD_COLOR := Color(0.35, 0.9, 0.45, 1.0)
const UNAFFORD_COLOR := Color(0.95, 0.35, 0.35, 1.0)
const CARD_SIZE := Vector2(150, 118)
const INV_CELL := Vector2(72, 72)

@onready var _frame: Panel = %Frame
@onready var _title: Label = %Title
@onready var _hint: Label = %Hint
@onready var _buy_tab: Button = %BuyTab
@onready var _inv_tab: Button = %InvTab
@onready var _buy_grid: GridContainer = %BuyGrid
@onready var _inv_grid: GridContainer = %InvGrid
@onready var _leave_button: Button = %LeaveButton

var _showing_inventory := false
var _last_crystals := -1.0
var _last_inventory_sig := ""


func _ready() -> void:
	add_to_group("item_shop_ui")
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_buy_tab.pressed.connect(func() -> void: _showing_inventory = false; _refresh(true))
	_inv_tab.pressed.connect(func() -> void: _showing_inventory = true; _refresh(true))
	_leave_button.pressed.connect(close_shop)
	set_process(false)
	set_process_unhandled_input(true)


func is_open() -> bool:
	return visible


func open_shop() -> void:
	visible = true
	set_process(true)
	_showing_inventory = false
	_refresh(true)


func close_shop() -> void:
	visible = false
	set_process(false)
	_last_crystals = -1.0
	_last_inventory_sig = ""


func _process(_delta: float) -> void:
	if not visible:
		return
	_refresh(false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			close_shop()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
			close_shop()
			get_viewport().set_input_as_handled()


func _refresh(force: bool) -> void:
	var unit := _local_unit()
	var role := unit.role() if unit != null else RoleConfig.Role.RUNNER
	var crystals := GameManager.crystals_for(GameManager.local_peer_id())
	var inventory_sig := ",".join(PackedStringArray(unit.shop_inventory)) if unit != null else ""
	_title.text = "Item Shop"
	_buy_tab.button_pressed = not _showing_inventory
	_inv_tab.button_pressed = _showing_inventory
	_buy_grid.visible = not _showing_inventory
	_inv_grid.visible = _showing_inventory
	if _showing_inventory:
		_hint.text = "Click an owned upgrade to sell it back for full Crystal refund"
		if force or inventory_sig != _last_inventory_sig:
			_rebuild_inventory(unit)
			_last_inventory_sig = inventory_sig
	else:
		if role != RoleConfig.Role.HUNTER:
			_hint.text = "Hunter upgrades only — Runner catalog coming later"
		else:
			_hint.text = "Click an upgrade to buy — cost shown in green if affordable"
		if force or not is_equal_approx(crystals, _last_crystals) or inventory_sig != _last_inventory_sig:
			_rebuild_buy(role, crystals)
			_last_crystals = crystals
			_last_inventory_sig = inventory_sig


func _rebuild_buy(role: int, crystals: float) -> void:
	_clear_children(_buy_grid)
	var entries := ShopCatalog.items_for_role(role)
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "No upgrades available for your role"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_buy_grid.add_child(empty)
		return
	for entry in entries:
		_buy_grid.add_child(_make_buy_card(entry, crystals))


func _rebuild_inventory(unit: Unit) -> void:
	_clear_children(_inv_grid)
	if unit == null or unit.shop_inventory.is_empty():
		var empty := Label.new()
		empty.text = "Inventory empty"
		_inv_grid.add_child(empty)
		return
	for index in unit.shop_inventory.size():
		var item_id := str(unit.shop_inventory[index])
		var entry := ShopCatalog.item_by_id(item_id)
		_inv_grid.add_child(_make_inv_card(entry, index))


func _make_buy_card(entry: Dictionary, crystals: float) -> Button:
	var cost := float(entry.get("cost", 0.0))
	var affordable := crystals >= cost
	var button := Button.new()
	button.custom_minimum_size = CARD_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.icon = StatIcons.icon(int(entry.get("stat", 0)))
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cost_color := AFFORD_COLOR if affordable else UNAFFORD_COLOR
	button.text = "%s\n%s" % [ShopCatalog.format_bonus(entry), _cost_line(cost)]
	button.add_theme_color_override("font_color", cost_color)
	button.add_theme_color_override("font_hover_color", cost_color)
	button.tooltip_text = "%s — %d Crystals" % [ShopCatalog.format_bonus(entry), int(cost)]
	button.disabled = not affordable
	var item_id := str(entry.get("id", ""))
	button.pressed.connect(func() -> void: _buy(item_id))
	return button


func _make_inv_card(entry: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = INV_CELL
	if entry.is_empty():
		button.text = "?"
		button.disabled = true
		return button
	button.icon = StatIcons.icon(int(entry.get("stat", 0)))
	button.expand_icon = true
	button.text = "+%d" % int(float(entry.get("cost", 0.0)))
	button.tooltip_text = "Sell %s for %d Crystals" % [
		ShopCatalog.format_bonus(entry),
		int(float(entry.get("cost", 0.0))),
	]
	button.pressed.connect(func() -> void: _sell(index))
	return button


func _cost_line(cost: float) -> String:
	return "%d Crystals" % int(cost)


func _buy(item_id: String) -> void:
	var unit := _local_unit()
	if unit == null:
		return
	unit.request_shop_buy(item_id)


func _sell(index: int) -> void:
	var unit := _local_unit()
	if unit == null:
		return
	unit.request_shop_sell(index)


func _local_unit() -> Unit:
	return SelectionQueries.unit_for_peer(get_tree(), GameManager.local_peer_id(), true)


func _clear_children(host: Node) -> void:
	for child in host.get_children():
		child.queue_free()
