extends GdUnitTestSuite

## Unit tests for Task C1: Tower Placement Auto-Zoom with Grid-Snap.
## Tests Game.gd placement-zoom state variables, constants, and method wiring.
## Also tests CellHighlight.gd structure.
## Uses source-code analysis since Game.gd has heavy scene dependencies.

const GAME_SCRIPT_PATH: String = "res://scripts/main/Game.gd"
const CELL_HIGHLIGHT_PATH: String = "res://scripts/ui/CellHighlight.gd"


# -- Section 1: State variables exist in Game.gd --------------------------------

func test_game_has_pre_placement_zoom_variable() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(src.contains("var _pre_placement_zoom")) \
		.override_failure_message("Game.gd missing _pre_placement_zoom variable") \
		.is_true()


func test_game_has_snap_grid_pos_variable() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(src.contains("var _snap_grid_pos")) \
		.override_failure_message("Game.gd missing _snap_grid_pos variable") \
		.is_true()


func test_game_has_auto_zoom_active_variable() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(src.contains("var _auto_zoom_active")) \
		.override_failure_message("Game.gd missing _auto_zoom_active variable") \
		.is_true()


func test_game_has_cell_highlight_variable() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(src.contains("var _cell_highlight")) \
		.override_failure_message("Game.gd missing _cell_highlight variable") \
		.is_true()


func test_game_has_placement_zoom_tween_variable() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(src.contains("var _placement_zoom_tween")) \
		.override_failure_message("Game.gd missing _placement_zoom_tween variable") \
		.is_true()


# -- Section 2: Constants exist in Game.gd --------------------------------------

func test_game_has_snap_hysteresis_threshold_constant() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(src.contains("SNAP_HYSTERESIS_THRESHOLD")) \
		.override_failure_message("Game.gd missing SNAP_HYSTERESIS_THRESHOLD constant") \
		.is_true()


func test_snap_hysteresis_threshold_value_is_32() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(src.contains("SNAP_HYSTERESIS_THRESHOLD: float = 32.0") or src.contains("SNAP_HYSTERESIS_THRESHOLD = 32.0")) \
		.override_failure_message("SNAP_HYSTERESIS_THRESHOLD should be 32.0") \
		.is_true()


func test_game_has_placement_zoom_duration_constant() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(src.contains("PLACEMENT_ZOOM_DURATION")) \
		.override_failure_message("Game.gd missing PLACEMENT_ZOOM_DURATION constant") \
		.is_true()


func test_placement_zoom_duration_value_is_03() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(src.contains("PLACEMENT_ZOOM_DURATION: float = 0.3") or src.contains("PLACEMENT_ZOOM_DURATION = 0.3")) \
		.override_failure_message("PLACEMENT_ZOOM_DURATION should be 0.3") \
		.is_true()


func test_game_has_placement_zoom_restore_delay_constant() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(src.contains("PLACEMENT_ZOOM_RESTORE_DELAY")) \
		.override_failure_message("Game.gd missing PLACEMENT_ZOOM_RESTORE_DELAY constant") \
		.is_true()


func test_placement_zoom_restore_delay_value_is_015() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(src.contains("PLACEMENT_ZOOM_RESTORE_DELAY: float = 0.15") or src.contains("PLACEMENT_ZOOM_RESTORE_DELAY = 0.15")) \
		.override_failure_message("PLACEMENT_ZOOM_RESTORE_DELAY should be 0.15") \
		.is_true()


# -- Section 3: New methods exist in Game.gd ------------------------------------

func test_game_has_restore_placement_zoom_method() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(src.contains("func _restore_placement_zoom")) \
		.override_failure_message("Game.gd missing _restore_placement_zoom method") \
		.is_true()


func test_game_has_create_cell_highlight_method() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(src.contains("func _create_cell_highlight")) \
		.override_failure_message("Game.gd missing _create_cell_highlight method") \
		.is_true()


func test_game_has_update_cell_highlight_method() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(src.contains("func _update_cell_highlight")) \
		.override_failure_message("Game.gd missing _update_cell_highlight method") \
		.is_true()


func test_game_has_clear_cell_highlight_method() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(src.contains("func _clear_cell_highlight")) \
		.override_failure_message("Game.gd missing _clear_cell_highlight method") \
		.is_true()


# -- Section 4: Method wiring (build_requested, cancel, click, drag) -----------

func test_on_build_requested_checks_is_mobile() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	# Find the _on_build_requested function body
	var idx: int = src.find("func _on_build_requested")
	assert_bool(idx >= 0) \
		.override_failure_message("Game.gd missing _on_build_requested method") \
		.is_true()
	var body: String = src.substr(idx, 600)
	assert_bool(body.contains("is_mobile()")) \
		.override_failure_message("_on_build_requested should check is_mobile()") \
		.is_true()


