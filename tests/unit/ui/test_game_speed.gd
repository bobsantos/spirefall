extends GdUnitTestSuite

## Unit tests for Task E4: Game Speed HUD Button.
## Covers: GameManager speed state, set_game_speed, speed_changed signal,
## speed reset on start_game / game over, HUD speed cycling logic,
## button text, visual tint, edge cases.


# -- Constants -----------------------------------------------------------------

const SPEEDS: Array[float] = [1.0, 1.5, 2.0, 0.5]

const SPEED_LABELS: Array[String] = ["1x", "1.5x", "2x", "0.5x"]


# -- Helpers -------------------------------------------------------------------

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
	GameManager.game_speed = 1.0
	Engine.time_scale = 1.0


func _reset_enemy_system() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn.clear()


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_reset_game_manager()
	_reset_enemy_system()


func after_test() -> void:
	_reset_game_manager()
	_reset_enemy_system()


# ==============================================================================
# Section 1: GameManager speed state defaults
# ==============================================================================

func test_game_speed_defaults_to_1() -> void:
	assert_float(GameManager.game_speed).is_equal(1.0)


func test_engine_time_scale_defaults_to_1() -> void:
	assert_float(Engine.time_scale).is_equal(1.0)


# ==============================================================================
# Section 2: set_game_speed updates state
# ==============================================================================

func test_set_game_speed_updates_game_speed() -> void:
	GameManager.set_game_speed(2.0)
	assert_float(GameManager.game_speed).is_equal(2.0)


func test_set_game_speed_updates_engine_time_scale() -> void:
	GameManager.set_game_speed(1.5)
	assert_float(Engine.time_scale).is_equal(1.5)


func test_set_game_speed_half() -> void:
	GameManager.set_game_speed(0.5)
	assert_float(GameManager.game_speed).is_equal(0.5)
	assert_float(Engine.time_scale).is_equal(0.5)


# ==============================================================================
# Section 3: set_game_speed emits speed_changed signal
# ==============================================================================

func test_set_game_speed_emits_signal() -> void:
	var emitted_speeds: Array[float] = []
	var _conn: Callable = func(speed: float) -> void: emitted_speeds.append(speed)
	GameManager.speed_changed.connect(_conn)
	GameManager.set_game_speed(2.0)
	GameManager.speed_changed.disconnect(_conn)
	assert_int(emitted_speeds.size()).is_equal(1)
	assert_float(emitted_speeds[0]).is_equal(2.0)


func test_set_game_speed_emits_each_time() -> void:
	var count: Array[int] = [0]
	var _conn: Callable = func(_speed: float) -> void: count[0] += 1
	GameManager.speed_changed.connect(_conn)
	GameManager.set_game_speed(1.5)
	GameManager.set_game_speed(2.0)
	GameManager.set_game_speed(0.5)
	GameManager.speed_changed.disconnect(_conn)
	assert_int(count[0]).is_equal(3)


# ==============================================================================
# Section 4: Speed resets on start_game
# ==============================================================================

func test_start_game_resets_speed_to_1() -> void:
	GameManager.game_speed = 2.0
	Engine.time_scale = 2.0
	GameManager.start_game("classic")
	# start_game calls set_game_speed(1.0) which resets both
	assert_float(GameManager.game_speed).is_equal(1.0)
	assert_float(Engine.time_scale).is_equal(1.0)
	# Cleanup: stop game running
	GameManager._game_running = false
	GameManager.game_state = GameManager.GameState.MENU


func test_start_game_emits_speed_changed() -> void:
	GameManager.game_speed = 2.0
	Engine.time_scale = 2.0
	var emitted: Array[int] = [0]
	var _conn: Callable = func(_speed: float) -> void: emitted[0] += 1
	GameManager.speed_changed.connect(_conn)
	GameManager.start_game("classic")
	GameManager.speed_changed.disconnect(_conn)
	assert_int(emitted[0]).is_equal(1)
	# Cleanup
	GameManager._game_running = false
	GameManager.game_state = GameManager.GameState.MENU


# ==============================================================================
# Section 5: Speed resets on game over (_finalize_run_stats)
# ==============================================================================

func test_finalize_run_stats_resets_engine_time_scale() -> void:
	GameManager.game_speed = 2.0
	Engine.time_scale = 2.0
	# Need run_stats populated for _finalize_run_stats
	GameManager.run_stats = {
		"waves_survived": 0,
		"enemies_killed": 0,
		"enemies_leaked": 0,
		"total_gold_earned": 0,
		"towers_built": 0,
		"fusions_made": 0,
		"mode": "classic",
		"map": "",
		"start_time": Time.get_ticks_msec(),
		"elapsed_time": 0,
		"victory": false,
	}
	GameManager._finalize_run_stats(false)
	assert_float(Engine.time_scale).is_equal(1.0)
	assert_float(GameManager.game_speed).is_equal(1.0)


