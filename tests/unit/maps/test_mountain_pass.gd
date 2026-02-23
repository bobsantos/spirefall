extends GdUnitTestSuite

## Unit tests for MountainPass map.
## Covers: inheritance, metadata, grid layout (S-curve walls, chokepoints),
## cell type distribution, pathfinding validity, and tower placement rules.


# -- Helpers -------------------------------------------------------------------

static var _mountain_script: GDScript = null


func _load_scripts() -> void:
	if _mountain_script == null:
		_mountain_script = load("res://scripts/maps/MountainPass.gd") as GDScript


## Create a MountainPass node without calling _ready() (avoids texture loads).
func _create_mountain_pass() -> Node2D:
	var node := Node2D.new()
	node.set_script(_mountain_script)
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


## Count cells of a given type in the current grid.
func _count_cells(cell_type: GridManager.CellType) -> int:
	var count: int = 0
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			if GridManager.get_cell(Vector2i(x, y)) == cell_type:
				count += 1
	return count


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_load_scripts()


func after() -> void:
	_mountain_script = null


func before_test() -> void:
	_reset_grid_manager()
	_reset_pathfinding()


# ==============================================================================
# SECTION 1: Inheritance and Metadata
# ==============================================================================

# -- 1.1 MountainPass extends MapBase -----------------------------------------

func test_mountain_pass_extends_map_base() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	assert_bool(node is MapBase).is_true()


# -- 1.2 MountainPass extends Node2D ------------------------------------------

func test_mountain_pass_extends_node2d() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	assert_bool(node is Node2D).is_true()


# -- 1.3 get_map_name returns "Mountain Pass" ---------------------------------

func test_mountain_pass_map_name() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	assert_str(node.get_map_name()).is_equal("Mountain Pass")


# -- 1.4 MAP_SPAWN constant is (0, 2) ----------------------------------------

func test_mountain_pass_spawn_constant() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	assert_bool(node.MAP_SPAWN == Vector2i(0, 2)).is_true()


# -- 1.5 MAP_EXIT constant is (19, 12) ----------------------------------------

func test_mountain_pass_exit_constant() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	assert_bool(node.MAP_EXIT == Vector2i(19, 12)).is_true()


# ==============================================================================
# SECTION 2: Spawn and Exit Points
# ==============================================================================

# -- 2.1 get_spawn_points returns [(0, 2)] ------------------------------------

func test_mountain_pass_spawn_points() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	var spawns: Array[Vector2i] = node.get_spawn_points()
	assert_int(spawns.size()).is_equal(1)
	assert_bool(spawns[0] == Vector2i(0, 2)).is_true()


# -- 2.2 get_exit_points returns [(19, 12)] -----------------------------------

func test_mountain_pass_exit_points() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	var exits: Array[Vector2i] = node.get_exit_points()
	assert_int(exits.size()).is_equal(1)
	assert_bool(exits[0] == Vector2i(19, 12)).is_true()


# -- 2.3 _setup_grid sets spawn cell to SPAWN type ----------------------------

func test_setup_grid_spawn_cell_type() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	assert_int(GridManager.get_cell(Vector2i(0, 2))).is_equal(GridManager.CellType.SPAWN)


# -- 2.4 _setup_grid sets exit cell to EXIT type ------------------------------

func test_setup_grid_exit_cell_type() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	assert_int(GridManager.get_cell(Vector2i(19, 12))).is_equal(GridManager.CellType.EXIT)


# -- 2.5 _setup_grid registers spawn_points in GridManager --------------------

func test_setup_grid_registers_spawn_points() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	assert_int(GridManager.spawn_points.size()).is_equal(1)
	assert_bool(GridManager.spawn_points[0] == Vector2i(0, 2)).is_true()


# -- 2.6 _setup_grid registers exit_points in GridManager ---------------------

func test_setup_grid_registers_exit_points() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	assert_int(GridManager.exit_points.size()).is_equal(1)
	assert_bool(GridManager.exit_points[0] == Vector2i(19, 12)).is_true()


# ==============================================================================
# SECTION 3: Wall Layout (UNBUILDABLE Cells)
# ==============================================================================

# -- 3.1 UNBUILDABLE count is between 30-40% of total (90-120 cells) ----------

