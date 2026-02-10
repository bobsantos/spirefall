extends GdUnitTestSuite

## Unit tests for FusionRegistry autoload.
## Covers: registration counts, key generation, fusion lookups (dual + legendary),
## can_fuse / can_fuse_legendary validation, partner finding, and dictionary accessors.


# -- Helpers -------------------------------------------------------------------

## Create a minimal TowerData resource for testing without loading .tres files.
func _make_tower_data(
	p_name: String = "TestTower",
	p_element: String = "fire",
	p_cost: int = 30,
	p_tier: int = 1,
	p_upgrade_to: TowerData = null,
	p_fusion_elements: Array[String] = []
) -> TowerData:
	var data := TowerData.new()
	data.tower_name = p_name
	data.element = p_element
	data.cost = p_cost
	data.tier = p_tier
	data.damage = 15
	data.attack_speed = 1.0
	data.range_cells = 4
	data.damage_type = p_element
	data.upgrade_to = p_upgrade_to
	data.fusion_elements = p_fusion_elements
	return data


## Returns a minimal GDScript that gives a Node2D the properties FusionRegistry
## reads (tower_data). Avoids loading BaseTower.tscn which needs sprites/timers.
static var _stub_script: GDScript = null
func _tower_stub_script() -> GDScript:
	if _stub_script != null:
		return _stub_script
	_stub_script = GDScript.new()
	_stub_script.source_code = """
extends Node2D

var tower_data: TowerData
var grid_position: Vector2i = Vector2i.ZERO

func apply_tower_data() -> void:
	pass
"""
	_stub_script.reload()
	return _stub_script


## Create a tower stub Node2D manually with the given TowerData.
func _make_tower_stub(data: TowerData) -> Node2D:
	var stub := Node2D.new()
	stub.set_script(_tower_stub_script())
	stub.tower_data = data
	return stub


# All 15 dual-element pairs in sorted key order
const DUAL_PAIRS: Array[Array] = [
	["earth", "fire"],
	["fire", "water"],
	["fire", "wind"],
	["fire", "lightning"],
	["fire", "ice"],
	["earth", "water"],
	["water", "wind"],
	["lightning", "water"],
	["ice", "water"],
	["earth", "wind"],
	["earth", "lightning"],
	["earth", "ice"],
	["lightning", "wind"],
	["ice", "wind"],
	["ice", "lightning"],
]

# All 6 legendary triple-element combos (elements as registered in FusionRegistry)
const LEGENDARY_TRIPLES: Array[Array] = [
	["earth", "fire", "water"],
	["fire", "lightning", "wind"],
	["ice", "water", "wind"],
	["earth", "ice", "lightning"],
	["earth", "fire", "wind"],
	["earth", "lightning", "water"],
]


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	# Clear TowerSystem._active_towers so partner tests start clean
	for tower: Node in TowerSystem._active_towers:
		if is_instance_valid(tower) and not tower.is_queued_for_deletion():
			tower.queue_free()
	TowerSystem._active_towers.clear()


func after_test() -> void:
	for tower: Node in TowerSystem._active_towers:
		if is_instance_valid(tower) and not tower.is_queued_for_deletion():
			tower.queue_free()
	TowerSystem._active_towers.clear()


# -- 1. All 15 dual fusions registered ----------------------------------------

func test_all_15_dual_fusions_registered() -> void:
	assert_int(FusionRegistry._dual_fusions.size()).is_equal(15)


# -- 2. All 6 legendary fusions registered ------------------------------------

func test_all_6_legendary_fusions_registered() -> void:
	assert_int(FusionRegistry._legendary_fusions.size()).is_equal(6)


# -- 3. _make_key sorts alphabetically ----------------------------------------

func test_make_key_sorts_alphabetically() -> void:
	# "water" comes after "fire" alphabetically, so result should be "fire+water"
	assert_str(FusionRegistry._make_key("water", "fire")).is_equal("fire+water")
	# Already sorted input should produce the same result
	assert_str(FusionRegistry._make_key("fire", "water")).is_equal("fire+water")


# -- 4. _make_legendary_key sorts ---------------------------------------------

func test_make_legendary_key_sorts() -> void:
	var elements: Array[String] = ["wind", "fire", "earth"]
	assert_str(FusionRegistry._make_legendary_key(elements)).is_equal("earth+fire+wind")


