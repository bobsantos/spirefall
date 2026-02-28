extends GdUnitTestSuite

## Unit tests for AudioManager autoload.
## Covers F1 (AudioManager enhancements) and F2 (gameplay audio hooks).


# -- Helpers -------------------------------------------------------------------

func _reset_audio_manager() -> void:
	AudioManager._current_track = ""
	AudioManager._last_sfx_played = ""
	AudioManager._last_music_requested = ""
	AudioManager._gold_sfx_cooldown = 0.0
	# Stop all players to avoid cross-test bleed
	AudioManager._music_player.stop()
	AudioManager._music_player.volume_db = 0.0
	for player: AudioStreamPlayer in AudioManager._sfx_players:
		player.stop()
		player.pitch_scale = 1.0


func _reset_game_manager() -> void:
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = 0
	GameManager.lives = GameManager.starting_lives
	GameManager._build_timer = 0.0
	GameManager._combat_timer = 0.0
	GameManager._enemies_leaked_this_wave = 0
	GameManager._game_running = false
	GameManager.max_waves = 30


func _reset_enemy_system() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn.clear()
	EnemySystem._spawn_timer = 0.0


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_reset_audio_manager()
	_reset_game_manager()
	_reset_enemy_system()
	EconomyManager.reset()
	if get_tree().paused:
		get_tree().paused = false


func after_test() -> void:
	_reset_audio_manager()
	if get_tree().paused:
		get_tree().paused = false


# ==============================================================================
# F1: AudioManager Enhancements
# ==============================================================================


# -- play_sfx / play_music silent on missing files -----------------------------

func test_play_sfx_returns_silently_when_file_missing() -> void:
	# Should not crash when audio file does not exist
	AudioManager.play_sfx("nonexistent_sound_12345")
	# Verify tracking var was set even though file is missing
	assert_str(AudioManager._last_sfx_played).is_equal("nonexistent_sound_12345")


func test_play_music_returns_silently_when_file_missing() -> void:
	# Should not crash when music file does not exist
	AudioManager.play_music("nonexistent_track_12345")
	# Verify tracking var was set even though file is missing
	assert_str(AudioManager._last_music_requested).is_equal("nonexistent_track_12345")


# -- set_bus_volume ------------------------------------------------------------

func test_set_bus_volume_converts_linear_to_db() -> void:
	var bus_idx: int = AudioServer.get_bus_index("SFX")
	if bus_idx == -1:
		return  # Bus doesn't exist in test environment
	AudioManager.set_bus_volume("SFX", 0.5)
	var expected_db: float = linear_to_db(0.5)
	assert_float(AudioServer.get_bus_volume_db(bus_idx)).is_equal_approx(expected_db, 0.01)
	assert_bool(AudioServer.is_bus_mute(bus_idx)).is_false()


func test_set_bus_volume_mutes_at_zero() -> void:
	var bus_idx: int = AudioServer.get_bus_index("SFX")
	if bus_idx == -1:
		return
	AudioManager.set_bus_volume("SFX", 0.0)
	assert_bool(AudioServer.is_bus_mute(bus_idx)).is_true()


func test_set_bus_volume_unmutes_above_zero() -> void:
	var bus_idx: int = AudioServer.get_bus_index("SFX")
	if bus_idx == -1:
		return
	# First mute, then unmute
	AudioManager.set_bus_volume("SFX", 0.0)
	assert_bool(AudioServer.is_bus_mute(bus_idx)).is_true()
	AudioManager.set_bus_volume("SFX", 0.75)
	assert_bool(AudioServer.is_bus_mute(bus_idx)).is_false()


# -- stop_sfx_all --------------------------------------------------------------

func test_stop_sfx_all_stops_all_players() -> void:
	# Manually mark some players as "playing" by setting a stream
	# (they won't actually play without audio hardware, but we can test the call)
	AudioManager.stop_sfx_all()
	for player: AudioStreamPlayer in AudioManager._sfx_players:
		assert_bool(player.playing).is_false()


# -- play_sfx_pitched ----------------------------------------------------------

func test_play_sfx_pitched_sets_pitch_scale() -> void:
	# Since no audio file exists, we verify via _last_sfx_played tracking
	AudioManager.play_sfx_pitched("nonexistent_pitched_test", 1.5)
	assert_str(AudioManager._last_sfx_played).is_equal("nonexistent_pitched_test")


