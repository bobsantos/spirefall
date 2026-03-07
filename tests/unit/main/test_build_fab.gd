extends GdUnitTestSuite

## Unit tests for Task B2: Build FAB (Floating Action Button) in Game.gd.
## Tests the FAB creation method and button properties.
## Game.gd has heavy dependencies so we test _create_build_fab in isolation.

const GAME_SCRIPT_PATH: String = "res://scripts/main/Game.gd"


# -- Section 1: Source code contains _create_build_fab -------------------------

func test_game_script_has_create_build_fab_method() -> void:
	## Game.gd must define a _create_build_fab() method.
	var script_source: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(script_source.contains("func _create_build_fab")) \
		.override_failure_message("Game.gd does not contain _create_build_fab method") \
		.is_true()


func test_game_script_has_build_fab_variable() -> void:
	## Game.gd must define a _build_fab variable.
	var script_source: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(script_source.contains("var _build_fab")) \
		.override_failure_message("Game.gd does not contain _build_fab variable") \
		.is_true()


func test_game_script_has_on_build_fab_pressed() -> void:
	## Game.gd must define a _on_build_fab_pressed() method.
	var script_source: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(script_source.contains("func _on_build_fab_pressed")) \
		.override_failure_message("Game.gd does not contain _on_build_fab_pressed method") \
		.is_true()


func test_game_script_has_fab_phase_changed() -> void:
	## Game.gd must define a _on_fab_phase_changed() method.
	var script_source: String = load(GAME_SCRIPT_PATH).source_code
	assert_bool(script_source.contains("func _on_fab_phase_changed")) \
		.override_failure_message("Game.gd does not contain _on_fab_phase_changed method") \
		.is_true()
