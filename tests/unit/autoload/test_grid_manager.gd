extends GdUnitTestSuite

## Unit tests for GridManager autoload.
## Covers: grid dimensions, cell types, bounds checking, tower placement/removal,
## coordinate conversions, map loading, and signals.


# -- Helpers -------------------------------------------------------------------

## Reset GridManager to a clean all-buildable grid with no towers.
func _reset_grid_manager() -> void:
	GridManager._initialize_grid()
	GridManager._tower_map.clear()
	GridManager.spawn_points.clear()
	GridManager.exit_points.clear()


## Set up a minimal map with one spawn and one exit so PathfindingSystem
## can validate paths. Spawn at top-left corner, exit at top-right corner.
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


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_reset_grid_manager()
	PathfindingSystem.recalculate()


# -- 1. Initial grid is all buildable -----------------------------------------

func test_initial_grid_all_buildable() -> void:
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			assert_int(GridManager.grid[x][y]).is_equal(GridManager.CellType.BUILDABLE)


# -- 2. Grid dimensions -------------------------------------------------------

func test_grid_dimensions() -> void:
	# 20 columns (outer array), each with 15 rows (inner array)
	assert_int(GridManager.grid.size()).is_equal(20)
	for x: int in range(GridManager.GRID_WIDTH):
		assert_int(GridManager.grid[x].size()).is_equal(15)


# -- 3. get_cell returns correct type for in-bounds cell ----------------------

func test_get_cell_in_bounds() -> void:
	# Default grid is all BUILDABLE
	assert_int(GridManager.get_cell(Vector2i(5, 5))).is_equal(GridManager.CellType.BUILDABLE)
	# Manually set a cell and verify get_cell reflects it
	GridManager.grid[3][7] = GridManager.CellType.PATH
	assert_int(GridManager.get_cell(Vector2i(3, 7))).is_equal(GridManager.CellType.PATH)


# -- 4. get_cell out of bounds returns UNBUILDABLE ----------------------------

func test_get_cell_out_of_bounds() -> void:
	assert_int(GridManager.get_cell(Vector2i(20, 0))).is_equal(GridManager.CellType.UNBUILDABLE)
	assert_int(GridManager.get_cell(Vector2i(0, 15))).is_equal(GridManager.CellType.UNBUILDABLE)
	assert_int(GridManager.get_cell(Vector2i(100, 100))).is_equal(GridManager.CellType.UNBUILDABLE)


# -- 5. get_cell with negative coordinates returns UNBUILDABLE ----------------

func test_get_cell_negative_coords() -> void:
	assert_int(GridManager.get_cell(Vector2i(-1, 0))).is_equal(GridManager.CellType.UNBUILDABLE)
	assert_int(GridManager.get_cell(Vector2i(0, -1))).is_equal(GridManager.CellType.UNBUILDABLE)
	assert_int(GridManager.get_cell(Vector2i(-5, -5))).is_equal(GridManager.CellType.UNBUILDABLE)


# -- 6. is_cell_buildable returns true for BUILDABLE cell ---------------------

func test_is_cell_buildable_true() -> void:
	assert_bool(GridManager.is_cell_buildable(Vector2i(10, 7))).is_true()


# -- 7. is_cell_buildable returns false for TOWER cell ------------------------

func test_is_cell_buildable_false_tower() -> void:
	GridManager.grid[5][5] = GridManager.CellType.TOWER
	assert_bool(GridManager.is_cell_buildable(Vector2i(5, 5))).is_false()


# -- 8. is_cell_buildable returns false for PATH cell -------------------------

func test_is_cell_buildable_false_path() -> void:
	GridManager.grid[2][3] = GridManager.CellType.PATH
	assert_bool(GridManager.is_cell_buildable(Vector2i(2, 3))).is_false()


# -- 9. load_map_data populates spawn and exit points -------------------------

func test_load_map_data_sets_spawns_exits() -> void:
	var map_grid: Array = []
	for x: int in range(GridManager.GRID_WIDTH):
		var col: Array = []
		for y: int in range(GridManager.GRID_HEIGHT):
			col.append(GridManager.CellType.BUILDABLE)
		map_grid.append(col)

	var spawns: Array[Vector2i] = [Vector2i(0, 7)]
	var exits: Array[Vector2i] = [Vector2i(19, 7)]

	GridManager.load_map_data(map_grid, spawns, exits)

	assert_int(GridManager.spawn_points.size()).is_equal(1)
	assert_object(GridManager.spawn_points[0]).is_equal(Vector2i(0, 7))
	assert_int(GridManager.exit_points.size()).is_equal(1)
	assert_object(GridManager.exit_points[0]).is_equal(Vector2i(19, 7))


