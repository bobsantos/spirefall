extends GdUnitTestSuite

## Unit tests for VolcanicCaldera.gd -- center-spawn map with 4 edge exits.
## Covers: extends MapBase, map name, spawn/exit points, grid layout,
## UNBUILDABLE center ring, UNBUILDABLE exit borders, PATH routes,
## pathfinding validity, cell type counts, and tower placement rules.


# -- Helpers -------------------------------------------------------------------

static var _caldera_script: GDScript = null


func _load_scripts() -> void:
	if _caldera_script == null:
		_caldera_script = load("res://scripts/maps/VolcanicCaldera.gd") as GDScript


## Create a VolcanicCaldera node without calling _ready().
func _create_caldera() -> Node2D:
	var node := Node2D.new()
	node.set_script(_caldera_script)
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
	_caldera_script = null


func before_test() -> void:
	_reset_grid_manager()
	_reset_pathfinding()


# ==============================================================================
# SECTION 1: Class Identity
# ==============================================================================

# -- 1.1 VolcanicCaldera extends MapBase ---------------------------------------

func test_extends_map_base() -> void:
	var node: Node2D = auto_free(_create_caldera())
	assert_bool(node is MapBase).is_true()


# -- 1.2 VolcanicCaldera extends Node2D ---------------------------------------

func test_extends_node2d() -> void:
	var node: Node2D = auto_free(_create_caldera())
	assert_bool(node is Node2D).is_true()


# ==============================================================================
# SECTION 2: Map Metadata
# ==============================================================================

# -- 2.1 get_map_name returns "Volcanic Caldera" ------------------------------

func test_get_map_name() -> void:
	var node: Node2D = auto_free(_create_caldera())
	assert_str(node.get_map_name()).is_equal("Volcanic Caldera")


# -- 2.2 get_spawn_points returns center spawn --------------------------------

func test_get_spawn_points() -> void:
	var node: Node2D = auto_free(_create_caldera())
	var spawns: Array[Vector2i] = node.get_spawn_points()
	assert_int(spawns.size()).is_equal(1)
	assert_bool(spawns[0] == Vector2i(10, 7)).is_true()


# -- 2.3 get_exit_points returns 4 edge exits ---------------------------------

func test_get_exit_points() -> void:
	var node: Node2D = auto_free(_create_caldera())
	var exits: Array[Vector2i] = node.get_exit_points()
	assert_int(exits.size()).is_equal(4)
	assert_bool(exits.has(Vector2i(0, 7))).is_true()
	assert_bool(exits.has(Vector2i(19, 7))).is_true()
	assert_bool(exits.has(Vector2i(10, 0))).is_true()
	assert_bool(exits.has(Vector2i(10, 14))).is_true()


# -- 2.4 Constants match expected values --------------------------------------

func test_constants() -> void:
	var node: Node2D = auto_free(_create_caldera())
	assert_bool(node.MAP_SPAWN == Vector2i(10, 7)).is_true()
	assert_bool(node.MAP_EXITS[0] == Vector2i(0, 7)).is_true()
	assert_bool(node.MAP_EXITS[1] == Vector2i(19, 7)).is_true()
	assert_bool(node.MAP_EXITS[2] == Vector2i(10, 0)).is_true()
	assert_bool(node.MAP_EXITS[3] == Vector2i(10, 14)).is_true()


# ==============================================================================
# SECTION 3: Grid Setup - Spawn and Exit Cells
# ==============================================================================

# -- 3.1 Spawn cell is marked as SPAWN ----------------------------------------

func test_spawn_cell_is_spawn_type() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	assert_int(GridManager.get_cell(Vector2i(10, 7))).is_equal(GridManager.CellType.SPAWN)


# -- 3.2 All 4 exit cells are marked as EXIT ----------------------------------

func test_exit_cells_are_exit_type() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	assert_int(GridManager.get_cell(Vector2i(0, 7))).is_equal(GridManager.CellType.EXIT)
	assert_int(GridManager.get_cell(Vector2i(19, 7))).is_equal(GridManager.CellType.EXIT)
	assert_int(GridManager.get_cell(Vector2i(10, 0))).is_equal(GridManager.CellType.EXIT)
	assert_int(GridManager.get_cell(Vector2i(10, 14))).is_equal(GridManager.CellType.EXIT)


# -- 3.3 GridManager spawn_points set correctly --------------------------------

func test_grid_manager_spawn_points() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	assert_int(GridManager.spawn_points.size()).is_equal(1)
	assert_bool(GridManager.spawn_points[0] == Vector2i(10, 7)).is_true()


