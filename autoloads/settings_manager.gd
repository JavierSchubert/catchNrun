extends Node
class_name SettingsManager

# Stored settings
var volume: float = 1.0
var fullscreen: bool = false
var zoom: float = 1.0

# Path for saving (works fine in HTML5)
const SAVE_PATH := "user://settings.cfg"

func _ready() -> void:
	load_settings()
	apply_settings()

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(volume)
	)
	# Apply fullscreen only on desktop
	if not OS.has_feature("web"):
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "volume", volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("gameplay", "zoom", zoom)
	config.save(SAVE_PATH)

func load_settings() -> void:
	var config := ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err != OK:
		return  # First run, nothing to load
	volume = config.get_value("audio", "volume", volume)
	fullscreen = config.get_value("video", "fullscreen", fullscreen)
	zoom = config.get_value("gameplay", "zoom", zoom)