# -- 10. load_map_data marks spawn cells in grid -----------------------------

func test_load_map_data_marks_spawn_cells() -> void:
	var map_grid: Array = []
	for x: int in range(GridManager.GRID_WIDTH):
		var col: Array = []
		for y: int in range(GridManager.GRID_HEIGHT):
			col.append(GridManager.CellType.BUILDABLE)
		map_grid.append(col)

	var spawns: Array[Vector2i] = [Vector2i(0, 7)]
	var exits: Array[Vector2i] = [Vector2i(19, 7)]

	GridManager.load_map_data(map_grid, spawns, exits)

	assert_int(GridManager.grid[0][7]).is_equal(GridManager.CellType.SPAWN)
	assert_int(GridManager.grid[19][7]).is_equal(GridManager.CellType.EXIT)


# -- 11. place_tower sets cell to TOWER ---------------------------------------

func test_place_tower_sets_cell() -> void:
	_setup_minimal_map()
	var tower_node: Node = auto_free(Node.new())
	# Place away from the path row (y=0) so we don't block the path
	var pos := Vector2i(5, 5)
	var result: bool = GridManager.place_tower(pos, tower_node)
	assert_bool(result).is_true()
	assert_int(GridManager.get_cell(pos)).is_equal(GridManager.CellType.TOWER)


# -- 12. place_tower stores the tower node reference --------------------------

func test_place_tower_stores_reference() -> void:
	_setup_minimal_map()
	var tower_node: Node = auto_free(Node.new())
	var pos := Vector2i(8, 8)
	GridManager.place_tower(pos, tower_node)
	assert_object(GridManager.get_tower_at(pos)).is_same(tower_node)


# -- 13. place_tower fails on unbuildable cell --------------------------------

func test_place_tower_fails_on_unbuildable() -> void:
	_setup_minimal_map()
	var tower_node: Node = auto_free(Node.new())
	GridManager.grid[3][3] = GridManager.CellType.UNBUILDABLE
	var result: bool = GridManager.place_tower(Vector2i(3, 3), tower_node)
	assert_bool(result).is_false()
	# Cell should remain UNBUILDABLE, not changed to TOWER
	assert_int(GridManager.get_cell(Vector2i(3, 3))).is_equal(GridManager.CellType.UNBUILDABLE)


# -- 14. place_tower fails if it would block path ----------------------------

func test_place_tower_fails_if_blocks_path() -> void:
	_setup_minimal_map()
	# Block the entire first row except spawn and exit by placing towers on y=0.
	# First, fill y=1..14 with UNBUILDABLE so the ONLY path is through y=0.
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(1, GridManager.GRID_HEIGHT):
			GridManager.grid[x][y] = GridManager.CellType.UNBUILDABLE
	PathfindingSystem.recalculate()

	# Now try to place a tower on the only open row at a middle cell.
	# This should fail because it would block the path from spawn to exit.
	var tower_node: Node = auto_free(Node.new())
	var blocking_pos := Vector2i(10, 0)
	var result: bool = GridManager.place_tower(blocking_pos, tower_node)
	assert_bool(result).is_false()
	# Cell should remain BUILDABLE since placement was rejected
	assert_int(GridManager.get_cell(blocking_pos)).is_equal(GridManager.CellType.BUILDABLE)


# -- 15. remove_tower restores cell to BUILDABLE ------------------------------

func test_remove_tower_restores_buildable() -> void:
	_setup_minimal_map()
	var tower_node: Node = auto_free(Node.new())
	var pos := Vector2i(5, 5)
	GridManager.place_tower(pos, tower_node)
	assert_int(GridManager.get_cell(pos)).is_equal(GridManager.CellType.TOWER)
	GridManager.remove_tower(pos)
	assert_int(GridManager.get_cell(pos)).is_equal(GridManager.CellType.BUILDABLE)


# -- 16. remove_tower clears the tower reference ------------------------------

func test_remove_tower_clears_reference() -> void:
	_setup_minimal_map()
	var tower_node: Node = auto_free(Node.new())
	var pos := Vector2i(5, 5)
	GridManager.place_tower(pos, tower_node)
	assert_object(GridManager.get_tower_at(pos)).is_same(tower_node)
	GridManager.remove_tower(pos)
	assert_object(GridManager.get_tower_at(pos)).is_null()


# -- 17. grid_to_world conversion --------------------------------------------

