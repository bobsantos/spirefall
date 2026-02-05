class_name GridManagerClass
extends Node

## Manages the 2D grid, tower placement validation, and cell state.

enum CellType { PATH, BUILDABLE, UNBUILDABLE, TOWER, SPAWN, EXIT }

signal tower_placed(grid_pos: Vector2i)
signal tower_removed(grid_pos: Vector2i)
signal grid_updated()

const GRID_WIDTH: int = 20
const GRID_HEIGHT: int = 15
const CELL_SIZE: int = 64

var grid: Array = []  # 2D array of CellType
var _tower_map: Dictionary = {}  # Vector2i -> Tower node reference

var spawn_points: Array[Vector2i] = []
var exit_points: Array[Vector2i] = []


func _ready() -> void:
	_initialize_grid()


func _initialize_grid() -> void:
	grid.clear()
	for x: int in range(GRID_WIDTH):
		var column: Array = []
		for y: int in range(GRID_HEIGHT):
			column.append(CellType.BUILDABLE)
		grid.append(column)


func load_map_data(map_grid: Array, spawns: Array[Vector2i], exits: Array[Vector2i]) -> void:
	grid = map_grid.duplicate(true)
	spawn_points = spawns.duplicate()
	exit_points = exits.duplicate()
	for sp: Vector2i in spawn_points:
		grid[sp.x][sp.y] = CellType.SPAWN
	for ep: Vector2i in exit_points:
		grid[ep.x][ep.y] = CellType.EXIT
	grid_updated.emit()


func get_cell(grid_pos: Vector2i) -> CellType:
	if not _is_in_bounds(grid_pos):
		return CellType.UNBUILDABLE
	return grid[grid_pos.x][grid_pos.y]


func is_cell_buildable(grid_pos: Vector2i) -> bool:
	return get_cell(grid_pos) == CellType.BUILDABLE


func would_block_path(grid_pos: Vector2i) -> bool:
	grid[grid_pos.x][grid_pos.y] = CellType.TOWER
	var blocked: bool = not PathfindingSystem.is_path_valid()
	grid[grid_pos.x][grid_pos.y] = CellType.BUILDABLE
	return blocked


func place_tower(grid_pos: Vector2i, tower_node: Node) -> bool:
	if not is_cell_buildable(grid_pos):
		return false
	if would_block_path(grid_pos):
		return false
	grid[grid_pos.x][grid_pos.y] = CellType.TOWER
	_tower_map[grid_pos] = tower_node
	PathfindingSystem.recalculate()
	tower_placed.emit(grid_pos)
	grid_updated.emit()
	return true


func remove_tower(grid_pos: Vector2i) -> void:
	if get_cell(grid_pos) != CellType.TOWER:
		return
	grid[grid_pos.x][grid_pos.y] = CellType.BUILDABLE
	_tower_map.erase(grid_pos)
	PathfindingSystem.recalculate()
	tower_removed.emit(grid_pos)
	grid_updated.emit()


func get_tower_at(grid_pos: Vector2i) -> Node:
	return _tower_map.get(grid_pos)


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * CELL_SIZE + CELL_SIZE / 2, grid_pos.y * CELL_SIZE + CELL_SIZE / 2)


func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x) / CELL_SIZE, int(world_pos.y) / CELL_SIZE)


func _is_in_bounds(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < GRID_WIDTH and grid_pos.y >= 0 and grid_pos.y < GRID_HEIGHT
