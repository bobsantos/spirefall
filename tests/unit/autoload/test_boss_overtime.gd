extends GdUnitTestSuite

## Tests for Boss Overtime system.
## When a boss wave's combat timer expires, overtime begins with escalating
## life drain instead of ending the wave.


# -- Stub Script ---------------------------------------------------------------

static var _enemy_stub_gd: GDScript = null

func _get_enemy_stub_script() -> GDScript:
	if _enemy_stub_gd != null:
		return _enemy_stub_gd
	_enemy_stub_gd = GDScript.new()
	_enemy_stub_gd.source_code = """
extends Node2D

var enemy_data: EnemyData
var path_points: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var speed: float = 64.0
var _base_speed: float = 64.0

func _recalculate_speed() -> void:
	if enemy_data:
		speed = _base_speed * enemy_data.speed_multiplier
"""
	_enemy_stub_gd.reload()
	return _enemy_stub_gd


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
	GameManager._boss_escaped_this_wave = false
	GameManager._previous_wave_timed_out = false
	GameManager._overtime_active = false
	GameManager._overtime_elapsed = 0.0
	GameManager._overtime_drain_accumulator = 0.0
	GameManager._boss_killed_this_wave = false
	GameManager._game_running = false


func _reset_enemy_system() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn.clear()
	EnemySystem._spawn_timer = 0.0


## Simulate a wave being fully cleared.
func _simulate_wave_cleared() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = true
	EnemySystem._enemies_to_spawn.clear()


## Put game into combat phase on a specific wave.
func _enter_combat_on_wave(wave: int) -> void:
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = wave
	GameManager._game_running = true
	# Reset overtime state (start_game sets these, but just in case)
	GameManager._overtime_active = false
	GameManager._overtime_elapsed = 0.0
	GameManager._overtime_drain_accumulator = 0.0
	GameManager._boss_killed_this_wave = false
	# Set timer based on boss status
	var wave_config: Dictionary = EnemySystem.get_wave_config(wave)
	if wave_config.get("is_boss_wave", false):
		GameManager._combat_timer = GameManager.boss_combat_phase_duration
	else:
		GameManager._combat_timer = GameManager.combat_phase_duration
	GameManager._combat_timer_max = GameManager._combat_timer


## Create a fake boss enemy stub and register it.
func _add_boss_enemy() -> Node2D:
	var enemy := Node2D.new()
	enemy.set_script(_get_enemy_stub_script())
	var data := EnemyData.new()
	data.is_boss = true
	data.enemy_name = "TestBoss"
	data.base_health = 10000
	data.speed_multiplier = 1.0
	data.gold_reward = 100
	data.escape_life_cost = 5
	enemy.enemy_data = data
	enemy.speed = 64.0
	enemy._base_speed = 64.0
	EnemySystem._active_enemies.append(enemy)
	EnemySystem._wave_finished_spawning = true
	EnemySystem._enemies_to_spawn.clear()
	return enemy


## Create a fake non-boss enemy stub and register it.
func _add_regular_enemy() -> Node2D:
	var enemy := Node2D.new()
	enemy.set_script(_get_enemy_stub_script())
	var data := EnemyData.new()
	data.is_boss = false
	data.enemy_name = "TestEnemy"
	data.base_health = 100
	data.speed_multiplier = 1.0
	data.gold_reward = 5
	enemy.enemy_data = data
	EnemySystem._active_enemies.append(enemy)
	EnemySystem._wave_finished_spawning = true
	EnemySystem._enemies_to_spawn.clear()
	return enemy


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_reset_game_manager()
	_reset_enemy_system()
	EconomyManager.reset()


func after_test() -> void:
	if get_tree().paused:
		get_tree().paused = false
	for enemy: Node in EnemySystem._active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.free()
	EnemySystem._active_enemies.clear()
	EnemySystem._enemies_to_spawn.clear()
	_reset_game_manager()


func after() -> void:
	_enemy_stub_gd = null


# ==============================================================================
# 1. Overtime activates on boss wave timer expiry
# ==============================================================================

