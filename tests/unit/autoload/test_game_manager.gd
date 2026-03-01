extends GdUnitTestSuite

## Unit tests for GameManager autoload.
## Covers: state transitions, phase signals, wave flow, lose_life, build timer,
## start_wave_early bonus, wave_cleared logic, and game over conditions.


# -- Helpers -------------------------------------------------------------------

func _reset_game_manager() -> void:
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = 0
	GameManager.lives = GameManager.starting_lives
	GameManager.max_waves = 30
	GameManager.current_mode = GameManager.GameMode.CLASSIC
	GameManager._build_timer = 0.0
	GameManager._combat_timer = 0.0
	GameManager._combat_timer_max = 0.0
	GameManager._enemies_leaked_this_wave = 0


func _reset_enemy_system() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn.clear()
	EnemySystem._spawn_timer = 0.0


## Simulate a wave being fully cleared by the EnemySystem.
## Sets the internal state so that GameManager._process() sees zero active
## enemies and a finished wave, triggering _on_wave_cleared().
func _simulate_wave_cleared() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = true
	EnemySystem._enemies_to_spawn.clear()


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_reset_game_manager()
	_reset_enemy_system()
	EconomyManager.reset()


func after_test() -> void:
	# GAME_OVER now pauses the tree — always unpause after each test
	if get_tree().paused:
		get_tree().paused = false
	# Free any enemy nodes that EnemySystem._process() may have spawned
	# during tests that call start_wave_early() -> spawn_wave().
	# These nodes are NOT in the scene tree, so queue_free() would leak them.
	for enemy: Node in EnemySystem._active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.free()
	EnemySystem._active_enemies.clear()
	EnemySystem._enemies_to_spawn.clear()


# -- 1. Initial State ----------------------------------------------------------

func test_initial_state_is_menu() -> void:
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.MENU)


# -- 2. start_game() ----------------------------------------------------------

func test_start_game_transitions_to_build() -> void:
	GameManager.start_game()
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.BUILD_PHASE)
	assert_int(GameManager.current_wave).is_equal(1)
	assert_int(GameManager.lives).is_equal(20)


# -- 3. start_game emits phase_changed ----------------------------------------

func test_start_game_emits_phase_changed() -> void:
	var emitted_args: Array = []
	var conn: Callable = func(new_phase: int) -> void: emitted_args.append(new_phase)
	GameManager.phase_changed.connect(conn)
	GameManager.start_game()
	GameManager.phase_changed.disconnect(conn)
	assert_int(emitted_args.size()).is_greater_equal(1)
	assert_int(emitted_args[0]).is_equal(GameManager.GameState.BUILD_PHASE)


# -- 4. lose_life decrements --------------------------------------------------

func test_lose_life_decrements() -> void:
	GameManager.start_game()
	GameManager.lose_life(1)
	assert_int(GameManager.lives).is_equal(19)


# -- 5. lose_life triggers game over ------------------------------------------

func test_lose_all_lives_triggers_game_over() -> void:
	GameManager.start_game()
	GameManager.lose_life(20)
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.GAME_OVER)
	assert_int(GameManager.lives).is_equal(0)


# -- 6. lose_life clamps at zero ----------------------------------------------

func test_lose_life_clamps_at_zero() -> void:
	GameManager.start_game()
	GameManager.lose_life(25)
	assert_int(GameManager.lives).is_equal(0)


# -- 7. record_enemy_leak increments ------------------------------------------

func test_record_enemy_leak_increments() -> void:
	GameManager._enemies_leaked_this_wave = 0
	GameManager.record_enemy_leak()
	assert_int(GameManager._enemies_leaked_this_wave).is_equal(1)
	GameManager.record_enemy_leak()
	assert_int(GameManager._enemies_leaked_this_wave).is_equal(2)


# -- 8. start_wave_early transitions from BUILD to COMBAT --------------------

func test_start_wave_early_from_build_phase() -> void:
	GameManager.start_game()
	# Now in BUILD_PHASE, wave 1
	GameManager.start_wave_early()
	# Clear spawn queue to prevent EnemySystem._process() from spawning real nodes
	EnemySystem._enemies_to_spawn.clear()
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.COMBAT_PHASE)


# -- 9. start_wave_early bonus gold -------------------------------------------

func test_start_wave_early_bonus_gold() -> void:
	GameManager.start_game()
	# _build_timer is set to build_phase_duration (30.0) after start_game
	# Manually set a known timer value for predictable bonus
	GameManager._build_timer = 15.0
	var gold_before: int = EconomyManager.gold
	GameManager.start_wave_early()
	# Clear spawn queue to prevent EnemySystem._process() from spawning real nodes
	EnemySystem._enemies_to_spawn.clear()
	# Bonus = int(15.0) * 10 = 150
	assert_int(EconomyManager.gold).is_equal(gold_before + 150)


