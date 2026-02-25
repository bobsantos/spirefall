extends GdUnitTestSuite

## Unit tests for Task E2: GameManager Stats Tracking.
## Covers: run_stats initialization, enemies_killed tracking, total_gold_earned
## tracking, enemies_leaked tracking, towers_built/fusions_made fields, mode/map
## fields, _finalize_run_stats, MetaProgression XP award on game over, and
## SaveSystem.record_run on game over.


# -- Helpers -------------------------------------------------------------------

const TEST_SAVE_PATH: String = "user://test_stats_save.json"

var _original_save_path: String
var _original_gold: int
var _original_meta_xp: int
var _original_meta_unlocked: Array[String]


func _reset_game_manager() -> void:
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = 0
	GameManager.lives = GameManager.starting_lives
	GameManager._build_timer = 0.0
	GameManager._combat_timer = 0.0
	GameManager._combat_timer_max = 0.0
	GameManager._enemies_leaked_this_wave = 0
	GameManager._game_running = false
	GameManager.run_stats = {}
	GameManager._previous_gold = 0


func _reset_economy_manager() -> void:
	EconomyManager.gold = EconomyManager.STARTING_GOLD


func _reset_enemy_system() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn.clear()


func _reset_save_system() -> void:
	SaveSystem._save_path = TEST_SAVE_PATH
	SaveSystem._data = SaveSystem._default_data()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


func _reset_meta_progression() -> void:
	MetaProgression._total_xp = 0
	MetaProgression._unlocked = []


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_save_path = SaveSystem._save_path
	_original_gold = EconomyManager.gold
	_original_meta_xp = MetaProgression._total_xp
	_original_meta_unlocked = MetaProgression._unlocked.duplicate()


func before_test() -> void:
	_reset_game_manager()
	_reset_economy_manager()
	_reset_enemy_system()
	_reset_save_system()
	_reset_meta_progression()


func after_test() -> void:
	# Disconnect any lingering signal connections from GameManager
	_reset_game_manager()
	_reset_economy_manager()
	_reset_enemy_system()
	_reset_save_system()
	_reset_meta_progression()


func after() -> void:
	SaveSystem._save_path = _original_save_path
	SaveSystem.load_save()
	EconomyManager.gold = _original_gold
	MetaProgression._total_xp = _original_meta_xp
	MetaProgression._unlocked = _original_meta_unlocked


# -- 1. run_stats initialization -----------------------------------------------

func test_run_stats_has_enemies_killed_after_start() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	assert_bool(GameManager.run_stats.has("enemies_killed")).is_true()
	assert_int(GameManager.run_stats["enemies_killed"]).is_equal(0)


func test_run_stats_has_total_gold_earned_after_start() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	assert_bool(GameManager.run_stats.has("total_gold_earned")).is_true()
	assert_int(GameManager.run_stats["total_gold_earned"]).is_equal(0)


func test_run_stats_has_enemies_leaked_after_start() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	assert_bool(GameManager.run_stats.has("enemies_leaked")).is_true()
	assert_int(GameManager.run_stats["enemies_leaked"]).is_equal(0)


func test_run_stats_has_towers_built_after_start() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	assert_bool(GameManager.run_stats.has("towers_built")).is_true()
	assert_int(GameManager.run_stats["towers_built"]).is_equal(0)


func test_run_stats_has_fusions_made_after_start() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	assert_bool(GameManager.run_stats.has("fusions_made")).is_true()
	assert_int(GameManager.run_stats["fusions_made"]).is_equal(0)


func test_run_stats_has_mode_after_start() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	assert_bool(GameManager.run_stats.has("mode")).is_true()
	assert_str(GameManager.run_stats["mode"]).is_equal("classic")


func test_run_stats_mode_set_to_draft() -> void:
	GameManager.start_game("draft")
	EnemySystem._enemies_to_spawn.clear()
	assert_str(GameManager.run_stats["mode"]).is_equal("draft")


func test_run_stats_mode_set_to_endless() -> void:
	GameManager.start_game("endless")
	EnemySystem._enemies_to_spawn.clear()
	assert_str(GameManager.run_stats["mode"]).is_equal("endless")


