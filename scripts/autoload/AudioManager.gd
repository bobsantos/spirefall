class_name AudioManagerClass
extends Node

## Handles music playback and spatial SFX.

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_pool_size: int = 8


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

	for i: int in range(_sfx_pool_size):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)


func play_sfx(sfx_name: String) -> void:
	var stream: AudioStream = load("res://assets/audio/sfx/%s.wav" % sfx_name) if ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % sfx_name) else null
	if stream == null:
		return
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return


func play_music(track_name: String) -> void:
	var stream: AudioStream = load("res://assets/audio/music/%s.ogg" % track_name) if ResourceLoader.exists("res://assets/audio/music/%s.ogg" % track_name) else null
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()
