extends GdUnitTestSuite

## Unit tests for ElementMatrix (static class).
## Covers: get_multiplier (8 tests), matrix validation (2 tests),
## get_elements (1 test), get_counter (3 tests), get_color (3 tests).


# -- get_multiplier: Strong / Weak / Neutral / Slight -------------------------

func test_get_multiplier_strong() -> void:
	# fire vs earth -> 1.5 (strong)
	assert_float(ElementMatrix.get_multiplier("fire", "earth")).is_equal(1.5)


func test_get_multiplier_weak() -> void:
	# fire vs water -> 0.5 (weak)
	assert_float(ElementMatrix.get_multiplier("fire", "water")).is_equal(0.5)


func test_get_multiplier_neutral() -> void:
	# fire vs fire -> 1.0 (neutral, same element)
	assert_float(ElementMatrix.get_multiplier("fire", "fire")).is_equal(1.0)


func test_get_multiplier_slight_strong() -> void:
	# wind vs earth -> 1.25 (slightly strong)
	assert_float(ElementMatrix.get_multiplier("wind", "earth")).is_equal(1.25)


func test_get_multiplier_slight_weak() -> void:
	# water vs lightning -> 0.75 (slightly weak)
	assert_float(ElementMatrix.get_multiplier("water", "lightning")).is_equal(0.75)


# -- get_multiplier: Edge cases (unknown / special elements) -------------------

func test_get_multiplier_none_target() -> void:
	# "none" is not in the matrix -> fallback to 1.0
	assert_float(ElementMatrix.get_multiplier("fire", "none")).is_equal(1.0)


func test_get_multiplier_chaos_target() -> void:
	# "chaos" is not in the matrix -> fallback to 1.0
	assert_float(ElementMatrix.get_multiplier("fire", "chaos")).is_equal(1.0)


func test_get_multiplier_unknown_attacker() -> void:
	# "plasma" is not in the matrix -> fallback to 1.0
	assert_float(ElementMatrix.get_multiplier("plasma", "fire")).is_equal(1.0)


# -- Matrix Validation --------------------------------------------------------

func test_matrix_symmetry_spot_checks() -> void:
	# Verify specific attacker/defender pairs match the GDD values.
	# These are NOT expected to be symmetric (A vs B != B vs A in general),
	# but each direction should match the MATRIX const.
	assert_float(ElementMatrix.get_multiplier("water", "fire")).is_equal(1.5)
	assert_float(ElementMatrix.get_multiplier("earth", "water")).is_equal(1.5)
	assert_float(ElementMatrix.get_multiplier("earth", "fire")).is_equal(0.5)
	assert_float(ElementMatrix.get_multiplier("lightning", "wind")).is_equal(1.5)
	assert_float(ElementMatrix.get_multiplier("lightning", "water")).is_equal(1.25)
	assert_float(ElementMatrix.get_multiplier("ice", "fire")).is_equal(0.5)
	assert_float(ElementMatrix.get_multiplier("ice", "wind")).is_equal(0.5)
	assert_float(ElementMatrix.get_multiplier("wind", "ice")).is_equal(1.5)


func test_all_36_combinations() -> void:
	# Iterate all 6x6 element pairs and verify get_multiplier matches the
	# MATRIX const directly, ensuring the function is a faithful accessor.
	var elements: Array[String] = ElementMatrix.get_elements()
	assert_int(elements.size()).is_equal(6)
	for attacker: String in elements:
		for defender: String in elements:
			var expected: float = ElementMatrix.MATRIX[attacker][defender]
			var actual: float = ElementMatrix.get_multiplier(attacker, defender)
			assert_float(actual).is_equal(expected)


# -- get_elements --------------------------------------------------------------

func test_get_elements_returns_6() -> void:
	var elements: Array[String] = ElementMatrix.get_elements()
	assert_int(elements.size()).is_equal(6)
	assert_array(elements).contains(["fire", "water", "earth", "wind", "lightning", "ice"])


# -- get_counter ---------------------------------------------------------------

func test_get_counter_fire() -> void:
	# The counter of fire is water (water deals 1.5x to fire)
	assert_str(ElementMatrix.get_counter("fire")).is_equal("water")


func test_get_counter_all_6() -> void:
	assert_str(ElementMatrix.get_counter("fire")).is_equal("water")
	assert_str(ElementMatrix.get_counter("water")).is_equal("earth")
	assert_str(ElementMatrix.get_counter("earth")).is_equal("wind")
	assert_str(ElementMatrix.get_counter("wind")).is_equal("lightning")
	assert_str(ElementMatrix.get_counter("lightning")).is_equal("fire")
	assert_str(ElementMatrix.get_counter("ice")).is_equal("fire")


func test_get_counter_unknown() -> void:
	# "none" has no counter defined -> returns empty string
	assert_str(ElementMatrix.get_counter("none")).is_equal("")


# -- get_color -----------------------------------------------------------------

func test_get_color_fire() -> void:
	var color: Color = ElementMatrix.get_color("fire")
	assert_float(color.r).is_equal_approx(1.0, 0.001)
	assert_float(color.g).is_equal_approx(0.4, 0.001)
	assert_float(color.b).is_equal_approx(0.2, 0.001)


func test_get_color_unknown() -> void:
	# Unknown element returns Color.WHITE
	var color: Color = ElementMatrix.get_color("plasma")
	assert_float(color.r).is_equal_approx(1.0, 0.001)
	assert_float(color.g).is_equal_approx(1.0, 0.001)
	assert_float(color.b).is_equal_approx(1.0, 0.001)
	assert_float(color.a).is_equal_approx(1.0, 0.001)


func test_get_color_all_6() -> void:
	# All 6 elements return non-WHITE colors
	var elements: Array[String] = ElementMatrix.get_elements()
	for element: String in elements:
		var color: Color = ElementMatrix.get_color(element)
		# At least one RGB channel must differ from WHITE (1,1,1)
		var is_white: bool = is_equal_approx(color.r, 1.0) and is_equal_approx(color.g, 1.0) and is_equal_approx(color.b, 1.0)
		assert_bool(is_white).is_false()