func test_run_stats_has_map_after_start() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	assert_bool(GameManager.run_stats.has("map")).is_true()
	assert_str(GameManager.run_stats["map"]).is_equal("")


func test_run_stats_has_waves_survived_after_start() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	assert_int(GameManager.run_stats["waves_survived"]).is_equal(0)


func test_run_stats_has_victory_after_start() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	assert_bool(GameManager.run_stats["victory"]).is_false()


func test_run_stats_has_start_time_after_start() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	assert_bool(GameManager.run_stats.has("start_time")).is_true()
	assert_bool(GameManager.run_stats["start_time"] > 0).is_true()


func test_run_stats_has_elapsed_time_after_start() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	assert_int(GameManager.run_stats["elapsed_time"]).is_equal(0)


# -- 2. enemies_killed tracking ------------------------------------------------

func test_on_enemy_killed_increments_stat() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	GameManager._on_stat_enemy_killed(null)
	assert_int(GameManager.run_stats["enemies_killed"]).is_equal(1)


func test_on_enemy_killed_increments_multiple_times() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	GameManager._on_stat_enemy_killed(null)
	GameManager._on_stat_enemy_killed(null)
	GameManager._on_stat_enemy_killed(null)
	assert_int(GameManager.run_stats["enemies_killed"]).is_equal(3)


# -- 3. total_gold_earned tracking ---------------------------------------------

func test_gold_earned_tracks_add_gold() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	EconomyManager.add_gold(50)
	assert_int(GameManager.run_stats["total_gold_earned"]).is_equal(50)


func test_gold_earned_accumulates() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	EconomyManager.add_gold(30)
	EconomyManager.add_gold(20)
	assert_int(GameManager.run_stats["total_gold_earned"]).is_equal(50)


func test_gold_spent_does_not_increase_earned() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	EconomyManager.add_gold(100)
	var earned_after_add: int = GameManager.run_stats["total_gold_earned"]
	EconomyManager.spend_gold(50)
	assert_int(GameManager.run_stats["total_gold_earned"]).is_equal(earned_after_add)


# -- 4. enemies_leaked tracking ------------------------------------------------

func test_record_enemy_leak_increments_leaked_stat() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	GameManager.record_enemy_leak()
	assert_int(GameManager.run_stats["enemies_leaked"]).is_equal(1)


func test_record_enemy_leak_accumulates() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	GameManager.record_enemy_leak()
	GameManager.record_enemy_leak()
	GameManager.record_enemy_leak()
	assert_int(GameManager.run_stats["enemies_leaked"]).is_equal(3)


# -- 5. map field population ---------------------------------------------------

func test_set_map_updates_run_stats() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	GameManager.set_current_map("forest_clearing")
	assert_str(GameManager.run_stats["map"]).is_equal("forest_clearing")


# -- 6. _finalize_run_stats ----------------------------------------------------

func test_finalize_sets_waves_survived() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	GameManager.current_wave = 15
	GameManager._finalize_run_stats(false)
	assert_int(GameManager.run_stats["waves_survived"]).is_equal(15)


func test_finalize_sets_victory_true() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	GameManager._finalize_run_stats(true)
	assert_bool(GameManager.run_stats["victory"]).is_true()


func test_finalize_sets_victory_false() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	GameManager._finalize_run_stats(false)
	assert_bool(GameManager.run_stats["victory"]).is_false()


func test_finalize_sets_elapsed_time() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	# Elapsed time should be non-negative (start_time was set on start_game)
	GameManager._finalize_run_stats(false)
	assert_bool(GameManager.run_stats["elapsed_time"] >= 0).is_true()


# -- 7. MetaProgression XP on game over ---------------------------------------

func test_finalize_awards_xp_via_meta_progression() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	GameManager.current_wave = 10
	GameManager._on_stat_enemy_killed(null)
	GameManager._on_stat_enemy_killed(null)
	# Finalize should calculate and award XP
	GameManager._finalize_run_stats(false)
	# XP = 10 waves * 10 + 2 kills * 1 + 0 gold bonus + 0 victory = 102
	assert_int(MetaProgression.get_total_xp()).is_equal(102)


