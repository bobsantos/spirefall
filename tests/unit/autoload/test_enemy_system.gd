extends GdUnitTestSuite

## Unit tests for EnemySystem autoload.
## Covers: wave config loading, enemy template caching, scaling formulas (HP/speed/gold),
## wave queue building, enemy lifecycle (killed/exit/wave cleared), split enemies,
## boss minion spawning, and signals.


# -- Helpers -------------------------------------------------------------------

## Create a minimal EnemyData resource for testing without loading .tres files.
func _make_template(
	p_name: String = "TestEnemy",
	p_health: int = 100,
	p_speed: float = 1.0,
	p_gold: int = 3,
	p_spawn_count: int = 1,
	p_is_boss: bool = false,
	p_is_flying: bool = false,
	p_split_on_death: bool = false,
	p_split_data: EnemyData = null,
	p_element: String = "none",
	p_stealth: bool = false,
	p_immune_element: String = "",
	p_weak_element: String = "",
	p_boss_ability_key: String = "",
	p_boss_ability_interval: float = 0.0,
	p_minion_data: EnemyData = null,
	p_minion_spawn_interval: float = 0.0,
	p_minion_spawn_count: int = 0,
	p_heal_per_second: float = 0.0
) -> EnemyData:
	var data := EnemyData.new()
	data.enemy_name = p_name
	data.base_health = p_health
	data.speed_multiplier = p_speed
	data.gold_reward = p_gold
	data.spawn_count = p_spawn_count
	data.is_boss = p_is_boss
	data.is_flying = p_is_flying
	data.split_on_death = p_split_on_death
	data.split_data = p_split_data
	data.element = p_element
	data.stealth = p_stealth
	data.immune_element = p_immune_element
	data.weak_element = p_weak_element
	data.boss_ability_key = p_boss_ability_key
	data.boss_ability_interval = p_boss_ability_interval
	data.minion_data = p_minion_data
	data.minion_spawn_interval = p_minion_spawn_interval
	data.minion_spawn_count = p_minion_spawn_count
	data.heal_per_second = p_heal_per_second
	return data


## Create a stub enemy Node2D that mimics the properties EnemySystem expects,
## without loading the full BaseEnemy scene (which requires sprites/textures).
func _make_enemy_stub(data: EnemyData, p_position: Vector2 = Vector2.ZERO) -> Node2D:
	var stub := Node2D.new()
	stub.set_meta("enemy_data_ref", data)
	stub.set_script(_enemy_stub_script())
	stub.enemy_data = data
	stub.path_points = PackedVector2Array([Vector2(0, 0), Vector2(640, 0)])
	stub._path_index = 0
	stub.position = p_position
	return stub


## Returns a minimal script that gives a Node2D the properties EnemySystem reads/writes.
static var _stub_script: GDScript = null
func _enemy_stub_script() -> GDScript:
	if _stub_script != null:
		return _stub_script
	_stub_script = GDScript.new()
	_stub_script.source_code = """
extends Node2D

var enemy_data: EnemyData
var path_points: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
"""
	_stub_script.reload()
	return _stub_script


func _reset_enemy_system() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn.clear()
	EnemySystem._spawn_timer = 0.0
	EnemySystem._spawn_interval = EnemySystem.DEFAULT_SPAWN_INTERVAL


func _reset_game_manager() -> void:
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = 0
	GameManager.lives = GameManager.starting_lives
	GameManager._build_timer = 0.0
	GameManager._enemies_leaked_this_wave = 0


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_reset_enemy_system()
	_reset_game_manager()
	EconomyManager.reset()


func after() -> void:
	_stub_script = null


# -- 1. Wave config loads successfully -----------------------------------------

func test_wave_config_loads_successfully() -> void:
	# _wave_config is populated in _ready() from wave_config.json
	assert_bool(EnemySystem._wave_config.is_empty()).is_false()
	# Should have 30 waves configured
	assert_int(EnemySystem._wave_config.size()).is_equal(30)


# -- 2. get_wave_config returns data ------------------------------------------

func test_get_wave_config_returns_data() -> void:
	var config: Dictionary = EnemySystem.get_wave_config(1)
	assert_bool(config.is_empty()).is_false()
	assert_bool(config.has("enemies")).is_true()
	# Wave 1 has enemies array
	var enemies: Array = config["enemies"]
	assert_bool(enemies.is_empty()).is_false()