# -- 5. get_fusion_result fire+water returns Steam Engine --------------------

func test_get_fusion_result_fire_water() -> void:
	var result: TowerData = FusionRegistry.get_fusion_result("fire", "water")
	assert_object(result).is_not_null()
	assert_str(result.tower_name).is_equal("Steam Engine")
	assert_int(result.tier).is_equal(2)


# -- 6. get_fusion_result reversed order returns same result ------------------

func test_get_fusion_result_reversed_order() -> void:
	var result_a: TowerData = FusionRegistry.get_fusion_result("fire", "water")
	var result_b: TowerData = FusionRegistry.get_fusion_result("water", "fire")
	assert_object(result_a).is_not_null()
	assert_object(result_b).is_not_null()
	# Both should resolve to the same resource path, so same tower_name
	assert_str(result_a.tower_name).is_equal(result_b.tower_name)


# -- 7. get_fusion_result all 15 pairs return non-null -----------------------

func test_get_fusion_result_all_15() -> void:
	for pair: Array in DUAL_PAIRS:
		var element_a: String = pair[0]
		var element_b: String = pair[1]
		var result: TowerData = FusionRegistry.get_fusion_result(element_a, element_b)
		assert_object(result).is_not_null()
		assert_int(result.tier).is_equal(2)


# -- 8. get_fusion_result invalid combo returns null -------------------------

func test_get_fusion_result_invalid_combo() -> void:
	# Same element cannot fuse
	var same: TowerData = FusionRegistry.get_fusion_result("fire", "fire")
	assert_object(same).is_null()
	# Unknown element
	var unknown: TowerData = FusionRegistry.get_fusion_result("fire", "plasma")
	assert_object(unknown).is_null()


# -- 9. get_legendary_result fire+water+earth returns Primordial Nexus -------

func test_get_legendary_result_fire_water_earth() -> void:
	var tier2_elements: Array[String] = ["fire", "water"]
	var result: TowerData = FusionRegistry.get_legendary_result(tier2_elements, "earth")
	assert_object(result).is_not_null()
	assert_str(result.tower_name).is_equal("Primordial Nexus")
	assert_int(result.tier).is_equal(3)


# -- 10. get_legendary_result all 6 combos return non-null -------------------

func test_get_legendary_result_all_6() -> void:
	for triple: Array in LEGENDARY_TRIPLES:
		# Use first two as tier2 elements, third as the new element
		var tier2_elements: Array[String] = [triple[0], triple[1]]
		var third: String = triple[2]
		var result: TowerData = FusionRegistry.get_legendary_result(tier2_elements, third)
		assert_object(result).is_not_null()
		assert_int(result.tier).is_equal(3)


# -- 11. get_legendary_result invalid returns null ---------------------------

func test_get_legendary_result_invalid() -> void:
	# Nonexistent triple
	var tier2_elements: Array[String] = ["fire", "ice"]
	var result: TowerData = FusionRegistry.get_legendary_result(tier2_elements, "ice")
	assert_object(result).is_null()

	# Completely bogus elements
	var bogus: TowerData = FusionRegistry.get_legendary_result(
		["plasma", "dark"] as Array[String], "void")
	assert_object(bogus).is_null()


# -- 12. can_fuse both superior (tier 1, no upgrade) -> true -----------------

func test_can_fuse_both_superior() -> void:
	var fire_data: TowerData = _make_tower_data("FireSup", "fire", 60, 1, null)
	var earth_data: TowerData = _make_tower_data("EarthSup", "earth", 70, 1, null)
	var tower_a: Node2D = auto_free(_make_tower_stub(fire_data))
	var tower_b: Node2D = auto_free(_make_tower_stub(earth_data))

	assert_bool(FusionRegistry.can_fuse(tower_a, tower_b)).is_true()


# -- 13. can_fuse fails same element -----------------------------------------

func test_can_fuse_fails_same_element() -> void:
	var fire_a: TowerData = _make_tower_data("FireA", "fire", 60, 1, null)
	var fire_b: TowerData = _make_tower_data("FireB", "fire", 60, 1, null)
	var tower_a: Node2D = auto_free(_make_tower_stub(fire_a))
	var tower_b: Node2D = auto_free(_make_tower_stub(fire_b))

	assert_bool(FusionRegistry.can_fuse(tower_a, tower_b)).is_false()


