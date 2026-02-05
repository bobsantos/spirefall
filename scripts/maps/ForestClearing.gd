extends Node2D

## Forest Clearing - Starting map. Open field, full mazing freedom.
## Spawn at top-left, exit at bottom-right.

const MAP_SPAWN: Vector2i = Vector2i(0, 7)
const MAP_EXIT: Vector2i = Vector2i(19, 7)

# Tile texture paths keyed by CellType
const TILE_TEXTURES: Dictionary = {
	GridManager.CellType.BUILDABLE: "res://assets/sprites/tiles/buildable.png",
	GridManager.CellType.PATH: "res://assets/sprites/tiles/path.png",
	GridManager.CellType.UNBUILDABLE: "res://assets/sprites/tiles/unbuildable.png",
	GridManager.CellType.SPAWN: "res://assets/sprites/tiles/spawn.png",
	GridManager.CellType.EXIT: "res://assets/sprites/tiles/exit.png",
}

# 2D array [x][y] of Sprite2D references for updating tiles
var _tile_sprites: Array = []


func _ready() -> void:
	_setup_grid()
	_create_tile_visuals()
	GridManager.grid_updated.connect(_on_grid_updated)


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


func _create_tile_visuals() -> void:
	_tile_sprites.clear()
	for x: int in range(GridManager.GRID_WIDTH):
		var column: Array = []
		for y: int in range(GridManager.GRID_HEIGHT):
			var tile_sprite := Sprite2D.new()
			tile_sprite.position = GridManager.grid_to_world(Vector2i(x, y))
			tile_sprite.texture = _get_tile_texture(GridManager.get_cell(Vector2i(x, y)))
			add_child(tile_sprite)
			column.append(tile_sprite)
		_tile_sprites.append(column)


func _on_grid_updated() -> void:
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			var cell_type: GridManager.CellType = GridManager.get_cell(Vector2i(x, y))
			# TOWER cells keep the buildable texture; the tower node renders itself
			var visual_type: GridManager.CellType = cell_type
			if cell_type == GridManager.CellType.TOWER:
				visual_type = GridManager.CellType.BUILDABLE
			_tile_sprites[x][y].texture = _get_tile_texture(visual_type)


func _get_tile_texture(cell_type: GridManager.CellType) -> Texture2D:
	if cell_type in TILE_TEXTURES:
		return load(TILE_TEXTURES[cell_type])
	# Fallback: treat unknown types as buildable
	return load(TILE_TEXTURES[GridManager.CellType.BUILDABLE])
