class_name PathfindingSystemClass
extends Node

## Wraps AStarGrid2D for enemy pathfinding with dynamic recalculation.

signal path_recalculated()

var _astar: AStarGrid2D


func _ready() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, GridManager.GRID_WIDTH, GridManager.GRID_HEIGHT)
	_astar.cell_size = Vector2(1, 1)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()


func recalculate() -> void:
	for x: int in range(GridManager.GRID_WIDTH):
		for y: int in range(GridManager.GRID_HEIGHT):
			var pos := Vector2i(x, y)
			var cell: int = GridManager.get_cell(pos)
			var solid: bool = (cell == GridManager.CellType.TOWER or cell == GridManager.CellType.UNBUILDABLE)
			_astar.set_point_solid(pos, solid)
	_astar.update()
	path_recalculated.emit()


func get_path_points(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	if _astar.is_point_solid(from) or _astar.is_point_solid(to):
		return PackedVector2Array()
	return _astar.get_point_path(from, to)


func get_world_path(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	var grid_path: PackedVector2Array = get_path_points(from, to)
	var world_path: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in grid_path:
		var grid_pos := Vector2i(int(point.x), int(point.y))
		world_path.append(GridManager.grid_to_world(grid_pos))
	return world_path


func is_path_valid() -> bool:
	recalculate()
	for spawn: Vector2i in GridManager.spawn_points:
		for exit_point: Vector2i in GridManager.exit_points:
			var path: PackedVector2Array = get_path_points(spawn, exit_point)
			if path.is_empty():
				return false
	return true


func get_enemy_path() -> PackedVector2Array:
	if GridManager.spawn_points.is_empty() or GridManager.exit_points.is_empty():
		return PackedVector2Array()
	return get_world_path(GridManager.spawn_points[0], GridManager.exit_points[0])


func get_flying_path() -> PackedVector2Array:
	## Returns a straight-line path from spawn to exit for flying enemies.
	## Flying enemies ignore the tower maze entirely -- they only need start and end points.
	if GridManager.spawn_points.is_empty() or GridManager.exit_points.is_empty():
		return PackedVector2Array()
	var start: Vector2 = GridManager.grid_to_world(GridManager.spawn_points[0])
	var end: Vector2 = GridManager.grid_to_world(GridManager.exit_points[0])
	var path := PackedVector2Array()
	path.append(start)
	path.append(end)
	return path