func test_overtime_activates_on_boss_wave_timer_expiry() -> void:
	# Wave 10 is a boss wave
	_enter_combat_on_wave(10)
	var enemy: Node2D = auto_free(_add_boss_enemy())

	# Expire the combat timer
	GameManager._combat_timer = 0.1
	GameManager._process(0.2)

	# Overtime should be active instead of wave clearing
	assert_bool(GameManager._overtime_active).is_true()
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.COMBAT_PHASE)


func test_overtime_does_not_activate_on_normal_wave_timer_expiry() -> void:
	# Wave 3 is a normal wave
	_enter_combat_on_wave(3)
	var enemy: Node2D = auto_free(_add_regular_enemy())

	# Expire the combat timer
	GameManager._combat_timer = 0.1
	GameManager._process(0.2)

	# Should NOT enter overtime -- normal wave clear behavior
	assert_bool(GameManager._overtime_active).is_false()
	# Wave should have cleared (moved to next phase)
	assert_int(GameManager.game_state).is_not_equal(GameManager.GameState.COMBAT_PHASE)


func test_overtime_emits_signal_on_activation() -> void:
	_enter_combat_on_wave(10)
	var enemy: Node2D = auto_free(_add_boss_enemy())

	var signal_count: Array[int] = [0]
	var conn: Callable = func() -> void: signal_count[0] += 1
	GameManager.overtime_started.connect(conn)

	GameManager._combat_timer = 0.1
	GameManager._process(0.2)

	GameManager.overtime_started.disconnect(conn)
	assert_int(signal_count[0]).is_equal(1)


func test_overtime_signal_not_emitted_twice() -> void:
	_enter_combat_on_wave(10)
	var enemy: Node2D = auto_free(_add_boss_enemy())

	var signal_count: Array[int] = [0]
	var conn: Callable = func() -> void: signal_count[0] += 1
	GameManager.overtime_started.connect(conn)

	# Expire timer and tick twice
	GameManager._combat_timer = 0.1
	GameManager._process(0.2)
	GameManager._process(1.0)

	GameManager.overtime_started.disconnect(conn)
	assert_int(signal_count[0]).is_equal(1)


# ==============================================================================
# 2. Life drain intervals match spec
# ==============================================================================

func test_phase_1_drain_every_5_seconds() -> void:
	# Phase 1: 0-10s overtime, drain 1 life every 5s
	_enter_combat_on_wave(10)
	var enemy: Node2D = auto_free(_add_boss_enemy())

	# Enter overtime
	GameManager._combat_timer = 0.1
	GameManager._process(0.2)
	assert_bool(GameManager._overtime_active).is_true()

	var lives_at_start: int = GameManager.lives

	# Tick 4.9s -- should not drain yet
	GameManager._process(4.9)
	assert_int(GameManager.lives).is_equal(lives_at_start)

	# Tick 0.2s more (total 5.1s) -- should drain 1 life
	GameManager._process(0.2)
	assert_int(GameManager.lives).is_equal(lives_at_start - 1)


func test_phase_2_drain_every_3_seconds() -> void:
	# Phase 2: 10-30s overtime, drain 1 life every 3s
	_enter_combat_on_wave(10)
	var enemy: Node2D = auto_free(_add_boss_enemy())

	# Enter overtime
	GameManager._combat_timer = 0.1
	GameManager._process(0.2)

	# Fast-forward to 10s overtime (2 drains at 5s and 10s)
	GameManager._overtime_elapsed = 10.0
	GameManager._overtime_drain_accumulator = 0.0
	var lives_before: int = GameManager.lives

	# Tick 2.9s -- should not drain yet
	GameManager._process(2.9)
	assert_int(GameManager.lives).is_equal(lives_before)

	# Tick 0.2s more (total 3.1s in phase 2) -- should drain 1 life
	GameManager._process(0.2)
	assert_int(GameManager.lives).is_equal(lives_before - 1)