# -- 10. start_wave_early emits early_wave_bonus signal -----------------------

func test_start_wave_early_emits_bonus_signal() -> void:
	GameManager.start_game()
	GameManager._build_timer = 10.0
	var emitted_args: Array = []
	var conn: Callable = func(amount: int) -> void: emitted_args.append(amount)
	GameManager.early_wave_bonus.connect(conn)
	GameManager.start_wave_early()
	# Clear spawn queue to prevent EnemySystem._process() from spawning real nodes
	EnemySystem._enemies_to_spawn.clear()
	GameManager.early_wave_bonus.disconnect(conn)
	# Bonus = int(10.0) * 10 = 100
	assert_int(emitted_args.size()).is_greater_equal(1)
	assert_int(emitted_args[0]).is_equal(100)


# -- 11. start_wave_early ignored in COMBAT -----------------------------------

func test_start_wave_early_ignored_in_combat() -> void:
	GameManager.start_game()
	GameManager.start_wave_early()
	# Clear spawn queue to prevent EnemySystem._process() from spawning real nodes
	EnemySystem._enemies_to_spawn.clear()
	# Now in COMBAT_PHASE
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.COMBAT_PHASE)
	var wave_before: int = GameManager.current_wave
	var gold_before: int = EconomyManager.gold
	GameManager.start_wave_early()
	# State and gold should be unchanged
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.COMBAT_PHASE)
	assert_int(GameManager.current_wave).is_equal(wave_before)
	assert_int(EconomyManager.gold).is_equal(gold_before)


# -- 12. wave_cleared advances to BUILD and increments wave -------------------

func test_wave_cleared_advances_to_build() -> void:
	GameManager.start_game()
	# wave == 1, in BUILD_PHASE -> go to COMBAT
	GameManager.start_wave_early()
	# Clear spawn queue to prevent EnemySystem._process() from spawning real nodes
	EnemySystem._enemies_to_spawn.clear()
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.COMBAT_PHASE)
	# Simulate all enemies cleared
	_simulate_wave_cleared()
	# Tick _process so GameManager detects the clear
	GameManager._process(0.016)
	# wave_cleared should transition to BUILD_PHASE, wave == 2
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.BUILD_PHASE)
	assert_int(GameManager.current_wave).is_equal(2)


# -- 13. wave_cleared triggers INCOME_PHASE every 5 waves ---------------------

func test_wave_cleared_income_phase_every_5() -> void:
	GameManager.start_game()
	# Advance to wave 5 by setting current_wave directly to 5 (as if we
	# are already on wave 5 in COMBAT_PHASE)
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 5
	var gold_before: int = EconomyManager.gold
	_simulate_wave_cleared()
	GameManager._process(0.016)
	# After income phase + auto-transition to BUILD, wave should be 6.
	# INCOME_PHASE calls apply_interest() then immediately transitions to BUILD,
	# which increments current_wave.
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.BUILD_PHASE)
	assert_int(GameManager.current_wave).is_equal(6)
	# Interest should have been applied (100 gold -> 5% -> +5)
	# Plus the wave bonus for wave 5 (also added before income transition)
	assert_int(EconomyManager.gold).is_greater(gold_before)


# -- 14. wave_cleared at max_waves triggers GAME_OVER -------------------------

func test_wave_cleared_at_max_waves_game_over() -> void:
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = GameManager.max_waves  # 30
	_simulate_wave_cleared()
	GameManager._process(0.016)
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.GAME_OVER)


# -- 15. game_over victory=true at max waves ----------------------------------

func test_game_over_victory_true_at_max() -> void:
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = GameManager.max_waves
	var emitted_args: Array = []
	var conn: Callable = func(victory: bool) -> void: emitted_args.append(victory)
	GameManager.game_over.connect(conn)
	_simulate_wave_cleared()
	GameManager._process(0.016)
	GameManager.game_over.disconnect(conn)
	assert_int(emitted_args.size()).is_greater_equal(1)
	assert_bool(emitted_args[0]).is_true()


# -- 16. game_over victory=false on death -------------------------------------

func test_game_over_victory_false_on_death() -> void:
	GameManager.start_game()
	var emitted_args: Array = []
	var conn: Callable = func(victory: bool) -> void: emitted_args.append(victory)
	GameManager.game_over.connect(conn)
	GameManager.lose_life(20)
	GameManager.game_over.disconnect(conn)
	assert_int(emitted_args.size()).is_greater_equal(1)
	assert_bool(emitted_args[0]).is_false()