func test_on_build_requested_references_mobile_placement_zoom() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	var idx: int = src.find("func _on_build_requested")
	var body: String = src.substr(idx, 600)
	assert_bool(body.contains("MOBILE_PLACEMENT_ZOOM")) \
		.override_failure_message("_on_build_requested should reference MOBILE_PLACEMENT_ZOOM") \
		.is_true()


func test_on_build_requested_sets_ghost_scale_1_on_mobile() -> void:
	## On mobile, ghost scale should be set to 1.0 (not 1.5) during auto-zoom.
	var src: String = load(GAME_SCRIPT_PATH).source_code
	var idx: int = src.find("func _on_build_requested")
	var body: String = src.substr(idx, 1000)
	assert_bool(body.contains("Vector2(1.0, 1.0)")) \
		.override_failure_message("_on_build_requested should set ghost scale to Vector2(1.0, 1.0) on mobile") \
		.is_true()


func test_update_ghost_uses_snap_hysteresis() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	var idx: int = src.find("func _update_ghost")
	assert_bool(idx >= 0) \
		.override_failure_message("Game.gd missing _update_ghost method") \
		.is_true()
	var body: String = src.substr(idx, 1200)
	assert_bool(body.contains("SNAP_HYSTERESIS_THRESHOLD")) \
		.override_failure_message("_update_ghost should reference SNAP_HYSTERESIS_THRESHOLD") \
		.is_true()


func test_update_ghost_references_snap_grid_pos() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	var idx: int = src.find("func _update_ghost")
	var body: String = src.substr(idx, 1200)
	assert_bool(body.contains("_snap_grid_pos")) \
		.override_failure_message("_update_ghost should reference _snap_grid_pos") \
		.is_true()


func test_cancel_placement_calls_restore_placement_zoom() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	var idx: int = src.find("func _cancel_placement")
	assert_bool(idx >= 0) \
		.override_failure_message("Game.gd missing _cancel_placement method") \
		.is_true()
	var body: String = src.substr(idx, 400)
	assert_bool(body.contains("_restore_placement_zoom")) \
		.override_failure_message("_cancel_placement should call _restore_placement_zoom") \
		.is_true()


func test_handle_click_calls_restore_on_successful_placement() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	var idx: int = src.find("func _handle_click")
	assert_bool(idx >= 0) \
		.override_failure_message("Game.gd missing _handle_click method") \
		.is_true()
	var body: String = src.substr(idx, 800)
	assert_bool(body.contains("_restore_placement_zoom")) \
		.override_failure_message("_handle_click should call _restore_placement_zoom after placement") \
		.is_true()


func test_handle_screen_drag_checks_auto_zoom_active() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	var idx: int = src.find("func _handle_screen_drag")
	assert_bool(idx >= 0) \
		.override_failure_message("Game.gd missing _handle_screen_drag method") \
		.is_true()
	var body: String = src.substr(idx, 800)
	assert_bool(body.contains("_auto_zoom_active")) \
		.override_failure_message("_handle_screen_drag should check _auto_zoom_active for pinch override") \
		.is_true()


# -- Section 5: _restore_placement_zoom method body checks ----------------------

func test_restore_placement_zoom_checks_is_mobile() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	var idx: int = src.find("func _restore_placement_zoom")
	assert_bool(idx >= 0).is_true()
	var body: String = src.substr(idx, 600)
	assert_bool(body.contains("is_mobile()")) \
		.override_failure_message("_restore_placement_zoom should check is_mobile()") \
		.is_true()


func test_restore_placement_zoom_resets_auto_zoom_active() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	var idx: int = src.find("func _restore_placement_zoom")
	var body: String = src.substr(idx, 600)
	assert_bool(body.contains("_auto_zoom_active = false")) \
		.override_failure_message("_restore_placement_zoom should set _auto_zoom_active = false") \
		.is_true()


func test_restore_placement_zoom_restores_ghost_scale() -> void:
	var src: String = load(GAME_SCRIPT_PATH).source_code
	var idx: int = src.find("func _restore_placement_zoom")
	var body: String = src.substr(idx, 600)
	assert_bool(body.contains("Vector2(1.5, 1.5)")) \
		.override_failure_message("_restore_placement_zoom should restore ghost scale to Vector2(1.5, 1.5)") \
		.is_true()


# -- Section 6: Desktop behavior unchanged (no auto-zoom on desktop) -----------

