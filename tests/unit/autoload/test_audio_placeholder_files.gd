extends GdUnitTestSuite

## Unit tests for Task F3: Placeholder audio files and new AudioManager hooks.
## TDD: these tests are written BEFORE implementation.
##
## Group 1: All 26 audio files exist on disk (20 SFX + 6 music).
## Group 2: New signal hooks (wave_clear, error_buzz).
## Group 3: Pitch variation on enemy_death and gold_clink.
## Group 4: Double-trigger fix (enemy_leak vs life_lost).
## Group 5: README documentation file exists.


# -- Constants -----------------------------------------------------------------

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"

## All 20 expected SFX file names (10 original + 10 new).
const EXPECTED_SFX: Array[String] = [
	# Original 10
	"tower_place",
	"tower_upgrade",
	"tower_sell",
	"tower_fuse",
	"enemy_death",
	"enemy_leak",
	"life_lost",
	"wave_start",
	"gold_clink",
	"ui_click",
	# New 10
	"tower_shoot_fire",
	"tower_shoot_water",
	"tower_shoot_earth",
	"tower_shoot_wind",
	"tower_shoot_lightning",
	"tower_shoot_ice",
	"wave_clear",
	"error_buzz",
	"draft_pick",
	"synergy_activate",
]

## All 6 expected music file names.
const EXPECTED_MUSIC: Array[String] = [
	"menu",
	"build_phase",
	"combat_phase",
	"boss_combat",
	"victory",
	"defeat",
]


# -- Helpers -------------------------------------------------------------------

func _reset_audio_manager() -> void:
	AudioManager._current_track = ""
	AudioManager._last_sfx_played = ""
	AudioManager._last_music_requested = ""
	AudioManager._gold_sfx_cooldown = 0.0
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
# Group 1: File existence -- SFX
# ==============================================================================


func test_sfx_tower_place_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "tower_place.wav")).is_true()


func test_sfx_tower_upgrade_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "tower_upgrade.wav")).is_true()


func test_sfx_tower_sell_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "tower_sell.wav")).is_true()


func test_sfx_tower_fuse_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "tower_fuse.wav")).is_true()


func test_sfx_enemy_death_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "enemy_death.wav")).is_true()


func test_sfx_enemy_leak_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "enemy_leak.wav")).is_true()


func test_sfx_life_lost_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "life_lost.wav")).is_true()


func test_sfx_wave_start_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "wave_start.wav")).is_true()


func test_sfx_gold_clink_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "gold_clink.wav")).is_true()


func test_sfx_ui_click_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "ui_click.wav")).is_true()


func test_sfx_tower_shoot_fire_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "tower_shoot_fire.wav")).is_true()


func test_sfx_tower_shoot_water_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "tower_shoot_water.wav")).is_true()


func test_sfx_tower_shoot_earth_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "tower_shoot_earth.wav")).is_true()


func test_sfx_tower_shoot_wind_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "tower_shoot_wind.wav")).is_true()


func test_sfx_tower_shoot_lightning_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "tower_shoot_lightning.wav")).is_true()


func test_sfx_tower_shoot_ice_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "tower_shoot_ice.wav")).is_true()


func test_sfx_wave_clear_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "wave_clear.wav")).is_true()


func test_sfx_error_buzz_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "error_buzz.wav")).is_true()


func test_sfx_draft_pick_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "draft_pick.wav")).is_true()


func test_sfx_synergy_activate_exists() -> void:
	assert_bool(FileAccess.file_exists(SFX_DIR + "synergy_activate.wav")).is_true()


# ==============================================================================
# Group 1: File existence -- Music
# ==============================================================================


func test_music_menu_exists() -> void:
	assert_bool(FileAccess.file_exists(MUSIC_DIR + "menu.wav")).is_true()


func test_music_build_phase_exists() -> void:
	assert_bool(FileAccess.file_exists(MUSIC_DIR + "build_phase.wav")).is_true()


func test_music_combat_phase_exists() -> void:
	assert_bool(FileAccess.file_exists(MUSIC_DIR + "combat_phase.wav")).is_true()


func test_music_boss_combat_exists() -> void:
	assert_bool(FileAccess.file_exists(MUSIC_DIR + "boss_combat.wav")).is_true()


func test_music_victory_exists() -> void:
	assert_bool(FileAccess.file_exists(MUSIC_DIR + "victory.wav")).is_true()


func test_music_defeat_exists() -> void:
	assert_bool(FileAccess.file_exists(MUSIC_DIR + "defeat.wav")).is_true()