# -- 3. get_wave_config missing wave -------------------------------------------

func test_get_wave_config_missing_wave() -> void:
	var config: Dictionary = EnemySystem.get_wave_config(999)
	assert_bool(config.is_empty()).is_true()


# -- 4. get_enemy_template loads .tres -----------------------------------------

func test_get_enemy_template_loads_tres() -> void:
	var template: EnemyData = EnemySystem.get_enemy_template("normal")
	assert_object(template).is_not_null()
	assert_str(template.enemy_name).is_equal("Normal")
	assert_int(template.base_health).is_equal(100)


# -- 5. get_enemy_template caches ---------------------------------------------

func test_get_enemy_template_caches() -> void:
	# Clear cache to test fresh load + caching
	EnemySystem._enemy_templates.erase("fast")
	var first: EnemyData = EnemySystem.get_enemy_template("fast")
	var second: EnemyData = EnemySystem.get_enemy_template("fast")
	# Same reference (cached)
	assert_object(second).is_same(first)


# -- 6. get_enemy_template invalid returns null --------------------------------

func test_get_enemy_template_invalid() -> void:
	var template: EnemyData = EnemySystem.get_enemy_template("nonexistent_enemy_type_xyz")
	assert_object(template).is_null()


# -- 7. Scaling HP wave 1 -----------------------------------------------------

func test_scaling_hp_wave_1() -> void:
	# HP = base * (1 + 0.15 * wave)^2 = 100 * (1.15)^2 = 100 * 1.3225 = 132
	var template: EnemyData = _make_template("ScaleTest", 100)
	var scaled: EnemyData = EnemySystem._create_scaled_enemy(template, 1)
	assert_int(scaled.base_health).is_equal(132)


# -- 8. Scaling HP wave 10 ----------------------------------------------------

func test_scaling_hp_wave_10() -> void:
	# HP = 100 * (1 + 0.15 * 10)^2 = 100 * (2.5)^2 = 100 * 6.25 = 625
	var template: EnemyData = _make_template("ScaleTest", 100)
	var scaled: EnemyData = EnemySystem._create_scaled_enemy(template, 10)
	assert_int(scaled.base_health).is_equal(625)


# -- 9. Scaling HP wave 30 ----------------------------------------------------

func test_scaling_hp_wave_30() -> void:
	# HP = 100 * (1 + 0.15 * 30)^2 = 100 * (5.5)^2 = 100 * 30.25 = 3025
	var template: EnemyData = _make_template("ScaleTest", 100)
	var scaled: EnemyData = EnemySystem._create_scaled_enemy(template, 30)
	assert_int(scaled.base_health).is_equal(3025)


# -- 10. Scaling speed wave 10 ------------------------------------------------

func test_scaling_speed_wave_10() -> void:
	# Speed = 1.0 * min(1 + 0.02 * 10, 2.0) = 1.0 * 1.2 = 1.2
	var template: EnemyData = _make_template("ScaleTest", 100, 1.0)
	var scaled: EnemyData = EnemySystem._create_scaled_enemy(template, 10)
	assert_float(scaled.speed_multiplier).is_equal_approx(1.2, 0.001)


# -- 11. Scaling speed capped at 2x -------------------------------------------

func test_scaling_speed_capped_at_2x() -> void:
	# Wave 60: min(1 + 0.02 * 60, 2.0) = min(2.2, 2.0) = 2.0
	# With base speed_multiplier 1.0: 1.0 * 2.0 = 2.0
	var template: EnemyData = _make_template("ScaleTest", 100, 1.0)
	var scaled: EnemyData = EnemySystem._create_scaled_enemy(template, 60)
	assert_float(scaled.speed_multiplier).is_equal_approx(2.0, 0.001)


# -- 12. Scaling gold wave 10 -------------------------------------------------

func test_scaling_gold_wave_10() -> void:
	# Gold = 3 * (1 + 0.08 * 10) = 3 * 1.8 = 5.4 -> int = 5
	var template: EnemyData = _make_template("ScaleTest", 100, 1.0, 3)
	var scaled: EnemyData = EnemySystem._create_scaled_enemy(template, 10)
	assert_int(scaled.gold_reward).is_equal(5)


