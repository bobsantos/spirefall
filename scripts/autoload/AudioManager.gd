class_name AudioManagerClass
extends Node

## Handles music playback, spatial SFX, crossfading, and gameplay audio hooks.

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_pool_size: int = 8

## Current music track name (without extension). Used to avoid restarting same track.
var _current_track: String = ""

## Test observability: set BEFORE file-existence checks so tests can verify
## the correct SFX/music name was requested even without actual audio files.
var _last_sfx_played: String = ""
var _last_music_requested: String = ""

## Gold SFX throttle: max 1 play per 0.15s
var _gold_sfx_cooldown: float = 0.0
const GOLD_SFX_COOLDOWN_DURATION: float = 0.15

## Crossfade duration (each direction)
const CROSSFADE_DURATION: float = 0.5

## Warn once per missing SFX/music key to aid development without spamming console.
var _missing_sfx_warned: Dictionary = {}
var _missing_music_warned: Dictionary = {}


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

	for i: int in range(_sfx_pool_size):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)

	_connect_gameplay_signals()


func _process(delta: float) -> void:
	if _gold_sfx_cooldown > 0.0:
		_gold_sfx_cooldown -= delta
		if _gold_sfx_cooldown < 0.0:
			_gold_sfx_cooldown = 0.0


# ==============================================================================
# F1: Core audio methods
# ==============================================================================


func play_sfx(sfx_name: String) -> void:
	_last_sfx_played = sfx_name

	var stream: AudioStream = _load_sfx_stream(sfx_name)
	if stream == null:
		return
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = 1.0
			player.play()
			return


func play_sfx_pitched(sfx_name: String, pitch_scale: float) -> void:
	_last_sfx_played = sfx_name

	var stream: AudioStream = _load_sfx_stream(sfx_name)
	if stream == null:
		return
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = pitch_scale
			player.play()
			return


func play_music(track_name: String) -> void:
	_last_music_requested = track_name

	# Skip if same track is already playing
	if track_name == _current_track and _music_player.playing:
		return

	_current_track = track_name

	var stream: AudioStream = _load_music_stream(track_name)
	if stream == null:
		return

	if _music_player.playing:
		_crossfade_to(stream)
	else:
		_music_player.stream = stream
		_music_player.volume_db = 0.0
		_music_player.play()


func stop_music() -> void:
	_music_player.stop()
	_current_track = ""


func stop_sfx_all() -> void:
	for player: AudioStreamPlayer in _sfx_players:
		player.stop()


func set_bus_volume(bus_name: String, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return
	if linear <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear))


func is_playing_music() -> bool:
	return _music_player.playing


func get_current_track() -> String:
	return _current_track


# ==============================================================================
# Private helpers
# ==============================================================================


## Try .wav then .ogg for SFX files. Warns once per missing key.
func _load_sfx_stream(sfx_name: String) -> AudioStream:
	var wav_path: String = "res://assets/audio/sfx/%s.wav" % sfx_name
	if ResourceLoader.exists(wav_path):
		return load(wav_path)
	var ogg_path: String = "res://assets/audio/sfx/%s.ogg" % sfx_name
	if ResourceLoader.exists(ogg_path):
		return load(ogg_path)
	if not _missing_sfx_warned.has(sfx_name):
		push_warning("AudioManager: Missing SFX '%s'" % sfx_name)
		_missing_sfx_warned[sfx_name] = true
	return null


## Try .ogg then .mp3 for music files. Warns once per missing key.
func _load_music_stream(track_name: String) -> AudioStream:
	var ogg_path: String = "res://assets/audio/music/%s.ogg" % track_name
	if ResourceLoader.exists(ogg_path):
		return load(ogg_path)
	var mp3_path: String = "res://assets/audio/music/%s.mp3" % track_name
	if ResourceLoader.exists(mp3_path):
		return load(mp3_path)
	if not _missing_music_warned.has(track_name):
		push_warning("AudioManager: Missing music '%s'" % track_name)
		_missing_music_warned[track_name] = true
	return null


## Crossfade: fade out current music (0.5s), then fade in new stream (0.5s).
func _crossfade_to(new_stream: AudioStream) -> void:
	var tween: Tween = create_tween()
	# Fade out
	tween.tween_property(_music_player, "volume_db", -80.0, CROSSFADE_DURATION)
	# Switch stream and fade in
	tween.tween_callback(_switch_music_stream.bind(new_stream))
	tween.tween_property(_music_player, "volume_db", 0.0, CROSSFADE_DURATION)


func _switch_music_stream(new_stream: AudioStream) -> void:
	_music_player.stream = new_stream
	_music_player.volume_db = -80.0
	_music_player.play()


# ==============================================================================
# F2: Gameplay audio hooks (signal-driven, centralized)
# ==============================================================================


func _connect_gameplay_signals() -> void:
	# Tower SFX
	TowerSystem.tower_created.connect(_on_tower_created)
	TowerSystem.tower_upgraded.connect(_on_tower_upgraded)
	TowerSystem.tower_sold.connect(_on_tower_sold)
	TowerSystem.tower_fused.connect(_on_tower_fused)

	# Enemy SFX
	EnemySystem.enemy_killed.connect(_on_enemy_killed)
	EnemySystem.enemy_reached_exit.connect(_on_enemy_leak)
	EnemySystem.enemy_reached_exit.connect(_on_life_lost)

	# Wave SFX
	GameManager.wave_started.connect(_on_wave_started)

	# Gold SFX (throttled)
	EconomyManager.gold_earned.connect(_on_gold_earned)

	# Music hooks
	GameManager.phase_changed.connect(_on_phase_changed)


func _on_tower_created(_tower: Node) -> void:
	play_sfx("tower_place")


func _on_tower_upgraded(_tower: Node) -> void:
	play_sfx("tower_upgrade")


func _on_tower_sold(_tower: Node, _refund: int) -> void:
	play_sfx("tower_sell")


func _on_tower_fused(_tower: Node) -> void:
	play_sfx("tower_fuse")


func _on_enemy_killed(_enemy: Node) -> void:
	play_sfx("enemy_death")


func _on_enemy_leak(_enemy: Node) -> void:
	play_sfx("enemy_leak")


func _on_life_lost(_enemy: Node) -> void:
	play_sfx("life_lost")


func _on_wave_started(_wave_number: int) -> void:
	play_sfx("wave_start")


func _on_gold_earned(_amount: int) -> void:
	if _gold_sfx_cooldown > 0.0:
		return
	play_sfx("gold_clink")
	_gold_sfx_cooldown = GOLD_SFX_COOLDOWN_DURATION


func _on_phase_changed(new_phase: GameManager.GameState) -> void:
	match new_phase:
		GameManager.GameState.COMBAT_PHASE:
			var wave: int = GameManager.current_wave
			if wave > 0 and wave <= 30 and wave % 10 == 0:
				play_music("boss_combat")
			else:
				play_music("combat_phase")
		GameManager.GameState.BUILD_PHASE:
			play_music("build_phase")
		GameManager.GameState.GAME_OVER:
			if GameManager.current_wave >= GameManager.max_waves:
				play_music("victory")
			else:
				play_music("defeat")
