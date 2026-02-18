extends GdUnitTestSuite

## Unit tests for ElementSynergy autoload.
## Covers: tier calculation, element counting, synergy bonus (damage multiplier),
## best synergy for fusion towers, element-specific aura bonuses (attack speed,
## range, chain, freeze chance, slow), synergy color, signal emission, and
## recalculate isolation.


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


## Minimal GDScript stub with the properties ElementSynergy reads from towers.
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


## Create a tower stub Node2D with the given TowerData.
func _make_tower_stub(data: TowerData) -> Node2D:
	var stub := Node2D.new()
	stub.set_script(_tower_stub_script())
	stub.tower_data = data
	return stub


## Convenience: add N base-element towers to TowerSystem._active_towers.
## Returns the array of created stubs (caller should auto_free them).
func _add_base_towers(element: String, count: int) -> Array[Node2D]:
	var stubs: Array[Node2D] = []
	for i: int in range(count):
		var data: TowerData = _make_tower_data("T%d" % i, element)
		var stub: Node2D = auto_free(_make_tower_stub(data))
		TowerSystem._active_towers.append(stub)
		stubs.append(stub)
	return stubs


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	# Clear TowerSystem active towers -- use free() since these nodes
	# are not in the scene tree (queue_free requires tree frame processing)
	for tower: Node in TowerSystem._active_towers:
		if is_instance_valid(tower) and not tower.is_queued_for_deletion():
			tower.free()
	TowerSystem._active_towers.clear()
	# Reset ElementSynergy internal state
	ElementSynergy._element_counts.clear()
	ElementSynergy._synergy_tiers.clear()


func after_test() -> void:
	for tower: Node in TowerSystem._active_towers:
		if is_instance_valid(tower) and not tower.is_queued_for_deletion():
			tower.free()
	TowerSystem._active_towers.clear()
	ElementSynergy._element_counts.clear()
	ElementSynergy._synergy_tiers.clear()


func after() -> void:
	_stub_script = null


# -- 1. test_calculate_tier_thresholds ----------------------------------------

func test_calculate_tier_thresholds() -> void:
	# Exact threshold values: 0->0, 3->1, 5->2, 8->3
	assert_int(ElementSynergy._calculate_tier(0)).is_equal(0)
	assert_int(ElementSynergy._calculate_tier(3)).is_equal(1)
	assert_int(ElementSynergy._calculate_tier(5)).is_equal(2)
	assert_int(ElementSynergy._calculate_tier(8)).is_equal(3)


# -- 2. test_calculate_tier_between_thresholds --------------------------------

func test_calculate_tier_between_thresholds() -> void:
	# Values between thresholds stay at the lower tier
	assert_int(ElementSynergy._calculate_tier(1)).is_equal(0)
	assert_int(ElementSynergy._calculate_tier(2)).is_equal(0)
	assert_int(ElementSynergy._calculate_tier(4)).is_equal(1)
	assert_int(ElementSynergy._calculate_tier(7)).is_equal(2)
	# Above max threshold still returns 3
	assert_int(ElementSynergy._calculate_tier(10)).is_equal(3)


# -- 3. test_element_count_single_tower ---------------------------------------

func test_element_count_single_tower() -> void:
	_add_base_towers("fire", 1)
	ElementSynergy.recalculate()
	assert_int(ElementSynergy.get_element_count("fire")).is_equal(1)
	assert_int(ElementSynergy.get_element_count("water")).is_equal(0)


# -- 4. test_element_count_fusion_tower ---------------------------------------

func test_element_count_fusion_tower() -> void:
	# A fusion tower with fire+water should contribute 1 to each element
	var fusion_data: TowerData = _make_tower_data(
		"SteamEngine", "fire", 130, 2, null, ["fire", "water"] as Array[String])
	var stub: Node2D = auto_free(_make_tower_stub(fusion_data))
	TowerSystem._active_towers.append(stub)
	ElementSynergy.recalculate()
	assert_int(ElementSynergy.get_element_count("fire")).is_equal(1)
	assert_int(ElementSynergy.get_element_count("water")).is_equal(1)


# -- 5. test_element_count_ignores_none ---------------------------------------

func test_element_count_ignores_none() -> void:
	var data: TowerData = _make_tower_data("NoneT", "none")
	var stub: Node2D = auto_free(_make_tower_stub(data))
	TowerSystem._active_towers.append(stub)
	ElementSynergy.recalculate()
	assert_int(ElementSynergy.get_element_count("none")).is_equal(0)


# -- 6. test_synergy_bonus_tier_0 ---------------------------------------------

func test_synergy_bonus_tier_0() -> void:
	# No towers -> tier 0 -> 1.0x multiplier
	ElementSynergy.recalculate()
	assert_float(ElementSynergy.get_synergy_bonus("fire")).is_equal(1.0)


