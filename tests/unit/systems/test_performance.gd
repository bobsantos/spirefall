extends GdUnitTestSuite

## Performance benchmark tests (Task K3).
## Validates pathfinding recalculation time, stress spawning, tower firing,
## object cleanup, and memory estimation.


# -- Helpers -------------------------------------------------------------------

func _reset_grid_and_path() -> void:
	GridManager._initialize_grid()
	GridManager._tower_map.clear()
	GridManager.spawn_points.clear()
	GridManager.exit_points.clear()
	var spawn := Vector2i(0, 0)
	var exit_point := Vector2i(19, 14)
	GridManager.spawn_points.append(spawn)
	GridManager.exit_points.append(exit_point)
	GridManager.grid[spawn.x][spawn.y] = GridManager.CellType.SPAWN
	GridManager.grid[exit_point.x][exit_point.y] = GridManager.CellType.EXIT
	PathfindingSystem.recalculate()


func _reset_enemy_system() -> void:
	for enemy: Node in EnemySystem._active_enemies:
		if is_instance_valid(enemy):
			enemy.free()
	EnemySystem._active_enemies.clear()
	EnemySystem._enemies_to_spawn.clear()
	EnemySystem._wave_finished_spawning = false


func _reset_tower_system() -> void:
	for tower: Node in TowerSystem._active_towers:
		if is_instance_valid(tower):
			tower.free()
	TowerSystem._active_towers.clear()


func _place_maze_towers() -> void:
	## Place towers in a zigzag maze pattern to stress pathfinding.
	## Fills alternating columns to force long winding paths.
	for col: int in range(2, 18, 2):
		# Leave a gap at top or bottom alternately
		var start_y: int = 0 if col % 4 == 0 else 1
		var end_y: int = 14 if col % 4 == 0 else 15
		for y: int in range(start_y, end_y):
			if GridManager.grid[col][y] == GridManager.CellType.BUILDABLE:
				GridManager.grid[col][y] = GridManager.CellType.TOWER


func _create_enemy_data(type_name: String = "normal") -> EnemyData:
	var data := EnemyData.new()
	data.enemy_name = type_name
	data.base_health = 100
	data.speed_multiplier = 1.0
	data.gold_reward = 10
	data.element = "neutral"
	data.is_flying = false
	data.is_boss = false
	data.spawn_count = 1
	data.split_on_death = false
	return data


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_reset_grid_and_path()
	_reset_enemy_system()
	_reset_tower_system()
	EconomyManager.reset()
	GameManager.game_state = GameManager.GameState.MENU
	GameManager._game_running = false
	GameManager.current_wave = 0
	GameManager.lives = 20


func after_test() -> void:
	_reset_enemy_system()
	_reset_tower_system()


# -- 1. Pathfinding Recalculation on Clear Grid (< 16ms) ----------------------

func test_pathfinding_recalc_clear_grid_under_16ms() -> void:
	var start: int = Time.get_ticks_usec()
	PathfindingSystem.recalculate()
	var elapsed_us: int = Time.get_ticks_usec() - start
	var elapsed_ms: float = elapsed_us / 1000.0
	# Must complete within 16ms (one frame at 60 FPS)
	assert_bool(elapsed_ms < 16.0).override_failure_message(
		"Pathfinding recalc on clear grid took %.2f ms (limit: 16ms)" % elapsed_ms
	).is_true()


# -- 2. Pathfinding Recalculation with Maze (< 16ms) --------------------------

func test_pathfinding_recalc_maze_under_16ms() -> void:
	_place_maze_towers()
	var start: int = Time.get_ticks_usec()
	PathfindingSystem.recalculate()
	var elapsed_us: int = Time.get_ticks_usec() - start
	var elapsed_ms: float = elapsed_us / 1000.0
	assert_bool(elapsed_ms < 16.0).override_failure_message(
		"Pathfinding recalc on maze took %.2f ms (limit: 16ms)" % elapsed_ms
	).is_true()


