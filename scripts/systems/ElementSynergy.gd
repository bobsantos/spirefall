class_name ElementSynergyClass
extends Node

## Tracks per-element tower counts and provides synergy bonuses.
## Synergy thresholds: 3 towers = +10% dmg, 5 = +20% dmg + aura, 8 = +30% dmg + enhanced aura.

signal synergy_changed()

# Threshold -> damage multiplier
const SYNERGY_TIERS: Dictionary = {
	0: 1.0,
	1: 1.1,  # 3+ towers
	2: 1.2,  # 5+ towers
	3: 1.3,  # 8+ towers
}

const TIER_THRESHOLDS: Array[int] = [0, 3, 5, 8]

# Element-specific aura bonuses at tier 2 (5+) and tier 3 (8+)
# Format: { "attack_speed_bonus", "slow_bonus", "range_bonus_cells", "chain_bonus", "freeze_chance_bonus" }
# Tier 2 values (5+):
const AURA_TIER_2: Dictionary = {
	"fire":      { "attack_speed_bonus": 0.10 },
	"water":     { "slow_bonus": 0.10 },
	"earth":     { "range_bonus_cells": 1 },
	"wind":      { "attack_speed_bonus": 0.15 },
	"lightning": { "chain_bonus": 1 },
	"ice":       { "freeze_chance_bonus": 0.10 },
}

# Tier 3 values (8+): doubled bonuses
const AURA_TIER_3: Dictionary = {
	"fire":      { "attack_speed_bonus": 0.20 },
	"water":     { "slow_bonus": 0.20 },
	"earth":     { "range_bonus_cells": 2 },
	"wind":      { "attack_speed_bonus": 0.30 },
	"lightning": { "chain_bonus": 2 },
	"ice":       { "freeze_chance_bonus": 0.20 },
}

# Element colors for synergy visual feedback (subtle glow tint)
const ELEMENT_COLORS: Dictionary = {
	"fire":      Color(1.0, 0.6, 0.3, 1.0),
	"water":     Color(0.3, 0.6, 1.0, 1.0),
	"earth":     Color(0.7, 0.55, 0.3, 1.0),
	"wind":      Color(0.5, 0.9, 0.5, 1.0),
	"lightning": Color(1.0, 1.0, 0.3, 1.0),
	"ice":       Color(0.6, 0.9, 1.0, 1.0),
}

var _element_counts: Dictionary = {}  # element string -> int
var _synergy_tiers: Dictionary = {}   # element string -> int (0-3)


func _ready() -> void:
	TowerSystem.tower_created.connect(_on_towers_changed)
	TowerSystem.tower_sold.connect(_on_tower_sold)
	TowerSystem.tower_upgraded.connect(_on_towers_changed)
	TowerSystem.tower_fused.connect(_on_towers_changed)


func _on_towers_changed(_tower: Node) -> void:
	recalculate()


func _on_tower_sold(_tower: Node, _refund: int) -> void:
	recalculate()


func recalculate() -> void:
	## Recount all tower elements and update synergy tiers.
	var old_tiers: Dictionary = _synergy_tiers.duplicate()
	_element_counts.clear()
	_synergy_tiers.clear()

	var towers: Array[Node] = TowerSystem.get_active_towers()
	for tower: Node in towers:
		if not is_instance_valid(tower) or not tower.tower_data:
			continue
		var elements: Array[String] = _get_tower_elements(tower)
		for elem: String in elements:
			if elem == "" or elem == "none" or elem == "chaos":
				continue
			_element_counts[elem] = _element_counts.get(elem, 0) + 1

	# Determine synergy tier for each element
	for elem: String in _element_counts:
		_synergy_tiers[elem] = _calculate_tier(_element_counts[elem])

	# Only emit signal if tiers actually changed
	if _synergy_tiers != old_tiers:
		synergy_changed.emit()


func _get_tower_elements(tower: Node) -> Array[String]:
	## Returns the elements a tower contributes to synergy counts.
	## Fusion towers (tier 2/3) count each element in fusion_elements.
	## Base towers (tier 1) count their single element.
	var data: TowerData = tower.tower_data
	if data.fusion_elements.size() > 0:
		return data.fusion_elements.duplicate()
	return [data.element]


func _calculate_tier(count: int) -> int:
	if count >= TIER_THRESHOLDS[3]:
		return 3
	elif count >= TIER_THRESHOLDS[2]:
		return 2
	elif count >= TIER_THRESHOLDS[1]:
		return 1
	return 0


func get_element_count(element: String) -> int:
	return _element_counts.get(element, 0)


func get_synergy_tier(element: String) -> int:
	## Returns 0, 1, 2, or 3 for the given element.
	return _synergy_tiers.get(element, 0)


func get_synergy_bonus(element: String) -> float:
	## Returns the damage multiplier for the given element (1.0, 1.1, 1.2, or 1.3).
	var tier: int = get_synergy_tier(element)
	return SYNERGY_TIERS.get(tier, 1.0)


