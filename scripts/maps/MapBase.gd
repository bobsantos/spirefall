class_name MapBase
extends Node2D

## Base class for all map scenes. Handles shared tile visual logic:
## creating sprites, updating them on grid changes, and texture mapping.
## Subclasses must override _setup_grid(), get_map_name(), get_spawn_points(),
## and get_exit_points(). Optionally override _get_custom_tile_textures()
## to provide map-specific tile textures.

# Default tile texture paths keyed by CellType
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


## Override in subclass to configure the grid via GridManager.load_map_data().
func _setup_grid() -> void:
	pass


## Override in subclass to return the human-readable map name.
func get_map_name() -> String:
	return ""


## Override in subclass to return spawn point positions.
func get_spawn_points() -> Array[Vector2i]:
	return [] as Array[Vector2i]


## Override in subclass to return exit point positions.
func get_exit_points() -> Array[Vector2i]:
	return [] as Array[Vector2i]


## Override in subclass to provide map-specific tile texture overrides.
## Returned dictionary keys are CellType, values are resource paths (String).
func _get_custom_tile_textures() -> Dictionary:
	return {}


## Returns the merged tile textures: base TILE_TEXTURES with custom overrides applied.
func _get_merged_tile_textures() -> Dictionary:
	var merged: Dictionary = TILE_TEXTURES.duplicate()
	var custom: Dictionary = _get_custom_tile_textures()
	for key: int in custom:
		merged[key] = custom[key]
	return merged


## Creates a Sprite2D for each grid cell and stores references in _tile_sprites.
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


## Updates all tile sprites when the grid changes.
func _on_grid_updated() -> void:
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			var cell_type: GridManager.CellType = GridManager.get_cell(Vector2i(x, y))
			var visual_type: GridManager.CellType = _get_visual_type(cell_type)
			_tile_sprites[x][y].texture = _get_tile_texture(visual_type)


## Maps cell types to their visual representation. TOWER cells display as BUILDABLE
## because the tower node renders itself.
func _get_visual_type(cell_type: GridManager.CellType) -> GridManager.CellType:
	if cell_type == GridManager.CellType.TOWER:
		return GridManager.CellType.BUILDABLE
	return cell_type


## Returns the texture resource path for a given cell type, using merged textures.
func _get_tile_texture_path(cell_type: GridManager.CellType) -> String:
	var textures: Dictionary = _get_merged_tile_textures()
	if cell_type in textures:
		return textures[cell_type]
	# Fallback: treat unknown types as buildable
	return textures[GridManager.CellType.BUILDABLE]


## Loads and returns the texture for a given cell type.
func _get_tile_texture(cell_type: GridManager.CellType) -> Texture2D:
	var path: String = _get_tile_texture_path(cell_type)
	return load(path)
