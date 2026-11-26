@tool
class_name SelectionPanel
extends Control
## Fixed-size selection strip: portrait ring, combat stats, and health bar.
## Empty selection keeps the grey panel + empty ring (no portrait / stats).

## Row-major order for the 2-column StatsGrid.
const PANEL_STATS: Array[StatBlock.Stat] = [
	StatBlock.Stat.MELEE_DAMAGE,
	StatBlock.Stat.CRITICAL_CHANCE,
	StatBlock.Stat.DEFENSE,
	StatBlock.Stat.LIFESTEAL_CHANCE,
	StatBlock.Stat.ATTACK_SPEED,
	StatBlock.Stat.MOVEMENT_SPEED,
]

const PANEL_SIZE := Vector2(520, 148)

@export var panel_style: StyleBoxFlat:
	set(value):
		panel_style = value
		_apply_styles()

@export var ring_style: StyleBoxFlat:
	set(value):
		ring_style = value
		_apply_styles()

@onready var _root: Panel = %Root
@onready var _right_col: Control = %RightCol
@onready var _portrait: TextureRect = %Portrait
@onready var _ring: Panel = %Ring
@onready var _stats_grid: GridContainer = %StatsGrid
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _regen_label: Label = %RegenLabel

var _stat_icons: Array[TextureRect] = []
var _stat_values: Array[RichTextLabel] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = PANEL_SIZE
	if _root != null:
		_root.custom_minimum_size = PANEL_SIZE
	_cache_stat_rows()
	_apply_stat_icons()
	_apply_styles()
	if Engine.is_editor_hint():
		return
	_show_empty()


func bind_selection(selected: Node, controllable: bool) -> void:
	if selected == null or not is_instance_valid(selected):
		_show_empty()
		return
	if selected is Unit:
		_show_unit(selected as Unit, controllable)
		return
	if selected is Building:
		_show_building(selected as Building)
		return
	_show_generic(selected)


func _cache_stat_rows() -> void:
	_stat_icons.clear()
	_stat_values.clear()
	if _stats_grid == null:
		return
	for child in _stats_grid.get_children():
		if child is not HBoxContainer:
			continue
		var row := child as HBoxContainer
		var icon := row.get_node_or_null("Icon") as TextureRect
		var value := row.get_node_or_null("Value") as RichTextLabel
		if icon == null or value == null:
			continue
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		value.fit_content = true
		value.scroll_active = false
		_stat_icons.append(icon)
		_stat_values.append(value)


func _apply_stat_icons() -> void:
	var count := mini(PANEL_STATS.size(), _stat_icons.size())
	for i in count:
		var stat: StatBlock.Stat = PANEL_STATS[i]
		var icon := _stat_icons[i]
		icon.texture = StatIcons.icon(stat)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.tooltip_text = StatIcons.display_name(stat)


func _apply_styles() -> void:
	if not is_node_ready():
		return
	if panel_style != null and _root != null:
		_root.add_theme_stylebox_override("panel", panel_style)
	if ring_style != null and _ring != null:
		_ring.add_theme_stylebox_override("panel", ring_style)


func _show_empty() -> void:
	_right_col.visible = false
	_portrait.texture = null
	_portrait.tooltip_text = ""
	_health_bar.value = 0.0
	_regen_label.text = ""
	_set_ring_color(Color(1, 1, 1, 0.25))


func _show_unit(unit: Unit, _controllable: bool) -> void:
	_right_col.visible = true
	_portrait.texture = unit.sprite.texture if unit.sprite else null
	_portrait.tooltip_text = ""
	## Building bind overwrites PANEL_STATS icons; restore before unit values.
	_apply_stat_icons()
	_bind_stat_values(unit.stats)
	_bind_health(unit)
	_set_ring_color(unit.selection_affinity_color(GameManager.local_peer_id()))


func _show_generic(_selected: Node) -> void:
	_right_col.visible = false
	_portrait.texture = null
	_portrait.tooltip_text = ""
	_health_bar.value = 0.0
	_regen_label.text = ""
	_set_ring_color(Color(1, 1, 1, 0.35))


func _show_building(building: Building) -> void:
	if building.def == null:
		_show_generic(building)
		return
	_right_col.visible = true
	_portrait.texture = BuildingIcons.icon_for_def(building.def)
	_portrait.tooltip_text = "%s Lv %d" % [building.def.display_name, building.level]
	_bind_building_stat_values(building)
	_bind_building_health(building)
	var own := building.is_own(GameManager.local_peer_id())
	_set_ring_color(SelectionCircle.COLOR_OWN if own else SelectionCircle.COLOR_RUNNER_TEAM)