# -- 3.4 GridManager exit_points set correctly ---------------------------------

func test_grid_manager_exit_points() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	assert_int(GridManager.exit_points.size()).is_equal(4)


# ==============================================================================
# SECTION 4: Center UNBUILDABLE Ring
# ==============================================================================

# -- 4.1 Cells within Manhattan distance 2 of center are UNBUILDABLE or PATH/SPAWN

func test_center_ring_unbuildable() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	var center := Vector2i(10, 7)
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			var dist: int = abs(x - center.x) + abs(y - center.y)
			if dist <= 2:
				var cell: int = GridManager.get_cell(Vector2i(x, y))
				# Should NOT be BUILDABLE within the center ring
				assert_bool(cell != GridManager.CellType.BUILDABLE).override_failure_message(
					"Cell (%d, %d) in center ring should not be BUILDABLE" % [x, y]
				).is_true()


# -- 4.2 Specific center ring cells are UNBUILDABLE ---------------------------

func test_specific_center_ring_cells() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	# Cells at Manhattan distance 1 from center (not on path lines)
	# (10,7) is SPAWN, (9,7) and (11,7) are PATH (horizontal), (10,6) and (10,8) are PATH (vertical)
	# Diagonal neighbors at distance 2: (9,6), (11,6), (9,8), (11,8)
	for pos: Vector2i in [Vector2i(9, 6), Vector2i(11, 6), Vector2i(9, 8), Vector2i(11, 8)]:
		assert_int(GridManager.get_cell(pos)).override_failure_message(
			"Cell (%d, %d) should be UNBUILDABLE" % [pos.x, pos.y]
		).is_equal(GridManager.CellType.UNBUILDABLE)


# -- 4.3 Tower placement fails on center ring UNBUILDABLE cells ----------------

func test_tower_placement_fails_on_center_ring() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	# (9, 6) should be UNBUILDABLE in center ring
	assert_bool(GridManager.is_cell_buildable(Vector2i(9, 6))).is_false()
	assert_bool(GridManager.is_cell_buildable(Vector2i(11, 8))).is_false()


# ==============================================================================
# SECTION 5: PATH Cells Along Default Routes
# ==============================================================================

# -- 5.1 Horizontal path from center to left exit (y=7) -----------------------

func test_horizontal_path_left() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	# Cells between spawn and left exit on y=7 should be PATH (except SPAWN/EXIT)
	for x: int in range(1, 10):
		var cell: int = GridManager.get_cell(Vector2i(x, 7))
		assert_bool(cell == GridManager.CellType.PATH).override_failure_message(
			"Cell (%d, 7) should be PATH but was %d" % [x, cell]
		).is_true()


# -- 5.2 Horizontal path from center to right exit (y=7) ----------------------

func test_horizontal_path_right() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	for x: int in range(11, 19):
		var cell: int = GridManager.get_cell(Vector2i(x, 7))
		assert_bool(cell == GridManager.CellType.PATH).override_failure_message(
			"Cell (%d, 7) should be PATH but was %d" % [x, cell]
		).is_true()


# -- 5.3 Vertical path from center to top exit (x=10) -------------------------

func test_vertical_path_top() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	for y: int in range(1, 7):
		var cell: int = GridManager.get_cell(Vector2i(10, y))
		assert_bool(cell == GridManager.CellType.PATH).override_failure_message(
			"Cell (10, %d) should be PATH but was %d" % [y, cell]
		).is_true()


# -- 5.4 Vertical path from center to bottom exit (x=10) ----------------------

func test_vertical_path_bottom() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	for y: int in range(8, 14):
		var cell: int = GridManager.get_cell(Vector2i(10, y))
		assert_bool(cell == GridManager.CellType.PATH).override_failure_message(
			"Cell (10, %d) should be PATH but was %d" % [y, cell]
		).is_true()


# ==============================================================================
# SECTION 6: Exit Border UNBUILDABLE Zones
# ==============================================================================

# -- 6.1 Left exit border cells are UNBUILDABLE --------------------------------

func test_left_exit_border_unbuildable() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	# Cells adjacent to left exit (0,7) should be UNBUILDABLE (not PATH/BUILDABLE)
	# (0,6) and (0,8) are border cells
	assert_int(GridManager.get_cell(Vector2i(0, 6))).is_equal(GridManager.CellType.UNBUILDABLE)
	assert_int(GridManager.get_cell(Vector2i(0, 8))).is_equal(GridManager.CellType.UNBUILDABLE)