func test_unbuildable_count_in_range() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	var unbuildable_count: int = _count_cells(GridManager.CellType.UNBUILDABLE)
	var total_cells: int = GridManager.GRID_WIDTH * GridManager.GRID_HEIGHT  # 300
	assert_int(unbuildable_count).is_greater_equal(90)
	assert_int(unbuildable_count).is_less_equal(120)


# -- 3.2 Horizontal wall exists at y=5 (partial, with gap on right) -----------

func test_horizontal_wall_y5() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	# Wall should cover most of the row
	var wall_count: int = 0
	for x: int in range(GridManager.GRID_WIDTH):
		if GridManager.get_cell(Vector2i(x, 5)) == GridManager.CellType.UNBUILDABLE:
			wall_count += 1
	# Expect a substantial wall (at least 12 cells) but not the full width
	assert_int(wall_count).is_greater_equal(12)
	assert_int(wall_count).is_less(GridManager.GRID_WIDTH)


# -- 3.3 Gap exists in y=5 wall for path traversal ----------------------------

func test_horizontal_wall_y5_has_gap() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	# At least one cell in row y=5 must NOT be UNBUILDABLE (gap for pathing)
	var has_gap: bool = false
	for x: int in range(GridManager.GRID_WIDTH):
		var cell: int = GridManager.get_cell(Vector2i(x, 5))
		if cell != GridManager.CellType.UNBUILDABLE:
			has_gap = true
			break
	assert_bool(has_gap).is_true()


# -- 3.4 Horizontal wall exists at y=10 (partial, with gap on left) -----------

func test_horizontal_wall_y10() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	var wall_count: int = 0
	for x: int in range(GridManager.GRID_WIDTH):
		if GridManager.get_cell(Vector2i(x, 10)) == GridManager.CellType.UNBUILDABLE:
			wall_count += 1
	assert_int(wall_count).is_greater_equal(12)
	assert_int(wall_count).is_less(GridManager.GRID_WIDTH)


# -- 3.5 Gap exists in y=10 wall for path traversal ---------------------------

func test_horizontal_wall_y10_has_gap() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	var has_gap: bool = false
	for x: int in range(GridManager.GRID_WIDTH):
		var cell: int = GridManager.get_cell(Vector2i(x, 10))
		if cell != GridManager.CellType.UNBUILDABLE:
			has_gap = true
			break
	assert_bool(has_gap).is_true()


# -- 3.6 Walls on opposite sides create S-curve (y=5 gap right, y=10 gap left)

func test_s_curve_gap_positions() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	# y=5 wall gap should be on the right side (x >= 15)
	var y5_gap_right: bool = false
	for x: int in range(15, GridManager.GRID_WIDTH):
		if GridManager.get_cell(Vector2i(x, 5)) != GridManager.CellType.UNBUILDABLE:
			y5_gap_right = true
			break
	assert_bool(y5_gap_right).is_true()

	# y=10 wall gap should be on the left side (x <= 4)
	var y10_gap_left: bool = false
	for x: int in range(0, 5):
		if GridManager.get_cell(Vector2i(x, 10)) != GridManager.CellType.UNBUILDABLE:
			y10_gap_left = true
			break
	assert_bool(y10_gap_left).is_true()


# ==============================================================================
# SECTION 4: Pathfinding
# ==============================================================================

# -- 4.1 Valid path exists from spawn to exit ----------------------------------

func test_valid_path_exists() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	var path: PackedVector2Array = PathfindingSystem.get_path_points(
		Vector2i(0, 2), Vector2i(19, 12)
	)
	assert_bool(path.size() > 0).is_true()


# -- 4.2 is_path_valid returns true after setup --------------------------------

func test_is_path_valid_after_setup() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	assert_bool(PathfindingSystem.is_path_valid()).is_true()


# -- 4.3 Path is longer than Manhattan distance (S-curve forces detour) --------

func test_path_longer_than_manhattan() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	var path: PackedVector2Array = PathfindingSystem.get_path_points(
		Vector2i(0, 2), Vector2i(19, 12)
	)
	# Manhattan distance = |19-0| + |12-2| = 29
	# S-curve path should be significantly longer
	assert_int(path.size()).is_greater(29)