func test_desktop_no_auto_zoom_on_build_requested() -> void:
	## On desktop, _on_build_requested should gate auto-zoom behind is_mobile() check.
	## The is_mobile() guard ensures desktop players never get auto-zoom.
	var src: String = load(GAME_SCRIPT_PATH).source_code
	var idx: int = src.find("func _on_build_requested")
	var body: String = src.substr(idx, 600)
	# The auto-zoom code (storing _pre_placement_zoom, tweening) should be inside
	# an is_mobile() block, not unconditional
	assert_bool(body.contains("if UIManager.is_mobile()") or body.contains("if not UIManager.is_mobile()")) \
		.override_failure_message("_on_build_requested should gate auto-zoom behind UIManager.is_mobile() check") \
		.is_true()


# -- Section 7: CellHighlight.gd structure tests --------------------------------

func test_cell_highlight_script_exists() -> void:
	assert_bool(FileAccess.file_exists(CELL_HIGHLIGHT_PATH)) \
		.override_failure_message("CellHighlight.gd should exist at " + CELL_HIGHLIGHT_PATH) \
		.is_true()


func test_cell_highlight_has_valid_color() -> void:
	if not FileAccess.file_exists(CELL_HIGHLIGHT_PATH):
		fail("CellHighlight.gd does not exist yet")
		return
	var src: String = load(CELL_HIGHLIGHT_PATH).source_code
	assert_bool(src.contains("VALID_COLOR")) \
		.override_failure_message("CellHighlight.gd missing VALID_COLOR constant") \
		.is_true()


func test_cell_highlight_valid_color_value() -> void:
	if not FileAccess.file_exists(CELL_HIGHLIGHT_PATH):
		fail("CellHighlight.gd does not exist yet")
		return
	var src: String = load(CELL_HIGHLIGHT_PATH).source_code
	assert_bool(src.contains("#00CC66")) \
		.override_failure_message("CellHighlight.gd VALID_COLOR should be #00CC66") \
		.is_true()


func test_cell_highlight_has_invalid_color() -> void:
	if not FileAccess.file_exists(CELL_HIGHLIGHT_PATH):
		fail("CellHighlight.gd does not exist yet")
		return
	var src: String = load(CELL_HIGHLIGHT_PATH).source_code
	assert_bool(src.contains("INVALID_COLOR")) \
		.override_failure_message("CellHighlight.gd missing INVALID_COLOR constant") \
		.is_true()


func test_cell_highlight_invalid_color_value() -> void:
	if not FileAccess.file_exists(CELL_HIGHLIGHT_PATH):
		fail("CellHighlight.gd does not exist yet")
		return
	var src: String = load(CELL_HIGHLIGHT_PATH).source_code
	assert_bool(src.contains("#CC3333")) \
		.override_failure_message("CellHighlight.gd INVALID_COLOR should be #CC3333") \
		.is_true()


func test_cell_highlight_has_border_width() -> void:
	if not FileAccess.file_exists(CELL_HIGHLIGHT_PATH):
		fail("CellHighlight.gd does not exist yet")
		return
	var src: String = load(CELL_HIGHLIGHT_PATH).source_code
	assert_bool(src.contains("BORDER_WIDTH") and src.contains("3.0")) \
		.override_failure_message("CellHighlight.gd should have BORDER_WIDTH = 3.0") \
		.is_true()


func test_cell_highlight_has_draw_method() -> void:
	if not FileAccess.file_exists(CELL_HIGHLIGHT_PATH):
		fail("CellHighlight.gd does not exist yet")
		return
	var src: String = load(CELL_HIGHLIGHT_PATH).source_code
	assert_bool(src.contains("func _draw")) \
		.override_failure_message("CellHighlight.gd missing _draw method") \
		.is_true()


func test_cell_highlight_draw_uses_draw_rect() -> void:
	if not FileAccess.file_exists(CELL_HIGHLIGHT_PATH):
		fail("CellHighlight.gd does not exist yet")
		return
	var src: String = load(CELL_HIGHLIGHT_PATH).source_code
	assert_bool(src.contains("draw_rect")) \
		.override_failure_message("CellHighlight.gd _draw should use draw_rect") \
		.is_true()


func test_cell_highlight_has_cell_size() -> void:
	if not FileAccess.file_exists(CELL_HIGHLIGHT_PATH):
		fail("CellHighlight.gd does not exist yet")
		return
	var src: String = load(CELL_HIGHLIGHT_PATH).source_code
	assert_bool(src.contains("CELL_SIZE") and src.contains("64")) \
		.override_failure_message("CellHighlight.gd should have CELL_SIZE = 64") \
		.is_true()
