extends MapBase

## Volcanic Caldera - Center-spawn map with 4 edge exits (4-star difficulty).
## Enemies radiate outward from the center in all 4 cardinal directions.
## Players must maze around cross-shaped default paths to slow enemies.

const MAP_SPAWN: Vector2i = Vector2i(10, 7)
const MAP_EXITS: Array[Vector2i] = [
	Vector2i(0, 7),   # Left
	Vector2i(19, 7),  # Right
	Vector2i(10, 0),  # Top
	Vector2i(10, 14), # Bottom
]

# Manhattan distance from center for the UNBUILDABLE ring
const CENTER_RING_RADIUS: int = 2


func _setup_grid() -> void:
	var grid: Array = []
	for x: int in range(GridManager.GRID_WIDTH):
		var column: Array = []
		for y: int in range(GridManager.GRID_HEIGHT):
			column.append(GridManager.CellType.BUILDABLE)
		grid.append(column)

	# Carve PATH lines from center to each exit along cardinal directions
	# Horizontal path (y=7): full width
	for x: int in range(GridManager.GRID_WIDTH):
		grid[x][7] = GridManager.CellType.PATH
	# Vertical path (x=10): full height
	for y: int in range(GridManager.GRID_HEIGHT):
		grid[10][y] = GridManager.CellType.PATH

	# UNBUILDABLE center ring: Manhattan distance <= 2 from center
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			var dist: int = abs(x - MAP_SPAWN.x) + abs(y - MAP_SPAWN.y)
			if dist <= CENTER_RING_RADIUS and grid[x][y] != GridManager.CellType.PATH:
				grid[x][y] = GridManager.CellType.UNBUILDABLE

	# UNBUILDABLE border cells around each exit (1 cell on each side perpendicular to path)
	# Left exit (0, 7) -- cells above and below
	grid[0][6] = GridManager.CellType.UNBUILDABLE
	grid[0][8] = GridManager.CellType.UNBUILDABLE
	# Right exit (19, 7) -- cells above and below
	grid[19][6] = GridManager.CellType.UNBUILDABLE
	grid[19][8] = GridManager.CellType.UNBUILDABLE
	# Top exit (10, 0) -- cells left and right
	grid[9][0] = GridManager.CellType.UNBUILDABLE
	grid[11][0] = GridManager.CellType.UNBUILDABLE
	# Bottom exit (10, 14) -- cells left and right
	grid[9][14] = GridManager.CellType.UNBUILDABLE
	grid[11][14] = GridManager.CellType.UNBUILDABLE

	GridManager.load_map_data(grid, [MAP_SPAWN], MAP_EXITS.duplicate())
	PathfindingSystem.recalculate()


func get_map_name() -> String:
	return "Volcanic Caldera"


func get_spawn_points() -> Array[Vector2i]:
	return [MAP_SPAWN]


func get_exit_points() -> Array[Vector2i]:
	return MAP_EXITS.duplicate()


func _get_custom_tile_textures() -> Dictionary:
	return {
		GridManager.CellType.UNBUILDABLE: "res://assets/sprites/tiles/lava.png",
	}