func test_phase_3_drain_every_2_seconds() -> void:
	# Phase 3: 30s+ overtime, drain 1 life every 2s
	_enter_combat_on_wave(10)
	var enemy: Node2D = auto_free(_add_boss_enemy())

	# Enter overtime
	GameManager._combat_timer = 0.1
	GameManager._process(0.2)

	# Fast-forward to 30s overtime
	GameManager._overtime_elapsed = 30.0
	GameManager._overtime_drain_accumulator = 0.0
	var lives_before: int = GameManager.lives

	# Tick 1.9s -- should not drain yet
	GameManager._process(1.9)
	assert_int(GameManager.lives).is_equal(lives_before)

	# Tick 0.2s more (total 2.1s in phase 3) -- should drain 1 life
	GameManager._process(0.2)
	assert_int(GameManager.lives).is_equal(lives_before - 1)


func test_overtime_drain_accumulates_correctly() -> void:
	# Verify multiple drains over time in phase 1 (5s interval)
	_enter_combat_on_wave(10)
	var enemy: Node2D = auto_free(_add_boss_enemy())

	# Enter overtime
	GameManager._combat_timer = 0.1
	GameManager._process(0.2)

	var lives_at_start: int = GameManager.lives

	# Use 1.0s steps to avoid floating point drift. 6s total -> 1 drain at 5s.
	GameManager._process(1.0)
	GameManager._process(1.0)
	GameManager._process(1.0)
	GameManager._process(1.0)
	GameManager._process(1.0)  # elapsed = 5.0, accum = 5.0 -> drain
	assert_int(GameManager.lives).is_equal(lives_at_start - 1)

	GameManager._process(1.0)  # elapsed = 6.0, accum = 1.0 -> no drain
	assert_int(GameManager.lives).is_equal(lives_at_start - 1)

	# Continue to 10.5s to trigger second drain
	GameManager._process(1.0)  # 7s
	GameManager._process(1.0)  # 8s
	GameManager._process(1.0)  # 9s
	GameManager._process(1.0)  # 10s, accum=5.0, interval now 3.0 -> drain (accum=2.0)
	assert_int(GameManager.lives).is_equal(lives_at_start - 2)


# ==============================================================================
# 3. Wave clears normally if boss dies during overtime
# ==============================================================================

func test_boss_killed_during_overtime_clears_wave() -> void:
	_enter_combat_on_wave(10)
	var enemy: Node2D = auto_free(_add_boss_enemy())

	# Enter overtime
	GameManager._combat_timer = 0.1
	GameManager._process(0.2)
	assert_bool(GameManager._overtime_active).is_true()

	# Simulate boss killed (remove from active enemies)
	_simulate_wave_cleared()

	# Tick so GameManager detects all enemies dead
	GameManager._process(0.016)

	# Overtime should end, wave should clear normally
	assert_bool(GameManager._overtime_active).is_false()
	assert_int(GameManager.game_state).is_not_equal(GameManager.GameState.COMBAT_PHASE)


func test_boss_killed_sets_flag_via_signal_handler() -> void:
	_enter_combat_on_wave(10)

	# Create a stub boss node
	var enemy: Node2D = auto_free(Node2D.new())
	enemy.set_script(_get_enemy_stub_script())
	var data := EnemyData.new()
	data.is_boss = true
	data.enemy_name = "TestBoss"
	data.base_health = 10000
	data.speed_multiplier = 1.0
	data.gold_reward = 100
	enemy.enemy_data = data

	# Call the boss check handler directly
	GameManager._on_enemy_killed_boss_check(enemy, data)

	assert_bool(GameManager._boss_killed_this_wave).is_true()


func test_non_boss_kill_does_not_set_flag() -> void:
	_enter_combat_on_wave(10)

	var enemy: Node2D = auto_free(Node2D.new())
	enemy.set_script(_get_enemy_stub_script())
	var data := EnemyData.new()
	data.is_boss = false
	data.enemy_name = "TestEnemy"
	data.base_health = 100
	data.speed_multiplier = 1.0
	enemy.enemy_data = data

	GameManager._on_enemy_killed_boss_check(enemy, data)

	assert_bool(GameManager._boss_killed_this_wave).is_false()


# ==============================================================================
# 4. Victory condition requires boss killed on wave 30
# ==============================================================================