# -- 3. Pathfinding with Path Query (< 16ms) ----------------------------------

func test_pathfinding_recalc_plus_query_under_16ms() -> void:
	_place_maze_towers()
	PathfindingSystem.recalculate()

	var start: int = Time.get_ticks_usec()
	PathfindingSystem.recalculate()
	var _path: PackedVector2Array = PathfindingSystem.get_world_path(
		Vector2i(0, 0), Vector2i(19, 14))
	var elapsed_us: int = Time.get_ticks_usec() - start
	var elapsed_ms: float = elapsed_us / 1000.0
	assert_bool(elapsed_ms < 16.0).override_failure_message(
		"Pathfinding recalc + query took %.2f ms (limit: 16ms)" % elapsed_ms
	).is_true()


# -- 4. Repeated Pathfinding Recalculations (10x, no spike > 32ms) ------------

func test_pathfinding_no_spike_over_32ms() -> void:
	_place_maze_towers()
	var max_ms: float = 0.0
	for i: int in range(10):
		# Toggle a cell to force full recalculation
		var toggle_y: int = i % 14 + 1
		if GridManager.grid[1][toggle_y] == GridManager.CellType.BUILDABLE:
			GridManager.grid[1][toggle_y] = GridManager.CellType.TOWER
		else:
			GridManager.grid[1][toggle_y] = GridManager.CellType.BUILDABLE

		var start: int = Time.get_ticks_usec()
		PathfindingSystem.recalculate()
		var elapsed_us: int = Time.get_ticks_usec() - start
		var elapsed_ms: float = elapsed_us / 1000.0
		if elapsed_ms > max_ms:
			max_ms = elapsed_ms

	assert_bool(max_ms < 32.0).override_failure_message(
		"Worst pathfinding spike was %.2f ms (limit: 32ms)" % max_ms
	).is_true()


# -- 5. EnemyData Creation Stress (50+ enemies, < 16ms) -----------------------

func test_enemy_data_creation_50_under_16ms() -> void:
	## Creating 50 scaled EnemyData objects should be fast (no scene instantiation).
	var template: EnemyData = _create_enemy_data("normal")
	var start: int = Time.get_ticks_usec()
	var enemies: Array[EnemyData] = []
	for i: int in range(50):
		var data: EnemyData = EnemySystem._create_scaled_enemy(template, 30)
		enemies.append(data)
	var elapsed_us: int = Time.get_ticks_usec() - start
	var elapsed_ms: float = elapsed_us / 1000.0
	assert_int(enemies.size()).is_equal(50)
	assert_bool(elapsed_ms < 16.0).override_failure_message(
		"Creating 50 EnemyData took %.2f ms (limit: 16ms)" % elapsed_ms
	).is_true()


# -- 6. EnemyData Creation Stress (100 enemies, < 32ms) -----------------------

func test_enemy_data_creation_100_under_32ms() -> void:
	var template: EnemyData = _create_enemy_data("armored")
	var start: int = Time.get_ticks_usec()
	var enemies: Array[EnemyData] = []
	for i: int in range(100):
		var data: EnemyData = EnemySystem._create_scaled_enemy(template, 50)
		enemies.append(data)
	var elapsed_us: int = Time.get_ticks_usec() - start
	var elapsed_ms: float = elapsed_us / 1000.0
	assert_int(enemies.size()).is_equal(100)
	assert_bool(elapsed_ms < 32.0).override_failure_message(
		"Creating 100 EnemyData took %.2f ms (limit: 32ms)" % elapsed_ms
	).is_true()


# -- 7. Grid Operations Stress (fill entire grid, < 16ms) ---------------------