# -- 17. build timer set on BUILD_PHASE entry ---------------------------------

func test_build_timer_set_on_build_phase() -> void:
	GameManager.start_game()
	assert_float(GameManager._build_timer).is_equal(GameManager.build_phase_duration)


# -- 18. wave 1 build timer does not auto-decrement ---------------------------

func test_wave_1_no_auto_start() -> void:
	GameManager.start_game()
	assert_int(GameManager.current_wave).is_equal(1)
	var timer_before: float = GameManager._build_timer
	# Tick several frames -- timer should NOT decrease for wave 1
	for i in range(10):
		GameManager._process(0.1)
	assert_float(GameManager._build_timer).is_equal(timer_before)
	# State should still be BUILD_PHASE
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.BUILD_PHASE)


# -- 19. COMBAT_PHASE emits wave_started with correct wave number -------------

func test_combat_phase_emits_wave_started() -> void:
	GameManager.start_game()
	# wave == 1 after start_game
	var emitted_args: Array = []
	var conn: Callable = func(wave_number: int) -> void: emitted_args.append(wave_number)
	GameManager.wave_started.connect(conn)
	GameManager.start_wave_early()
	# Clear spawn queue to prevent EnemySystem._process() from spawning real nodes
	EnemySystem._enemies_to_spawn.clear()
	GameManager.wave_started.disconnect(conn)
	assert_int(emitted_args.size()).is_greater_equal(1)
	assert_int(emitted_args[0]).is_equal(1)


# -- 23. Endless mode never game over on wave clear ----------------------------

func test_endless_mode_never_game_over_on_wave_clear() -> void:
	GameManager.start_game("endless")
	assert_int(GameManager.current_mode).is_equal(GameManager.GameMode.ENDLESS)
	# Simulate clearing wave 999 (max_waves is 999 in endless)
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 999
	_simulate_wave_cleared()
	GameManager._process(0.016)
	# Should NOT transition to GAME_OVER -- endless mode keeps going
	assert_int(GameManager.game_state).is_not_equal(GameManager.GameState.GAME_OVER)
	# Should be in BUILD_PHASE (wave 1000)
	assert_int(GameManager.current_wave).is_equal(1000)


# -- 24. Endless mode game over on zero lives ----------------------------------

func test_endless_mode_game_over_on_zero_lives() -> void:
	GameManager.start_game("endless")
	GameManager.lose_life(20)
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.GAME_OVER)
	assert_int(GameManager.lives).is_equal(0)


# -- 25. Endless mode tracks waves survived ------------------------------------

func test_endless_mode_tracks_waves_survived() -> void:
	GameManager.start_game("endless")
	# Simulate playing to wave 42
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 42
	# Now lose all lives to trigger game over and finalize stats
	GameManager.lose_life(20)
	assert_int(GameManager.run_stats["waves_survived"]).is_equal(42)


# -- 20. GAME_OVER pauses the tree so gameplay stops --------------------------

func test_game_over_pauses_tree() -> void:
	get_tree().paused = false
	GameManager.start_game()
	GameManager.lose_life(20)
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.GAME_OVER)
	assert_bool(get_tree().paused).is_true()


# -- 21. GAME_OVER emits paused_changed(true) ---------------------------------

func test_game_over_emits_paused_changed_true() -> void:
	get_tree().paused = false
	GameManager.start_game()
	var emitted: Array[bool] = []
	var conn: Callable = func(v: bool) -> void: emitted.append(v)
	GameManager.paused_changed.connect(conn)
	GameManager.lose_life(20)
	GameManager.paused_changed.disconnect(conn)
	assert_int(emitted.size()).is_greater_equal(1)
	assert_bool(emitted[0]).is_true()


# -- 22. wave_completed signal emitted on wave clear --------------------------

func test_wave_completed_signal_emitted() -> void:
	GameManager.start_game()
	GameManager.start_wave_early()
	# Clear spawn queue to prevent EnemySystem._process() from spawning real nodes
	EnemySystem._enemies_to_spawn.clear()
	# Now in COMBAT_PHASE, wave == 1
	var emitted_args: Array = []
	var conn: Callable = func(wave_number: int) -> void: emitted_args.append(wave_number)
	GameManager.wave_completed.connect(conn)
	_simulate_wave_cleared()
	GameManager._process(0.016)
	GameManager.wave_completed.disconnect(conn)
	assert_int(emitted_args.size()).is_greater_equal(1)
	assert_int(emitted_args[0]).is_equal(1)