# -- 14. can_fuse fails not superior (has upgrade_to) -----------------------

func test_can_fuse_fails_not_superior() -> void:
	var upgrade_data: TowerData = _make_tower_data("FireUpgrade", "fire", 50)
	var fire_data: TowerData = _make_tower_data("FireBase", "fire", 30, 1, upgrade_data)
	var earth_data: TowerData = _make_tower_data("EarthSup", "earth", 70, 1, null)
	var tower_a: Node2D = auto_free(_make_tower_stub(fire_data))
	var tower_b: Node2D = auto_free(_make_tower_stub(earth_data))

	# tower_a has upgrade_to != null, so it's not "Superior" yet
	assert_bool(FusionRegistry.can_fuse(tower_a, tower_b)).is_false()


# -- 15. can_fuse fails wrong tier -------------------------------------------

func test_can_fuse_fails_wrong_tier() -> void:
	# Tier 2 tower cannot be used in a dual fusion
	var tier2_data: TowerData = _make_tower_data(
		"MagmaForge", "earth", 130, 2, null, ["earth", "fire"] as Array[String])
	var water_data: TowerData = _make_tower_data("WaterSup", "water", 60, 1, null)
	var tower_a: Node2D = auto_free(_make_tower_stub(tier2_data))
	var tower_b: Node2D = auto_free(_make_tower_stub(water_data))

	assert_bool(FusionRegistry.can_fuse(tower_a, tower_b)).is_false()


# -- 16. can_fuse_legendary valid --------------------------------------------

func test_can_fuse_legendary_valid() -> void:
	# Tier 2 (earth+fire) + Superior water -> Primordial Nexus
	var tier2_data: TowerData = _make_tower_data(
		"MagmaForge", "earth", 130, 2, null, ["earth", "fire"] as Array[String])
	var water_data: TowerData = _make_tower_data("WaterSup", "water", 60, 1, null)
	var tower_tier2: Node2D = auto_free(_make_tower_stub(tier2_data))
	var tower_sup: Node2D = auto_free(_make_tower_stub(water_data))

	assert_bool(FusionRegistry.can_fuse_legendary(tower_tier2, tower_sup)).is_true()


# -- 17. can_fuse_legendary fails element already in fusion ------------------

func test_can_fuse_legendary_fails_element_already_in_fusion() -> void:
	# Tier 2 (earth+fire) + Superior earth -> earth already in fusion_elements
	var tier2_data: TowerData = _make_tower_data(
		"MagmaForge", "earth", 130, 2, null, ["earth", "fire"] as Array[String])
	var earth_data: TowerData = _make_tower_data("EarthSup", "earth", 70, 1, null)
	var tower_tier2: Node2D = auto_free(_make_tower_stub(tier2_data))
	var tower_sup: Node2D = auto_free(_make_tower_stub(earth_data))

	assert_bool(FusionRegistry.can_fuse_legendary(tower_tier2, tower_sup)).is_false()


# -- 18. can_fuse_legendary fails not tier 2 ---------------------------------

func test_can_fuse_legendary_fails_not_tier2() -> void:
	# Tier 1 tower as the "tier2" argument -> fails
	var fire_data: TowerData = _make_tower_data("FireSup", "fire", 60, 1, null)
	var water_data: TowerData = _make_tower_data("WaterSup", "water", 60, 1, null)
	var tower_a: Node2D = auto_free(_make_tower_stub(fire_data))
	var tower_b: Node2D = auto_free(_make_tower_stub(water_data))

	assert_bool(FusionRegistry.can_fuse_legendary(tower_a, tower_b)).is_false()


# -- 19. can_fuse_legendary fails not superior (has upgrade_to) --------------

func test_can_fuse_legendary_fails_not_superior() -> void:
	var tier2_data: TowerData = _make_tower_data(
		"MagmaForge", "earth", 130, 2, null, ["earth", "fire"] as Array[String])
	var upgrade_data: TowerData = _make_tower_data("WaterUpgrade", "water", 50)
	var water_data: TowerData = _make_tower_data("WaterBase", "water", 30, 1, upgrade_data)
	var tower_tier2: Node2D = auto_free(_make_tower_stub(tier2_data))
	var tower_sup: Node2D = auto_free(_make_tower_stub(water_data))

	# tower_sup has upgrade_to != null, so it's not "Superior" -> fails
	assert_bool(FusionRegistry.can_fuse_legendary(tower_tier2, tower_sup)).is_false()


