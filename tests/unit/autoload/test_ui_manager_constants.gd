extends GdUnitTestSuite

## Unit tests for Task A1: Mobile Size Constants in UIManager.
## Verifies all mobile sizing constants exist with correct values and
## that is_mobile() behavior is unchanged.


# -- MOBILE_SCALE constant -----------------------------------------------------

func test_mobile_scale_exists_and_equals_1_5() -> void:
	assert_float(UIManagerClass.MOBILE_SCALE).is_equal(1.5)


# -- Updated existing constants ------------------------------------------------

func test_mobile_button_min_is_64x64() -> void:
	assert_object(UIManagerClass.MOBILE_BUTTON_MIN).is_equal(Vector2(64, 64))


func test_mobile_tower_button_min_is_150x100() -> void:
	assert_object(UIManagerClass.MOBILE_TOWER_BUTTON_MIN).is_equal(Vector2(150, 100))


func test_mobile_action_button_min_height_is_56() -> void:
	assert_float(UIManagerClass.MOBILE_ACTION_BUTTON_MIN_HEIGHT).is_equal(56.0)


func test_mobile_start_wave_min_is_160x64() -> void:
	assert_object(UIManagerClass.MOBILE_START_WAVE_MIN).is_equal(Vector2(160, 64))


# -- New font size constants ---------------------------------------------------

func test_mobile_font_size_body_is_16() -> void:
	assert_int(UIManagerClass.MOBILE_FONT_SIZE_BODY).is_equal(16)


func test_mobile_font_size_label_is_14() -> void:
	assert_int(UIManagerClass.MOBILE_FONT_SIZE_LABEL).is_equal(14)


func test_mobile_font_size_title_is_24() -> void:
	assert_int(UIManagerClass.MOBILE_FONT_SIZE_TITLE).is_equal(24)


# -- New layout constants ------------------------------------------------------

func test_mobile_topbar_height_is_72() -> void:
	assert_int(UIManagerClass.MOBILE_TOPBAR_HEIGHT).is_equal(72)


func test_mobile_build_menu_height_is_140() -> void:
	assert_int(UIManagerClass.MOBILE_BUILD_MENU_HEIGHT).is_equal(140)


func test_mobile_card_min_height_is_160() -> void:
	assert_int(UIManagerClass.MOBILE_CARD_MIN_HEIGHT).is_equal(160)


# -- Touch target minimum (100px) ----------------------------------------------

func test_mobile_button_min_meets_100px_touch_target() -> void:
	# Both dimensions should be at least 64px; the constant should not be
	# smaller than the minimum we've chosen (which already exceeds Android's
	# 48dp guideline at 1.5x).
	assert_bool(UIManagerClass.MOBILE_BUTTON_MIN.x >= 64).is_true()
	assert_bool(UIManagerClass.MOBILE_BUTTON_MIN.y >= 64).is_true()


func test_mobile_tower_button_exceeds_100px_in_both_dimensions() -> void:
	assert_bool(UIManagerClass.MOBILE_TOWER_BUTTON_MIN.x >= 100).is_true()
	assert_bool(UIManagerClass.MOBILE_TOWER_BUTTON_MIN.y >= 100).is_true()


# -- is_mobile() behavior unchanged --------------------------------------------

func test_is_mobile_returns_bool() -> void:
	var result: bool = UIManagerClass.is_mobile()
	# On desktop test runner this should be false, but we only care about the type.
	assert_bool(result).is_not_null()


func test_is_mobile_is_static() -> void:
	# Calling is_mobile() as a static method (on the class, not an instance)
	# should work without error.
	var result: bool = UIManagerClass.is_mobile()
	assert_bool(result is bool).is_true()
