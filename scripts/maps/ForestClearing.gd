extends MapBase

## Forest Clearing - Starting map. Open field, full mazing freedom.
## Spawn at top-left, exit at bottom-right.

const MAP_SPAWN: Vector2i = Vector2i(0, 7)
const MAP_EXIT: Vector2i = Vector2i(19, 7)


func _setup_grid() -> void:
	# Forest Clearing: entirely buildable except spawn/exit row path
	var grid: Array = []
	for x: int in range(GridManager.GRID_WIDTH):
		var column: Array = []
		for y: int in range(GridManager.GRID_HEIGHT):
			column.append(GridManager.CellType.BUILDABLE)
		grid.append(column)

	# Carve initial path: straight line across middle row (y=7)
	for x: int in range(GridManager.GRID_WIDTH):
		grid[x][7] = GridManager.CellType.PATH

	GridManager.load_map_data(grid, [MAP_SPAWN], [MAP_EXIT])
	PathfindingSystem.recalculate()


func get_map_name() -> String:
	return "Forest Clearing"


func get_spawn_points() -> Array[Vector2i]:
	return [MAP_SPAWN]


func get_exit_points() -> Array[Vector2i]:
	return [MAP_EXIT]