# -- 13. Build wave queue correct count ---------------------------------------

func test_build_wave_queue_correct_count() -> void:
	# Wave 1 config: 8 normal enemies, each with spawn_count=1
	# _build_wave_queue loads templates from .tres files, so ensure normal is loadable
	var queue: Array = EnemySystem._build_wave_queue(1)
	assert_int(queue.size()).is_equal(8)


# -- 14. Swarm multiplies by spawn_count --------------------------------------

func test_swarm_multiplies_by_spawn_count() -> void:
	# Inject a wave config entry with swarm enemies and a test template
	# Swarm has spawn_count=3, so count 3 * spawn_count 3 = 9
	var swarm_template: EnemyData = _make_template("TestSwarm", 30, 1.4, 1, 3)
	EnemySystem._enemy_templates["test_swarm"] = swarm_template

	# Temporarily inject a wave config for wave 100
	var test_wave_entry: Dictionary = {
		"wave": 100,
		"enemies": [{"type": "test_swarm", "count": 3}]
	}
	EnemySystem._wave_config[100] = test_wave_entry

	var queue: Array = EnemySystem._build_wave_queue(100)
	# 3 (count) * 3 (spawn_count) = 9 enemies in queue
	assert_int(queue.size()).is_equal(9)

	# Cleanup injected data
	EnemySystem._wave_config.erase(100)
	EnemySystem._enemy_templates.erase("test_swarm")


# -- 15. Boss wave uses boss spawn interval -----------------------------------

func test_boss_wave_uses_boss_spawn_interval() -> void:
	# Wave 10 is a boss wave with is_boss_wave: true (and no custom spawn_interval)
	EnemySystem._build_wave_queue(10)
	assert_float(EnemySystem._spawn_interval).is_equal(EnemySystem.BOSS_SPAWN_INTERVAL)


# -- 16. spawn_wave sets queue -------------------------------------------------

func test_spawn_wave_sets_queue() -> void:
	# Set up minimal map so PathfindingSystem.get_enemy_path() returns a valid path
	_setup_minimal_map()
	GameManager.current_wave = 1
	EnemySystem.spawn_wave(1)
	assert_bool(EnemySystem._enemies_to_spawn.is_empty()).is_false()


# -- 17. is_wave_finished false during spawn -----------------------------------

func test_is_wave_finished_false_during_spawn() -> void:
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn = [_make_template()]
	assert_bool(EnemySystem.is_wave_finished()).is_false()


# -- 18. is_wave_finished true when done ---------------------------------------

func test_is_wave_finished_true_when_done() -> void:
	EnemySystem._wave_finished_spawning = true
	EnemySystem._enemies_to_spawn.clear()
	assert_bool(EnemySystem.is_wave_finished()).is_true()


# -- 19. get_active_enemy_count ------------------------------------------------

func test_get_active_enemy_count() -> void:
	assert_int(EnemySystem.get_active_enemy_count()).is_equal(0)
	# Add stub enemies to the active list
	var stub_a: Node2D = auto_free(_make_enemy_stub(_make_template()))
	var stub_b: Node2D = auto_free(_make_enemy_stub(_make_template()))
	EnemySystem._active_enemies.append(stub_a)
	EnemySystem._active_enemies.append(stub_b)
	assert_int(EnemySystem.get_active_enemy_count()).is_equal(2)


# -- 20. on_enemy_killed awards gold ------------------------------------------

func test_on_enemy_killed_awards_gold() -> void:
	var data: EnemyData = _make_template("GoldEnemy", 100, 1.0, 10)
	var stub: Node2D = auto_free(_make_enemy_stub(data))
	EnemySystem._active_enemies.append(stub)
	# Also set wave finished so wave_cleared can fire cleanly
	EnemySystem._wave_finished_spawning = true

	var gold_before: int = EconomyManager.gold
	EnemySystem.on_enemy_killed(stub)
	assert_int(EconomyManager.gold).is_equal(gold_before + 10)


# -- 21. on_enemy_killed emits signal -----------------------------------------

