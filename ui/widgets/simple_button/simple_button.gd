class_name SimpleButton
extends Button

@export var style: SimpleButtonStyle


func _ready():
	if style == null:
		return

	_apply_style()

	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_normal)
	button_down.connect(_on_press)
	button_up.connect(_on_release)


func _apply_style():
	modulate = style.icon_normal
	_set_bg(style.bg_normal)


func _on_hover():
	modulate = style.icon_hover
	_set_bg(style.bg_hover)


func _on_normal():
	modulate = style.icon_normal
	_set_bg(style.bg_normal)


func _on_press():
	modulate = style.icon_press
	_set_bg(style.bg_press)


func _on_release():
	if is_hovered():
		_on_hover()
	else:
		_on_normal()


func _set_bg(color: Color):
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = style.border_color
	sb.set_border_width_all(style.border_width)
	sb.set_corner_radius_all(style.corner_radius)

	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", sb)
	add_theme_stylebox_override("pressed", sb)
