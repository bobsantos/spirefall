extends GdUnitTestSuite

## Unit tests for PathfindingSystem autoload.
## Covers: path existence, blocked paths, recalculation, world path conversion,
## flying paths, signals, diagonal mode, and unbuildable cell handling.


# -- Helpers -------------------------------------------------------------------

## Reset GridManager to a clean all-buildable grid with no towers.
func _reset_grid_manager() -> void:
	GridManager._initialize_grid()
	GridManager._tower_map.clear()
	GridManager.spawn_points.clear()
	GridManager.exit_points.clear()


## Set up a minimal map with one spawn and one exit.
## Spawn at top-left corner (0,0), exit at top-right corner (19,0).
## The first row (y=0) remains BUILDABLE, giving a clear horizontal path.
func _setup_minimal_map() -> void:
	_reset_grid_manager()
	var spawn := Vector2i(0, 0)
	var exit := Vector2i(19, 0)
	GridManager.spawn_points.append(spawn)
	GridManager.exit_points.append(exit)
	GridManager.grid[spawn.x][spawn.y] = GridManager.CellType.SPAWN
	GridManager.grid[exit.x][exit.y] = GridManager.CellType.EXIT
	PathfindingSystem.recalculate()


## Block an entire column from top to bottom, creating a solid wall.
func _block_column(x: int) -> void:
	for y: int in range(GridManager.GRID_HEIGHT):
		GridManager.grid[x][y] = GridManager.CellType.UNBUILDABLE


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_setup_minimal_map()


# -- 1. Path exists on clear grid ---------------------------------------------

func test_path_exists_on_clear_grid() -> void:
	var path: PackedVector2Array = PathfindingSystem.get_path_points(
		Vector2i(0, 0), Vector2i(19, 0))
	assert_bool(path.is_empty()).is_false()
	# Path should start at spawn and end at exit
	assert_object(Vector2i(int(path[0].x), int(path[0].y))).is_equal(Vector2i(0, 0))
	assert_object(Vector2i(int(path[path.size() - 1].x), int(path[path.size() - 1].y))).is_equal(Vector2i(19, 0))


# -- 2. Path blocked returns empty ---------------------------------------------

func test_path_blocked_returns_empty() -> void:
	# Build a solid wall across the entire grid at column 10, blocking all routes
	_block_column(10)
	PathfindingSystem.recalculate()
	var path: PackedVector2Array = PathfindingSystem.get_path_points(
		Vector2i(0, 0), Vector2i(19, 0))
	assert_bool(path.is_empty()).is_true()


# -- 3. Recalculate updates solids (path routes around tower) ------------------

func test_recalculate_updates_solids() -> void:
	# Get original path on clear grid along row y=0
	var original_path: PackedVector2Array = PathfindingSystem.get_path_points(
		Vector2i(0, 0), Vector2i(19, 0))
	assert_bool(original_path.is_empty()).is_false()

	# Place a tower on the direct path at (10, 0)
	GridManager.grid[10][0] = GridManager.CellType.TOWER
	PathfindingSystem.recalculate()

	var new_path: PackedVector2Array = PathfindingSystem.get_path_points(
		Vector2i(0, 0), Vector2i(19, 0))
	assert_bool(new_path.is_empty()).is_false()

	# New path must be longer because it routes around the tower
	assert_bool(new_path.size() > original_path.size()).is_true()

	# Verify the tower cell (10, 0) is not in the new path
	var tower_in_path: bool = false
	for point: Vector2 in new_path:
		if Vector2i(int(point.x), int(point.y)) == Vector2i(10, 0):
			tower_in_path = true
			break
	assert_bool(tower_in_path).is_false()


# -- 4. is_path_valid returns true on open grid --------------------------------

func test_is_path_valid_true() -> void:
	assert_bool(PathfindingSystem.is_path_valid()).is_true()


# -- 5. is_path_valid returns false when blocked --------------------------------

func test_is_path_valid_false_blocked() -> void:
	# Build a solid wall across the entire grid at column 10
	_block_column(10)
	# is_path_valid calls recalculate() internally, so no need to call it first
	assert_bool(PathfindingSystem.is_path_valid()).is_false()


# -- 6. get_world_path converts grid coords to world pixel coords -------------

func test_get_world_path_converts_coords() -> void:
	var world_path: PackedVector2Array = PathfindingSystem.get_world_path(
		Vector2i(0, 0), Vector2i(19, 0))
	assert_bool(world_path.is_empty()).is_false()

	# First point should be world coords of grid (0, 0) = (32, 32)
	assert_float(world_path[0].x).is_equal(32.0)
	assert_float(world_path[0].y).is_equal(32.0)

	# Last point should be world coords of grid (19, 0) = (1248, 32)
	var last: Vector2 = world_path[world_path.size() - 1]
	assert_float(last.x).is_equal(1248.0)
	assert_float(last.y).is_equal(32.0)


# -- 7. get_enemy_path uses first spawn and exit points ------------------------

