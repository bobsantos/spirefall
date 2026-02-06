class_name FusionRegistryClass
extends Node

## Lookup table for dual-element and legendary tower fusions.
## Keys are sorted alphabetically: "earth+fire", "fire+water", etc.

# Sorted element pair key -> fusion tower .tres resource path
var _dual_fusions: Dictionary = {}


func _ready() -> void:
	_register_dual_fusions()


func _register_dual_fusions() -> void:
	_dual_fusions["earth+fire"] = "res://resources/towers/fusions/magma_forge.tres"
	_dual_fusions["fire+water"] = "res://resources/towers/fusions/steam_engine.tres"
	_dual_fusions["fire+wind"] = "res://resources/towers/fusions/inferno_vortex.tres"
	_dual_fusions["fire+lightning"] = "res://resources/towers/fusions/plasma_cannon.tres"
	_dual_fusions["fire+ice"] = "res://resources/towers/fusions/thermal_shock.tres"
	_dual_fusions["earth+water"] = "res://resources/towers/fusions/mud_pit.tres"
	_dual_fusions["water+wind"] = "res://resources/towers/fusions/tsunami_shrine.tres"
	_dual_fusions["lightning+water"] = "res://resources/towers/fusions/storm_beacon.tres"
	_dual_fusions["ice+water"] = "res://resources/towers/fusions/glacier_keep.tres"
	_dual_fusions["earth+wind"] = "res://resources/towers/fusions/sandstorm_citadel.tres"
	_dual_fusions["earth+lightning"] = "res://resources/towers/fusions/seismic_coil.tres"
	_dual_fusions["earth+ice"] = "res://resources/towers/fusions/permafrost_pillar.tres"
	_dual_fusions["lightning+wind"] = "res://resources/towers/fusions/tempest_spire.tres"
	_dual_fusions["ice+wind"] = "res://resources/towers/fusions/blizzard_tower.tres"
	_dual_fusions["ice+lightning"] = "res://resources/towers/fusions/cryo_volt_array.tres"


func _make_key(element_a: String, element_b: String) -> String:
	var elements: Array = [element_a, element_b]
	elements.sort()
	return "%s+%s" % [elements[0], elements[1]]


func get_fusion_result(element_a: String, element_b: String) -> TowerData:
	## Returns the TowerData for the fusion of two elements, or null if no fusion exists.
	var key: String = _make_key(element_a, element_b)
	if key in _dual_fusions:
		return load(_dual_fusions[key])
	return null


func can_fuse(tower_a: Node, tower_b: Node) -> bool:
	## Returns true if two towers can be fused together.
	## Both must be Superior (tier 1, no upgrade_to) and different elements.
	if tower_a.tower_data.tier != 1 or tower_b.tower_data.tier != 1:
		return false
	if tower_a.tower_data.upgrade_to != null or tower_b.tower_data.upgrade_to != null:
		return false
	if tower_a.tower_data.element == tower_b.tower_data.element:
		return false
	return get_fusion_result(tower_a.tower_data.element, tower_b.tower_data.element) != null


func get_fusion_partners(tower: Node) -> Array[Node]:
	## Returns all towers on the map that can be fused with the given tower.
	if tower.tower_data.tier != 1 or tower.tower_data.upgrade_to != null:
		return []
	var partners: Array[Node] = []
	for other: Node in TowerSystem.get_active_towers():
		if other == tower:
			continue
		if can_fuse(tower, other):
			partners.append(other)
	return partners
