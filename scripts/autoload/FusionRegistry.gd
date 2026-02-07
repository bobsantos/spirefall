class_name FusionRegistryClass
extends Node

## Lookup table for dual-element and legendary tower fusions.
## Dual keys are 2 sorted elements: "earth+fire", "fire+water", etc.
## Legendary keys are 3 sorted elements: "earth+fire+water", etc.

# Sorted element pair key -> fusion tower .tres resource path
var _dual_fusions: Dictionary = {}
# Sorted element triple key -> legendary tower .tres resource path
var _legendary_fusions: Dictionary = {}


func _ready() -> void:
	_register_dual_fusions()
	_register_legendary_fusions()


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


func _register_legendary_fusions() -> void:
	_legendary_fusions["earth+fire+water"] = "res://resources/towers/legendaries/primordial_nexus.tres"
	_legendary_fusions["fire+lightning+wind"] = "res://resources/towers/legendaries/supercell_obelisk.tres"
	_legendary_fusions["ice+water+wind"] = "res://resources/towers/legendaries/arctic_maelstrom.tres"
	_legendary_fusions["earth+ice+lightning"] = "res://resources/towers/legendaries/crystalline_monolith.tres"
	_legendary_fusions["earth+fire+wind"] = "res://resources/towers/legendaries/volcanic_tempest.tres"
	_legendary_fusions["earth+lightning+water"] = "res://resources/towers/legendaries/tectonic_dynamo.tres"


func get_all_dual_fusions() -> Dictionary:
	return _dual_fusions


func get_all_legendary_fusions() -> Dictionary:
	return _legendary_fusions


func _make_key(element_a: String, element_b: String) -> String:
	var elements: Array = [element_a, element_b]
	elements.sort()
	return "%s+%s" % [elements[0], elements[1]]


func _make_legendary_key(elements: Array[String]) -> String:
	## Sort 3 elements alphabetically and join with "+".
	var sorted: Array[String] = elements.duplicate()
	sorted.sort()
	return "%s+%s+%s" % [sorted[0], sorted[1], sorted[2]]


func get_fusion_result(element_a: String, element_b: String) -> TowerData:
	## Returns the TowerData for the fusion of two elements, or null if no fusion exists.
	var key: String = _make_key(element_a, element_b)
	if key in _dual_fusions:
		return load(_dual_fusions[key])
	return null


func get_legendary_result(tier2_elements: Array[String], third_element: String) -> TowerData:
	## Combines a tier2 tower's fusion_elements with a third element, looks up the legendary.
	## Returns null if no legendary combo exists.
	var all_elements: Array[String] = tier2_elements.duplicate()
	if third_element not in all_elements:
		all_elements.append(third_element)
	if all_elements.size() != 3:
		return null
	var key: String = _make_legendary_key(all_elements)
	if key in _legendary_fusions:
		return load(_legendary_fusions[key])
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


func can_fuse_legendary(tower_tier2: Node, tower_superior: Node) -> bool:
	## Returns true if a tier-2 dual fusion tower and a fully-upgraded tier-1 tower
	## can be combined into a legendary tier-3 tower.
	## tower_tier2 must be tier==2, tower_superior must be tier==1 with upgrade_to==null.
	if tower_tier2.tower_data.tier != 2:
		return false
	if tower_superior.tower_data.tier != 1 or tower_superior.tower_data.upgrade_to != null:
		return false
	# The third element must NOT already be in the tier2's fusion_elements
	var third_element: String = tower_superior.tower_data.element
	if third_element in tower_tier2.tower_data.fusion_elements:
		return false
	return get_legendary_result(tower_tier2.tower_data.fusion_elements, third_element) != null


func get_fusion_partners(tower: Node) -> Array[Node]:
	## Returns all towers on the map that can be fused with the given tower.
	## Works for both dual fusions (tier 1 + tier 1) and legendary fusions.
	if tower.tower_data.tier != 1 or tower.tower_data.upgrade_to != null:
		return []
	var partners: Array[Node] = []
	for other: Node in TowerSystem.get_active_towers():
		if other == tower:
			continue
		if can_fuse(tower, other):
			partners.append(other)
	return partners


func get_legendary_partners(tower: Node) -> Array[Node]:
	## Returns all towers on the map that can be fused with the given tower for a legendary.
	## Works from either direction: if tower is tier 2, finds eligible superior towers;
	## if tower is tier 1 (superior), finds eligible tier 2 towers.
	var partners: Array[Node] = []
	for other: Node in TowerSystem.get_active_towers():
		if other == tower:
			continue
		# Try tower as tier2, other as superior
		if tower.tower_data.tier == 2 and can_fuse_legendary(tower, other):
			partners.append(other)
		# Try other as tier2, tower as superior
		elif other.tower_data.tier == 2 and can_fuse_legendary(other, tower):
			partners.append(other)
	return partners