func test_victory_requires_boss_killed_on_final_wave() -> void:
	_enter_combat_on_wave(30)
	GameManager._boss_killed_this_wave = true
	_simulate_wave_cleared()

	var emitted_victory: Array[bool] = []
	var conn: Callable = func(v: bool) -> void: emitted_victory.append(v)
	GameManager.game_over.connect(conn)

	GameManager._process(0.016)

	GameManager.game_over.disconnect(conn)
	assert_int(emitted_victory.size()).is_equal(1)
	assert_bool(emitted_victory[0]).is_true()


func test_no_victory_without_boss_kill_on_final_wave() -> void:
	_enter_combat_on_wave(30)
	GameManager._boss_killed_this_wave = false
	_simulate_wave_cleared()

	var emitted_victory: Array[bool] = []
	var conn: Callable = func(v: bool) -> void: emitted_victory.append(v)
	GameManager.game_over.connect(conn)

	GameManager._process(0.016)

	GameManager.game_over.disconnect(conn)
	assert_int(emitted_victory.size()).is_equal(1)
	assert_bool(emitted_victory[0]).is_false()


func test_non_boss_wave_victory_not_affected() -> void:
	# Wave 29 clear should still transition normally regardless of boss kill flag
	_enter_combat_on_wave(29)
	GameManager._boss_killed_this_wave = false
	_simulate_wave_cleared()

	GameManager._process(0.016)

	# Should be in BUILD_PHASE (wave 30), not GAME_OVER
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.BUILD_PHASE)
	assert_int(GameManager.current_wave).is_equal(30)


# ==============================================================================
# 5. Boss speed increases during overtime
# ==============================================================================

func test_boss_speed_increases_during_overtime() -> void:
	_enter_combat_on_wave(10)

	var enemy: Node2D = auto_free(_add_boss_enemy())
	var original_speed_mult: float = enemy.enemy_data.speed_multiplier

	# Expire timer to enter overtime
	GameManager._combat_timer = 0.1
	GameManager._process(0.2)

	assert_bool(GameManager._overtime_active).is_true()
	# Boss speed_multiplier should be boosted by 50%
	assert_float(enemy.enemy_data.speed_multiplier).is_equal_approx(original_speed_mult * 1.5, 0.01)


func test_get_active_bosses_returns_boss_enemies() -> void:
	var boss: Node2D = auto_free(_add_boss_enemy())
	var regular: Node2D = auto_free(_add_regular_enemy())

	var bosses: Array[Node] = EnemySystem.get_active_bosses()
	assert_int(bosses.size()).is_equal(1)


func test_get_active_bosses_empty_when_no_bosses() -> void:
	var regular: Node2D = auto_free(_add_regular_enemy())
	var bosses: Array[Node] = EnemySystem.get_active_bosses()
	assert_int(bosses.size()).is_equal(0)


# ==============================================================================
# 6. Overtime state resets between waves
# ==============================================================================

func test_overtime_resets_on_new_combat_phase() -> void:
	# Set overtime state as if previous wave used it
	GameManager._overtime_active = true
	GameManager._overtime_elapsed = 25.0
	GameManager._overtime_drain_accumulator = 2.5
	GameManager._boss_killed_this_wave = true

	# Transition to a new combat phase
	GameManager.start_game()
	GameManager._game_running = true
	GameManager._transition_to(GameManager.GameState.COMBAT_PHASE)
	EnemySystem._enemies_to_spawn.clear()

	assert_bool(GameManager._overtime_active).is_false()
	assert_float(GameManager._overtime_elapsed).is_equal(0.0)
	assert_float(GameManager._overtime_drain_accumulator).is_equal(0.0)
	assert_bool(GameManager._boss_killed_this_wave).is_false()


func test_overtime_resets_on_start_game() -> void:
	GameManager._overtime_active = true
	GameManager._overtime_elapsed = 15.0
	GameManager._boss_killed_this_wave = true

	GameManager.start_game()

	assert_bool(GameManager._overtime_active).is_false()
	assert_float(GameManager._overtime_elapsed).is_equal(0.0)
	assert_bool(GameManager._boss_killed_this_wave).is_false()


