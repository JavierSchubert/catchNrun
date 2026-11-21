extends Node
## Persists audio / display preferences and applies them at boot.

const SAVE_PATH := "user://settings.cfg"

var fullscreen: bool = false


func _ready() -> void:
	load_settings()
	apply_display()
	# SoundManager may not be ready yet; defer bus sync one frame.
	call_deferred("_sync_audio_from_disk")


func apply_display() -> void:
	if OS.has_feature("web"):
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func persist_audio() -> void:
	if SoundManager == null:
		return
	save_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	if SoundManager != null:
		config.set_value("audio", "music_volume", SoundManager.music_volume)
		config.set_value("audio", "sfx_volume", SoundManager.sfx_volume)
		config.set_value("audio", "music_muted", SoundManager.music_muted)
		config.set_value("audio", "sfx_muted", SoundManager.sfx_muted)
	config.set_value("video", "fullscreen", fullscreen)
	config.save(SAVE_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	fullscreen = bool(config.get_value("video", "fullscreen", fullscreen))


func _sync_audio_from_disk() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		SoundManager.apply_bus_settings()
		SoundManager.ensure_music()
		return
	var music_vol := float(config.get_value("audio", "music_volume", SoundManager.music_volume))
	var sfx_vol := float(config.get_value("audio", "sfx_volume", SoundManager.sfx_volume))
	# Guard against a broken first save that wrote 0 and silenced everything.
	SoundManager.music_volume = music_vol if music_vol > 0.001 else SoundManager.music_volume
	SoundManager.sfx_volume = sfx_vol if sfx_vol > 0.001 else SoundManager.sfx_volume
	SoundManager.music_muted = bool(config.get_value("audio", "music_muted", SoundManager.music_muted))
	SoundManager.sfx_muted = bool(config.get_value("audio", "sfx_muted", SoundManager.sfx_muted))
	SoundManager.apply_bus_settings()
	SoundManager.ensure_music()
