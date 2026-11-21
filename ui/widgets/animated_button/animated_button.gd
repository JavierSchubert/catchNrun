@tool
extends Control
class_name AnimatedButton

signal activated(sender: AnimatedButton)

@onready var visual: Control = %visual
@onready var bg: Panel = %bg
@onready var btn: TextureButton = %btn
@onready var lbl: Label = %lbl

var _style_res: AnimatedButtonStyle

@export var style: AnimatedButtonStyle:
	set(value):
		_style_res = value
		if is_node_ready() and _style_res != null:
			_apply_style()
	get:
		return _style_res

@export_group("Preview (Editor only)")
@export var preview_icon: Texture2D:
	set(value):
		preview_icon = value
		if is_node_ready():
			_apply_icon()

@export var preview_text := "":
	set(value):
		preview_text = value
		if is_node_ready():
			_apply_label()

@export var play_click_sound := true

var _tween: Tween
var _base_scale: Vector2
var _base_pos: Vector2
var _panel_style: StyleBoxFlat


func _ready() -> void:
	if style != null:
		_apply_style()
	_apply_icon()
	_apply_label()
	if Engine.is_editor_hint():
		return
	btn.pressed.connect(_on_pressed)
	btn.mouse_entered.connect(_on_hover_enter)
	btn.mouse_exited.connect(_on_hover_exit)
	btn.button_down.connect(_on_down)
	btn.button_up.connect(_on_up)
	_base_scale = visual.scale
	_base_pos = visual.position


func _apply_style() -> void:
	if style == null:
		return
	lbl.visible = style.label_visible
	lbl.add_theme_font_size_override("font_size", style.label_font_size)
	btn.modulate = style.icon_normal
	bg.visible = style.change_color_bg
	if _panel_style == null:
		_panel_style = StyleBoxFlat.new()
		bg.add_theme_stylebox_override("panel", _panel_style)
	_panel_style.bg_color = style.bg_normal
	_panel_style.border_color = style.border_color
	_panel_style.set_border_width_all(style.border_width)
	_panel_style.set_corner_radius_all(style.corner_radius)


func _apply_label() -> void:
	lbl.text = preview_text


func _apply_icon() -> void:
	if not is_instance_valid(btn):
		return
	var tex := preview_icon
	btn.texture_normal = tex
	btn.texture_hover = tex
	btn.texture_pressed = tex
	btn.texture_disabled = tex


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


func _on_hover_enter() -> void:
	if style == null or btn.is_pressed():
		return
	_animate(_base_scale * style.hover_scale, _base_pos, style.bg_hover, style.icon_hover)


func _on_hover_exit() -> void:
	if style == null or btn.is_pressed():
		return
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
	if play_click_sound and not Engine.is_editor_hint():
		SoundManager.play_ui()
	activated.emit(self)
	btn.release_focus()
