extends Node
class_name SoundManager

enum sound {
	ENEMY_HIT,	# 0
	FIRE,		# 1
	UI,			# 2
	PUNCH,		# 3
	BG_MUSIC,	# 4
	BG_MUSIC1,
	BG_MUSIC2,
	BG_MUSIC3,
	COIN_DROP
}

var sound_dict: Dictionary[sound, Resource] = {
	sound.ENEMY_HIT: preload("res://assets/audio/sfx/EnemyHit.wav"),
	sound.FIRE: preload("res://assets/audio/sfx/ShotgunFire.wav"),
	sound.UI: preload("res://assets/audio/sfx/UI Pop.mp3"),
	sound.PUNCH: preload("res://assets/audio/sfx/Punch.mp3"),
	sound.COIN_DROP: preload("res://assets/audio/sfx/coin_drop.mp3"),
	sound.BG_MUSIC: preload("res://assets/audio/music/Bg Music.mp3"),
	sound.BG_MUSIC1: preload("res://assets/audio/music/osrs_bh1.mp3"),
	sound.BG_MUSIC2: preload("res://assets/audio/music/osrs_bh2.mp3"),
	sound.BG_MUSIC3: preload("res://assets/audio/music/osrs_bh3.mp3"),
}

@export var stream_players: Array[AudioStreamPlayer]

var is_playing_bg_music: bool = false
var bg_music_stream: AudioStreamPlayer = null

# Persisted settings (per bus)
var music_volume: float = 0.0
var sfx_volume: float = 0.0
var music_muted: bool = false
var sfx_muted: bool = false


func _ready() -> void:
	apply_bus_settings()


# -------------------------
# Playback
# -------------------------
func play_sound(type: int) -> void:
	var stream := get_free_stream_player()
	if not stream:
		return

	var audio: Resource = sound_dict.get(type)
	if audio == null:
		return

	stream.stream = audio
	stream.bus = "SFX"
	stream.pitch_scale = randf_range(0.8, 1.3)
	stream.play()


func play_music(type: int) -> void:
	var stream := get_free_stream_player()
	if not stream or is_playing_bg_music:
		return

	var audio: Resource = sound_dict.get(type)
	if audio == null:
		return

	stream.stream = audio
	stream.bus = "Music"
	stream.play()

	is_playing_bg_music = true
	bg_music_stream = stream


func stop_music() -> void:
	if bg_music_stream and bg_music_stream.playing:
		bg_music_stream.stop()
	bg_music_stream = null
	is_playing_bg_music = false


func get_free_stream_player() -> AudioStreamPlayer:
	for stream: AudioStreamPlayer in stream_players:
		if not stream.playing:
			return stream
	return null


# -------------------------
# Bus settings application
# -------------------------
func apply_bus_settings() -> void:
	_apply_bus("Music", music_volume, music_muted)
	_apply_bus("SFX", sfx_volume, sfx_muted)


func _apply_bus(bus_name: String, vol_linear: float, muted: bool) -> void:
	var id := AudioServer.get_bus_index(bus_name)
	if id == -1:
		return

	AudioServer.set_bus_mute(id, muted)

	# Avoid -INF dB from linear_to_db(0.0)
	var safe_linear: float = max(vol_linear, 0.001)
	AudioServer.set_bus_volume_db(id, linear_to_db(safe_linear))


# -------------------------
# Public setters (use these)
# -------------------------
func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	apply_bus_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	apply_bus_settings()


func set_music_muted(m: bool) -> void:
	music_muted = m
	apply_bus_settings()


func set_sfx_muted(m: bool) -> void:
	sfx_muted = m
	apply_bus_settings()