# -- 4.4 Path navigates through both wall gaps --------------------------------

func test_path_traverses_wall_gaps() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	var path: PackedVector2Array = PathfindingSystem.get_path_points(
		Vector2i(0, 2), Vector2i(19, 12)
	)
	# Path must cross y=5 and y=10 at some point (traversing both walls)
	var crosses_y5: bool = false
	var crosses_y10: bool = false
	for i: int in range(path.size() - 1):
		var curr_y: int = int(path[i].y)
		var next_y: int = int(path[i + 1].y)
		if (curr_y <= 5 and next_y >= 5) or (curr_y >= 5 and next_y <= 5):
			crosses_y5 = true
		if (curr_y <= 10 and next_y >= 10) or (curr_y >= 10 and next_y <= 10):
			crosses_y10 = true
	assert_bool(crosses_y5).is_true()
	assert_bool(crosses_y10).is_true()


# ==============================================================================
# SECTION 5: PATH Cells (Default Route)
# ==============================================================================

# -- 5.1 PATH cells exist in the grid -----------------------------------------

func test_path_cells_exist() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	var path_count: int = _count_cells(GridManager.CellType.PATH)
	assert_int(path_count).is_greater(0)


# -- 5.2 PATH cells form a connected route (not random scattered cells) --------

func test_path_cells_are_connected() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	# Verify path cells exist in each section of the S-curve:
	# Top section (y < 5), middle section (5 < y < 10), bottom section (y > 10)
	var path_in_top: bool = false
	var path_in_mid: bool = false
	var path_in_bottom: bool = false
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			var cell: int = GridManager.get_cell(Vector2i(x, y))
			if cell == GridManager.CellType.PATH or cell == GridManager.CellType.SPAWN or cell == GridManager.CellType.EXIT:
				if y < 5:
					path_in_top = true
				elif y > 5 and y < 10:
					path_in_mid = true
				elif y > 10:
					path_in_bottom = true
	assert_bool(path_in_top).is_true()
	assert_bool(path_in_mid).is_true()
	assert_bool(path_in_bottom).is_true()


# ==============================================================================
# SECTION 6: BUILDABLE Cells (Player Mazing Space)
# ==============================================================================

# -- 6.1 BUILDABLE cells exist for player tower placement ---------------------

func test_buildable_cells_exist() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	var buildable_count: int = _count_cells(GridManager.CellType.BUILDABLE)
	assert_int(buildable_count).is_greater(0)


# -- 6.2 BUILDABLE cells are at least 30% of total (player has mazing space) --

func test_buildable_count_sufficient() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	var buildable_count: int = _count_cells(GridManager.CellType.BUILDABLE)
	# At least 90 buildable cells (30%) for meaningful mazing
	assert_int(buildable_count).is_greater_equal(90)


# -- 6.3 BUILDABLE cells exist in multiple sections (not all in one area) ------

func test_buildable_cells_distributed() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	var buildable_top: int = 0  # y < 5
	var buildable_mid: int = 0  # 5 < y < 10
	var buildable_bot: int = 0  # y > 10
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			if GridManager.get_cell(Vector2i(x, y)) == GridManager.CellType.BUILDABLE:
				if y < 5:
					buildable_top += 1
				elif y > 5 and y < 10:
					buildable_mid += 1
				elif y > 10:
					buildable_bot += 1
	assert_int(buildable_top).is_greater(0)
	assert_int(buildable_mid).is_greater(0)
	assert_int(buildable_bot).is_greater(0)


# ==============================================================================
# SECTION 7: Tower Placement Rules
# ==============================================================================

# -- 7.1 UNBUILDABLE wall cells reject tower placement ------------------------

func test_wall_cells_not_buildable() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	# Pick some cells we know are UNBUILDABLE (y=5 wall, y=10 wall)
	# Find the first UNBUILDABLE cell to test
	var found_unbuildable: bool = false
	for x: int in range(GridManager.GRID_WIDTH):
		if GridManager.get_cell(Vector2i(x, 5)) == GridManager.CellType.UNBUILDABLE:
			assert_bool(GridManager.is_cell_buildable(Vector2i(x, 5))).is_false()
			found_unbuildable = true
			break
	assert_bool(found_unbuildable).is_true()