func test_on_enemy_killed_emits_signal() -> void:
	var data: EnemyData = _make_template("SigEnemy", 100, 1.0, 5)
	var stub: Node2D = auto_free(_make_enemy_stub(data))
	EnemySystem._active_enemies.append(stub)
	EnemySystem._wave_finished_spawning = true

	var signal_count: Array[int] = [0]
	var _conn: Callable = func(_enemy: Node) -> void: signal_count[0] += 1
	EnemySystem.enemy_killed.connect(_conn)
	EnemySystem.on_enemy_killed(stub)
	EnemySystem.enemy_killed.disconnect(_conn)
	assert_int(signal_count[0]).is_equal(1)


# -- 22. on_enemy_reached_exit loses life --------------------------------------

func test_on_enemy_reached_exit_loses_life() -> void:
	GameManager.start_game()
	var data: EnemyData = _make_template("LeakEnemy")
	var stub: Node2D = auto_free(_make_enemy_stub(data))
	EnemySystem._active_enemies.append(stub)
	EnemySystem._wave_finished_spawning = true

	var lives_before: int = GameManager.lives
	EnemySystem.on_enemy_reached_exit(stub)
	assert_int(GameManager.lives).is_equal(lives_before - 1)


# -- 23. wave_cleared signal when all dead -------------------------------------

func test_wave_cleared_signal_when_all_dead() -> void:
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 1

	var data: EnemyData = _make_template("LastEnemy", 100, 1.0, 5)
	var stub: Node2D = auto_free(_make_enemy_stub(data))
	EnemySystem._active_enemies.append(stub)
	EnemySystem._wave_finished_spawning = true

	monitor_signals(EnemySystem, false)
	EnemySystem.on_enemy_killed(stub)
	# After the last enemy is removed and _wave_finished_spawning is true,
	# wave_cleared should be emitted
	await assert_signal(EnemySystem).wait_until(500).is_emitted(
		"wave_cleared", [1])


# -- 24. Split enemies spawn two children -------------------------------------

func test_split_enemies_spawn_two_children() -> void:
	GameManager.start_game()
	GameManager.current_wave = 5

	var child_template: EnemyData = _make_template("SplitChild", 50, 1.0, 1)
	var parent_data: EnemyData = _make_template(
		"SplitParent", 150, 1.0, 4, 1, false, false, true, child_template)

	var parent: Node2D = auto_free(_make_enemy_stub(parent_data, Vector2(100, 0)))
	parent._path_index = 3
	EnemySystem._active_enemies.append(parent)
	EnemySystem._wave_finished_spawning = false

	# Store the original enemy scene so we can restore it, then replace
	# with a stub scene that produces simple Node2D objects
	var original_scene: PackedScene = EnemySystem._enemy_scene
	EnemySystem._enemy_scene = _create_stub_scene()

	EnemySystem.spawn_split_enemies(parent)

	# Parent should have been removed, 2 children should be in active list
	assert_bool(EnemySystem._active_enemies.has(parent)).is_false()
	assert_int(EnemySystem._active_enemies.size()).is_equal(2)

	# Clean up spawned children
	for child: Node in EnemySystem._active_enemies:
		child.free()
	EnemySystem._active_enemies.clear()
	EnemySystem._enemy_scene = original_scene


# -- 25. Split children continue from parent path index -----------------------

func test_split_children_continue_from_parent_index() -> void:
	GameManager.start_game()
	GameManager.current_wave = 5

	var child_template: EnemyData = _make_template("SplitChild", 50, 1.0, 1)
	var parent_data: EnemyData = _make_template(
		"SplitParent", 150, 1.0, 4, 1, false, false, true, child_template)

	var parent: Node2D = auto_free(_make_enemy_stub(parent_data, Vector2(200, 0)))
	parent._path_index = 5
	EnemySystem._active_enemies.append(parent)
	EnemySystem._wave_finished_spawning = false

	var original_scene: PackedScene = EnemySystem._enemy_scene
	EnemySystem._enemy_scene = _create_stub_scene()

	EnemySystem.spawn_split_enemies(parent)

	# Both children should have _path_index == 5 (same as parent)
	for child: Node in EnemySystem._active_enemies:
		assert_int(child._path_index).is_equal(5)

	# Clean up
	for child: Node in EnemySystem._active_enemies:
		child.free()
	EnemySystem._active_enemies.clear()
	EnemySystem._enemy_scene = original_scene


