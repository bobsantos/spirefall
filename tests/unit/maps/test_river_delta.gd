extends GdUnitTestSuite

## Unit tests for RiverDelta.gd map.
## Covers: class hierarchy, map metadata, grid layout (rivers, bridges, islands),
## spawn/exit configuration, pathfinding validity, and tower placement rules.


# -- Helpers -------------------------------------------------------------------

static var _river_script: GDScript = null


func _load_scripts() -> void:
	if _river_script == null:
		_river_script = load("res://scripts/maps/RiverDelta.gd") as GDScript


## Create a RiverDelta node without calling _ready() (avoids texture loads).
func _create_river_delta() -> Node2D:
	var node := Node2D.new()
	node.set_script(_river_script)
	return node


## Reset GridManager state to a clean slate.
func _reset_grid_manager() -> void:
	GridManager._initialize_grid()
	GridManager._tower_map.clear()
	GridManager.spawn_points.clear()
	GridManager.exit_points.clear()


## Reset PathfindingSystem state.
func _reset_pathfinding() -> void:
	PathfindingSystem._astar.region = Rect2i(0, 0, GridManager.GRID_WIDTH, GridManager.GRID_HEIGHT)
	PathfindingSystem._astar.cell_size = Vector2(1, 1)
	PathfindingSystem._astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	PathfindingSystem._astar.update()


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_load_scripts()


func after() -> void:
	_river_script = null


func before_test() -> void:
	_reset_grid_manager()
	_reset_pathfinding()


# ==============================================================================
# SECTION 1: Class Hierarchy and Metadata
# ==============================================================================

# -- 1.1 RiverDelta extends MapBase --------------------------------------------

func test_river_delta_extends_map_base() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	assert_bool(node is MapBase).is_true()


# -- 1.2 RiverDelta extends Node2D (via MapBase) -------------------------------

func test_river_delta_extends_node2d() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	assert_bool(node is Node2D).is_true()


# -- 1.3 get_map_name returns "River Delta" ------------------------------------

func test_river_delta_map_name() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	assert_str(node.get_map_name()).is_equal("River Delta")


# ==============================================================================
# SECTION 2: Spawn and Exit Points
# ==============================================================================

# -- 2.1 get_spawn_points returns 3 spawn points -------------------------------

func test_spawn_points_count() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	var spawns: Array[Vector2i] = node.get_spawn_points()
	assert_int(spawns.size()).is_equal(3)


# -- 2.2 Spawn points are at (0, 2), (0, 7), (0, 12) -------------------------

func test_spawn_points_positions() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	var spawns: Array[Vector2i] = node.get_spawn_points()
	assert_bool(spawns[0] == Vector2i(0, 2)).is_true()
	assert_bool(spawns[1] == Vector2i(0, 7)).is_true()
	assert_bool(spawns[2] == Vector2i(0, 12)).is_true()


# -- 2.3 get_exit_points returns 3 exit points --------------------------------

func test_exit_points_count() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	var exits: Array[Vector2i] = node.get_exit_points()
	assert_int(exits.size()).is_equal(3)


# -- 2.4 Exit points are at (19, 2), (19, 7), (19, 12) -----------------------

func test_exit_points_positions() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	var exits: Array[Vector2i] = node.get_exit_points()
	assert_bool(exits[0] == Vector2i(19, 2)).is_true()
	assert_bool(exits[1] == Vector2i(19, 7)).is_true()
	assert_bool(exits[2] == Vector2i(19, 12)).is_true()


# -- 2.5 Spawn cells are marked SPAWN in grid after setup ---------------------

func test_spawn_cells_marked_spawn() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	assert_int(GridManager.get_cell(Vector2i(0, 2))).is_equal(GridManager.CellType.SPAWN)
	assert_int(GridManager.get_cell(Vector2i(0, 7))).is_equal(GridManager.CellType.SPAWN)
	assert_int(GridManager.get_cell(Vector2i(0, 12))).is_equal(GridManager.CellType.SPAWN)


