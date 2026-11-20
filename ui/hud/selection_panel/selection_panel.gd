class_name SelectionPanel
extends Control
## Bottom-of-screen selection strip: circular portrait + stats for the selected entity.

const PORTRAIT_SIZE := 72.0
const PANEL_HEIGHT := 96.0
const CIRCLE_SHADER := preload("res://ui/hud/selection_panel/circle_mask.gdshader")

var _root: PanelContainer
var _portrait: TextureRect
var _ring: Panel
var _name_label: Label
var _meta_label: Label
var _stats_label: Label
var _empty_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(360.0, PANEL_HEIGHT)
	_build()
	_show_empty()


func bind_selection(selected: Node, controllable: bool) -> void:
	if selected == null or not is_instance_valid(selected):
		_show_empty()
		return
	if selected is Unit:
		_show_unit(selected as Unit, controllable)
		return
	_show_generic(selected)


func _build() -> void:
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.82)
	style.border_color = Color(1, 1, 1, 0.12)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 14
	style.content_margin_bottom = 10
	_root.add_theme_stylebox_override("panel", style)
	add_child(_root)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	_root.add_child(row)

	var portrait_wrap := Control.new()
	portrait_wrap.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait_wrap)

	_ring = Panel.new()
	_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0, 0, 0, 0)
	ring_style.border_color = SelectionCircle.COLOR_OWN
	ring_style.set_border_width_all(2)
	ring_style.set_corner_radius_all(int(PORTRAIT_SIZE))
	_ring.add_theme_stylebox_override("panel", ring_style)
	portrait_wrap.add_child(_ring)

	_portrait = TextureRect.new()
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = CIRCLE_SHADER
	_portrait.material = shader_mat
	portrait_wrap.add_child(_portrait)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)

	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_font_size_override("font_size", 18)
	text_col.add_child(_name_label)

	_meta_label = Label.new()
	_meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meta_label.add_theme_font_size_override("font_size", 14)
	_meta_label.modulate = Color(0.85, 0.88, 0.92, 0.9)
	text_col.add_child(_meta_label)

	_stats_label = Label.new()
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_label.add_theme_font_size_override("font_size", 13)
	_stats_label.modulate = Color(0.78, 0.82, 0.86, 0.95)
	text_col.add_child(_stats_label)

	_empty_label = Label.new()
	_empty_label.text = "No selection"
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty_label.add_theme_font_size_override("font_size", 16)
	_empty_label.modulate = Color(1, 1, 1, 0.55)
	text_col.add_child(_empty_label)


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
	var style := _ring.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = color
	_ring.add_theme_stylebox_override("panel", style)
