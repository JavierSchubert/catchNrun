extends Node
## Pooled one-shots for SFX plus a dedicated music player. Volumes live on the Music/SFX buses.

enum Sound {
	UI,
	ENEMY_HIT,
	COIN_DROP,
	BG_MUSIC_1,
	BG_MUSIC_2,
	BG_MUSIC_3,
}

const _POOL_SIZE := 8

var music_volume: float = 0.75
var sfx_volume: float = 0.85
var music_muted: bool = false
var sfx_muted: bool = false

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _sound_dict: Dictionary = {}


func _ready() -> void:
	_sound_dict = {
		Sound.UI: preload("res://assets/audio/sfx/UI Pop.mp3"),
		Sound.ENEMY_HIT: preload("res://assets/audio/sfx/EnemyHit.wav"),
		Sound.COIN_DROP: preload("res://assets/audio/sfx/coin_drop.mp3"),
		Sound.BG_MUSIC_1: preload("res://assets/audio/music/osrs_bh1.mp3"),
		Sound.BG_MUSIC_2: preload("res://assets/audio/music/osrs_bh2.mp3"),
		Sound.BG_MUSIC_3: preload("res://assets/audio/music/osrs_bh3.mp3"),
	}
	for _i in _POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		player.volume_db = -8.0
		add_child(player)
		_sfx_players.append(player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	_music_player.volume_db = -10.0
	add_child(_music_player)
	apply_bus_settings()


func play_ui() -> void:
	play_sound(Sound.UI)


func play_sound(type: Sound, pitch_variance: float = 0.15) -> void:
	var audio: AudioStream = _sound_dict.get(type) as AudioStream
	if audio == null:
		return
	var stream := _free_sfx_player()
	if stream == null:
		return
	stream.stream = audio
	stream.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	stream.play()


func play_music(type: Sound = Sound.BG_MUSIC_1, restart: bool = false) -> void:
	var audio: AudioStream = _sound_dict.get(type) as AudioStream
	if audio == null:
		return
	if _music_player.playing and not restart and _music_player.stream == audio:
		return
	_music_player.stream = audio
	_music_player.play()


func stop_music() -> void:
	if _music_player.playing:
		_music_player.stop()


func apply_bus_settings() -> void:
	_apply_bus("Music", music_volume, music_muted)
	_apply_bus("SFX", sfx_volume, sfx_muted)


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	apply_bus_settings()
	SettingsManager.persist_audio()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	apply_bus_settings()
	SettingsManager.persist_audio()


func set_music_muted(m: bool) -> void:
	music_muted = m
	apply_bus_settings()
	SettingsManager.persist_audio()


func set_sfx_muted(m: bool) -> void:
	sfx_muted = m
	apply_bus_settings()
	SettingsManager.persist_audio()


func _apply_bus(bus_name: String, vol_linear: float, muted: bool) -> void:
	var id := AudioServer.get_bus_index(bus_name)
	if id == -1:
		return
	AudioServer.set_bus_mute(id, muted)
	var safe_linear: float = maxf(vol_linear, 0.0001)
	AudioServer.set_bus_volume_db(id, linear_to_db(safe_linear))


func _free_sfx_player() -> AudioStreamPlayer:
	for stream in _sfx_players:
		if not stream.playing:
			return stream
	return _sfx_players[0] if not _sfx_players.is_empty() else null