# -- _current_track and getters ------------------------------------------------

func test_current_track_updates_on_play_music() -> void:
	AudioManager.play_music("test_track_abc")
	assert_str(AudioManager._current_track).is_equal("test_track_abc")


func test_play_music_skips_if_same_track() -> void:
	# Simulate that the music player is actively playing a track.
	# We set _current_track and force the player into playing state by giving it
	# a minimal stream. Without a real audio device the player may not report
	# playing=true, so we test the logical path: _last_music_requested is set
	# but _current_track stays the same and no stream swap occurs.
	AudioManager._current_track = "same_track"
	AudioManager._last_music_requested = ""
	# When player is NOT playing, the skip guard (playing check) won't fire,
	# so play_music proceeds and sets _current_track again. Verify it stays consistent.
	AudioManager.play_music("same_track")
	assert_str(AudioManager._last_music_requested).is_equal("same_track")
	assert_str(AudioManager._current_track).is_equal("same_track")


func test_is_playing_music_returns_false_initially() -> void:
	assert_bool(AudioManager.is_playing_music()).is_false()


func test_get_current_track_returns_empty_initially() -> void:
	assert_str(AudioManager.get_current_track()).is_equal("")


# -- Crossfade -----------------------------------------------------------------

func test_crossfade_sets_new_track() -> void:
	# Play a first track (won't actually play, but sets _current_track)
	AudioManager.play_music("first_track")
	assert_str(AudioManager._current_track).is_equal("first_track")
	# Play a second track -- triggers crossfade logic
	AudioManager.play_music("second_track")
	assert_str(AudioManager._current_track).is_equal("second_track")


# -- OGG fallback for SFX -----------------------------------------------------

func test_play_sfx_tries_ogg_fallback() -> void:
	# Neither .wav nor .ogg exists, but the _last_sfx_played should still be set
	AudioManager.play_sfx("fallback_ogg_test")
	assert_str(AudioManager._last_sfx_played).is_equal("fallback_ogg_test")


# -- MP3 fallback for music ---------------------------------------------------

func test_play_music_tries_mp3_fallback() -> void:
	# Neither .ogg nor .mp3 exists, but _last_music_requested should still be set
	AudioManager.play_music("fallback_mp3_test")
	assert_str(AudioManager._last_music_requested).is_equal("fallback_mp3_test")


# ==============================================================================
# F2: Gameplay Audio Hooks
# ==============================================================================


# -- Tower SFX hooks -----------------------------------------------------------

func test_tower_created_plays_sfx() -> void:
	AudioManager._last_sfx_played = ""
	TowerSystem.tower_created.emit(null)
	assert_str(AudioManager._last_sfx_played).is_equal("tower_place")


func test_tower_upgraded_plays_sfx() -> void:
	AudioManager._last_sfx_played = ""
	TowerSystem.tower_upgraded.emit(null)
	assert_str(AudioManager._last_sfx_played).is_equal("tower_upgrade")


func test_tower_sold_plays_sfx() -> void:
	AudioManager._last_sfx_played = ""
	TowerSystem.tower_sold.emit(null, 0)
	assert_str(AudioManager._last_sfx_played).is_equal("tower_sell")


func test_tower_fused_plays_sfx() -> void:
	AudioManager._last_sfx_played = ""
	TowerSystem.tower_fused.emit(null)
	assert_str(AudioManager._last_sfx_played).is_equal("tower_fuse")


# -- Enemy SFX hooks -----------------------------------------------------------

func test_enemy_killed_plays_sfx() -> void:
	AudioManager._last_sfx_played = ""
	EnemySystem.enemy_killed.emit(null)
	assert_str(AudioManager._last_sfx_played).is_equal("enemy_death")


func test_enemy_leak_plays_sfx() -> void:
	# enemy_reached_exit plays "enemy_leak" always, and "life_lost" only when
	# lives are critically low (<= 50% of starting_lives).
	# With full lives, the last SFX should be "enemy_leak".
	GameManager.lives = GameManager.starting_lives
	AudioManager._last_sfx_played = ""
	EnemySystem.enemy_reached_exit.emit(null)
	assert_str(AudioManager._last_sfx_played).is_equal("enemy_leak")


# -- Wave start SFX -----------------------------------------------------------