# -- 7.2 BUILDABLE cells accept tower placement (is_cell_buildable) -----------

func test_buildable_cells_accept_towers() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	# Find the first BUILDABLE cell
	var found_buildable: bool = false
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			if GridManager.get_cell(Vector2i(x, y)) == GridManager.CellType.BUILDABLE:
				assert_bool(GridManager.is_cell_buildable(Vector2i(x, y))).is_true()
				found_buildable = true
				break
		if found_buildable:
			break
	assert_bool(found_buildable).is_true()


# -- 7.3 PATH cells reject tower placement ------------------------------------

func test_path_cells_not_buildable() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	var found_path: bool = false
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			if GridManager.get_cell(Vector2i(x, y)) == GridManager.CellType.PATH:
				assert_bool(GridManager.is_cell_buildable(Vector2i(x, y))).is_false()
				found_path = true
				break
		if found_path:
			break
	assert_bool(found_path).is_true()


# -- 7.4 SPAWN cell rejects tower placement -----------------------------------

func test_spawn_cell_not_buildable() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	assert_bool(GridManager.is_cell_buildable(Vector2i(0, 2))).is_false()


# -- 7.5 EXIT cell rejects tower placement ------------------------------------

func test_exit_cell_not_buildable() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	assert_bool(GridManager.is_cell_buildable(Vector2i(19, 12))).is_false()


# ==============================================================================
# SECTION 8: Custom Tile Textures
# ==============================================================================

# -- 8.1 _get_custom_tile_textures returns 1 override -------------------------

func test_custom_textures_count() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	var custom: Dictionary = node._get_custom_tile_textures()
	assert_int(custom.size()).is_equal(1)


# -- 8.2 UNBUILDABLE overridden to mountain_wall.png --------------------------

func test_custom_texture_unbuildable_is_mountain_wall() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	var custom: Dictionary = node._get_custom_tile_textures()
	assert_bool(custom.has(GridManager.CellType.UNBUILDABLE)).is_true()
	assert_str(custom[GridManager.CellType.UNBUILDABLE]).is_equal(
		"res://assets/sprites/tiles/mountain_wall.png"
	)


# -- 8.3 _get_tile_texture_path returns mountain_wall.png for UNBUILDABLE -----

func test_tile_texture_path_unbuildable() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	var path: String = node._get_tile_texture_path(GridManager.CellType.UNBUILDABLE)
	assert_str(path).is_equal("res://assets/sprites/tiles/mountain_wall.png")


# -- 8.4 Non-overridden types still use base paths ----------------------------

func test_non_overridden_types_use_base_paths() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	assert_str(node._get_tile_texture_path(GridManager.CellType.BUILDABLE)).is_equal(
		MapBase.TILE_TEXTURES[GridManager.CellType.BUILDABLE]
	)
	assert_str(node._get_tile_texture_path(GridManager.CellType.PATH)).is_equal(
		MapBase.TILE_TEXTURES[GridManager.CellType.PATH]
	)
	assert_str(node._get_tile_texture_path(GridManager.CellType.SPAWN)).is_equal(
		MapBase.TILE_TEXTURES[GridManager.CellType.SPAWN]
	)
	assert_str(node._get_tile_texture_path(GridManager.CellType.EXIT)).is_equal(
		MapBase.TILE_TEXTURES[GridManager.CellType.EXIT]
	)


# ==============================================================================
# SECTION 9: Grid Completeness
# ==============================================================================

# -- 9.1 Every cell is one of the valid types (no gaps) -----------------------

func test_all_cells_have_valid_types() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
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


# -- 9.2 Total cell count is exactly 300 (20x15) ------------------------------

func test_total_cell_count() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	var total: int = 0
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			total += 1
	assert_int(total).is_equal(300)


# -- 9.3 Exactly 1 SPAWN and 1 EXIT cell --------------------------------------

func test_exactly_one_spawn_one_exit() -> void:
	var node: Node2D = auto_free(_create_mountain_pass())
	node._setup_grid()
	var spawn_count: int = _count_cells(GridManager.CellType.SPAWN)
	var exit_count: int = _count_cells(GridManager.CellType.EXIT)
	assert_int(spawn_count).is_equal(1)
	assert_int(exit_count).is_equal(1)
