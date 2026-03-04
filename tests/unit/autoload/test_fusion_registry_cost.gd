extends GdUnitTestSuite

## Unit tests for FusionRegistry.get_fusion_cost() and get_legendary_cost().


# -- 1. get_fusion_cost valid pair returns positive int -----------------------

func test_get_fusion_cost_valid_pair() -> void:
	var cost: int = FusionRegistry.get_fusion_cost("earth", "fire")
	assert_int(cost).is_greater(0)


# -- 2. get_fusion_cost same element returns -1 --------------------------------

func test_get_fusion_cost_invalid_pair() -> void:
	var cost: int = FusionRegistry.get_fusion_cost("earth", "earth")
	assert_int(cost).is_equal(-1)


# -- 3. get_fusion_cost nonexistent elements returns -1 ------------------------

func test_get_fusion_cost_nonexistent_elements() -> void:
	var cost: int = FusionRegistry.get_fusion_cost("shadow", "void")
	assert_int(cost).is_equal(-1)


# -- 4. get_legendary_cost valid triple returns positive int -------------------

func test_get_legendary_cost_valid_triple() -> void:
	var tier2_elements: Array[String] = ["earth", "fire"]
	var cost: int = FusionRegistry.get_legendary_cost(tier2_elements, "water")
	assert_int(cost).is_greater(0)


# -- 5. get_legendary_cost invalid triple returns -1 ---------------------------

func test_get_legendary_cost_invalid_triple() -> void:
	var tier2_elements: Array[String] = ["shadow", "void"]
	var cost: int = FusionRegistry.get_legendary_cost(tier2_elements, "plasma")
	assert_int(cost).is_equal(-1)


# -- 6. get_fusion_cost is order independent -----------------------------------

func test_get_fusion_cost_order_independent() -> void:
	var cost_a: int = FusionRegistry.get_fusion_cost("fire", "earth")
	var cost_b: int = FusionRegistry.get_fusion_cost("earth", "fire")
	assert_int(cost_a).is_greater(0)
	assert_int(cost_a).is_equal(cost_b)
