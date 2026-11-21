@tool
extends Control
class_name AnimatedButton

signal activated(sender: AnimatedButton)


@onready var visual: Control = %visual
@onready var bg: Panel = %bg
@onready var btn: TextureButton = %btn
@onready var lbl: Label = %lbl


# -----------------------------
# Style (override-friendly)
# -----------------------------
var _style_res: AnimatedButtonStyle

@export var style: AnimatedButtonStyle:
	set(value):
		_style_res = value
		if is_node_ready() and _style_res != null:
			_apply_style()
	get:
		return _style_res

# -----------------------------
# Fallback / editor preview content
# (used only when setup() has not been called)
# -----------------------------
@export_group("Preview (Editor only)")
@export var preview_icon: Texture2D:
	set(value):
		preview_icon = value
		if is_node_ready() and btn_stats == null:
			_apply_icon()

@export var preview_text := "":
	set(value):
		preview_text = value
		if Engine.is_editor_hint() and is_node_ready() and btn_stats == null:
			_apply_label()


# If you want to allow wrapping in some contexts, put this into your style resource.
# For now it's a local toggle; default is "single line + ellipsis" to keep grid aligned.
@export var allow_wrap := true:
	set(value):
		allow_wrap = value
		if is_node_ready():
			_configure_label_wrapping()


# -----------------------------
# Runtime data
# -----------------------------
var btn_data: Dictionary
var btn_stats

var _tween: Tween
var _base_scale: Vector2
var _base_pos: Vector2
var _panel_style: StyleBoxFlat


func _ready() -> void:
	# Apply style if present (it might be overridden before or after add_child()).
	if style != null:
		_apply_style()
	
	# Always show whatever data we have at this point (preview or real).
	_configure_label_wrapping()
	_apply_icon()
	_apply_label()

	# Stop here in editor – no signals, no tweens
	if Engine.is_editor_hint():
		return

	# ----- Runtime only below -----
	btn.pressed.connect(_on_pressed)
	btn.mouse_entered.connect(_on_hover_enter)
	btn.mouse_exited.connect(_on_hover_exit)
	btn.button_down.connect(_on_down)
	btn.button_up.connect(_on_up)

	_base_scale = visual.scale
	_base_pos = visual.position


func setup(data: Dictionary) -> void:
	btn_data = data
	btn_stats = btn_data.stats
	if is_node_ready():
		_apply_icon()
		_apply_label()
	else:
		call_deferred("_apply_icon")
		call_deferred("_apply_label")


# -----------------------------
# Styling
# -----------------------------
func _apply_style() -> void:
	if style == null:
		return

	# label visibility + size
	lbl.visible = style.label_visible
	lbl.label_settings = null
	lbl.add_theme_font_size_override("font_size", style.label_font_size)

	# button / bg visibility
	btn.modulate = style.icon_normal
	bg.visible = style.change_color_bg

	# panel style override (use a per-instance StyleBoxFlat)
	if _panel_style == null:
		_panel_style = StyleBoxFlat.new()
		bg.add_theme_stylebox_override("panel", _panel_style)

	_panel_style.bg_color = style.bg_normal
	_panel_style.border_color = style.border_color
	_panel_style.set_border_width_all(style.border_width)
	_panel_style.set_corner_radius_all(style.corner_radius)


func _configure_label_wrapping() -> void:
	if allow_wrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	else:
		# Best for grids: consistent height, no random row stretching.
		lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


# -----------------------------
# Content
# -----------------------------
func _apply_label() -> void:
	if btn_stats != null:
		lbl.text = str(btn_stats.name)
	else:
		lbl.text = preview_text


func _apply_icon() -> void:
	if not is_instance_valid(btn):
		return

	var tex: Texture2D = null
	
	if btn_stats != null:
		tex = btn_stats.icon
	else:
		tex = preview_icon
	
	btn.texture_normal = tex
	btn.texture_hover = tex
	btn.texture_pressed = tex
	btn.texture_disabled = tex


# -----------------------------
# Animation helpers
# -----------------------------
func _kill_tween() -> void:
	if _tween and _tween.is_running():
		_tween.kill()


func _animate(target_scale: Vector2, target_pos: Vector2, target_bg: Color, target_icon: Color) -> void:
	if style == null:
		return

	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_ease(Tween.EASE_OUT)

	_tween.tween_property(visual, "scale", target_scale, style.anim_time)
	_tween.parallel().tween_property(visual, "position", target_pos, style.anim_time)

	if style.change_color_bg and _panel_style != null:
		_tween.parallel().tween_property(_panel_style, "bg_color", target_bg, style.anim_time)

	if style.change_color_btn:
		_tween.parallel().tween_property(btn, "modulate", target_icon, style.anim_time)


# -----------------------------
# Input handlers
# -----------------------------
func _on_hover_enter() -> void:
	if style == null:
		return
	if not btn.is_pressed():
		_animate(_base_scale * style.hover_scale, _base_pos, style.bg_hover, style.icon_hover)


func _on_hover_exit() -> void:
	if style == null:
		return
	if not btn.is_pressed():
		_animate(_base_scale, _base_pos, style.bg_normal, style.icon_normal)


func _on_down() -> void:
	if style == null:
		return
	_animate(_base_scale * style.press_scale, _base_pos + style.press_offset, style.bg_press, style.icon_press)


func _on_up() -> void:
	if style == null:
		return
	if btn.is_hovered():
		_animate(_base_scale * style.hover_scale, _base_pos, style.bg_hover, style.icon_hover)
	else:
		_animate(_base_scale, _base_pos, style.bg_normal, style.icon_normal)


func _on_pressed() -> void:
	activated.emit(self)
	btn.release_focus()
