extends GdUnitTestSuite

## Integration tests for game state flow.
## Verifies that GameManager, EnemySystem, and EconomyManager interact correctly
## across full game lifecycle transitions: build/combat cycles, income phases,
## game over (defeat and victory), early wave start bonuses, and restarts.
##
## All nodes are constructed manually in-memory to avoid loading scene files
## that require sprite textures (which fail in headless mode).


# -- Helpers -------------------------------------------------------------------

## Returns a minimal GDScript for enemy stubs used with EnemySystem spawning.
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
"""
	_enemy_stub_gd.reload()
	return _enemy_stub_gd


## Create a PackedScene for EnemySystem._enemy_scene swapping.
func _create_enemy_stub_scene() -> PackedScene:
	var scene := PackedScene.new()
	var node := Node2D.new()
	node.name = "StubEnemy"
	node.set_script(_get_enemy_stub_script())
	scene.pack(node)
	node.free()
	return scene


## Create a minimal EnemyData resource for testing.
func _make_enemy_data(
	p_name: String = "TestEnemy",
	p_health: int = 100,
	p_speed: float = 1.0,
	p_gold: int = 3,
	p_element: String = "none"
) -> EnemyData:
	var data := EnemyData.new()
	data.enemy_name = p_name
	data.base_health = p_health
	data.speed_multiplier = p_speed
	data.gold_reward = p_gold
	data.element = p_element
	data.spawn_count = 1
	return data


## Create a simple enemy stub node and register it in EnemySystem.
func _spawn_stub_enemy(p_name: String = "Stub", gold: int = 3) -> Node2D:
	var data: EnemyData = _make_enemy_data(p_name, 100, 1.0, gold)
	var enemy := Node2D.new()
	enemy.set_script(_get_enemy_stub_script())
	enemy.enemy_data = data
	EnemySystem._active_enemies.append(enemy)
	return enemy


## Reset GridManager to a clean all-buildable grid with spawn/exit points.
func _setup_minimal_map() -> void:
	GridManager._initialize_grid()
	GridManager._tower_map.clear()
	GridManager.spawn_points.clear()
	GridManager.exit_points.clear()
	var spawn := Vector2i(0, 0)
	var exit_pt := Vector2i(19, 0)
	GridManager.spawn_points.append(spawn)
	GridManager.exit_points.append(exit_pt)
	GridManager.grid[spawn.x][spawn.y] = GridManager.CellType.SPAWN
	GridManager.grid[exit_pt.x][exit_pt.y] = GridManager.CellType.EXIT
	PathfindingSystem.recalculate()


## Simulate a wave being fully cleared by setting EnemySystem internal state
## so GameManager._process() detects zero active enemies and finished spawning.
func _simulate_wave_cleared() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = true
	EnemySystem._enemies_to_spawn.clear()


func _reset_autoloads() -> void:
	# GameManager
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = 0
	GameManager.lives = GameManager.starting_lives
	GameManager._build_timer = 0.0
	GameManager._enemies_leaked_this_wave = 0
	# EnemySystem
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn.clear()
	EnemySystem._spawn_timer = 0.0
	# TowerSystem -- use free() since towers are not in the scene tree
	for tower: Node in TowerSystem._active_towers:
		if is_instance_valid(tower) and not tower.is_queued_for_deletion():
			tower.free()
	TowerSystem._active_towers.clear()
	# EconomyManager
	EconomyManager.reset()
	# ElementSynergy
	ElementSynergy._element_counts.clear()
	ElementSynergy._synergy_tiers.clear()
	# Grid
	_setup_minimal_map()


# Save/restore original enemy scene to avoid polluting other test suites
var _original_enemy_scene: PackedScene


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_enemy_scene = EnemySystem._enemy_scene


func before_test() -> void:
	_reset_autoloads()
	EnemySystem._enemy_scene = _create_enemy_stub_scene()


func after_test() -> void:
	for enemy: Node in EnemySystem._active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.free()
	EnemySystem._active_enemies.clear()
	EnemySystem._enemy_scene = _original_enemy_scene


func after() -> void:
	_enemy_stub_gd = null


# ==============================================================================
# TEST 1: Full wave cycle -- BUILD -> COMBAT -> wave clear -> BUILD (wave+1)
# ==============================================================================

func test_full_wave_cycle() -> void:
	# Start the game: transitions to BUILD_PHASE, wave 1
	GameManager.start_game()
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.BUILD_PHASE)
	assert_int(GameManager.current_wave).is_equal(1)

	# Player starts wave early: transitions to COMBAT_PHASE
	GameManager.start_wave_early()
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.COMBAT_PHASE)

	# start_wave_early -> spawn_wave populates _enemies_to_spawn.
	# Clear the queue so we control exactly which enemies exist for this test.
	EnemySystem._enemies_to_spawn.clear()

	# Spawn a single enemy and kill it to trigger wave clear
	var enemy: Node2D = auto_free(_spawn_stub_enemy("WaveMob", 5))
	EnemySystem._wave_finished_spawning = true

	EnemySystem.on_enemy_killed(enemy)

	# GameManager should detect wave cleared and transition to BUILD_PHASE, wave 2.
	# on_enemy_killed -> _remove_enemy -> wave_cleared is emitted synchronously, but
	# GameManager detects state via _process() polling active enemies + is_wave_finished.
	GameManager._process(0.016)
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.BUILD_PHASE)
	assert_int(GameManager.current_wave).is_equal(2)


# ==============================================================================
# TEST 2: Income phase every 5 waves -- interest applied then BUILD
# ==============================================================================

func test_income_phase_every_5_waves() -> void:
	GameManager.start_game()

	# Fast-forward to wave 5 in combat phase
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 5

	# Give the player some gold so interest is meaningful
	# Starting gold is 100 (from reset). Add more to see interest.
	EconomyManager.add_gold(400)  # Now at 500 gold
	var gold_before: int = EconomyManager.gold
	assert_int(gold_before).is_equal(500)

	# Simulate wave 5 cleared
	_simulate_wave_cleared()
	GameManager._process(0.016)

	# After wave 5: _on_wave_cleared awards wave bonus, then transitions to
	# INCOME_PHASE which calls apply_interest(), then auto-transitions to BUILD_PHASE.
	# Final state should be BUILD_PHASE with wave 6.
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.BUILD_PHASE)
	assert_int(GameManager.current_wave).is_equal(6)

	# Verify gold increased from both wave bonus and interest.
	# Wave 5 bonus (0 leaks): (10 + 5*3) * 1.25 = 31
	# Interest on (500 + 31) = 531: tiers = 5 -> 25% cap, interest = 531 * 0.25 = 132
	# Total: 500 + 31 + 132 = 663
	var wave_bonus: int = EconomyManager.calculate_wave_bonus(5, 0)
	assert_int(wave_bonus).is_equal(31)

	# The interest is applied to (gold_before + wave_bonus)
	var gold_after_bonus: int = gold_before + wave_bonus
	var interest_tiers: int = gold_after_bonus / EconomyManager.INTEREST_INTERVAL
	var interest_pct: float = minf(interest_tiers * EconomyManager.INTEREST_RATE, EconomyManager.INTEREST_CAP)
	var expected_interest: int = int(gold_after_bonus * interest_pct)
	var expected_total: int = gold_after_bonus + expected_interest

	assert_int(EconomyManager.gold).is_equal(expected_total)
	# Sanity: gold should have increased
	assert_int(EconomyManager.gold).is_greater(gold_before)


# ==============================================================================
# TEST 3: Game over on zero lives -- enemy leaks reduce lives to 0
# ==============================================================================

func test_game_over_on_zero_lives() -> void:
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 3
	assert_int(GameManager.lives).is_equal(20)

	# Simulate enemies leaking (each leak costs 1 life)
	# Use EnemySystem.on_enemy_reached_exit which calls GameManager.lose_life(1)
	# and GameManager.record_enemy_leak()
	for i: int in range(20):
		var enemy: Node2D = auto_free(_spawn_stub_enemy("Leaker_%d" % i))
		EnemySystem._wave_finished_spawning = false  # Keep wave going
		EnemySystem.on_enemy_reached_exit(enemy)

	# After 20 leaks, lives should be 0 and state should be GAME_OVER
	assert_int(GameManager.lives).is_equal(0)
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.GAME_OVER)

	# Verify it was a defeat (not victory) via signal
	# The game_over signal was emitted with victory=false because
	# current_wave (3) < max_waves (30)
	monitor_signals(GameManager, false)
	# Re-trigger to verify signal args (already transitioned, so check state)
	# Instead of re-triggering, verify the state implies defeat
	assert_int(GameManager.current_wave).is_less(GameManager.max_waves)


# ==============================================================================
# TEST 4: Victory at wave 30 -- clear final wave triggers GAME_OVER victory
# ==============================================================================

func test_victory_at_wave_30() -> void:
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 30  # Final wave

	monitor_signals(GameManager, false)

	# Simulate wave 30 cleared
	_simulate_wave_cleared()
	GameManager._process(0.016)

	# State should be GAME_OVER
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.GAME_OVER)

	# Verify victory=true via signal
	await assert_signal(GameManager).wait_until(500).is_emitted(
		"game_over", [true])

	# Wave should still be 30 (no increment past max)
	assert_int(GameManager.current_wave).is_equal(30)


# ==============================================================================
# TEST 5: Early wave start bonus -- remaining timer converted to gold
# ==============================================================================

func test_early_wave_start_bonus() -> void:
	GameManager.start_game()
	# Now in BUILD_PHASE, wave 1, timer = build_phase_duration (30.0)

	# Simulate some time passing (timer decrements only for wave > 1,
	# but we can set it manually)
	GameManager._build_timer = 20.0

	var gold_before: int = EconomyManager.gold

	monitor_signals(GameManager, false)

	# Start wave early while timer has 20 seconds remaining
	GameManager.start_wave_early()

	# Should transition to COMBAT_PHASE
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.COMBAT_PHASE)

	# Bonus = int(20.0) * 10 = 200 gold
	var expected_bonus: int = 200
	assert_int(EconomyManager.gold).is_equal(gold_before + expected_bonus)

	# Verify the early_wave_bonus signal was emitted with the correct amount
	await assert_signal(GameManager).wait_until(500).is_emitted(
		"early_wave_bonus", [expected_bonus])


# ==============================================================================
# TEST 6: Economy reset before restart -- gold returns to starting value
# ==============================================================================

func test_economy_reset_before_restart() -> void:
	# Play a partial game: start, earn some gold, lose
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 5

	# Earn some extra gold
	EconomyManager.add_gold(300)
	assert_int(EconomyManager.gold).is_greater(EconomyManager.STARTING_GOLD)

	# Trigger game over by losing all lives
	GameManager.lose_life(GameManager.lives)
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.GAME_OVER)

	# Now "restart" the game: reset economy and start_game
	EconomyManager.reset()
	assert_int(EconomyManager.gold).is_equal(EconomyManager.STARTING_GOLD)

	GameManager.start_game()
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.BUILD_PHASE)
	assert_int(GameManager.current_wave).is_equal(1)
	assert_int(GameManager.lives).is_equal(GameManager.starting_lives)
	assert_int(EconomyManager.gold).is_equal(EconomyManager.STARTING_GOLD)
