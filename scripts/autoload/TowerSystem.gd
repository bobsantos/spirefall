class_name TowerSystemClass
extends Node

## Factory for tower creation, upgrading, selling, and fusion.

signal tower_created(tower: Node)
signal tower_upgraded(tower: Node)
signal tower_sold(tower: Node, refund: int)
signal tower_fused(tower: Node)
signal tower_ascended(tower: Node)
signal fusion_failed(tower: Node, reason: String)

const FUSE_FAIL_CANT_AFFORD := "Not enough gold"
const FUSE_FAIL_INVALID_COMBO := "Invalid fusion combination"
const FUSE_FAIL_NO_RESULT := "No fusion result exists"

const ASCEND_COST: int = 95
const ASCEND_MIN_SAME_ELEMENT: int = 3

# Maps element -> ascended resource path
const ASCENDED_PATHS: Dictionary = {
	"fire": "res://resources/towers/flame_spire_ascended.tres",
	"water": "res://resources/towers/tidal_obelisk_ascended.tres",
	"earth": "res://resources/towers/stone_bastion_ascended.tres",
	"wind": "res://resources/towers/gale_tower_ascended.tres",
	"lightning": "res://resources/towers/thunder_pylon_ascended.tres",
	"ice": "res://resources/towers/frost_sentinel_ascended.tres",
}

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


func _is_superior(tower: Node) -> bool:
	## A tower is Superior when it is tier 1 with no further upgrade path.
	if not tower or not tower.tower_data:
		return false
	return tower.tower_data.tier == 1 and tower.tower_data.upgrade_to == null


func _is_ascended(tower: Node) -> bool:
	## An Ascended tower has an ascended resource name (ends with " Ascended").
	if not tower or not tower.tower_data:
		return false
	return tower.tower_data.tower_name.ends_with(" Ascended")


func _count_same_element_towers(element: String) -> int:
	## Count tier-1 towers of the given element (base, enhanced, superior, ascended).
	var count: int = 0
	for t: Node in _active_towers:
		if not is_instance_valid(t) or not t.tower_data:
			continue
		if t.tower_data.tier == 1 and t.tower_data.element == element:
			count += 1
	return count


func can_ascend(tower: Node) -> bool:
	## Tower can ascend if it is Superior (not already Ascended), the player owns
	## 3+ same-element towers, and can afford the cost.
	if not _is_superior(tower):
		return false
	if _is_ascended(tower):
		return false
	var element: String = tower.tower_data.element
	if element not in ASCENDED_PATHS:
		return false
	if _count_same_element_towers(element) < ASCEND_MIN_SAME_ELEMENT:
		return false
	if not EconomyManager.can_afford(ASCEND_COST):
		return false
	return true


func ascend_tower(tower: Node) -> bool:
	## Upgrade a Superior tower to its Ascended variant.
	if not can_ascend(tower):
		return false
	var element: String = tower.tower_data.element
	var ascended_data: TowerData = load(ASCENDED_PATHS[element]) as TowerData
	if ascended_data == null:
		return false
	EconomyManager.spend_gold(ASCEND_COST)
	tower.tower_data = ascended_data
	tower.apply_tower_data()
	tower_ascended.emit(tower)
	return true


func fuse_towers(tower_a: Node, tower_b: Node) -> bool:
	## Fuse two Superior-tier towers of different elements into a dual-element fusion tower.
	## tower_a is kept in place and becomes the fusion result; tower_b is consumed.
	if not FusionRegistry.can_fuse(tower_a, tower_b):
		fusion_failed.emit(tower_a, FUSE_FAIL_INVALID_COMBO)
		return false
	var result: TowerData = FusionRegistry.get_fusion_result(
		tower_a.tower_data.element, tower_b.tower_data.element
	)
	if result == null:
		fusion_failed.emit(tower_a, FUSE_FAIL_NO_RESULT)
		return false
	# Fusion cost is the result tower's cost (additional fee on top of invested towers)
	var fusion_cost: int = result.cost
	if not EconomyManager.can_afford(fusion_cost):
		fusion_failed.emit(tower_a, "%s -- need %dg" % [FUSE_FAIL_CANT_AFFORD, fusion_cost])
		return false
	EconomyManager.spend_gold(fusion_cost)
	# Remove tower_b from grid (no refund)
	var grid_pos_b: Vector2i = tower_b.grid_position
	GridManager.remove_tower(grid_pos_b)
	_active_towers.erase(tower_b)
	tower_b.queue_free()
	# Replace tower_a in-place with fusion result
	tower_a.tower_data = result
	tower_a.apply_tower_data()
	tower_fused.emit(tower_a)
	return true


func fuse_legendary(tower_tier2: Node, tower_superior: Node) -> bool:
	## Fuse a tier-2 dual fusion tower with a Superior tier-1 tower into a legendary tier-3.
	## tower_tier2 is kept in place and becomes the legendary; tower_superior is consumed.
	if not FusionRegistry.can_fuse_legendary(tower_tier2, tower_superior):
		fusion_failed.emit(tower_tier2, FUSE_FAIL_INVALID_COMBO)
		return false
	var result: TowerData = FusionRegistry.get_legendary_result(
		tower_tier2.tower_data.fusion_elements, tower_superior.tower_data.element
	)
	if result == null:
		fusion_failed.emit(tower_tier2, FUSE_FAIL_NO_RESULT)
		return false
	var fusion_cost: int = result.cost
	if not EconomyManager.can_afford(fusion_cost):
		fusion_failed.emit(tower_tier2, "%s -- need %dg" % [FUSE_FAIL_CANT_AFFORD, fusion_cost])
		return false
	EconomyManager.spend_gold(fusion_cost)
	# Remove the superior tower from grid (no refund)
	var grid_pos_b: Vector2i = tower_superior.grid_position
	GridManager.remove_tower(grid_pos_b)
	_active_towers.erase(tower_superior)
	tower_superior.queue_free()
	# Replace tier2 tower in-place with legendary result
	tower_tier2.tower_data = result
	tower_tier2.apply_tower_data()
	tower_fused.emit(tower_tier2)
	return true


func get_active_towers() -> Array[Node]:
	return _active_towers