# -- 26. Split awards parent gold ---------------------------------------------

func test_split_awards_parent_gold() -> void:
	GameManager.start_game()
	GameManager.current_wave = 5

	var child_template: EnemyData = _make_template("SplitChild", 50, 1.0, 1)
	var parent_data: EnemyData = _make_template(
		"SplitParent", 150, 1.0, 8, 1, false, false, true, child_template)

	var parent: Node2D = auto_free(_make_enemy_stub(parent_data, Vector2(100, 0)))
	EnemySystem._active_enemies.append(parent)
	EnemySystem._wave_finished_spawning = false

	var original_scene: PackedScene = EnemySystem._enemy_scene
	EnemySystem._enemy_scene = _create_stub_scene()

	var gold_before: int = EconomyManager.gold
	EnemySystem.spawn_split_enemies(parent)
	# Parent gold_reward (8) should have been awarded
	assert_int(EconomyManager.gold).is_equal(gold_before + 8)

	# Clean up
	for child: Node in EnemySystem._active_enemies:
		child.free()
	EnemySystem._active_enemies.clear()
	EnemySystem._enemy_scene = original_scene


# -- 27. Boss minions spawn at boss position -----------------------------------

func test_boss_minions_spawn_at_boss_position() -> void:
	GameManager.start_game()
	GameManager.current_wave = 10

	var minion_template: EnemyData = _make_template("IceMinion", 60, 1.2, 2)
	var boss_data: EnemyData = _make_template(
		"TestBoss", 5000, 0.5, 100, 1, true, false, false, null, "ice",
		false, "ice", "", "tower_freeze", 8.0, minion_template, 15.0, 2)

	var boss: Node2D = auto_free(_make_enemy_stub(boss_data, Vector2(300, 200)))
	boss._path_index = 4
	EnemySystem._active_enemies.append(boss)
	EnemySystem._wave_finished_spawning = false

	var original_scene: PackedScene = EnemySystem._enemy_scene
	EnemySystem._enemy_scene = _create_stub_scene()

	EnemySystem.spawn_boss_minions(boss, minion_template, 3)

	# 3 minions should have been added + the boss still in active
	assert_int(EnemySystem._active_enemies.size()).is_equal(4)  # 1 boss + 3 minions

	# Verify minions are positioned near the boss (within offset range of +/-16)
	for i: int in range(1, EnemySystem._active_enemies.size()):
		var minion: Node = EnemySystem._active_enemies[i]
		var dist: float = minion.position.distance_to(boss.position)
		# Max offset is sqrt(16^2 + 16^2) ~= 22.6, give a margin
		assert_float(dist).is_less(30.0)

	# Clean up
	for i: int in range(EnemySystem._active_enemies.size() - 1, -1, -1):
		var e: Node = EnemySystem._active_enemies[i]
		if e != boss:
			e.free()
	EnemySystem._active_enemies.clear()
	EnemySystem._enemy_scene = original_scene


# -- 28. Fallback queue for unknown wave ---------------------------------------

func test_fallback_queue_for_unknown_wave() -> void:
	# Wave 999 is not in the config, should use _build_fallback_queue
	# Fallback count = 8 + int(999 / 3) = 8 + 333 = 341
	# But this also loads the "normal" template from .tres
	var queue: Array = EnemySystem._build_wave_queue(999)
	var expected_count: int = 8 + int(999.0 / 3.0)
	assert_int(queue.size()).is_equal(expected_count)
	# Spawn interval should be reset to DEFAULT
	assert_float(EnemySystem._spawn_interval).is_equal(EnemySystem.DEFAULT_SPAWN_INTERVAL)


# -- 29. _create_scaled_enemy copies all fields --------------------------------

