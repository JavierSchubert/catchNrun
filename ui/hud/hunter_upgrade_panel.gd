class_name HunterUpgradePanel
extends Control
## Presents the local Hunter's server-rolled level-up choices.

@onready var _title: Label = %Title
@onready var _hint: Label = %Hint
@onready var _choice_buttons: Array[Button] = [
	%ChoiceOne,
	%ChoiceTwo,
	%ChoiceThree,
]

var _display_signature := ""


func _ready() -> void:
	for index in _choice_buttons.size():
		_choice_buttons[index].pressed.connect(_on_choice_pressed.bind(index))
	set_process(true)


func _process(_delta: float) -> void:
	var hunter := _local_hunter()
	visible = hunter != null and hunter.pending_upgrade_choice_level > 0
	if not visible:
		_display_signature = ""
		return
	var signature := "%d:%s:%s:%s" % [
		hunter.pending_upgrade_choice_level,
		hunter.pending_upgrade_choice_stats,
		hunter.pending_upgrade_choice_rarities,
		hunter.pending_upgrade_choice_values,
	]
	if signature == _display_signature:
		return
	_display_signature = signature
	_title.text = "Hunter Upgrade — Level %d" % hunter.pending_upgrade_choice_level
	_hint.text = "Luck %.0f%% — improves rarity odds" % (
		hunter.stats.final_value(StatBlock.Stat.LUCK) * 100.0
	)
	var count := hunter.pending_upgrade_choice_stats.size()
	var complete := count == HunterUpgradeProgression.CHOICE_COUNT \
			and hunter.pending_upgrade_choice_rarities.size() == count \
			and hunter.pending_upgrade_choice_values.size() == count
	for index in _choice_buttons.size():
		var button := _choice_buttons[index]
		button.disabled = not complete
		if not complete:
			button.text = "Rolling..."
			continue
		var stat_id := hunter.pending_upgrade_choice_stats[index]
		var rarity := hunter.pending_upgrade_choice_rarities[index]
		var value := hunter.pending_upgrade_choice_values[index]
		button.text = "%s\n\n%s\n\nRange: %s" % [
			HunterUpgradeProgression.rarity_name(rarity),
			HunterUpgradeProgression.format_bonus(stat_id, value),
			HunterUpgradeProgression.format_range(stat_id, rarity),
		]
		button.tooltip_text = "Choose this %s reward" % HunterUpgradeProgression.rarity_name(rarity)
		_apply_rarity_style(button, HunterUpgradeProgression.rarity_color(rarity))


func _local_hunter() -> Unit:
	var local_id := GameManager.local_peer_id()
	if int(GameManager.players.get(local_id, {}).get("role", GameManager.ANY_ROLE)) \
			!= RoleConfig.Role.HUNTER:
		return null
	for node in get_tree().get_nodes_in_group("units"):
		if node is Unit and (node as Unit).peer_id == local_id:
			return node as Unit
	return null


func _on_choice_pressed(index: int) -> void:
	var hunter := _local_hunter()
	if hunter == null or index >= hunter.pending_upgrade_choice_stats.size():
		return
	hunter.request_hunter_upgrade(index)


func _apply_rarity_style(button: Button, color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = color.darkened(0.68)
	normal.border_color = color
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 8.0
	normal.content_margin_top = 8.0
	normal.content_margin_right = 8.0
	normal.content_margin_bottom = 8.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.darkened(0.52)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", Color(0.94, 0.95, 0.98))