# -- 2.6 Exit cells are marked EXIT in grid after setup -----------------------

func test_exit_cells_marked_exit() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	assert_int(GridManager.get_cell(Vector2i(19, 2))).is_equal(GridManager.CellType.EXIT)
	assert_int(GridManager.get_cell(Vector2i(19, 7))).is_equal(GridManager.CellType.EXIT)
	assert_int(GridManager.get_cell(Vector2i(19, 12))).is_equal(GridManager.CellType.EXIT)


# -- 2.7 GridManager spawn_points set correctly after setup --------------------

func test_grid_manager_spawn_points_set() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	assert_int(GridManager.spawn_points.size()).is_equal(3)
	assert_bool(GridManager.spawn_points[0] == Vector2i(0, 2)).is_true()
	assert_bool(GridManager.spawn_points[1] == Vector2i(0, 7)).is_true()
	assert_bool(GridManager.spawn_points[2] == Vector2i(0, 12)).is_true()


# -- 2.8 GridManager exit_points set correctly after setup ---------------------

func test_grid_manager_exit_points_set() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	assert_int(GridManager.exit_points.size()).is_equal(3)
	assert_bool(GridManager.exit_points[0] == Vector2i(19, 2)).is_true()
	assert_bool(GridManager.exit_points[1] == Vector2i(19, 7)).is_true()
	assert_bool(GridManager.exit_points[2] == Vector2i(19, 12)).is_true()


# ==============================================================================
# SECTION 3: River Layout (UNBUILDABLE cells)
# ==============================================================================

# -- 3.1 River column x=7 has UNBUILDABLE cells (except bridges) ---------------

func test_river_column_7_unbuildable() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	var bridge_rows: Array = node.BRIDGE_ROWS
	for y: int in range(GridManager.GRID_HEIGHT):
		if y in bridge_rows:
			continue
		var cell: int = GridManager.get_cell(Vector2i(7, y))
		assert_int(cell).override_failure_message(
			"River cell (7, %d) should be UNBUILDABLE but was %d" % [y, cell]
		).is_equal(GridManager.CellType.UNBUILDABLE)


# -- 3.2 River column x=13 has UNBUILDABLE cells (except bridges) --------------

func test_river_column_13_unbuildable() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	var bridge_rows: Array = node.BRIDGE_ROWS
	for y: int in range(GridManager.GRID_HEIGHT):
		if y in bridge_rows:
			continue
		var cell: int = GridManager.get_cell(Vector2i(13, y))
		assert_int(cell).override_failure_message(
			"River cell (13, %d) should be UNBUILDABLE but was %d" % [y, cell]
		).is_equal(GridManager.CellType.UNBUILDABLE)


# -- 3.3 UNBUILDABLE count is reasonable (river cells ~25-35 range) -----------

func test_unbuildable_count_reasonable() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	var unbuildable_count: int = 0
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			if GridManager.get_cell(Vector2i(x, y)) == GridManager.CellType.UNBUILDABLE:
				unbuildable_count += 1
	# Two rivers of 15 cells minus bridge gaps each: expect roughly 20-30 UNBUILDABLE
	assert_bool(unbuildable_count >= 15).override_failure_message(
		"Too few UNBUILDABLE cells: %d (expected >= 15)" % unbuildable_count
	).is_true()
	assert_bool(unbuildable_count <= 35).override_failure_message(
		"Too many UNBUILDABLE cells: %d (expected <= 35)" % unbuildable_count
	).is_true()


# ==============================================================================
# SECTION 4: Bridge Cells (PATH type)
# ==============================================================================

# -- 4.1 Bridge cells at river x=7 are PATH -----------------------------------