# -- 6.2 Right exit border cells are UNBUILDABLE -------------------------------

func test_right_exit_border_unbuildable() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	assert_int(GridManager.get_cell(Vector2i(19, 6))).is_equal(GridManager.CellType.UNBUILDABLE)
	assert_int(GridManager.get_cell(Vector2i(19, 8))).is_equal(GridManager.CellType.UNBUILDABLE)


# -- 6.3 Top exit border cells are UNBUILDABLE ---------------------------------

func test_top_exit_border_unbuildable() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	assert_int(GridManager.get_cell(Vector2i(9, 0))).is_equal(GridManager.CellType.UNBUILDABLE)
	assert_int(GridManager.get_cell(Vector2i(11, 0))).is_equal(GridManager.CellType.UNBUILDABLE)


# -- 6.4 Bottom exit border cells are UNBUILDABLE -----------------------------

func test_bottom_exit_border_unbuildable() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	assert_int(GridManager.get_cell(Vector2i(9, 14))).is_equal(GridManager.CellType.UNBUILDABLE)
	assert_int(GridManager.get_cell(Vector2i(11, 14))).is_equal(GridManager.CellType.UNBUILDABLE)


# ==============================================================================
# SECTION 7: Pathfinding Validity
# ==============================================================================

# -- 7.1 Path valid from spawn to left exit -----------------------------------

func test_path_valid_to_left_exit() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	var path: PackedVector2Array = PathfindingSystem.get_path_points(
		Vector2i(10, 7), Vector2i(0, 7)
	)
	assert_bool(path.size() > 0).is_true()


# -- 7.2 Path valid from spawn to right exit ----------------------------------

func test_path_valid_to_right_exit() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	var path: PackedVector2Array = PathfindingSystem.get_path_points(
		Vector2i(10, 7), Vector2i(19, 7)
	)
	assert_bool(path.size() > 0).is_true()


# -- 7.3 Path valid from spawn to top exit ------------------------------------

func test_path_valid_to_top_exit() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	var path: PackedVector2Array = PathfindingSystem.get_path_points(
		Vector2i(10, 7), Vector2i(10, 0)
	)
	assert_bool(path.size() > 0).is_true()


# -- 7.4 Path valid from spawn to bottom exit ---------------------------------

func test_path_valid_to_bottom_exit() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	var path: PackedVector2Array = PathfindingSystem.get_path_points(
		Vector2i(10, 7), Vector2i(10, 14)
	)
	assert_bool(path.size() > 0).is_true()


# -- 7.5 is_path_valid returns true for all spawn-exit pairs ------------------

func test_is_path_valid() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	assert_bool(PathfindingSystem.is_path_valid()).is_true()


# ==============================================================================
# SECTION 8: Cell Type Distribution
# ==============================================================================

# -- 8.1 Majority of cells are BUILDABLE (for mazing) -------------------------

func test_majority_buildable() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	var buildable_count: int = 0
	var total: int = GridManager.GRID_WIDTH * GridManager.GRID_HEIGHT
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			if GridManager.get_cell(Vector2i(x, y)) == GridManager.CellType.BUILDABLE:
				buildable_count += 1
	# Should be at least 60% buildable for mazing
	assert_bool(buildable_count > total * 0.60).override_failure_message(
		"Only %d/%d cells are BUILDABLE (expected > 60%%)" % [buildable_count, total]
	).is_true()


# -- 8.2 UNBUILDABLE count is reasonable (15-25% of grid) ---------------------

func test_unbuildable_count_reasonable() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	var unbuildable_count: int = 0
	var total: int = GridManager.GRID_WIDTH * GridManager.GRID_HEIGHT
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			if GridManager.get_cell(Vector2i(x, y)) == GridManager.CellType.UNBUILDABLE:
				unbuildable_count += 1
	var pct: float = float(unbuildable_count) / float(total)
	assert_bool(pct >= 0.03 and pct <= 0.25).override_failure_message(
		"UNBUILDABLE count %d (%.1f%%) outside expected 3-25%% range" % [unbuildable_count, pct * 100]
	).is_true()


# -- 8.3 PATH count matches expected route lengths ----------------------------

func test_path_cell_count() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	var path_count: int = 0
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			if GridManager.get_cell(Vector2i(x, y)) == GridManager.CellType.PATH:
				path_count += 1
	# Horizontal path: x=1..9 and x=11..18 on y=7 = 18 cells
	# Vertical path: y=1..6 and y=8..13 on x=10 = 12 cells
	# Total PATH = 30 (center is SPAWN, exits are EXIT)
	# Minus any overlaps -- but paths cross at center which is SPAWN
	assert_bool(path_count >= 25 and path_count <= 35).override_failure_message(
		"PATH count %d outside expected 25-35 range" % path_count
	).is_true()