func test_grid_to_world_conversion() -> void:
	# (0,0) -> center of cell = (32, 32)
	var world_0_0: Vector2 = GridManager.grid_to_world(Vector2i(0, 0))
	assert_float(world_0_0.x).is_equal(32.0)
	assert_float(world_0_0.y).is_equal(32.0)
	# (1,1) -> (64 + 32, 64 + 32) = (96, 96)
	var world_1_1: Vector2 = GridManager.grid_to_world(Vector2i(1, 1))
	assert_float(world_1_1.x).is_equal(96.0)
	assert_float(world_1_1.y).is_equal(96.0)
	# (19,14) -> last cell = (19*64 + 32, 14*64 + 32) = (1248, 928)
	var world_max: Vector2 = GridManager.grid_to_world(Vector2i(19, 14))
	assert_float(world_max.x).is_equal(1248.0)
	assert_float(world_max.y).is_equal(928.0)


# -- 18. world_to_grid conversion --------------------------------------------

func test_world_to_grid_conversion() -> void:
	# (32, 32) -> center of (0,0) cell -> (0, 0)
	var grid_0_0: Vector2i = GridManager.world_to_grid(Vector2(32.0, 32.0))
	assert_object(grid_0_0).is_equal(Vector2i(0, 0))
	# (100, 100) -> int(100)/64 = 1, int(100)/64 = 1 -> (1, 1)
	var grid_1_1: Vector2i = GridManager.world_to_grid(Vector2(100.0, 100.0))
	assert_object(grid_1_1).is_equal(Vector2i(1, 1))
	# (63, 63) -> int(63)/64 = 0 -> (0, 0) (still in first cell)
	var grid_edge: Vector2i = GridManager.world_to_grid(Vector2(63.0, 63.0))
	assert_object(grid_edge).is_equal(Vector2i(0, 0))
	# (64, 64) -> exactly at cell boundary -> (1, 1)
	var grid_boundary: Vector2i = GridManager.world_to_grid(Vector2(64.0, 64.0))
	assert_object(grid_boundary).is_equal(Vector2i(1, 1))


# -- 19. is_in_bounds edge cases ----------------------------------------------

func test_is_in_bounds_edges() -> void:
	# Corners and edges
	assert_bool(GridManager.is_in_bounds(Vector2i(0, 0))).is_true()
	assert_bool(GridManager.is_in_bounds(Vector2i(19, 14))).is_true()
	# Just outside
	assert_bool(GridManager.is_in_bounds(Vector2i(20, 14))).is_false()
	assert_bool(GridManager.is_in_bounds(Vector2i(19, 15))).is_false()
	# Negative
	assert_bool(GridManager.is_in_bounds(Vector2i(-1, 0))).is_false()
	assert_bool(GridManager.is_in_bounds(Vector2i(0, -1))).is_false()


# -- 20. can_place_tower combines buildable + path check ---------------------

func test_can_place_tower_combines_checks() -> void:
	_setup_minimal_map()
	# A buildable cell that doesn't block path should be placeable
	assert_bool(GridManager.can_place_tower(Vector2i(5, 5))).is_true()
	# An unbuildable cell should not be placeable
	GridManager.grid[3][3] = GridManager.CellType.UNBUILDABLE
	assert_bool(GridManager.can_place_tower(Vector2i(3, 3))).is_false()
	# A cell on a TOWER should not be placeable
	GridManager.grid[4][4] = GridManager.CellType.TOWER
	assert_bool(GridManager.can_place_tower(Vector2i(4, 4))).is_false()


# -- 21. tower_placed signal emitted on successful placement -----------------

func test_tower_placed_signal_emitted() -> void:
	_setup_minimal_map()
	var tower_node: Node = auto_free(Node.new())
	var pos := Vector2i(5, 5)
	monitor_signals(GridManager, false)
	GridManager.place_tower(pos, tower_node)
	await assert_signal(GridManager).wait_until(500).is_emitted(
		"tower_placed", [pos])


# -- 22. tower_removed signal emitted on removal ----------------------------

func test_tower_removed_signal_emitted() -> void:
	_setup_minimal_map()
	var tower_node: Node = auto_free(Node.new())
	var pos := Vector2i(5, 5)
	GridManager.place_tower(pos, tower_node)
	monitor_signals(GridManager, false)
	GridManager.remove_tower(pos)
	await assert_signal(GridManager).wait_until(500).is_emitted(
		"tower_removed", [pos])


# -- 23. grid_updated signal emitted on placement and removal ----------------

func test_grid_updated_signal_emitted() -> void:
	_setup_minimal_map()
	var tower_node: Node = auto_free(Node.new())
	var pos := Vector2i(5, 5)

	# Test signal on placement
	monitor_signals(GridManager, false)
	GridManager.place_tower(pos, tower_node)
	await assert_signal(GridManager).wait_until(500).is_emitted("grid_updated")

	# Test signal on removal
	monitor_signals(GridManager, false)
	GridManager.remove_tower(pos)
	await assert_signal(GridManager).wait_until(500).is_emitted("grid_updated")