# -- 7. test_synergy_bonus_tier_1 ---------------------------------------------

func test_synergy_bonus_tier_1() -> void:
	_add_base_towers("fire", 3)
	ElementSynergy.recalculate()
	assert_float(ElementSynergy.get_synergy_bonus("fire")).is_equal(1.1)


# -- 8. test_synergy_bonus_tier_2 ---------------------------------------------

func test_synergy_bonus_tier_2() -> void:
	_add_base_towers("fire", 5)
	ElementSynergy.recalculate()
	assert_float(ElementSynergy.get_synergy_bonus("fire")).is_equal(1.2)


# -- 9. test_synergy_bonus_tier_3 ---------------------------------------------

func test_synergy_bonus_tier_3() -> void:
	_add_base_towers("fire", 8)
	ElementSynergy.recalculate()
	assert_float(ElementSynergy.get_synergy_bonus("fire")).is_equal(1.3)


# -- 10. test_best_synergy_bonus_fusion_tower ---------------------------------

func test_best_synergy_bonus_fusion_tower() -> void:
	# 5 fire base towers + 3 water base towers = fire tier 2 (1.2x), water tier 1 (1.1x)
	_add_base_towers("fire", 5)
	_add_base_towers("water", 3)
	# Add a fire+water fusion tower (contributes +1 to each -> fire=6, water=4)
	var fusion_data: TowerData = _make_tower_data(
		"SteamEngine", "fire", 130, 2, null, ["fire", "water"] as Array[String])
	var fusion_stub: Node2D = auto_free(_make_tower_stub(fusion_data))
	TowerSystem._active_towers.append(fusion_stub)
	ElementSynergy.recalculate()
	# fire count = 6 -> tier 2 (1.2x), water count = 4 -> tier 1 (1.1x)
	# Best synergy for the fusion tower should be 1.2x (fire)
	var best: float = ElementSynergy.get_best_synergy_bonus(fusion_stub)
	assert_float(best).is_equal(1.2)


# -- 11. test_attack_speed_bonus_fire_tier2 -----------------------------------

func test_attack_speed_bonus_fire_tier2() -> void:
	_add_base_towers("fire", 5)
	ElementSynergy.recalculate()
	# Query with any fire tower
	var query_tower: Node2D = TowerSystem._active_towers[0]
	assert_float(ElementSynergy.get_attack_speed_bonus(query_tower)).is_equal(0.10)


# -- 12. test_attack_speed_bonus_fire_tier3 -----------------------------------

func test_attack_speed_bonus_fire_tier3() -> void:
	_add_base_towers("fire", 8)
	ElementSynergy.recalculate()
	var query_tower: Node2D = TowerSystem._active_towers[0]
	assert_float(ElementSynergy.get_attack_speed_bonus(query_tower)).is_equal(0.20)


# -- 13. test_attack_speed_bonus_wind_tier2 -----------------------------------

func test_attack_speed_bonus_wind_tier2() -> void:
	_add_base_towers("wind", 5)
	ElementSynergy.recalculate()
	var query_tower: Node2D = TowerSystem._active_towers[0]
	assert_float(ElementSynergy.get_attack_speed_bonus(query_tower)).is_equal(0.15)


# -- 14. test_range_bonus_earth_tier2 -----------------------------------------

func test_range_bonus_earth_tier2() -> void:
	_add_base_towers("earth", 5)
	ElementSynergy.recalculate()
	var query_tower: Node2D = TowerSystem._active_towers[0]
	assert_int(ElementSynergy.get_range_bonus_cells(query_tower)).is_equal(1)


# -- 15. test_range_bonus_earth_tier3 -----------------------------------------

func test_range_bonus_earth_tier3() -> void:
	_add_base_towers("earth", 8)
	ElementSynergy.recalculate()
	var query_tower: Node2D = TowerSystem._active_towers[0]
	assert_int(ElementSynergy.get_range_bonus_cells(query_tower)).is_equal(2)


# -- 16. test_chain_bonus_lightning_tier2 -------------------------------------

func test_chain_bonus_lightning_tier2() -> void:
	_add_base_towers("lightning", 5)
	ElementSynergy.recalculate()
	var query_tower: Node2D = TowerSystem._active_towers[0]
	assert_int(ElementSynergy.get_chain_bonus(query_tower)).is_equal(1)


# -- 17. test_freeze_chance_bonus_ice_tier2 -----------------------------------

func test_freeze_chance_bonus_ice_tier2() -> void:
	_add_base_towers("ice", 5)
	ElementSynergy.recalculate()
	var query_tower: Node2D = TowerSystem._active_towers[0]
	assert_float(ElementSynergy.get_freeze_chance_bonus(query_tower)).is_equal(0.10)