func test_create_scaled_enemy_copies_all_fields() -> void:
	var split_child: EnemyData = _make_template("Child")
	var minion: EnemyData = _make_template("Minion")
	var template: EnemyData = _make_template(
		"FullCopy", 200, 1.5, 10, 2, true, true, true, split_child, "fire",
		true, "fire", "water", "fire_trail", 5.0, minion, 10.0, 3, 8.0)

	var scaled: EnemyData = EnemySystem._create_scaled_enemy(template, 5)

	# Non-scaled fields should be copied exactly
	assert_str(scaled.enemy_name).is_equal("FullCopy")
	assert_str(scaled.element).is_equal("fire")
	assert_str(scaled.special).is_equal("")
	assert_bool(scaled.is_flying).is_true()
	assert_bool(scaled.is_boss).is_true()
	assert_int(scaled.spawn_count).is_equal(2)
	assert_bool(scaled.split_on_death).is_true()
	assert_object(scaled.split_data).is_same(split_child)
	assert_bool(scaled.stealth).is_true()
	assert_str(scaled.immune_element).is_equal("fire")
	assert_str(scaled.weak_element).is_equal("water")
	assert_str(scaled.boss_ability_key).is_equal("fire_trail")
	assert_float(scaled.boss_ability_interval).is_equal(5.0)
	assert_object(scaled.minion_data).is_same(minion)
	assert_float(scaled.minion_spawn_interval).is_equal(10.0)
	assert_int(scaled.minion_spawn_count).is_equal(3)
	assert_float(scaled.heal_per_second).is_equal(8.0)

	# Scaled fields should be different from template
	# HP = 200 * (1 + 0.15 * 5)^2 = 200 * 1.75^2 = 200 * 3.0625 = 612
	assert_int(scaled.base_health).is_equal(612)
	# Speed = 1.5 * min(1 + 0.02 * 5, 2.0) = 1.5 * 1.1 = 1.65
	assert_float(scaled.speed_multiplier).is_equal_approx(1.65, 0.001)
	# Gold = 10 * (1 + 0.08 * 5) = 10 * 1.4 = 14
	assert_int(scaled.gold_reward).is_equal(14)


# -- 30. enemy_spawned signal --------------------------------------------------

func test_enemy_spawned_signal() -> void:
	# Set up minimal map for path generation
	_setup_minimal_map()
	GameManager.current_wave = 1

	# Replace the enemy scene with our stub scene
	var original_scene: PackedScene = EnemySystem._enemy_scene
	EnemySystem._enemy_scene = _create_stub_scene()

	# Load wave queue
	EnemySystem.spawn_wave(1)
	assert_bool(EnemySystem._enemies_to_spawn.is_empty()).is_false()

	# Connect directly to capture the synchronous signal emission
	var signal_count: Array[int] = [0]
	var _conn: Callable = func(_enemy: Node) -> void: signal_count[0] += 1
	EnemySystem.enemy_spawned.connect(_conn)

	# Trigger one spawn by calling _spawn_next_enemy directly
	EnemySystem._spawn_next_enemy()

	EnemySystem.enemy_spawned.disconnect(_conn)
	assert_int(signal_count[0]).is_equal(1)

	# Clean up spawned enemies
	for enemy: Node in EnemySystem._active_enemies:
		enemy.free()
	EnemySystem._active_enemies.clear()
	EnemySystem._enemies_to_spawn.clear()
	EnemySystem._enemy_scene = original_scene


# -- Map Setup Helper ----------------------------------------------------------

## Set up a minimal map with spawn/exit so PathfindingSystem can generate paths.
func _setup_minimal_map() -> void:
	GridManager._initialize_grid()
	GridManager._tower_map.clear()
	GridManager.spawn_points.clear()
	GridManager.exit_points.clear()
	var spawn := Vector2i(0, 0)
	var exit := Vector2i(19, 0)
	GridManager.spawn_points.append(spawn)
	GridManager.exit_points.append(exit)
	GridManager.grid[spawn.x][spawn.y] = GridManager.CellType.SPAWN
	GridManager.grid[exit.x][exit.y] = GridManager.CellType.EXIT
	PathfindingSystem.recalculate()


# -- Stub Scene Helper ---------------------------------------------------------

## Create a PackedScene that produces a Node2D with the enemy_data / path_points
## / _path_index properties that EnemySystem reads and writes during spawning.
## This avoids loading BaseEnemy.tscn which requires sprite textures.
func _create_stub_scene() -> PackedScene:
	var scene := PackedScene.new()
	var node := Node2D.new()
	node.name = "StubEnemy"
	node.set_script(_enemy_stub_script())
	scene.pack(node)
	node.free()
	return scene
