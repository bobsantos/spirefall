extends GdUnitTestSuite

## Unit tests for SceneManager autoload.
## Covers: initial state, config persistence, convenience methods, signal emission,
## transition guard, fade overlay setup, and invalid path handling.


# -- Helpers -------------------------------------------------------------------

func _reset_scene_manager() -> void:
	SceneManager.current_game_config = {}
	SceneManager.is_transitioning = false
	SceneManager._last_scene_path = ""
	# Reset overlay alpha in case a previous test tweened it
	if is_instance_valid(SceneManager._overlay):
		SceneManager._overlay.color.a = 0.0
	# Kill any active tween to prevent lingering transitions
	if SceneManager._tween and SceneManager._tween.is_valid():
		SceneManager._tween.kill()
		SceneManager._tween = null


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_reset_scene_manager()


func after_test() -> void:
	_reset_scene_manager()


# -- 1. Initial state ----------------------------------------------------------

func test_initial_config_is_empty_dictionary() -> void:
	assert_dict(SceneManager.current_game_config).is_empty()


func test_initial_is_transitioning_is_false() -> void:
	assert_bool(SceneManager.is_transitioning).is_false()


# -- 2. Config persistence -----------------------------------------------------

func test_current_game_config_persists_after_assignment() -> void:
	var config: Dictionary = {"mode": "classic", "map": "forest", "difficulty": 2}
	SceneManager.current_game_config = config
	assert_dict(SceneManager.current_game_config).is_equal(config)
	assert_str(SceneManager.current_game_config["mode"]).is_equal("classic")


# -- 3. go_to_game stores config and triggers scene change ---------------------

func test_go_to_game_stores_config() -> void:
	var config: Dictionary = {"mode": "draft", "map": "volcano"}
	# Set transitioning to prevent actual scene change
	SceneManager.is_transitioning = true
	SceneManager.go_to_game(config)
	# Config should be stored even if transition is blocked
	assert_dict(SceneManager.current_game_config).is_equal(config)


func test_go_to_game_sets_last_scene_path() -> void:
	var config: Dictionary = {"mode": "classic"}
	SceneManager.go_to_game(config)
	assert_str(SceneManager._last_scene_path).is_equal("res://scenes/main/Game.tscn")


# -- 4. go_to_main_menu resets config -----------------------------------------

func test_go_to_main_menu_clears_config() -> void:
	SceneManager.current_game_config = {"mode": "endless"}
	SceneManager.go_to_main_menu()
	assert_dict(SceneManager.current_game_config).is_empty()


func test_go_to_main_menu_sets_last_scene_path() -> void:
	SceneManager.go_to_main_menu()
	assert_str(SceneManager._last_scene_path).is_equal("res://scenes/main/MainMenu.tscn")


# -- 5. restart_game preserves config -----------------------------------------

func test_restart_game_preserves_config() -> void:
	var config: Dictionary = {"mode": "classic", "difficulty": 3}
	SceneManager.current_game_config = config
	SceneManager.restart_game()
	assert_dict(SceneManager.current_game_config).is_equal(config)


func test_restart_game_sets_last_scene_path() -> void:
	SceneManager.current_game_config = {"mode": "classic"}
	SceneManager.restart_game()
	assert_str(SceneManager._last_scene_path).is_equal("res://scenes/main/Game.tscn")


# -- 6. scene_changing signal emitted -----------------------------------------

func test_change_scene_emits_scene_changing_signal() -> void:
	var signal_count: Array[int] = [0]
	var _conn: Callable = func() -> void: signal_count[0] += 1
	SceneManager.scene_changing.connect(_conn)
	SceneManager.change_scene("res://scenes/main/Game.tscn")
	SceneManager.scene_changing.disconnect(_conn)
	assert_int(signal_count[0]).is_equal(1)


func test_go_to_game_emits_scene_changing_signal() -> void:
	var signal_count: Array[int] = [0]
	var _conn: Callable = func() -> void: signal_count[0] += 1
	SceneManager.scene_changing.connect(_conn)
	SceneManager.go_to_game({"mode": "classic"})
	SceneManager.scene_changing.disconnect(_conn)
	assert_int(signal_count[0]).is_equal(1)


# -- 7. is_transitioning flag -------------------------------------------------

func test_change_scene_sets_is_transitioning_true() -> void:
	SceneManager.change_scene("res://scenes/main/Game.tscn")
	assert_bool(SceneManager.is_transitioning).is_true()


func test_change_scene_blocked_while_transitioning() -> void:
	SceneManager.is_transitioning = true
	var signal_count: Array[int] = [0]
	var _conn: Callable = func() -> void: signal_count[0] += 1
	SceneManager.scene_changing.connect(_conn)
	SceneManager.change_scene("res://scenes/main/Game.tscn")
	SceneManager.scene_changing.disconnect(_conn)
	# Signal should NOT have been emitted because transition was blocked
	assert_int(signal_count[0]).is_equal(0)


# -- 8. Fade overlay setup ----------------------------------------------------

func test_overlay_canvas_layer_exists() -> void:
	var canvas_layer: CanvasLayer = SceneManager._canvas_layer
	assert_object(canvas_layer).is_not_null()
	assert_bool(canvas_layer is CanvasLayer).is_true()
	assert_bool(canvas_layer.is_inside_tree()).is_true()


func test_overlay_color_rect_exists() -> void:
	var overlay: ColorRect = SceneManager._overlay
	assert_object(overlay).is_not_null()
	assert_bool(overlay is ColorRect).is_true()


func test_overlay_starts_transparent() -> void:
	# After reset, overlay should be fully transparent
	assert_float(SceneManager._overlay.color.a).is_equal(0.0)


func test_overlay_canvas_layer_is_high() -> void:
	# The fade overlay should render above all game content
	assert_int(SceneManager._canvas_layer.layer).is_equal(100)


# -- 9. change_scene with empty/invalid path ----------------------------------

func test_change_scene_with_empty_path_does_not_crash() -> void:
	SceneManager.change_scene("")
	# Should not crash; is_transitioning should remain false (early return)
	assert_bool(SceneManager.is_transitioning).is_false()


func test_change_scene_with_empty_path_does_not_emit_signal() -> void:
	var signal_count: Array[int] = [0]
	var _conn: Callable = func() -> void: signal_count[0] += 1
	SceneManager.scene_changing.connect(_conn)
	SceneManager.change_scene("")
	SceneManager.scene_changing.disconnect(_conn)
	assert_int(signal_count[0]).is_equal(0)