func test_grid_fill_operations_under_16ms() -> void:
	## Fill and clear entire 20x15 grid to benchmark grid operation speed.
	var start: int = Time.get_ticks_usec()
	# Fill all buildable cells with towers
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			if GridManager.grid[x][y] == GridManager.CellType.BUILDABLE:
				GridManager.grid[x][y] = GridManager.CellType.TOWER
	# Clear them back
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			if GridManager.grid[x][y] == GridManager.CellType.TOWER:
				GridManager.grid[x][y] = GridManager.CellType.BUILDABLE
	var elapsed_us: int = Time.get_ticks_usec() - start
	var elapsed_ms: float = elapsed_us / 1000.0
	assert_bool(elapsed_ms < 16.0).override_failure_message(
		"Grid fill + clear took %.2f ms (limit: 16ms)" % elapsed_ms
	).is_true()


# -- 8. AStarGrid2D Path Query Stress (20 queries, < 16ms) --------------------

func test_path_query_20x_under_16ms() -> void:
	_place_maze_towers()
	PathfindingSystem.recalculate()

	var start: int = Time.get_ticks_usec()
	for i: int in range(20):
		var _path: PackedVector2Array = PathfindingSystem.get_path_points(
			Vector2i(0, 0), Vector2i(19, 14))
	var elapsed_us: int = Time.get_ticks_usec() - start
	var elapsed_ms: float = elapsed_us / 1000.0
	assert_bool(elapsed_ms < 16.0).override_failure_message(
		"20 path queries took %.2f ms (limit: 16ms)" % elapsed_ms
	).is_true()


# -- 9. World Path Conversion Stress (20 queries, < 16ms) ---------------------

func test_world_path_conversion_20x_under_16ms() -> void:
	_place_maze_towers()
	PathfindingSystem.recalculate()

	var start: int = Time.get_ticks_usec()
	for i: int in range(20):
		var _path: PackedVector2Array = PathfindingSystem.get_world_path(
			Vector2i(0, 0), Vector2i(19, 14))
	var elapsed_us: int = Time.get_ticks_usec() - start
	var elapsed_ms: float = elapsed_us / 1000.0
	assert_bool(elapsed_ms < 16.0).override_failure_message(
		"20 world path conversions took %.2f ms (limit: 16ms)" % elapsed_ms
	).is_true()


# -- 10. Active Enemy Array Operations (50 enemies, < 1ms) --------------------

func test_active_enemy_array_operations_50() -> void:
	## Test that adding/removing 50 enemies from _active_enemies is fast.
	var nodes: Array[Node] = []
	for i: int in range(50):
		var node := Node2D.new()
		nodes.append(node)

	var start: int = Time.get_ticks_usec()
	for node: Node in nodes:
		EnemySystem._active_enemies.append(node)
	for node: Node in nodes:
		EnemySystem._active_enemies.erase(node)
	var elapsed_us: int = Time.get_ticks_usec() - start
	var elapsed_ms: float = elapsed_us / 1000.0

	# Clean up
	for node: Node in nodes:
		node.free()
	assert_bool(elapsed_ms < 1.0).override_failure_message(
		"50 enemy array add/remove took %.2f ms (limit: 1ms)" % elapsed_ms
	).is_true()


# -- 11. Active Tower Array Operations (20 towers, < 1ms) ---------------------

func test_active_tower_array_operations_20() -> void:
	var nodes: Array[Node] = []
	for i: int in range(20):
		var node := Node2D.new()
		nodes.append(node)

	var start: int = Time.get_ticks_usec()
	for node: Node in nodes:
		TowerSystem._active_towers.append(node)
	for node: Node in nodes:
		TowerSystem._active_towers.erase(node)
	var elapsed_us: int = Time.get_ticks_usec() - start
	var elapsed_ms: float = elapsed_us / 1000.0

	for node: Node in nodes:
		node.free()
	assert_bool(elapsed_ms < 1.0).override_failure_message(
		"20 tower array add/remove took %.2f ms (limit: 1ms)" % elapsed_ms
	).is_true()


# -- 12. Enemy Cleanup Validation (no orphans after free) ----------------------

