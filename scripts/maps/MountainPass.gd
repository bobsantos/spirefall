extends MapBase

## Mountain Pass - S-curve map with pre-built mountain walls creating
## natural chokepoints. Players have less mazing freedom but must
## strategically place towers in the corridors between walls.
## Spawn at top-left, exit at bottom-right.

const MAP_SPAWN: Vector2i = Vector2i(0, 2)
const MAP_EXIT: Vector2i = Vector2i(19, 12)


func _setup_grid() -> void:
	var grid: Array = []
	for x: int in range(GridManager.GRID_WIDTH):
		var column: Array = []
		for y: int in range(GridManager.GRID_HEIGHT):
			column.append(GridManager.CellType.BUILDABLE)
		grid.append(column)

	# --- Mountain borders ---
	# Top ridge: y=0, x=3..19
	for x: int in range(3, 20):
		grid[x][0] = GridManager.CellType.UNBUILDABLE
	# Bottom ridge: y=14, x=0..16
	for x: int in range(0, 17):
		grid[x][14] = GridManager.CellType.UNBUILDABLE

	# --- Left cliff face (x=0) ---
	# y=0,1,3,4 (gap at y=2 for spawn)
	for y: int in [0, 1, 3, 4]:
		grid[0][y] = GridManager.CellType.UNBUILDABLE
	# y=6..13 (continuous left wall through middle and lower sections)
	for y: int in range(6, 14):
		grid[0][y] = GridManager.CellType.UNBUILDABLE

	# --- Right cliff face (x=19) ---
	# y=1..4 (top section, y=0 covered by top ridge)
	for y: int in range(1, 5):
		grid[19][y] = GridManager.CellType.UNBUILDABLE
	# y=6..9 (middle section wall)
	for y: int in range(6, 10):
		grid[19][y] = GridManager.CellType.UNBUILDABLE
	# y=11,13 (lower section, gap at y=12 for exit)
	for y: int in [11, 13]:
		grid[19][y] = GridManager.CellType.UNBUILDABLE

	# --- Horizontal wall 1: y=5, x=0..16 (gap at x=17..19 on right) ---
	for x: int in range(0, 17):
		grid[x][5] = GridManager.CellType.UNBUILDABLE

	# --- Horizontal wall 2: y=10, x=3..19 (gap at x=0..2 on left) ---
	for x: int in range(3, 20):
		grid[x][10] = GridManager.CellType.UNBUILDABLE

	# --- Inner mountain features ---
	# Vertical outcrop near spawn corridor: x=3, y=1,3,4
	for y: int in [1, 3, 4]:
		grid[3][y] = GridManager.CellType.UNBUILDABLE
	# Vertical outcrop near exit corridor: x=16, y=11,13
	for y: int in [11, 13]:
		grid[16][y] = GridManager.CellType.UNBUILDABLE
	# Central rock island: x=8..12, y=7..8
	for x: int in range(8, 13):
		for y: int in range(7, 9):
			grid[x][y] = GridManager.CellType.UNBUILDABLE

	# --- Default PATH cells (suggested S-curve route) ---
	# Top corridor: y=2, x=1..17 (going right)
	for x: int in range(1, 18):
		grid[x][2] = GridManager.CellType.PATH
	# Right descent: x=17, y=3..6 (through gap in y=5 wall)
	for y: int in range(3, 7):
		grid[17][y] = GridManager.CellType.PATH
	# Middle corridor: y=6, x=2..16 (going left)
	for x: int in range(2, 17):
		grid[x][6] = GridManager.CellType.PATH
	# Left descent: x=2, y=7..12 (through gap in y=10 wall, down to bottom corridor)
	for y: int in range(7, 13):
		grid[2][y] = GridManager.CellType.PATH
	# Bottom corridor: y=12, x=3..18 (going right to exit)
	for x: int in range(3, 19):
		grid[x][12] = GridManager.CellType.PATH

	GridManager.load_map_data(grid, [MAP_SPAWN], [MAP_EXIT])
	PathfindingSystem.recalculate()


func get_map_name() -> String:
	return "Mountain Pass"


func get_spawn_points() -> Array[Vector2i]:
	return [MAP_SPAWN]


func get_exit_points() -> Array[Vector2i]:
	return [MAP_EXIT]


func _get_custom_tile_textures() -> Dictionary:
	return {
		GridManager.CellType.UNBUILDABLE: "res://assets/sprites/tiles/mountain_wall.png",
	}
