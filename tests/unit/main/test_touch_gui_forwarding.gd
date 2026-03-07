extends GdUnitTestSuite

## Unit tests for mobile-web touch-to-GUI fix: direct action invocation.
## Verifies that _try_forward_touch_to_gui uses direct action calls (not
## synthetic mouse events) and that the helper methods _control_hit_test
## and _find_hit_button exist with correct signatures.
## Uses source-code analysis since Game.gd has heavy scene dependencies.

const GAME_SCRIPT_PATH: String = "res://scripts/main/Game.gd"
const HUD_SCRIPT_PATH: String = "res://scripts/ui/HUD.gd"

var _src: String


func before() -> void:
	_src = load(GAME_SCRIPT_PATH).source_code


# -- Section 1: Old synthetic injection removed --------------------------------

func test_inject_mouse_click_method_removed() -> void:
	## _inject_mouse_click should no longer exist -- replaced by direct invocation.
	assert_bool(_src.contains("func _inject_mouse_click")) \
		.override_failure_message("_inject_mouse_click method should be removed") \
		.is_false()


func test_collect_visible_buttons_method_removed() -> void:
	## _collect_visible_buttons should no longer exist -- replaced by _find_hit_button.
	assert_bool(_src.contains("func _collect_visible_buttons")) \
		.override_failure_message("_collect_visible_buttons method should be removed") \
		.is_false()


func test_no_parse_input_event_in_touch_gui() -> void:
	## _try_forward_touch_to_gui should NOT call Input.parse_input_event
	## (that was the old synthetic injection approach that failed on mobile-web).
	## We check only non-comment lines (lines not starting with ##).
	var method_body: String = _extract_method_body("_try_forward_touch_to_gui")
	var has_call: bool = false
	for line: String in method_body.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("##") or stripped.begins_with("#"):
			continue
		if stripped.contains("Input.parse_input_event"):
			has_call = true
			break
	assert_bool(has_call) \
		.override_failure_message("_try_forward_touch_to_gui should not call Input.parse_input_event") \
		.is_false()


# -- Section 2: New helper methods exist ---------------------------------------

func test_control_hit_test_method_exists() -> void:
	## _control_hit_test helper must exist for rect-based hit testing.
	assert_bool(_src.contains("func _control_hit_test")) \
		.override_failure_message("Game.gd missing _control_hit_test method") \
		.is_true()


func test_control_hit_test_takes_control_and_vector2() -> void:
	## _control_hit_test should accept (ctrl: Control, screen_pos: Vector2).
	assert_bool(_src.contains("func _control_hit_test(ctrl: Control, screen_pos: Vector2)")) \
		.override_failure_message("_control_hit_test should take (ctrl: Control, screen_pos: Vector2)") \
		.is_true()


func test_control_hit_test_returns_bool() -> void:
	## _control_hit_test should return bool.
	assert_bool(_src.contains("func _control_hit_test(ctrl: Control, screen_pos: Vector2) -> bool")) \
		.override_failure_message("_control_hit_test should return bool") \
		.is_true()


func test_find_hit_button_method_exists() -> void:
	## _find_hit_button helper must exist for recursive button search.
	assert_bool(_src.contains("func _find_hit_button")) \
		.override_failure_message("Game.gd missing _find_hit_button method") \
		.is_true()


func test_find_hit_button_takes_control_and_vector2() -> void:
	## _find_hit_button should accept (root: Control, screen_pos: Vector2).
	assert_bool(_src.contains("func _find_hit_button(root: Control, screen_pos: Vector2)")) \
		.override_failure_message("_find_hit_button should take (root: Control, screen_pos: Vector2)") \
		.is_true()


func test_find_hit_button_returns_button() -> void:
	## _find_hit_button should return Button (nullable).
	assert_bool(_src.contains("func _find_hit_button(root: Control, screen_pos: Vector2) -> Button")) \
		.override_failure_message("_find_hit_button should return Button") \
		.is_true()


# -- Section 3: Direct action invocations in _try_forward_touch_to_gui ---------

func test_build_fab_calls_toggle_build_sheet() -> void:
	## When Build FAB is tapped, _try_forward_touch_to_gui should call
	## _toggle_build_sheet() directly (not inject a mouse event).
	var method_body: String = _extract_method_body("_try_forward_touch_to_gui")
	assert_bool(method_body.contains("_toggle_build_sheet()")) \
		.override_failure_message("Should call _toggle_build_sheet() for Build FAB tap") \
		.is_true()