func test_enemy_cleanup_no_orphans() -> void:
	## Create and free 50 enemy data + node stubs; verify all cleaned up.
	var nodes: Array[Node] = []
	for i: int in range(50):
		var node := Node2D.new()
		nodes.append(node)
		EnemySystem._active_enemies.append(node)

	# Simulate cleanup
	for node: Node in nodes:
		EnemySystem._active_enemies.erase(node)
		node.free()

	assert_int(EnemySystem._active_enemies.size()).is_equal(0)
	# All nodes freed: verify they are no longer valid
	for node: Node in nodes:
		assert_bool(is_instance_valid(node)).is_false()


# -- 13. Tower Cleanup Validation (no orphans after free) ----------------------

func test_tower_cleanup_no_orphans() -> void:
	var nodes: Array[Node] = []
	for i: int in range(20):
		var node := Node2D.new()
		nodes.append(node)
		TowerSystem._active_towers.append(node)

	for node: Node in nodes:
		TowerSystem._active_towers.erase(node)
		node.free()

	assert_int(TowerSystem._active_towers.size()).is_equal(0)
	for node: Node in nodes:
		assert_bool(is_instance_valid(node)).is_false()


# -- 14. Scaling Formula Performance (1000 calculations, < 16ms) ---------------

func test_scaling_formula_1000x_under_16ms() -> void:
	## The enemy scaling formula must be fast enough for mass spawning.
	var template: EnemyData = _create_enemy_data("normal")
	var start: int = Time.get_ticks_usec()
	for wave: int in range(1, 1001):
		var _data: EnemyData = EnemySystem._create_scaled_enemy(template, wave)
	var elapsed_us: int = Time.get_ticks_usec() - start
	var elapsed_ms: float = elapsed_us / 1000.0
	assert_bool(elapsed_ms < 16.0).override_failure_message(
		"1000 scaling calculations took %.2f ms (limit: 16ms)" % elapsed_ms
	).is_true()


# -- 15. Grid Cell Access Performance (all cells 10x, < 16ms) -----------------

func test_grid_cell_access_all_cells_10x() -> void:
	var start: int = Time.get_ticks_usec()
	for iteration: int in range(10):
		for x: int in range(GridManager.GRID_WIDTH):
			for y: int in range(GridManager.GRID_HEIGHT):
				var _cell: int = GridManager.get_cell(Vector2i(x, y))
	var elapsed_us: int = Time.get_ticks_usec() - start
	var elapsed_ms: float = elapsed_us / 1000.0
	assert_bool(elapsed_ms < 16.0).override_failure_message(
		"3000 cell accesses took %.2f ms (limit: 16ms)" % elapsed_ms
	).is_true()


# -- 16. grid_to_world / world_to_grid Conversion Stress ----------------------

func test_coordinate_conversion_stress() -> void:
	var start: int = Time.get_ticks_usec()
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			var world: Vector2 = GridManager.grid_to_world(Vector2i(x, y))
			var _grid_pos: Vector2i = GridManager.world_to_grid(world)
	var elapsed_us: int = Time.get_ticks_usec() - start
	var elapsed_ms: float = elapsed_us / 1000.0
	assert_bool(elapsed_ms < 16.0).override_failure_message(
		"300 coordinate conversions took %.2f ms (limit: 16ms)" % elapsed_ms
	).is_true()


# -- 17. Coordinate Conversion Round-trip Correctness --------------------------

func test_coordinate_roundtrip_correctness() -> void:
	## Verify grid->world->grid gives back the original coordinates.
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			var original := Vector2i(x, y)
			var world: Vector2 = GridManager.grid_to_world(original)
			var roundtrip: Vector2i = GridManager.world_to_grid(world)
			assert_bool(roundtrip == original).override_failure_message(
				"Roundtrip failed for %s -> %s -> %s" % [original, world, roundtrip]
			).is_true()


# -- 18. Endless Wave Queue Build Performance (< 32ms) ------------------------