func test_get_enemy_path_uses_first_spawn_exit() -> void:
	var enemy_path: PackedVector2Array = PathfindingSystem.get_enemy_path()
	assert_bool(enemy_path.is_empty()).is_false()

	# Should return world-coordinate path from spawn_points[0] to exit_points[0]
	var spawn_world: Vector2 = GridManager.grid_to_world(GridManager.spawn_points[0])
	var exit_world: Vector2 = GridManager.grid_to_world(GridManager.exit_points[0])

	assert_float(enemy_path[0].x).is_equal(spawn_world.x)
	assert_float(enemy_path[0].y).is_equal(spawn_world.y)

	var last: Vector2 = enemy_path[enemy_path.size() - 1]
	assert_float(last.x).is_equal(exit_world.x)
	assert_float(last.y).is_equal(exit_world.y)


# -- 8. get_enemy_path returns empty when no spawn points ----------------------

func test_get_enemy_path_empty_when_no_spawns() -> void:
	GridManager.spawn_points.clear()
	var path: PackedVector2Array = PathfindingSystem.get_enemy_path()
	assert_bool(path.is_empty()).is_true()


# -- 9. get_flying_path returns exactly two points (start and end) -------------

func test_get_flying_path_returns_two_points() -> void:
	var flying_path: PackedVector2Array = PathfindingSystem.get_flying_path()
	assert_int(flying_path.size()).is_equal(2)

	# First point = world coords of spawn, second = world coords of exit
	var spawn_world: Vector2 = GridManager.grid_to_world(GridManager.spawn_points[0])
	var exit_world: Vector2 = GridManager.grid_to_world(GridManager.exit_points[0])

	assert_float(flying_path[0].x).is_equal(spawn_world.x)
	assert_float(flying_path[0].y).is_equal(spawn_world.y)
	assert_float(flying_path[1].x).is_equal(exit_world.x)
	assert_float(flying_path[1].y).is_equal(exit_world.y)


# -- 10. get_flying_path ignores towers (same result regardless) ---------------

func test_get_flying_path_ignores_towers() -> void:
	var path_before: PackedVector2Array = PathfindingSystem.get_flying_path()

	# Place towers across the grid to block normal paths
	for x: int in range(1, 19):
		GridManager.grid[x][0] = GridManager.CellType.TOWER
	PathfindingSystem.recalculate()

	var path_after: PackedVector2Array = PathfindingSystem.get_flying_path()

	# Flying path should be identical regardless of tower placement
	assert_int(path_after.size()).is_equal(2)
	assert_float(path_after[0].x).is_equal(path_before[0].x)
	assert_float(path_after[0].y).is_equal(path_before[0].y)
	assert_float(path_after[1].x).is_equal(path_before[1].x)
	assert_float(path_after[1].y).is_equal(path_before[1].y)


# -- 11. path_recalculated signal emitted on recalculate() ---------------------

func test_path_recalculated_signal() -> void:
	monitor_signals(PathfindingSystem, false)
	PathfindingSystem.recalculate()
	await assert_signal(PathfindingSystem).wait_until(500).is_emitted("path_recalculated")


# -- 12. Diagonal mode is NEVER (path only uses cardinal directions) -----------

func test_diagonal_mode_never() -> void:
	# Verify the AStarGrid2D is configured with no diagonals
	assert_int(PathfindingSystem._astar.diagonal_mode).is_equal(
		AStarGrid2D.DIAGONAL_MODE_NEVER)

	# Verify path only takes cardinal steps (no diagonal moves)
	var path: PackedVector2Array = PathfindingSystem.get_path_points(
		Vector2i(0, 0), Vector2i(5, 5))
	assert_bool(path.is_empty()).is_false()

	# Check each consecutive pair of points differs by exactly 1 on one axis
	for i: int in range(path.size() - 1):
		var current := Vector2i(int(path[i].x), int(path[i].y))
		var next := Vector2i(int(path[i + 1].x), int(path[i + 1].y))
		var dx: int = absi(next.x - current.x)
		var dy: int = absi(next.y - current.y)
		# Each step must be exactly 1 cell in one cardinal direction
		assert_int(dx + dy).is_equal(1)


# -- 13. UNBUILDABLE cells treated as solid (no path through them) -------------

func test_no_path_through_unbuildable() -> void:
	# Make an entire row unbuildable except the endpoints, creating a wall.
	# Use row y=0 where our spawn-exit route lives.
	# Set middle cells (1..18) to UNBUILDABLE on y=0, forcing path around.
	for x: int in range(1, 19):
		GridManager.grid[x][0] = GridManager.CellType.UNBUILDABLE
	PathfindingSystem.recalculate()

	# Direct path along y=0 is blocked; path must go through other rows
	var path: PackedVector2Array = PathfindingSystem.get_path_points(
		Vector2i(0, 0), Vector2i(19, 0))
	assert_bool(path.is_empty()).is_false()

	# Verify no point in the path crosses the UNBUILDABLE cells on row 0
	for point: Vector2 in path:
		var gp := Vector2i(int(point.x), int(point.y))
		if gp.x >= 1 and gp.x <= 18:
			assert_int(gp.y).is_not_equal(0)