func test_pause_button_in_touch_forwarding() -> void:
	## Mobile pause button path should be in the HUD button list for touch forwarding.
	var method_body: String = _extract_method_body("_try_forward_touch_to_gui")
	assert_bool(method_body.contains("MobilePauseButton")) \
		.override_failure_message("Should include MobilePauseButton in HUD button paths") \
		.is_true()


func test_cancel_fab_calls_cancel_placement() -> void:
	## When the cancel FAB is tapped, should call _cancel_placement.
	var method_body: String = _extract_method_body("_try_forward_touch_to_gui")
	assert_bool(method_body.contains("_cancel_fab") and method_body.contains("_cancel_placement")) \
		.override_failure_message("Should call _cancel_placement for cancel FAB tap") \
		.is_true()


func test_no_overflow_menu_in_touch_forwarding() -> void:
	## Old overflow menu/dimmer handling should be removed from touch forwarding.
	var method_body: String = _extract_method_body("_try_forward_touch_to_gui")
	assert_bool(method_body.contains("_overflow_menu")) \
		.override_failure_message("_overflow_menu should not appear in _try_forward_touch_to_gui") \
		.is_false()


func test_build_menu_buttons_emit_pressed() -> void:
	## Build menu tower buttons should have their pressed signal emitted directly.
	var method_body: String = _extract_method_body("_try_forward_touch_to_gui")
	# The method should handle build_menu and emit pressed on hit buttons
	assert_bool(method_body.contains("UIManager.build_menu") and method_body.contains(".pressed.emit()")) \
		.override_failure_message("Should emit pressed for build menu buttons") \
		.is_true()


func test_tower_info_panel_buttons_emit_pressed() -> void:
	## Tower info panel buttons should have their pressed signal emitted directly.
	var method_body: String = _extract_method_body("_try_forward_touch_to_gui")
	assert_bool(method_body.contains("UIManager.tower_info_panel")) \
		.override_failure_message("Should handle tower info panel buttons") \
		.is_true()


func test_hud_speed_button_emits_pressed() -> void:
	## Speed button in HUD should emit pressed directly.
	var method_body: String = _extract_method_body("_try_forward_touch_to_gui")
	assert_bool(method_body.contains("TopBar/SpeedButton")) \
		.override_failure_message("Should check TopBar/SpeedButton") \
		.is_true()


func test_hud_start_wave_button_emits_pressed() -> void:
	## Start wave button in HUD should emit pressed directly.
	var method_body: String = _extract_method_body("_try_forward_touch_to_gui")
	assert_bool(method_body.contains("WaveControls/StartWaveButton")) \
		.override_failure_message("Should check WaveControls/StartWaveButton") \
		.is_true()


# -- Section 4: Cancel FAB checked before build menu ---------------------------

func test_cancel_fab_checked_before_build_menu() -> void:
	## Cancel FAB must be checked BEFORE build menu, so tapping the cancel button
	## during placement cancels placement rather than activating a build menu button.
	var method_body: String = _extract_method_body("_try_forward_touch_to_gui")
	var cancel_fab_pos: int = method_body.find("_cancel_fab")
	var build_menu_pos: int = method_body.find("UIManager.build_menu")
	assert_bool(cancel_fab_pos >= 0 and build_menu_pos >= 0) \
		.override_failure_message("Both _cancel_fab and build_menu must be referenced") \
		.is_true()
	assert_bool(cancel_fab_pos < build_menu_pos) \
		.override_failure_message("Cancel FAB should be checked before build menu") \
		.is_true()


# -- Section 5: Build menu panel consumes taps (no grid click) -----------------

func test_build_menu_panel_consumes_non_button_taps() -> void:
	## Tapping on the build menu panel (not on a button) should still return true
	## to prevent the tap from becoming a grid click.
	var method_body: String = _extract_method_body("_try_forward_touch_to_gui")
	# Should have a second _control_hit_test for build_menu after button check
	var build_menu_section: String = method_body.substr(method_body.find("Build-menu"))
	assert_bool(build_menu_section.contains("_control_hit_test(UIManager.build_menu")) \
		.override_failure_message("Should consume taps on build menu panel area") \
		.is_true()


# -- Section 6: _control_hit_test uses correct transform ----------------------