# -- 20. get_fusion_partners finds valid partners ----------------------------

func test_get_fusion_partners_finds_valid() -> void:
	var fire_data: TowerData = _make_tower_data("FireSup", "fire", 60, 1, null)
	var earth_data: TowerData = _make_tower_data("EarthSup", "earth", 70, 1, null)
	var water_data: TowerData = _make_tower_data("WaterSup", "water", 60, 1, null)

	var fire_tower: Node2D = auto_free(_make_tower_stub(fire_data))
	var earth_tower: Node2D = auto_free(_make_tower_stub(earth_data))
	var water_tower: Node2D = auto_free(_make_tower_stub(water_data))

	# Add all to TowerSystem._active_towers so get_fusion_partners can find them
	TowerSystem._active_towers.append(fire_tower)
	TowerSystem._active_towers.append(earth_tower)
	TowerSystem._active_towers.append(water_tower)

	# Fire tower should find earth and water as partners
	var partners: Array[Node] = FusionRegistry.get_fusion_partners(fire_tower)
	assert_int(partners.size()).is_equal(2)
	assert_bool(partners.has(earth_tower)).is_true()
	assert_bool(partners.has(water_tower)).is_true()


# -- 21. get_fusion_partners excludes self -----------------------------------

func test_get_fusion_partners_excludes_self() -> void:
	var fire_data: TowerData = _make_tower_data("FireSup", "fire", 60, 1, null)
	var earth_data: TowerData = _make_tower_data("EarthSup", "earth", 70, 1, null)

	var fire_tower: Node2D = auto_free(_make_tower_stub(fire_data))
	var earth_tower: Node2D = auto_free(_make_tower_stub(earth_data))

	TowerSystem._active_towers.append(fire_tower)
	TowerSystem._active_towers.append(earth_tower)

	var partners: Array[Node] = FusionRegistry.get_fusion_partners(fire_tower)
	assert_bool(partners.has(fire_tower)).is_false()
	assert_bool(partners.has(earth_tower)).is_true()


# -- 22. get_legendary_partners bidirectional --------------------------------

func test_get_legendary_partners_bidirectional() -> void:
	# Tier 2 (earth+fire) and Superior water
	var tier2_data: TowerData = _make_tower_data(
		"MagmaForge", "earth", 130, 2, null, ["earth", "fire"] as Array[String])
	var water_data: TowerData = _make_tower_data("WaterSup", "water", 60, 1, null)

	var tier2_tower: Node2D = auto_free(_make_tower_stub(tier2_data))
	var water_tower: Node2D = auto_free(_make_tower_stub(water_data))

	TowerSystem._active_towers.append(tier2_tower)
	TowerSystem._active_towers.append(water_tower)

	# From tier2 perspective: should find the water superior
	var partners_from_tier2: Array[Node] = FusionRegistry.get_legendary_partners(tier2_tower)
	assert_int(partners_from_tier2.size()).is_equal(1)
	assert_bool(partners_from_tier2.has(water_tower)).is_true()

	# From superior perspective: should find the tier2 tower
	var partners_from_sup: Array[Node] = FusionRegistry.get_legendary_partners(water_tower)
	assert_int(partners_from_sup.size()).is_equal(1)
	assert_bool(partners_from_sup.has(tier2_tower)).is_true()


# -- 23. get_all_dual_fusions returns dict with 15 entries -------------------

func test_get_all_dual_fusions_returns_dict() -> void:
	var fusions: Dictionary = FusionRegistry.get_all_dual_fusions()
	assert_int(fusions.size()).is_equal(15)
	# Verify it's the same dictionary reference
	assert_object(fusions).is_same(FusionRegistry._dual_fusions)


# -- 24. get_all_legendary_fusions returns dict with 6 entries ---------------

func test_get_all_legendary_fusions_returns_dict() -> void:
	var fusions: Dictionary = FusionRegistry.get_all_legendary_fusions()
	assert_int(fusions.size()).is_equal(6)
	# Verify it's the same dictionary reference
	assert_object(fusions).is_same(FusionRegistry._legendary_fusions)
