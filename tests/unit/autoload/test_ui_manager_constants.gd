extends GdUnitTestSuite

## Unit tests for UIManager mobile size constants (v3, 270dp-validated).
## Verifies all mobile sizing constants, helper methods, and touch-target minimums.


# -- MOBILE_SCALE constant (unchanged) ----------------------------------------

func test_mobile_scale_exists_and_equals_1_5() -> void:
	assert_float(UIManagerClass.MOBILE_SCALE).is_equal(1.5)


# -- Updated button/touch-target constants ------------------------------------

func test_mobile_button_min_is_128x128() -> void:
	assert_object(UIManagerClass.MOBILE_BUTTON_MIN).is_equal(Vector2(128, 128))


func test_mobile_tower_button_min_is_170x128() -> void:
	assert_object(UIManagerClass.MOBILE_TOWER_BUTTON_MIN).is_equal(Vector2(170, 128))


func test_mobile_action_button_min_height_is_128() -> void:
	assert_float(UIManagerClass.MOBILE_ACTION_BUTTON_MIN_HEIGHT).is_equal(128.0)


func test_mobile_start_wave_min_is_200x128() -> void:
	assert_object(UIManagerClass.MOBILE_START_WAVE_MIN).is_equal(Vector2(200, 128))


# -- Updated font size constants -----------------------------------------------

func test_mobile_font_size_body_is_24() -> void:
	assert_int(UIManagerClass.MOBILE_FONT_SIZE_BODY).is_equal(24)


func test_mobile_font_size_label_is_20() -> void:
	assert_int(UIManagerClass.MOBILE_FONT_SIZE_LABEL).is_equal(20)


func test_mobile_font_size_title_is_36() -> void:
	assert_int(UIManagerClass.MOBILE_FONT_SIZE_TITLE).is_equal(36)


# -- Updated layout constants --------------------------------------------------

func test_mobile_topbar_height_is_48() -> void:
	assert_int(UIManagerClass.MOBILE_TOPBAR_HEIGHT).is_equal(48)


func test_mobile_build_menu_height_is_300() -> void:
	assert_int(UIManagerClass.MOBILE_BUILD_MENU_HEIGHT).is_equal(300)


func test_mobile_card_min_height_is_200() -> void:
	assert_int(UIManagerClass.MOBILE_CARD_MIN_HEIGHT).is_equal(200)


# -- New constants (v3) --------------------------------------------------------

func test_mobile_font_size_small_is_16() -> void:
	assert_int(UIManagerClass.MOBILE_FONT_SIZE_SMALL).is_equal(16)


func test_mobile_damage_number_scale_is_1_8() -> void:
	assert_float(UIManagerClass.MOBILE_DAMAGE_NUMBER_SCALE).is_equal(1.8)


func test_mobile_placement_zoom_is_1_5() -> void:
	assert_float(UIManagerClass.MOBILE_PLACEMENT_ZOOM).is_equal(1.5)


func test_mobile_panel_max_height_ratio_is_0_35() -> void:
	assert_float(UIManagerClass.MOBILE_PANEL_MAX_HEIGHT_RATIO).is_equal(0.35)


func test_mobile_panel_collapsed_height_is_160() -> void:
	assert_int(UIManagerClass.MOBILE_PANEL_COLLAPSED_HEIGHT).is_equal(160)


func test_mobile_overflow_button_size_is_96x48() -> void:
	assert_object(UIManagerClass.MOBILE_OVERFLOW_BUTTON_SIZE).is_equal(Vector2(96, 48))


# -- Touch target minimum (128px) validation -----------------------------------

func test_mobile_button_min_meets_128px_touch_target() -> void:
	assert_bool(UIManagerClass.MOBILE_BUTTON_MIN.x >= 128).is_true()
	assert_bool(UIManagerClass.MOBILE_BUTTON_MIN.y >= 128).is_true()


func test_mobile_tower_button_exceeds_128px_in_both_dimensions() -> void:
	assert_bool(UIManagerClass.MOBILE_TOWER_BUTTON_MIN.x >= 128).is_true()
	assert_bool(UIManagerClass.MOBILE_TOWER_BUTTON_MIN.y >= 128).is_true()


func test_mobile_action_button_min_height_meets_128px() -> void:
	assert_bool(UIManagerClass.MOBILE_ACTION_BUTTON_MIN_HEIGHT >= 128.0).is_true()


func test_mobile_start_wave_min_meets_128px_in_both_dimensions() -> void:
	assert_bool(UIManagerClass.MOBILE_START_WAVE_MIN.x >= 128).is_true()
	assert_bool(UIManagerClass.MOBILE_START_WAVE_MIN.y >= 128).is_true()


# -- Helper methods ------------------------------------------------------------

func test_format_hint_returns_desktop_text_when_not_mobile() -> void:
	# On desktop test runner, is_mobile() is false.
	var result: String = UIManagerClass.format_hint("Press E", "Tap here")
	assert_str(result).is_equal("Press E")


func test_format_hint_returns_string() -> void:
	var result: String = UIManagerClass.format_hint("desktop", "mobile")
	assert_str(result).is_not_empty()


func test_haptic_is_callable() -> void:
	# Just verify the method exists and can be called without error.
	UIManagerClass.haptic(50)
	# If we get here without error, the test passes.
	assert_bool(true).is_true()


# -- is_mobile() behavior unchanged --------------------------------------------

func test_is_mobile_returns_bool() -> void:
	var result: bool = UIManagerClass.is_mobile()
	assert_bool(result).is_not_null()


func test_is_mobile_is_static() -> void:
	var result: bool = UIManagerClass.is_mobile()
	assert_bool(result is bool).is_true()