func test_bridge_cells_river_7_are_path() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	var bridge_rows: Array = node.BRIDGE_ROWS
	for y: int in bridge_rows:
		var cell: int = GridManager.get_cell(Vector2i(7, y))
		assert_int(cell).override_failure_message(
			"Bridge cell (7, %d) should be PATH but was %d" % [y, cell]
		).is_equal(GridManager.CellType.PATH)


# -- 4.2 Bridge cells at river x=13 are PATH ----------------------------------

func test_bridge_cells_river_13_are_path() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	var bridge_rows: Array = node.BRIDGE_ROWS
	for y: int in bridge_rows:
		var cell: int = GridManager.get_cell(Vector2i(13, y))
		assert_int(cell).override_failure_message(
			"Bridge cell (13, %d) should be PATH but was %d" % [y, cell]
		).is_equal(GridManager.CellType.PATH)


# -- 4.3 At least 2 bridge rows exist per river --------------------------------

func test_at_least_two_bridge_rows() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	assert_bool(node.BRIDGE_ROWS.size() >= 2).override_failure_message(
		"Expected at least 2 bridge rows, got %d" % node.BRIDGE_ROWS.size()
	).is_true()


# -- 4.4 Bridge rows are within valid grid y range ----------------------------

func test_bridge_rows_within_grid_bounds() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	for y: int in node.BRIDGE_ROWS:
		assert_bool(y >= 0 and y < GridManager.GRID_HEIGHT).override_failure_message(
			"Bridge row y=%d is out of bounds" % y
		).is_true()


# ==============================================================================
# SECTION 5: Island Cells (BUILDABLE)
# ==============================================================================

# -- 5.1 Non-river, non-path, non-spawn, non-exit cells are BUILDABLE ---------

func test_island_cells_are_buildable() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	var river_columns: Array = node.RIVER_COLUMNS
	var bridge_rows: Array = node.BRIDGE_ROWS
	var spawns: Array[Vector2i] = node.get_spawn_points()
	var exits: Array[Vector2i] = node.get_exit_points()
	var path_rows: Array = node.PATH_ROWS

	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			var pos := Vector2i(x, y)
			var cell: int = GridManager.get_cell(pos)

			# Skip special cells
			if x in river_columns:
				continue  # river or bridge
			if y in path_rows:
				continue  # horizontal path lanes
			if pos in spawns or pos in exits:
				continue

			assert_int(cell).override_failure_message(
				"Island cell (%d, %d) should be BUILDABLE but was %d" % [x, y, cell]
			).is_equal(GridManager.CellType.BUILDABLE)


# -- 5.2 Left island has BUILDABLE cells (x < 7, non-path rows) ---------------

func test_left_island_has_buildable_cells() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	# Sample a few cells from the left island
	assert_int(GridManager.get_cell(Vector2i(3, 0))).is_equal(GridManager.CellType.BUILDABLE)
	assert_int(GridManager.get_cell(Vector2i(5, 5))).is_equal(GridManager.CellType.BUILDABLE)
	assert_int(GridManager.get_cell(Vector2i(2, 10))).is_equal(GridManager.CellType.BUILDABLE)


# -- 5.3 Middle island has BUILDABLE cells (8 <= x <= 12, non-path rows) ------

func test_middle_island_has_buildable_cells() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	# Sample cells between the two rivers
	assert_int(GridManager.get_cell(Vector2i(10, 0))).is_equal(GridManager.CellType.BUILDABLE)
	assert_int(GridManager.get_cell(Vector2i(9, 5))).is_equal(GridManager.CellType.BUILDABLE)
	assert_int(GridManager.get_cell(Vector2i(11, 10))).is_equal(GridManager.CellType.BUILDABLE)


# -- 5.4 Right island has BUILDABLE cells (x > 13, non-path rows) -------------