func _bind_building_stat_values(building: Building) -> void:
	var count := mini(_stat_icons.size(), _stat_values.size())
	for i in count:
		_stat_icons[i].texture = null
		_stat_icons[i].tooltip_text = ""
		_stat_values[i].text = ""
	match building.def.kind:
		BuildingDef.Kind.TOWER:
			_set_stat_row(0, StatBlock.Stat.MELEE_DAMAGE, StatIcons.format_value(building.stats, StatBlock.Stat.RANGED_DAMAGE), "Damage")
			_set_stat_row(1, StatBlock.Stat.CRITICAL_CHANCE, StatIcons.format_value(building.stats, StatBlock.Stat.CRITICAL_CHANCE), "")
			_set_stat_row(2, StatBlock.Stat.DEFENSE, "Lv %d" % building.level, "Level")
			_set_stat_row(4, StatBlock.Stat.ATTACK_SPEED, StatIcons.format_value(building.stats, StatBlock.Stat.ATTACK_SPEED), "")
			_set_stat_row(5, StatBlock.Stat.ATTACK_RANGE, StatIcons.format_value(building.stats, StatBlock.Stat.ATTACK_RANGE), "")
		BuildingDef.Kind.WALL:
			var hp := "%.0f / %.0f" % [building.health.current, building.max_health]
			_set_stat_row(0, StatBlock.Stat.MAX_HEALTH, hp, "Health")
			_set_stat_row(2, StatBlock.Stat.DEFENSE, _wall_shield_text(building), "Shield")
			_set_stat_row(4, StatBlock.Stat.DEFENSE, "Lv %d / %d" % [building.level, building.def.max_level], "Level")
		BuildingDef.Kind.CRYSTAL_MINE:
			var hp := "%.0f / %.0f" % [building.health.current, building.max_health]
			_set_stat_row(0, StatBlock.Stat.MAX_HEALTH, hp, "Health")
			var output := building.def.mine_output_for_level(building.level)
			var rate := "%s / %ss" % [
				StatIcons.short_number(output),
				StatIcons.short_number(building.def.mine_interval),
			]
			_stat_icons[2].texture = BuildingIcons.crystal_icon()
			_stat_icons[2].tooltip_text = "Crystal output"
			_stat_values[2].text = rate
			_set_stat_row(4, StatBlock.Stat.DEFENSE, "Lv %d / %d" % [building.level, building.def.max_level], "Level")


func _set_stat_row(index: int, stat: StatBlock.Stat, text: String, tooltip_override: String) -> void:
	if index < 0 or index >= _stat_icons.size() or index >= _stat_values.size():
		return
	_stat_icons[index].texture = StatIcons.icon(stat)
	_stat_icons[index].tooltip_text = tooltip_override if not tooltip_override.is_empty() else StatIcons.display_name(stat)
	_stat_values[index].text = text


func _wall_shield_text(building: Building) -> String:
	if building.max_shield > 0.0:
		return "%.0f / %.0f" % [building.shield.current, building.max_shield]
	return "Lv %d+" % building.def.shield_unlock_level


func _bind_building_health(building: Building) -> void:
	var maximum := building.max_health
	var current := building.health.current if building.health else 0.0
	var ratio := clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	_health_bar.value = ratio
	_regen_label.text = "Lv %d" % building.level


func _bind_stat_values(sheet: StatSheet) -> void:
	var count := mini(PANEL_STATS.size(), _stat_values.size())
	for i in count:
		_stat_values[i].text = StatIcons.format_value(sheet, PANEL_STATS[i])


func _bind_health(unit: Unit) -> void:
	var maximum := unit.stats.final_value(StatBlock.Stat.MAX_HEALTH)
	var current := unit.health.current if unit.health else 0.0
	var ratio := clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	_health_bar.value = ratio
	var not_full := maximum > 0.0 and current < maximum - 0.001
	var regen := unit.stats.final_value(StatBlock.Stat.HEALTH_REGENERATION)
	if not_full and regen > 0.0:
		if is_equal_approx(regen, roundf(regen)):
			_regen_label.text = "+%d" % int(roundf(regen))
		else:
			_regen_label.text = "+%.1f" % regen
	else:
		_regen_label.text = ""


func _set_ring_color(color: Color) -> void:
	var base := ring_style if ring_style != null else _ring.get_theme_stylebox("panel")
	if base == null:
		return
	var style := base.duplicate() as StyleBoxFlat
	style.border_color = color
	_ring.add_theme_stylebox_override("panel", style)
