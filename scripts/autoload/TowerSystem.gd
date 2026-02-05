class_name TowerSystemClass
extends Node

## Factory for tower creation, upgrading, selling, and fusion.

signal tower_created(tower: Node)
signal tower_upgraded(tower: Node)
signal tower_sold(tower: Node, refund: int)

var _tower_scene: PackedScene = preload("res://scenes/towers/BaseTower.tscn")
var _active_towers: Array[Node] = []


func create_tower(tower_data: TowerData, grid_pos: Vector2i) -> Node:
	if not EconomyManager.can_afford(tower_data.cost):
		return null
	if not GridManager.is_cell_buildable(grid_pos):
		return null
	if GridManager.would_block_path(grid_pos):
		return null

	EconomyManager.spend_gold(tower_data.cost)

	var tower: Node = _tower_scene.instantiate()
	tower.tower_data = tower_data
	tower.grid_position = grid_pos
	tower.position = GridManager.grid_to_world(grid_pos)

	GridManager.place_tower(grid_pos, tower)
	_active_towers.append(tower)
	tower_created.emit(tower)
	return tower


func upgrade_tower(tower: Node) -> bool:
	var upgrade_data: TowerData = tower.tower_data.upgrade_to
	if upgrade_data == null:
		return false
	var cost: int = upgrade_data.cost - tower.tower_data.cost
	if not EconomyManager.can_afford(cost):
		return false
	EconomyManager.spend_gold(cost)
	tower.tower_data = upgrade_data
	tower.apply_tower_data()
	tower_upgraded.emit(tower)
	return true


func sell_tower(tower: Node) -> void:
	var refund_pct: float = 0.75 if GameManager.game_state == GameManager.GameState.BUILD_PHASE else 0.50
	var refund: int = int(tower.tower_data.cost * refund_pct)
	EconomyManager.add_gold(refund)

	var grid_pos: Vector2i = tower.grid_position
	GridManager.remove_tower(grid_pos)
	_active_towers.erase(tower)
	tower_sold.emit(tower, refund)
	tower.queue_free()


func get_active_towers() -> Array[Node]:
	return _active_towers