# ==============================================================================
# Group 1: Completeness check -- no missing files
# ==============================================================================


func test_all_expected_sfx_files_exist() -> void:
	for sfx_name: String in EXPECTED_SFX:
		var path: String = SFX_DIR + sfx_name + ".wav"
		assert_bool(FileAccess.file_exists(path)) \
			.override_failure_message("Missing SFX file: %s" % path) \
			.is_true()


func test_all_expected_music_files_exist() -> void:
	for track_name: String in EXPECTED_MUSIC:
		var path: String = MUSIC_DIR + track_name + ".wav"
		assert_bool(FileAccess.file_exists(path)) \
			.override_failure_message("Missing music file: %s" % path) \
			.is_true()


# ==============================================================================
# Group 2: New audio hooks -- signal connections
# ==============================================================================


func test_wave_cleared_plays_wave_clear_sfx() -> void:
	AudioManager._last_sfx_played = ""
	EnemySystem.wave_cleared.emit(1)
	assert_str(AudioManager._last_sfx_played).is_equal("wave_clear")


func test_insufficient_funds_plays_error_buzz() -> void:
	AudioManager._last_sfx_played = ""
	EconomyManager.insufficient_funds.emit(100)
	assert_str(AudioManager._last_sfx_played).is_equal("error_buzz")


# ==============================================================================
# Group 3: Pitch variation on kill and gold SFX
# ==============================================================================


func test_enemy_killed_uses_pitched_sfx() -> void:
	# After F3, enemy_killed should call play_sfx_pitched("enemy_death", ...)
	# with a random pitch in [0.85, 1.15]. We only verify the name was set
	# since the pitch is randomized per call.
	AudioManager._last_sfx_played = ""
	EnemySystem.enemy_killed.emit(null)
	assert_str(AudioManager._last_sfx_played).is_equal("enemy_death")


func test_gold_earned_uses_pitched_sfx() -> void:
	# After F3, gold_earned should call play_sfx_pitched("gold_clink", ...)
	# with a random pitch in [0.9, 1.1]. Verify by resetting cooldown first.
	AudioManager._gold_sfx_cooldown = 0.0
	AudioManager._last_sfx_played = ""
	EconomyManager.gold_earned.emit(10)
	assert_str(AudioManager._last_sfx_played).is_equal("gold_clink")


# ==============================================================================
# Group 4: Double-trigger fix -- enemy_leak vs life_lost
# ==============================================================================


func test_enemy_leak_plays_only_enemy_leak_when_lives_above_half() -> void:
	# With lives > 50% of starting_lives, enemy_reached_exit should play
	# only "enemy_leak" (NOT "life_lost"). This fixes the old double-trigger
	# where both sounds played on every leak.
	GameManager.lives = GameManager.starting_lives  # 100% = well above 50%
	AudioManager._last_sfx_played = ""
	EnemySystem.enemy_reached_exit.emit(null)
	assert_str(AudioManager._last_sfx_played).is_equal("enemy_leak")


func test_enemy_leak_plays_life_lost_when_lives_at_or_below_half() -> void:
	# With lives <= 50% of starting_lives, enemy_reached_exit should play
	# "life_lost" as the final SFX (in addition to or instead of enemy_leak).
	# starting_lives defaults to 20, so 10 is exactly 50%.
	GameManager.lives = GameManager.starting_lives / 2
	AudioManager._last_sfx_played = ""
	EnemySystem.enemy_reached_exit.emit(null)
	assert_str(AudioManager._last_sfx_played).is_equal("life_lost")


func test_enemy_leak_plays_life_lost_when_lives_below_half() -> void:
	# With lives well below 50%, "life_lost" should be the last SFX played.
	GameManager.lives = 1
	AudioManager._last_sfx_played = ""
	EnemySystem.enemy_reached_exit.emit(null)
	assert_str(AudioManager._last_sfx_played).is_equal("life_lost")


func test_enemy_leak_plays_enemy_leak_when_lives_just_above_half() -> void:
	# Lives at 51% (just above threshold) should NOT trigger life_lost.
	# starting_lives=20, so 11/20 = 55% > 50%.
	GameManager.lives = (GameManager.starting_lives / 2) + 1
	AudioManager._last_sfx_played = ""
	EnemySystem.enemy_reached_exit.emit(null)
	assert_str(AudioManager._last_sfx_played).is_equal("enemy_leak")


# ==============================================================================
# Group 5: README documentation
# ==============================================================================


func test_audio_readme_exists() -> void:
	assert_bool(FileAccess.file_exists("res://assets/audio/README.md")).is_true()