func test_finalize_awards_victory_bonus_xp() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	GameManager.current_wave = 30
	# Finalize with victory
	GameManager._finalize_run_stats(true)
	# XP = 30 waves * 10 + 0 kills + 0 gold + 200 victory = 500
	assert_int(MetaProgression.get_total_xp()).is_equal(500)


func test_finalize_awards_gold_bonus_xp() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	GameManager.current_wave = 5
	# Add 250 gold to trigger gold bonus: floor(250 / 100) * 5 = 10
	EconomyManager.add_gold(250)
	GameManager._finalize_run_stats(false)
	# XP = 5 * 10 + 0 kills + 10 gold bonus + 0 victory = 60
	assert_int(MetaProgression.get_total_xp()).is_equal(60)


# -- 8. SaveSystem.record_run on game over -------------------------------------

func test_finalize_calls_save_system_record_run() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	GameManager.current_wave = 10
	GameManager._finalize_run_stats(false)
	# record_run should have been called -- check run_history
	var history: Array = SaveSystem._data["progression"]["run_history"]
	assert_int(history.size()).is_equal(1)


func test_finalize_record_run_contains_expected_keys() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	GameManager.current_wave = 10
	GameManager._finalize_run_stats(false)
	var history: Array = SaveSystem._data["progression"]["run_history"]
	var record: Dictionary = history[0]
	assert_bool(record.has("waves_survived")).is_true()
	assert_bool(record.has("enemies_killed")).is_true()
	assert_bool(record.has("total_gold_earned")).is_true()
	assert_bool(record.has("victory")).is_true()
	assert_bool(record.has("mode")).is_true()


func test_finalize_record_run_updates_aggregate_stats() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	GameManager.current_wave = 10
	GameManager._on_stat_enemy_killed(null)
	GameManager._on_stat_enemy_killed(null)
	GameManager._finalize_run_stats(false)
	var stats: Dictionary = SaveSystem._data["stats"]
	assert_int(stats["total_runs"]).is_equal(1)
	assert_int(stats["total_kills"]).is_equal(2)
	assert_int(stats["total_waves"]).is_equal(10)


# -- 9. EconomyManager gold_earned signal -------------------------------------

func test_economy_manager_emits_gold_earned_on_add() -> void:
	var amounts: Array[int] = []
	var conn: Callable = func(amount: int) -> void: amounts.append(amount)
	EconomyManager.gold_earned.connect(conn)
	EconomyManager.add_gold(75)
	EconomyManager.gold_earned.disconnect(conn)
	assert_int(amounts.size()).is_equal(1)
	assert_int(amounts[0]).is_equal(75)


func test_economy_manager_no_gold_earned_on_spend() -> void:
	var amounts: Array[int] = []
	var conn: Callable = func(amount: int) -> void: amounts.append(amount)
	EconomyManager.gold_earned.connect(conn)
	EconomyManager.spend_gold(10)
	EconomyManager.gold_earned.disconnect(conn)
	assert_int(amounts.size()).is_equal(0)


# -- 10. Signal wiring: EnemySystem.enemy_killed -> stats ----------------------

func test_enemy_killed_signal_increments_stats() -> void:
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	# Emit enemy_killed signal as if an enemy was killed
	EnemySystem.enemy_killed.emit(null)
	assert_int(GameManager.run_stats["enemies_killed"]).is_equal(1)


# -- 11. Previous gold tracking resets on start_game ---------------------------

func test_previous_gold_resets_on_start_game() -> void:
	# Earn some gold, then start a new game -- gold earned should reset
	EconomyManager.add_gold(999)
	GameManager.start_game("classic")
	EnemySystem._enemies_to_spawn.clear()
	assert_int(GameManager.run_stats["total_gold_earned"]).is_equal(0)
	# New gold should be tracked from zero
	EconomyManager.add_gold(25)
	assert_int(GameManager.run_stats["total_gold_earned"]).is_equal(25)