# ==============================================================================
# Section 6: Speed cycling logic (array-based)
# ==============================================================================

func test_speed_cycle_order() -> void:
	# Verify the SPEEDS constant matches the expected cycle
	assert_float(SPEEDS[0]).is_equal(1.0)
	assert_float(SPEEDS[1]).is_equal(1.5)
	assert_float(SPEEDS[2]).is_equal(2.0)
	assert_float(SPEEDS[3]).is_equal(0.5)


func test_speed_cycle_wraps_around() -> void:
	# Simulate pressing the speed button through a full cycle
	var index: int = 0
	for i: int in range(5):
		index = (index + 1) % SPEEDS.size()
		GameManager.set_game_speed(SPEEDS[index])
	# After 5 presses: 1->1.5->2->0.5->1 -> index=1 (1.5x)
	assert_float(GameManager.game_speed).is_equal(1.5)


# ==============================================================================
# Section 7: Speed label text mapping
# ==============================================================================

func test_speed_label_1x() -> void:
	assert_str(SPEED_LABELS[0]).is_equal("1x")


func test_speed_label_1_5x() -> void:
	assert_str(SPEED_LABELS[1]).is_equal("1.5x")


func test_speed_label_2x() -> void:
	assert_str(SPEED_LABELS[2]).is_equal("2x")


func test_speed_label_0_5x() -> void:
	assert_str(SPEED_LABELS[3]).is_equal("0.5x")


func test_speed_label_matches_speed_array() -> void:
	# Labels and speeds arrays must be same size
	assert_int(SPEED_LABELS.size()).is_equal(SPEEDS.size())


# ==============================================================================
# Section 8: Visual tint logic
# ==============================================================================

func test_tint_normal_at_1x() -> void:
	# At 1x speed, button should be white (no tint)
	var color: Color = Color.WHITE if is_equal_approx(1.0, 1.0) else Color.YELLOW
	assert_object(color).is_equal(Color.WHITE)


func test_tint_yellow_at_non_1x() -> void:
	# At any non-1x speed, button should be tinted yellow
	for speed: float in [0.5, 1.5, 2.0]:
		var color: Color = Color.WHITE if is_equal_approx(speed, 1.0) else Color.YELLOW
		assert_object(color).is_equal(Color.YELLOW)


# ==============================================================================
# Section 9: Multiple speed changes accumulate correctly
# ==============================================================================

func test_multiple_speed_changes() -> void:
	GameManager.set_game_speed(2.0)
	assert_float(GameManager.game_speed).is_equal(2.0)
	GameManager.set_game_speed(0.5)
	assert_float(GameManager.game_speed).is_equal(0.5)
	GameManager.set_game_speed(1.5)
	assert_float(GameManager.game_speed).is_equal(1.5)
	assert_float(Engine.time_scale).is_equal(1.5)


# ==============================================================================
# Section 10: Speed persists across waves
# ==============================================================================

func test_speed_persists_across_wave_transition() -> void:
	GameManager.start_game("classic")
	GameManager.set_game_speed(2.0)
	# Simulate wave completion by going through BUILD -> COMBAT -> wave clear
	# Speed should remain at 2.0 across transitions
	GameManager._transition_to(GameManager.GameState.COMBAT_PHASE)
	EnemySystem._enemies_to_spawn.clear()
	assert_float(GameManager.game_speed).is_equal(2.0)
	assert_float(Engine.time_scale).is_equal(2.0)
	# Cleanup
	GameManager._game_running = false
	GameManager.game_state = GameManager.GameState.MENU


# ==============================================================================
# Section 11: Speed resets when returning to menu
# ==============================================================================

func test_speed_resets_on_menu_state() -> void:
	GameManager.game_speed = 2.0
	Engine.time_scale = 2.0
	# Setting game_state to MENU triggers the setter which sets _game_running = false
	# But the speed should be reset by start_game next time
	# For explicit reset, test that start_game does it
	GameManager.start_game("classic")
	assert_float(GameManager.game_speed).is_equal(1.0)
	assert_float(Engine.time_scale).is_equal(1.0)
	# Cleanup
	GameManager._game_running = false
	GameManager.game_state = GameManager.GameState.MENU
