@tool
class_name SelectionPanel
extends Control
## Fixed-size selection strip: portrait, name/role, combat stats, and health bar.
## Layout lives in selection_panel.tscn; runtime only binds selection data.

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

@onready var _root: PanelContainer = %Root
@onready var _portrait: TextureRect = %Portrait
@onready var _ring: Panel = %Ring
@onready var _name_label: Label = %NameLabel
@onready var _role_label: Label = %RoleLabel
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
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
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
	_portrait.texture = null
	_name_label.text = "No selection"
	_role_label.text = ""
	_clear_stat_values()
	_health_bar.value = 0.0
	_regen_label.text = ""
	_set_ring_color(Color(1, 1, 1, 0.25))


func _show_unit(unit: Unit, controllable: bool) -> void:
	_portrait.texture = unit.sprite.texture if unit.sprite else null
	_name_label.text = unit.name_label.text if unit.name_label else str(unit.name)
	var role_name := "Hunter" if unit.role() == RoleConfig.Role.HUNTER else "Runner"
	var mode := "Controllable" if controllable else "View only"
	_role_label.text = "%s · %s" % [role_name, mode]
	_bind_stat_values(unit.stats)
	_bind_health(unit)
	var local_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	_set_ring_color(unit.selection_affinity_color(local_id))


func _show_generic(selected: Node) -> void:
	_portrait.texture = null
	_name_label.text = str(selected.name)
	_role_label.text = "Entity"
	_clear_stat_values()
	_health_bar.value = 0.0
	_regen_label.text = ""
	_set_ring_color(Color(1, 1, 1, 0.35))


func _bind_stat_values(sheet: StatSheet) -> void:
	var count := mini(PANEL_STATS.size(), _stat_values.size())
	for i in count:
		_stat_values[i].text = StatIcons.format_value(sheet, PANEL_STATS[i])


func _clear_stat_values() -> void:
	for value in _stat_values:
		value.text = "—"


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
