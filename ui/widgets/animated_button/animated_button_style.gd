extends Resource
class_name AnimatedButtonStyle
""" Class for the config of settings_menu_button_style.tres """


@export_group("color change")
@export var change_color_bg := true
@export var change_color_btn := true

@export_group("animation settings")
@export var hover_scale := 1.06
@export var press_scale := 0.98
@export var press_offset := Vector2(0, 2)
@export var anim_time := 0.08

@export_group("icon color")
@export var icon_normal := Color.WHITE
@export var icon_hover  := Color("#c5c5c5")
@export var icon_press  := Color("#acacac")
@export var icon_disabled := Color("#777777")

@export_group("background color")
@export var bg_normal := Color("#424242")
@export var bg_hover  := Color("#4d4d4d")
@export var bg_press  := Color("#383838")

@export_group("button settings")
@export var border_color := Color("#1f1f1f")
@export var border_width := 2
@export var corner_radius := 4

@export_group("label settings")
@export var label_font_size := 16
@export var label_visible := true