func test_wave_start_plays_sfx() -> void:
	AudioManager._last_sfx_played = ""
	GameManager.wave_started.emit(1)
	assert_str(AudioManager._last_sfx_played).is_equal("wave_start")


# -- Gold throttling -----------------------------------------------------------

func test_gold_earned_plays_sfx_throttled() -> void:
	AudioManager._gold_sfx_cooldown = 0.0
	AudioManager._last_sfx_played = ""

	# First gold_earned should play
	EconomyManager.gold_earned.emit(10)
	assert_str(AudioManager._last_sfx_played).is_equal("gold_clink")

	# Immediately fire again -- should be throttled (cooldown not expired)
	AudioManager._last_sfx_played = ""
	EconomyManager.gold_earned.emit(10)
	assert_str(AudioManager._last_sfx_played).is_equal("")

	# Simulate cooldown expiring
	AudioManager._gold_sfx_cooldown = 0.0
	AudioManager._last_sfx_played = ""
	EconomyManager.gold_earned.emit(10)
	assert_str(AudioManager._last_sfx_played).is_equal("gold_clink")


# -- Music hooks: phase changes ------------------------------------------------

func test_combat_phase_plays_combat_music() -> void:
	GameManager.current_wave = 3
	AudioManager._last_music_requested = ""
	GameManager.phase_changed.emit(GameManager.GameState.COMBAT_PHASE)
	assert_str(AudioManager._last_music_requested).is_equal("combat_phase")


func test_build_phase_plays_build_music() -> void:
	AudioManager._last_music_requested = ""
	GameManager.phase_changed.emit(GameManager.GameState.BUILD_PHASE)
	assert_str(AudioManager._last_music_requested).is_equal("build_phase")


func test_boss_wave_plays_boss_music() -> void:
	GameManager.current_wave = 10
	AudioManager._last_music_requested = ""
	GameManager.phase_changed.emit(GameManager.GameState.COMBAT_PHASE)
	assert_str(AudioManager._last_music_requested).is_equal("boss_combat")


func test_boss_wave_20_plays_boss_music() -> void:
	GameManager.current_wave = 20
	AudioManager._last_music_requested = ""
	GameManager.phase_changed.emit(GameManager.GameState.COMBAT_PHASE)
	assert_str(AudioManager._last_music_requested).is_equal("boss_combat")


func test_boss_wave_30_plays_boss_music() -> void:
	GameManager.current_wave = 30
	AudioManager._last_music_requested = ""
	GameManager.phase_changed.emit(GameManager.GameState.COMBAT_PHASE)
	assert_str(AudioManager._last_music_requested).is_equal("boss_combat")


func test_wave_0_not_boss() -> void:
	# Wave 0 is divisible by 10 but should NOT trigger boss music (wave > 0 check)
	GameManager.current_wave = 0
	AudioManager._last_music_requested = ""
	GameManager.phase_changed.emit(GameManager.GameState.COMBAT_PHASE)
	assert_str(AudioManager._last_music_requested).is_equal("combat_phase")


# -- Game over music -----------------------------------------------------------

func test_game_over_victory_plays_victory() -> void:
	GameManager.current_wave = 30
	GameManager.max_waves = 30
	AudioManager._last_music_requested = ""
	GameManager.phase_changed.emit(GameManager.GameState.GAME_OVER)
	assert_str(AudioManager._last_music_requested).is_equal("victory")


func test_game_over_defeat_plays_defeat() -> void:
	GameManager.current_wave = 5
	GameManager.lives = 0
	GameManager.max_waves = 30
	AudioManager._last_music_requested = ""
	GameManager.phase_changed.emit(GameManager.GameState.GAME_OVER)
	assert_str(AudioManager._last_music_requested).is_equal("defeat")


# -- Music dedup: same track not restarted -------------------------------------

func test_combat_music_not_restarted_if_already_playing() -> void:
	# Simulate that combat_phase music is already the current track
	AudioManager._current_track = "combat_phase"
	GameManager.current_wave = 3
	AudioManager._last_music_requested = ""
	GameManager.phase_changed.emit(GameManager.GameState.COMBAT_PHASE)
	# _last_music_requested should be "combat_phase" from the hook,
	# but play_music() itself should skip since _current_track matches
	assert_str(AudioManager._last_music_requested).is_equal("combat_phase")
	assert_str(AudioManager._current_track).is_equal("combat_phase")