# ==============================================================================
# 7. _is_boss_wave helper
# ==============================================================================

func test_is_boss_wave_for_wave_10() -> void:
	GameManager.current_wave = 10
	assert_bool(GameManager._is_boss_wave()).is_true()


func test_is_boss_wave_for_wave_20() -> void:
	GameManager.current_wave = 20
	assert_bool(GameManager._is_boss_wave()).is_true()


func test_is_boss_wave_for_wave_30() -> void:
	GameManager.current_wave = 30
	assert_bool(GameManager._is_boss_wave()).is_true()


func test_is_not_boss_wave_for_wave_5() -> void:
	GameManager.current_wave = 5
	assert_bool(GameManager._is_boss_wave()).is_false()


func test_is_not_boss_wave_for_wave_15() -> void:
	GameManager.current_wave = 15
	assert_bool(GameManager._is_boss_wave()).is_false()


# ==============================================================================
# 8. Overtime causes game over when lives hit zero
# ==============================================================================

func test_overtime_drain_causes_game_over() -> void:
	_enter_combat_on_wave(10)
	GameManager.lives = 2  # Low lives
	var enemy: Node2D = auto_free(_add_boss_enemy())

	# Enter overtime
	GameManager._combat_timer = 0.1
	GameManager._process(0.2)

	# Tick past first drain (5s) and second drain (10s) -- should lose 2 lives -> game over
	for i in range(110):
		if GameManager.game_state == GameManager.GameState.GAME_OVER:
			break
		GameManager._process(0.1)

	assert_int(GameManager.game_state).is_equal(GameManager.GameState.GAME_OVER)
	assert_int(GameManager.lives).is_equal(0)


# ==============================================================================
# 9. Overtime elapsed tracking
# ==============================================================================

func test_overtime_elapsed_tracks_time() -> void:
	_enter_combat_on_wave(10)
	var enemy: Node2D = auto_free(_add_boss_enemy())

	# Enter overtime
	GameManager._combat_timer = 0.1
	GameManager._process(0.2)

	# Tick 5 seconds
	GameManager._process(5.0)

	# elapsed should be approximately 5.0 (plus the initial overshoot)
	assert_float(GameManager._overtime_elapsed).is_greater(4.5)
	assert_float(GameManager._overtime_elapsed).is_less(6.0)


# ==============================================================================
# 10. Boss wave 20 also triggers overtime
# ==============================================================================

func test_overtime_on_wave_20() -> void:
	_enter_combat_on_wave(20)
	var enemy: Node2D = auto_free(_add_boss_enemy())

	GameManager._combat_timer = 0.1
	GameManager._process(0.2)

	assert_bool(GameManager._overtime_active).is_true()


# ==============================================================================
# 11. Victory condition edge cases
# ==============================================================================

func test_victory_with_boss_killed_and_no_escape() -> void:
	# Both conditions met: boss killed and didn't escape
	_enter_combat_on_wave(30)
	GameManager._boss_killed_this_wave = true
	GameManager._boss_escaped_this_wave = false
	_simulate_wave_cleared()

	var emitted_victory: Array[bool] = []
	var conn: Callable = func(v: bool) -> void: emitted_victory.append(v)
	GameManager.game_over.connect(conn)
	GameManager._process(0.016)
	GameManager.game_over.disconnect(conn)

	assert_bool(emitted_victory[0]).is_true()


func test_no_victory_when_boss_escaped_even_if_killed() -> void:
	# Edge case: boss escaped but was also somehow killed (shouldn't happen,
	# but the escaped flag should override)
	_enter_combat_on_wave(30)
	GameManager._boss_killed_this_wave = true
	GameManager._boss_escaped_this_wave = true
	_simulate_wave_cleared()

	var emitted_victory: Array[bool] = []
	var conn: Callable = func(v: bool) -> void: emitted_victory.append(v)
	GameManager.game_over.connect(conn)
	GameManager._process(0.016)
	GameManager.game_over.disconnect(conn)

	assert_bool(emitted_victory[0]).is_false()