func get_best_synergy_bonus(tower: Node) -> float:
	## For fusion towers with multiple elements, return the highest damage multiplier.
	if not tower or not tower.tower_data:
		return 1.0
	var elements: Array[String] = _get_tower_elements(tower)
	var best: float = 1.0
	for elem: String in elements:
		var bonus: float = get_synergy_bonus(elem)
		if bonus > best:
			best = bonus
	return best


func get_best_synergy_tier(tower: Node) -> int:
	## For fusion towers with multiple elements, return the highest synergy tier.
	if not tower or not tower.tower_data:
		return 0
	var elements: Array[String] = _get_tower_elements(tower)
	var best: int = 0
	for elem: String in elements:
		var tier: int = get_synergy_tier(elem)
		if tier > best:
			best = tier
	return best


func get_attack_speed_bonus(tower: Node) -> float:
	## Returns additional attack speed fraction for fire/wind synergy towers.
	## e.g. 0.10 means +10% attack speed.
	if not tower or not tower.tower_data:
		return 0.0
	var elements: Array[String] = _get_tower_elements(tower)
	var best: float = 0.0
	for elem: String in elements:
		if elem != "fire" and elem != "wind":
			continue
		var tier: int = get_synergy_tier(elem)
		if tier >= 3 and elem in AURA_TIER_3:
			best = maxf(best, AURA_TIER_3[elem].get("attack_speed_bonus", 0.0))
		elif tier >= 2 and elem in AURA_TIER_2:
			best = maxf(best, AURA_TIER_2[elem].get("attack_speed_bonus", 0.0))
	return best


func get_range_bonus_cells(tower: Node) -> int:
	## Returns additional range in cells for earth synergy towers.
	if not tower or not tower.tower_data:
		return 0
	var elements: Array[String] = _get_tower_elements(tower)
	var best: int = 0
	for elem: String in elements:
		if elem != "earth":
			continue
		var tier: int = get_synergy_tier(elem)
		if tier >= 3 and elem in AURA_TIER_3:
			best = maxi(best, AURA_TIER_3[elem].get("range_bonus_cells", 0))
		elif tier >= 2 and elem in AURA_TIER_2:
			best = maxi(best, AURA_TIER_2[elem].get("range_bonus_cells", 0))
	return best


func get_chain_bonus(tower: Node) -> int:
	## Returns additional chain bounces for lightning synergy towers.
	if not tower or not tower.tower_data:
		return 0
	var elements: Array[String] = _get_tower_elements(tower)
	var best: int = 0
	for elem: String in elements:
		if elem != "lightning":
			continue
		var tier: int = get_synergy_tier(elem)
		if tier >= 3 and elem in AURA_TIER_3:
			best = maxi(best, AURA_TIER_3[elem].get("chain_bonus", 0))
		elif tier >= 2 and elem in AURA_TIER_2:
			best = maxi(best, AURA_TIER_2[elem].get("chain_bonus", 0))
	return best


func get_freeze_chance_bonus(tower: Node) -> float:
	## Returns additional freeze chance for ice synergy towers.
	if not tower or not tower.tower_data:
		return 0.0
	var elements: Array[String] = _get_tower_elements(tower)
	var best: float = 0.0
	for elem: String in elements:
		if elem != "ice":
			continue
		var tier: int = get_synergy_tier(elem)
		if tier >= 3 and elem in AURA_TIER_3:
			best = maxf(best, AURA_TIER_3[elem].get("freeze_chance_bonus", 0.0))
		elif tier >= 2 and elem in AURA_TIER_2:
			best = maxf(best, AURA_TIER_2[elem].get("freeze_chance_bonus", 0.0))
	return best


func get_slow_bonus(tower: Node) -> float:
	## Returns additional slow fraction for water synergy towers.
	if not tower or not tower.tower_data:
		return 0.0
	var elements: Array[String] = _get_tower_elements(tower)
	var best: float = 0.0
	for elem: String in elements:
		if elem != "water":
			continue
		var tier: int = get_synergy_tier(elem)
		if tier >= 3 and elem in AURA_TIER_3:
			best = maxf(best, AURA_TIER_3[elem].get("slow_bonus", 0.0))
		elif tier >= 2 and elem in AURA_TIER_2:
			best = maxf(best, AURA_TIER_2[elem].get("slow_bonus", 0.0))
	return best


func get_synergy_color(tower: Node) -> Color:
	## Returns the synergy glow color for a tower, or Color.WHITE if no synergy.
	if not tower or not tower.tower_data:
		return Color.WHITE
	var elements: Array[String] = _get_tower_elements(tower)
	var best_tier: int = 0
	var best_elem: String = ""
	for elem: String in elements:
		var tier: int = get_synergy_tier(elem)
		if tier > best_tier:
			best_tier = tier
			best_elem = elem
	if best_tier == 0 or best_elem == "":
		return Color.WHITE
	var base_color: Color = ELEMENT_COLORS.get(best_elem, Color.WHITE)
	# Subtle tint: lerp from white toward element color based on tier strength
	var strength: float = 0.15 * best_tier  # 0.15 at tier 1, 0.30 at tier 2, 0.45 at tier 3
	return Color.WHITE.lerp(base_color, strength)