# -- 8.4 Exactly 1 SPAWN cell and 4 EXIT cells --------------------------------

func test_spawn_and_exit_counts() -> void:
	var node: Node2D = auto_free(_create_caldera())
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
	assert_int(spawn_count).is_equal(1)
	assert_int(exit_count).is_equal(4)


# ==============================================================================
# SECTION 9: Tower Placement
# ==============================================================================

# -- 9.1 Tower placement works on BUILDABLE cells far from center -------------

func test_tower_placement_on_buildable() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	# (2, 2) should be BUILDABLE (far from center and exits)
	assert_bool(GridManager.is_cell_buildable(Vector2i(2, 2))).is_true()


# -- 9.2 Tower placement fails on PATH cells ----------------------------------

func test_tower_placement_fails_on_path() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	# (5, 7) is a horizontal PATH cell
	assert_bool(GridManager.is_cell_buildable(Vector2i(5, 7))).is_false()


# -- 9.3 Tower placement fails on SPAWN cell ----------------------------------

func test_tower_placement_fails_on_spawn() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	assert_bool(GridManager.is_cell_buildable(Vector2i(10, 7))).is_false()


# -- 9.4 Tower placement fails on EXIT cells ----------------------------------

func test_tower_placement_fails_on_exit() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	assert_bool(GridManager.is_cell_buildable(Vector2i(0, 7))).is_false()
	assert_bool(GridManager.is_cell_buildable(Vector2i(19, 7))).is_false()
	assert_bool(GridManager.is_cell_buildable(Vector2i(10, 0))).is_false()
	assert_bool(GridManager.is_cell_buildable(Vector2i(10, 14))).is_false()


# ==============================================================================
# SECTION 10: Custom Tile Textures
# ==============================================================================

# -- 10.1 _get_custom_tile_textures returns 1 override -------------------------

func test_custom_textures_count() -> void:
	var node: Node2D = auto_free(_create_caldera())
	var custom: Dictionary = node._get_custom_tile_textures()
	assert_int(custom.size()).is_equal(1)


# -- 10.2 UNBUILDABLE overridden to lava.png -----------------------------------

func test_custom_texture_unbuildable_is_lava() -> void:
	var node: Node2D = auto_free(_create_caldera())
	var custom: Dictionary = node._get_custom_tile_textures()
	assert_bool(custom.has(GridManager.CellType.UNBUILDABLE)).is_true()
	assert_str(custom[GridManager.CellType.UNBUILDABLE]).is_equal(
		"res://assets/sprites/tiles/lava.png"
	)


# -- 10.3 _get_tile_texture_path returns lava.png for UNBUILDABLE --------------

func test_tile_texture_path_unbuildable() -> void:
	var node: Node2D = auto_free(_create_caldera())
	var path: String = node._get_tile_texture_path(GridManager.CellType.UNBUILDABLE)
	assert_str(path).is_equal("res://assets/sprites/tiles/lava.png")


# -- 10.4 Non-overridden types still use base paths ---------------------------

func test_non_overridden_types_use_base_paths() -> void:
	var node: Node2D = auto_free(_create_caldera())
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
# SECTION 11: Grid Completeness
# ==============================================================================

# -- 11.1 Every cell is a valid CellType (no default BUILDABLE leak) -----------

func test_all_cells_valid_type() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	var valid_types: Array = [
		GridManager.CellType.PATH,
		GridManager.CellType.BUILDABLE,
		GridManager.CellType.UNBUILDABLE,
		GridManager.CellType.TOWER,
		GridManager.CellType.SPAWN,
		GridManager.CellType.EXIT,
	]
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			var cell: int = GridManager.get_cell(Vector2i(x, y))
			assert_bool(valid_types.has(cell)).override_failure_message(
				"Cell (%d, %d) has invalid type %d" % [x, y, cell]
			).is_true()


# -- 11.2 No TOWER cells exist after initial setup ----------------------------

func test_no_tower_cells_after_setup() -> void:
	var node: Node2D = auto_free(_create_caldera())
	node._setup_grid()
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			assert_bool(GridManager.get_cell(Vector2i(x, y)) != GridManager.CellType.TOWER).override_failure_message(
				"Cell (%d, %d) should not be TOWER after setup" % [x, y]
			).is_true()
