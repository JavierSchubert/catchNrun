extends Control
class_name SettingsMenu
## Right-edge settings button that toggles the audio overlay.

const SETTINGS_SCENE := "res://ui/widgets/settings_menu/settings_menu.tscn"

@onready var settings: AnimatedButton = %settings
@onready var audio_overlay: Control = %audio_overlay

var _open := false


static func attach(parent: Node) -> SettingsMenu:
	var menu := (load(SETTINGS_SCENE) as PackedScene).instantiate() as SettingsMenu
	parent.add_child(menu)
	return menu


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings.activated.connect(_on_settings_activated)
	audio_overlay.visible = false
	_open = false


func _on_settings_activated(_sender: AnimatedButton) -> void:
	_open = not _open
	audio_overlay.visible = _open
	if _open:
		call_deferred("_place_overlay")


func _place_overlay() -> void:
	if not is_instance_valid(audio_overlay) or not audio_overlay.visible:
		return
	var btn_rect := settings.get_global_rect()
	var overlay_size := audio_overlay.get_combined_minimum_size()
	if overlay_size == Vector2.ZERO:
		overlay_size = audio_overlay.size
	if btn_rect.size == Vector2.ZERO or overlay_size == Vector2.ZERO:
		call_deferred("_place_overlay")
		return
	var screen_w := get_viewport_rect().size.x
	var margin := 16.0
	var overlay_x := screen_w - margin - overlay_size.x - 72.0
	var overlay_y := btn_rect.position.y + btn_rect.size.y * 0.5 - overlay_size.y * 0.5
	audio_overlay.global_position = Vector2(overlay_x, overlay_y)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse := get_global_mouse_position()
		if audio_overlay.get_global_rect().has_point(mouse):
			return
		if settings.get_global_rect().has_point(mouse):
			return
		_open = false
		audio_overlay.visible = false
