extends Control
class_name AudioController

@onready var audio_control: HSlider = %audio_control
@onready var icon: AnimatedButton = %mute_button

@export var icon_unmuted: Texture2D
@export var icon_muted: Texture2D
@export var audio_bus_name: String = "SFX"

var _is_muted := false
var _prev_volume := 0.5
var _ignore_slider := false


func _ready() -> void:
	if AudioServer.get_bus_index(audio_bus_name) == -1:
		push_error("AudioController: bus not found: %s" % audio_bus_name)
		return
	audio_control.value_changed.connect(_on_value_changed)
	icon.activated.connect(_on_mute_pressed)
	icon.play_click_sound = true
	_prev_volume = _get_saved_volume()
	_is_muted = _get_saved_muted()
	_ignore_slider = true
	audio_control.value = 0.0 if _is_muted else _prev_volume
	_ignore_slider = false
	_update_mute_visual()


func _on_mute_pressed(_sender: AnimatedButton) -> void:
	_is_muted = not _is_muted
	_set_saved_muted(_is_muted)
	if _is_muted:
		_prev_volume = maxf(_get_saved_volume(), 0.1)
		_ignore_slider = true
		audio_control.value = 0.0
		_ignore_slider = false
	else:
		var restore := _prev_volume if _prev_volume > 0.0 else 0.5
		_ignore_slider = true
		audio_control.value = restore
		_ignore_slider = false
		_set_saved_volume(restore)
	_update_mute_visual()


func _update_mute_visual() -> void:
	icon.preview_icon = icon_muted if _is_muted else icon_unmuted
	audio_control.editable = not _is_muted


func _on_value_changed(new_value: float) -> void:
	if _ignore_slider:
		return
	if _is_muted and new_value > 0.0:
		_is_muted = false
		_set_saved_muted(false)
		_update_mute_visual()
	_set_saved_volume(new_value)
	if new_value > 0.0:
		_prev_volume = new_value


func _get_saved_volume() -> float:
	match audio_bus_name:
		"Music":
			return SoundManager.music_volume
		"SFX":
			return SoundManager.sfx_volume
		_:
			return 1.0


func _set_saved_volume(v: float) -> void:
	match audio_bus_name:
		"Music":
			SoundManager.set_music_volume(v)
		"SFX":
			SoundManager.set_sfx_volume(v)


func _get_saved_muted() -> bool:
	match audio_bus_name:
		"Music":
			return SoundManager.music_muted
		"SFX":
			return SoundManager.sfx_muted
		_:
			return false


func _set_saved_muted(m: bool) -> void:
	match audio_bus_name:
		"Music":
			SoundManager.set_music_muted(m)
		"SFX":
			SoundManager.set_sfx_muted(m)