func test_right_island_has_buildable_cells() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	# Sample cells from the right island
	assert_int(GridManager.get_cell(Vector2i(15, 0))).is_equal(GridManager.CellType.BUILDABLE)
	assert_int(GridManager.get_cell(Vector2i(17, 5))).is_equal(GridManager.CellType.BUILDABLE)
	assert_int(GridManager.get_cell(Vector2i(16, 10))).is_equal(GridManager.CellType.BUILDABLE)


# ==============================================================================
# SECTION 6: Horizontal Path Lanes
# ==============================================================================

# -- 6.1 Horizontal path lanes exist at y=2, y=7, y=12 -----------------------

func test_horizontal_path_lanes_exist() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	# Check non-river, non-spawn/exit cells on path rows are PATH
	for y: int in [2, 7, 12]:
		for x: int in range(1, 19):  # exclude spawn (x=0) and exit (x=19)
			if x == 7 or x == 13:
				continue  # bridge cells checked separately
			var cell: int = GridManager.get_cell(Vector2i(x, y))
			assert_int(cell).override_failure_message(
				"Path lane cell (%d, %d) should be PATH but was %d" % [x, y, cell]
			).is_equal(GridManager.CellType.PATH)


# -- 6.2 PATH_ROWS constant contains correct values ---------------------------

func test_path_rows_constant() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	assert_bool(2 in node.PATH_ROWS).is_true()
	assert_bool(7 in node.PATH_ROWS).is_true()
	assert_bool(12 in node.PATH_ROWS).is_true()


# ==============================================================================
# SECTION 7: Pathfinding Validity
# ==============================================================================

# -- 7.1 PathfindingSystem.is_path_valid() returns true (all 9 combinations) --

func test_all_paths_valid() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	assert_bool(PathfindingSystem.is_path_valid()).is_true()


# -- 7.2 Path exists from spawn (0,2) to exit (19,2) --------------------------

func test_path_spawn_0_to_exit_0() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	var path: PackedVector2Array = PathfindingSystem.get_path_points(
		Vector2i(0, 2), Vector2i(19, 2)
	)
	assert_bool(path.size() > 0).override_failure_message(
		"No path from (0,2) to (19,2)"
	).is_true()


# -- 7.3 Path exists from spawn (0,7) to exit (19,7) --------------------------

func test_path_spawn_1_to_exit_1() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	var path: PackedVector2Array = PathfindingSystem.get_path_points(
		Vector2i(0, 7), Vector2i(19, 7)
	)
	assert_bool(path.size() > 0).override_failure_message(
		"No path from (0,7) to (19,7)"
	).is_true()


# -- 7.4 Path exists from spawn (0,12) to exit (19,12) ------------------------

func test_path_spawn_2_to_exit_2() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	var path: PackedVector2Array = PathfindingSystem.get_path_points(
		Vector2i(0, 12), Vector2i(19, 12)
	)
	assert_bool(path.size() > 0).override_failure_message(
		"No path from (0,12) to (19,12)"
	).is_true()


# -- 7.5 Cross-paths work: spawn (0,2) to exit (19,12) ------------------------

func test_cross_path_top_to_bottom() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	var path: PackedVector2Array = PathfindingSystem.get_path_points(
		Vector2i(0, 2), Vector2i(19, 12)
	)
	assert_bool(path.size() > 0).override_failure_message(
		"No cross-path from (0,2) to (19,12)"
	).is_true()


# -- 7.6 Cross-paths work: spawn (0,12) to exit (19,2) ------------------------

func test_cross_path_bottom_to_top() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	var path: PackedVector2Array = PathfindingSystem.get_path_points(
		Vector2i(0, 12), Vector2i(19, 2)
	)
	assert_bool(path.size() > 0).override_failure_message(
		"No cross-path from (0,12) to (19,2)"
	).is_true()


# -- 7.7 All 9 spawn-exit pairs have valid paths ------------------------------

