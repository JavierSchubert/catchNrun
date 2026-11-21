@tool
class_name SelectionPanel
extends Control
## Bottom-of-screen selection strip: circular portrait + stats for the selected entity.
## Layout and StyleBoxes live in selection_panel.tscn / *.tres; runtime binds selection data.

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
@onready var _meta_label: Label = %MetaLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _empty_label: Label = %EmptyLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _apply_styles() -> void:
	if not is_node_ready():
		return
	if panel_style != null and _root != null:
		_root.add_theme_stylebox_override("panel", panel_style)
	if ring_style != null and _ring != null:
		_ring.add_theme_stylebox_override("panel", ring_style)


func _show_empty() -> void:
	_portrait.texture = null
	_name_label.visible = false
	_meta_label.visible = false
	_stats_label.visible = false
	_empty_label.visible = true
	_set_ring_color(Color(1, 1, 1, 0.25))


func _show_unit(unit: Unit, controllable: bool) -> void:
	_empty_label.visible = false
	_name_label.visible = true
	_meta_label.visible = true
	_stats_label.visible = true
	_portrait.texture = unit.sprite.texture if unit.sprite else null
	_name_label.text = unit.name_label.text if unit.name_label else str(unit.name)
	var role_name := "Hunter" if unit.role() == RoleConfig.Role.HUNTER else "Runner"
	var mode := "Controllable" if controllable else "View only"
	_meta_label.text = "%s  ·  %s" % [role_name, mode]
	var maximum := unit.stats.final_value(StatBlock.Stat.MAX_HEALTH)
	var speed := unit.stats.final_value(StatBlock.Stat.MOVEMENT_SPEED)
	var melee := unit.stats.final_value(StatBlock.Stat.MELEE_DAMAGE)
	var defense := unit.stats.final_value(StatBlock.Stat.DEFENSE)
	_stats_label.text = "HP %.0f / %.0f   Speed %.0f   Melee %.0f   Defense %.0f" % [
		unit.health.current,
		maximum,
		speed,
		melee,
		defense,
	]
	var local_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	_set_ring_color(unit.selection_affinity_color(local_id))


func _show_generic(selected: Node) -> void:
	_empty_label.visible = false
	_name_label.visible = true
	_meta_label.visible = true
	_stats_label.visible = false
	_portrait.texture = null
	_name_label.text = str(selected.name)
	_meta_label.text = "Selected entity"
	_set_ring_color(Color(1, 1, 1, 0.35))


func _set_ring_color(color: Color) -> void:
	var base := ring_style if ring_style != null else _ring.get_theme_stylebox("panel")
	if base == null:
		return
	var style := base.duplicate() as StyleBoxFlat
	style.border_color = color
	_ring.add_theme_stylebox_override("panel", style)