func test_control_hit_test_uses_get_global_transform_with_canvas() -> void:
	## _control_hit_test must use get_global_transform_with_canvas() to properly
	## account for CanvasLayer transforms and viewport stretch.
	var method_body: String = _extract_method_body("_control_hit_test")
	assert_bool(method_body.contains("get_global_transform_with_canvas")) \
		.override_failure_message("_control_hit_test must use get_global_transform_with_canvas") \
		.is_true()


func test_control_hit_test_uses_affine_inverse() -> void:
	## _control_hit_test must apply affine_inverse to transform screen coords to local.
	var method_body: String = _extract_method_body("_control_hit_test")
	assert_bool(method_body.contains("affine_inverse")) \
		.override_failure_message("_control_hit_test must use affine_inverse") \
		.is_true()


func test_control_hit_test_checks_is_inside_tree() -> void:
	## _control_hit_test must check is_inside_tree before accessing transforms.
	var method_body: String = _extract_method_body("_control_hit_test")
	assert_bool(method_body.contains("is_inside_tree")) \
		.override_failure_message("_control_hit_test must check is_inside_tree") \
		.is_true()


# -- Section 7: _find_hit_button skips disabled buttons ------------------------

func test_find_hit_button_skips_disabled() -> void:
	## _find_hit_button should not return disabled buttons (e.g., unaffordable towers).
	var method_body: String = _extract_method_body("_find_hit_button")
	assert_bool(method_body.contains("disabled")) \
		.override_failure_message("_find_hit_button should check disabled state") \
		.is_true()


func test_find_hit_button_is_recursive() -> void:
	## _find_hit_button should recurse into child Controls.
	var method_body: String = _extract_method_body("_find_hit_button")
	assert_bool(method_body.contains("_find_hit_button(")) \
		.override_failure_message("_find_hit_button should recurse into children") \
		.is_true()


# -- Section 8: HUD has required methods for direct invocation -----------------

func test_hud_has_create_pause_button() -> void:
	## HUD.gd must have _create_pause_button method (replaces old overflow menu).
	var hud_src: String = load(HUD_SCRIPT_PATH).source_code
	assert_bool(hud_src.contains("func _create_pause_button")) \
		.override_failure_message("HUD.gd must have _create_pause_button method") \
		.is_true()


func test_hud_has_on_pause_pressed() -> void:
	## HUD.gd must have _on_pause_pressed method (called by Game.gd touch forwarding).
	var hud_src: String = load(HUD_SCRIPT_PATH).source_code
	assert_bool(hud_src.contains("func _on_pause_pressed")) \
		.override_failure_message("HUD.gd must have _on_pause_pressed method") \
		.is_true()


func test_hud_has_get_overflow_button() -> void:
	## HUD.gd must have get_overflow_button method (called by Game.gd for hit testing).
	var hud_src: String = load(HUD_SCRIPT_PATH).source_code
	assert_bool(hud_src.contains("func get_overflow_button")) \
		.override_failure_message("HUD.gd must have get_overflow_button method") \
		.is_true()


# -- Section 9: No platform-conditional injection logic left -------------------

func test_no_needs_injection_variable() -> void:
	## The old needs_injection variable (OS.has_feature("web") check) should be gone.
	## Direct invocation works on all platforms, no conditional needed.
	var method_body: String = _extract_method_body("_try_forward_touch_to_gui")
	assert_bool(method_body.contains("needs_injection")) \
		.override_failure_message("needs_injection logic should be removed (direct invocation works everywhere)") \
		.is_false()


func test_no_os_has_feature_web_in_touch_gui() -> void:
	## No OS.has_feature("web") check needed in _try_forward_touch_to_gui.
	var method_body: String = _extract_method_body("_try_forward_touch_to_gui")
	assert_bool(method_body.contains("OS.has_feature")) \
		.override_failure_message("OS.has_feature check should be removed from _try_forward_touch_to_gui") \
		.is_false()


# -- Helpers -------------------------------------------------------------------

func _extract_method_body(method_name: String) -> String:
	## Extract the body of a GDScript method from source code.
	## Returns everything from the func declaration to the next top-level func.
	var start_pattern: String = "func %s" % method_name
	var start_idx: int = _src.find(start_pattern)
	if start_idx < 0:
		return ""
	# Find the next top-level func (line starting with "func " at column 0)
	var search_from: int = start_idx + start_pattern.length()
	var next_func_idx: int = _src.find("\nfunc ", search_from)
	if next_func_idx < 0:
		return _src.substr(start_idx)
	return _src.substr(start_idx, next_func_idx - start_idx)