func test_all_nine_spawn_exit_pairs() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	var spawns: Array[Vector2i] = node.get_spawn_points()
	var exits: Array[Vector2i] = node.get_exit_points()
	for spawn: Vector2i in spawns:
		for exit_pt: Vector2i in exits:
			var path: PackedVector2Array = PathfindingSystem.get_path_points(spawn, exit_pt)
			assert_bool(path.size() > 0).override_failure_message(
				"No path from (%d,%d) to (%d,%d)" % [spawn.x, spawn.y, exit_pt.x, exit_pt.y]
			).is_true()


# ==============================================================================
# SECTION 8: Tower Placement Rules
# ==============================================================================

# -- 8.1 Tower placement works on island BUILDABLE cell -----------------------

func test_tower_placement_on_buildable() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	# Pick a buildable island cell
	assert_bool(GridManager.is_cell_buildable(Vector2i(3, 0))).is_true()


# -- 8.2 Tower placement fails on river UNBUILDABLE cell -----------------------

func test_tower_placement_fails_on_river() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	# River cell at x=7 (non-bridge row)
	var bridge_rows: Array = node.BRIDGE_ROWS
	var test_y: int = 0
	for y: int in range(GridManager.GRID_HEIGHT):
		if y not in bridge_rows and y not in node.PATH_ROWS:
			test_y = y
			break
	assert_bool(GridManager.is_cell_buildable(Vector2i(7, test_y))).is_false()


# -- 8.3 Tower placement fails on bridge PATH cell ----------------------------

func test_tower_placement_fails_on_bridge() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	var bridge_rows: Array = node.BRIDGE_ROWS
	# Bridge at river x=7, first bridge row
	assert_bool(GridManager.is_cell_buildable(Vector2i(7, bridge_rows[0]))).is_false()


# -- 8.4 Tower placement fails on horizontal PATH lane cell -------------------

func test_tower_placement_fails_on_path_lane() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	# Path lane cell at (5, 7)
	assert_bool(GridManager.is_cell_buildable(Vector2i(5, 7))).is_false()


# -- 8.5 Tower placement fails on spawn cell ----------------------------------

func test_tower_placement_fails_on_spawn() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	assert_bool(GridManager.is_cell_buildable(Vector2i(0, 2))).is_false()


# -- 8.6 Tower placement fails on exit cell -----------------------------------

func test_tower_placement_fails_on_exit() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	assert_bool(GridManager.is_cell_buildable(Vector2i(19, 2))).is_false()


# ==============================================================================
# SECTION 9: Constants and Configuration
# ==============================================================================

# -- 9.1 RIVER_COLUMNS constant contains 7 and 13 ----------------------------

func test_river_columns_constant() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	assert_bool(7 in node.RIVER_COLUMNS).is_true()
	assert_bool(13 in node.RIVER_COLUMNS).is_true()


# -- 9.2 MAP_SPAWNS constant has 3 entries ------------------------------------

func test_map_spawns_constant() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	assert_int(node.MAP_SPAWNS.size()).is_equal(3)


# -- 9.3 MAP_EXITS constant has 3 entries -------------------------------------

func test_map_exits_constant() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	assert_int(node.MAP_EXITS.size()).is_equal(3)


# -- 9.4 _get_custom_tile_textures returns 2 overrides -------------------------

func test_custom_textures_count() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	var custom: Dictionary = node._get_custom_tile_textures()
	assert_int(custom.size()).is_equal(2)


# -- 9.5 UNBUILDABLE overridden to river.png -----------------------------------

func test_custom_texture_unbuildable_is_river() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	var custom: Dictionary = node._get_custom_tile_textures()
	assert_bool(custom.has(GridManager.CellType.UNBUILDABLE)).is_true()
	assert_str(custom[GridManager.CellType.UNBUILDABLE]).is_equal(
		"res://assets/sprites/tiles/river.png"
	)


# -- 9.6 PATH overridden to bridge.png ----------------------------------------