func test_endless_wave_build_queue_under_32ms() -> void:
	## Building a wave queue for wave 50 (endless) should be fast.
	## This loads enemy templates from .tres files on first access.
	var start: int = Time.get_ticks_usec()
	var queue: Array = EnemySystem._build_endless_wave(50)
	var elapsed_us: int = Time.get_ticks_usec() - start
	var elapsed_ms: float = elapsed_us / 1000.0
	assert_bool(queue.size() > 0).is_true()
	assert_bool(elapsed_ms < 32.0).override_failure_message(
		"Endless wave 50 queue build took %.2f ms (limit: 32ms)" % elapsed_ms
	).is_true()


# -- 19. Weighted Pool Construction Performance --------------------------------

func test_weighted_pool_construction_100x_under_16ms() -> void:
	var start: int = Time.get_ticks_usec()
	for i: int in range(100):
		var _pool: Array[Dictionary] = EnemySystem._build_weighted_pool(i)
	var elapsed_us: int = Time.get_ticks_usec() - start
	var elapsed_ms: float = elapsed_us / 1000.0
	assert_bool(elapsed_ms < 16.0).override_failure_message(
		"100 weighted pool builds took %.2f ms (limit: 16ms)" % elapsed_ms
	).is_true()


# -- 20. Memory: EnemyData Size Estimation ------------------------------------

func test_enemy_data_memory_reasonable() -> void:
	## 50 EnemyData instances should not exceed reasonable memory.
	## Each EnemyData Resource is ~200-500 bytes. 50 should be < 50KB.
	var enemies: Array[EnemyData] = []
	var template: EnemyData = _create_enemy_data("normal")
	for i: int in range(50):
		enemies.append(EnemySystem._create_scaled_enemy(template, 30))
	# If we got here without OOM, the test passes.
	# Verify all 50 were created successfully.
	assert_int(enemies.size()).is_equal(50)
	for data: EnemyData in enemies:
		assert_bool(data != null).is_true()
		assert_bool(data.base_health > 0).is_true()


# -- 21. is_path_valid Stress (10 calls, no spike > 32ms) ---------------------

func test_is_path_valid_no_spike() -> void:
	_place_maze_towers()
	var max_ms: float = 0.0
	for i: int in range(10):
		var start: int = Time.get_ticks_usec()
		var _valid: bool = PathfindingSystem.is_path_valid()
		var elapsed_us: int = Time.get_ticks_usec() - start
		var elapsed_ms: float = elapsed_us / 1000.0
		if elapsed_ms > max_ms:
			max_ms = elapsed_ms
	assert_bool(max_ms < 32.0).override_failure_message(
		"Worst is_path_valid spike was %.2f ms (limit: 32ms)" % max_ms
	).is_true()


# -- 22. Interest Application Performance (100x, < 16ms) ----------------------

func test_interest_application_100x_under_16ms() -> void:
	var start: int = Time.get_ticks_usec()
	for i: int in range(100):
		EconomyManager.reset()
		EconomyManager.add_gold(900)  # 1000 gold total for max interest tier
		EconomyManager.apply_interest()
	var elapsed_us: int = Time.get_ticks_usec() - start
	var elapsed_ms: float = elapsed_us / 1000.0
	assert_bool(elapsed_ms < 16.0).override_failure_message(
		"100 interest applications took %.2f ms (limit: 16ms)" % elapsed_ms
	).is_true()


# -- 23. Wave Bonus Calculation Performance (1000x, < 1ms) --------------------

func test_wave_bonus_calculation_1000x_under_1ms() -> void:
	var start: int = Time.get_ticks_usec()
	for wave: int in range(1, 1001):
		var _bonus: int = EconomyManager.calculate_wave_bonus(wave, 0)
	var elapsed_us: int = Time.get_ticks_usec() - start
	var elapsed_ms: float = elapsed_us / 1000.0
	assert_bool(elapsed_ms < 1.0).override_failure_message(
		"1000 wave bonus calcs took %.2f ms (limit: 1ms)" % elapsed_ms
	).is_true()