# -- 18. test_slow_bonus_water_tier2 ------------------------------------------

func test_slow_bonus_water_tier2() -> void:
	_add_base_towers("water", 5)
	ElementSynergy.recalculate()
	var query_tower: Node2D = TowerSystem._active_towers[0]
	assert_float(ElementSynergy.get_slow_bonus(query_tower)).is_equal(0.10)


# -- 19. test_no_aura_bonus_below_tier2 ---------------------------------------

func test_no_aura_bonus_below_tier2() -> void:
	# 3 fire towers -> tier 1, which does NOT grant aura bonuses (only tier 2+)
	_add_base_towers("fire", 3)
	ElementSynergy.recalculate()
	var query_tower: Node2D = TowerSystem._active_towers[0]
	assert_float(ElementSynergy.get_attack_speed_bonus(query_tower)).is_equal(0.0)


# -- 20. test_synergy_color_at_tier0 ------------------------------------------

func test_synergy_color_at_tier0() -> void:
	# No towers -> tier 0 -> Color.WHITE
	ElementSynergy.recalculate()
	var data: TowerData = _make_tower_data("Fire", "fire")
	var stub: Node2D = auto_free(_make_tower_stub(data))
	# Don't add to active towers -- synergy for fire is tier 0
	var color: Color = ElementSynergy.get_synergy_color(stub)
	assert_object(color).is_equal(Color.WHITE)


# -- 21. test_synergy_color_at_tier1 ------------------------------------------

func test_synergy_color_at_tier1() -> void:
	_add_base_towers("fire", 3)
	ElementSynergy.recalculate()
	var query_tower: Node2D = TowerSystem._active_towers[0]
	var color: Color = ElementSynergy.get_synergy_color(query_tower)
	# Tier 1: strength = 0.15 * 1 = 0.15
	var expected: Color = Color.WHITE.lerp(
		ElementSynergyClass.ELEMENT_COLORS["fire"], 0.15)
	assert_float(color.r).is_equal_approx(expected.r, 0.001)
	assert_float(color.g).is_equal_approx(expected.g, 0.001)
	assert_float(color.b).is_equal_approx(expected.b, 0.001)
	assert_float(color.a).is_equal_approx(expected.a, 0.001)


# -- 22. test_synergy_changed_signal_on_tier_change ---------------------------

func test_synergy_changed_signal_on_tier_change() -> void:
	# Start with 2 fire towers (tier 0). Adding a 3rd should push to tier 1.
	_add_base_towers("fire", 2)
	ElementSynergy.recalculate()
	assert_int(ElementSynergy.get_synergy_tier("fire")).is_equal(0)

	monitor_signals(ElementSynergy, false)
	# Add a 3rd fire tower and recalculate
	var data: TowerData = _make_tower_data("Fire3", "fire")
	var stub: Node2D = auto_free(_make_tower_stub(data))
	TowerSystem._active_towers.append(stub)
	ElementSynergy.recalculate()
	await assert_signal(ElementSynergy).wait_until(500).is_emitted("synergy_changed")


# -- 23. test_synergy_changed_not_emitted_when_same_tier ----------------------

func test_synergy_changed_not_emitted_when_same_tier() -> void:
	# 3 fire towers (tier 1). Adding a 4th stays at tier 1 -> no signal.
	_add_base_towers("fire", 3)
	ElementSynergy.recalculate()
	assert_int(ElementSynergy.get_synergy_tier("fire")).is_equal(1)

	monitor_signals(ElementSynergy, false)
	# Add a 4th fire tower (still tier 1, needs 5 for tier 2)
	var data: TowerData = _make_tower_data("Fire4", "fire")
	var stub: Node2D = auto_free(_make_tower_stub(data))
	TowerSystem._active_towers.append(stub)
	ElementSynergy.recalculate()
	await assert_signal(ElementSynergy).wait_until(500).is_not_emitted("synergy_changed")


# -- 24. test_recalculate_clears_old_counts -----------------------------------

func test_recalculate_clears_old_counts() -> void:
	# Add 5 fire towers -> tier 2
	var towers: Array[Node2D] = _add_base_towers("fire", 5)
	ElementSynergy.recalculate()
	assert_int(ElementSynergy.get_element_count("fire")).is_equal(5)
	assert_int(ElementSynergy.get_synergy_tier("fire")).is_equal(2)

	# "Sell" 3 towers by removing from active list
	for i: int in range(3):
		TowerSystem._active_towers.erase(towers[i])
	ElementSynergy.recalculate()
	# Now only 2 fire towers -> tier 0
	assert_int(ElementSynergy.get_element_count("fire")).is_equal(2)
	assert_int(ElementSynergy.get_synergy_tier("fire")).is_equal(0)
	assert_float(ElementSynergy.get_synergy_bonus("fire")).is_equal(1.0)
