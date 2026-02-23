extends MapBase

## River Delta - Three islands separated by two vertical rivers with bridge crossings.
## Three spawn points on the left, three exits on the right. Bridges connect islands
## via PATH corridors, allowing enemies to cross between lanes.

const MAP_SPAWNS: Array[Vector2i] = [Vector2i(0, 2), Vector2i(0, 7), Vector2i(0, 12)]
const MAP_EXITS: Array[Vector2i] = [Vector2i(19, 2), Vector2i(19, 7), Vector2i(19, 12)]

# Vertical river column positions
const RIVER_COLUMNS: Array[int] = [7, 13]

# Horizontal path lane rows (one per spawn/exit pair)
const PATH_ROWS: Array[int] = [2, 7, 12]

# Bridge crossing rows -- where rivers become PATH instead of UNBUILDABLE.
# Placed at the same y as the path lanes so enemies can cross directly.
# Also add extra bridges between lanes to enable cross-pathing.
const BRIDGE_ROWS: Array[int] = [2, 5, 7, 10, 12]


func _setup_grid() -> void:
	var grid: Array = []
	for x: int in range(GridManager.GRID_WIDTH):
		var column: Array = []
		for y: int in range(GridManager.GRID_HEIGHT):
			column.append(GridManager.CellType.BUILDABLE)
		grid.append(column)

	# Carve horizontal path lanes
	for y: int in PATH_ROWS:
		for x: int in range(GridManager.GRID_WIDTH):
			grid[x][y] = GridManager.CellType.PATH

	# Carve vertical rivers (UNBUILDABLE), with bridge gaps (PATH)
	for river_x: int in RIVER_COLUMNS:
		for y: int in range(GridManager.GRID_HEIGHT):
			if y in BRIDGE_ROWS:
				grid[river_x][y] = GridManager.CellType.PATH
			else:
				grid[river_x][y] = GridManager.CellType.UNBUILDABLE

	GridManager.load_map_data(grid, MAP_SPAWNS, MAP_EXITS)
	PathfindingSystem.recalculate()


func get_map_name() -> String:
	return "River Delta"


func get_spawn_points() -> Array[Vector2i]:
	return MAP_SPAWNS


func get_exit_points() -> Array[Vector2i]:
	return MAP_EXITS


func _get_custom_tile_textures() -> Dictionary:
	return {
		GridManager.CellType.UNBUILDABLE: "res://assets/sprites/tiles/river.png",
		GridManager.CellType.PATH: "res://assets/sprites/tiles/bridge.png",
	}