func test_custom_texture_path_is_bridge() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	var custom: Dictionary = node._get_custom_tile_textures()
	assert_bool(custom.has(GridManager.CellType.PATH)).is_true()
	assert_str(custom[GridManager.CellType.PATH]).is_equal(
		"res://assets/sprites/tiles/bridge.png"
	)


# -- 9.7 _get_tile_texture_path returns river.png for UNBUILDABLE -------------

func test_tile_texture_path_unbuildable() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	var path: String = node._get_tile_texture_path(GridManager.CellType.UNBUILDABLE)
	assert_str(path).is_equal("res://assets/sprites/tiles/river.png")


# -- 9.8 _get_tile_texture_path returns bridge.png for PATH --------------------

func test_tile_texture_path_path() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	var path: String = node._get_tile_texture_path(GridManager.CellType.PATH)
	assert_str(path).is_equal("res://assets/sprites/tiles/bridge.png")


# -- 9.9 Non-overridden types still use base paths ----------------------------

func test_non_overridden_types_use_base_paths() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	assert_str(node._get_tile_texture_path(GridManager.CellType.BUILDABLE)).is_equal(
		MapBase.TILE_TEXTURES[GridManager.CellType.BUILDABLE]
	)
	assert_str(node._get_tile_texture_path(GridManager.CellType.SPAWN)).is_equal(
		MapBase.TILE_TEXTURES[GridManager.CellType.SPAWN]
	)
	assert_str(node._get_tile_texture_path(GridManager.CellType.EXIT)).is_equal(
		MapBase.TILE_TEXTURES[GridManager.CellType.EXIT]
	)


# ==============================================================================
# SECTION 10: Grid Dimensions and Completeness
# ==============================================================================

# -- 10.1 Grid has correct dimensions after setup -----------------------------

func test_grid_dimensions_after_setup() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	assert_int(GridManager.grid.size()).is_equal(GridManager.GRID_WIDTH)
	for x: int in range(GridManager.GRID_WIDTH):
		assert_int(GridManager.grid[x].size()).is_equal(GridManager.GRID_HEIGHT)


# -- 10.2 Every cell is one of the expected types ----------------------------

func test_all_cells_have_valid_types() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	var valid_types: Array = [
		GridManager.CellType.PATH,
		GridManager.CellType.BUILDABLE,
		GridManager.CellType.UNBUILDABLE,
		GridManager.CellType.SPAWN,
		GridManager.CellType.EXIT,
	]
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			var cell: int = GridManager.get_cell(Vector2i(x, y))
			assert_bool(cell in valid_types).override_failure_message(
				"Cell (%d, %d) has invalid type %d" % [x, y, cell]
			).is_true()


# -- 10.3 Total PATH cells is reasonable (3 lanes + bridges) ------------------

func test_path_cell_count_reasonable() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	var path_count: int = 0
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			if GridManager.get_cell(Vector2i(x, y)) == GridManager.CellType.PATH:
				path_count += 1
	# 3 lanes * ~18 cells each (minus spawn/exit) + bridge cells
	# Expect roughly 50-60 PATH cells
	assert_bool(path_count >= 40).override_failure_message(
		"Too few PATH cells: %d (expected >= 40)" % path_count
	).is_true()
	assert_bool(path_count <= 70).override_failure_message(
		"Too many PATH cells: %d (expected <= 70)" % path_count
	).is_true()


# -- 10.4 Exactly 3 SPAWN cells and 3 EXIT cells ------------------------------

func test_spawn_and_exit_cell_counts() -> void:
	var node: Node2D = auto_free(_create_river_delta())
	node._setup_grid()
	var spawn_count: int = 0
	var exit_count: int = 0
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			var cell: int = GridManager.get_cell(Vector2i(x, y))
			if cell == GridManager.CellType.SPAWN:
				spawn_count += 1
			elif cell == GridManager.CellType.EXIT:
				exit_count += 1
	assert_int(spawn_count).is_equal(3)
	assert_int(exit_count).is_equal(3)
