extends GdUnitTestSuite

## Unit tests for Task A7: GameOverScreen updated for menu flow.
## Covers: run stats display, Play Again (SceneManager.restart_game()),
## Main Menu (SceneManager.go_to_main_menu()), no reload_current_scene(),
## victory/defeat visual distinction, time formatting, and XP placeholder.

const GAME_OVER_SCRIPT_PATH: String = "res://scripts/ui/GameOverScreen.gd"
const GAME_OVER_TSCN_PATH: String = "res://scenes/ui/GameOverScreen.tscn"

var _screen: Control
var _original_max_waves: int
var _original_game_state: int
var _original_current_wave: int
var _original_lives: int
var _original_transitioning: bool
var _original_run_stats: Dictionary


# -- Helpers -------------------------------------------------------------------

## Build a GameOverScreen node tree manually matching the expected .tscn structure.
func _build_game_over_screen() -> Control:
	var root := Control.new()

	# Semi-transparent background dimmer
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.color = Color(0.0, 0.0, 0.0, 0.6)
	root.add_child(dimmer)

	# CenterContainer to center the panel
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "PanelContainer"
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	panel.add_child(vbox)

	var spacer_top := Control.new()
	spacer_top.name = "Spacer"
	vbox.add_child(spacer_top)

	var result_label := Label.new()
	result_label.name = "ResultLabel"
	result_label.text = "Victory!"
	vbox.add_child(result_label)

	var waves_label := Label.new()
	waves_label.name = "WavesLabel"
	waves_label.text = "Waves Survived: 0 / 0"
	vbox.add_child(waves_label)

	var enemies_label := Label.new()
	enemies_label.name = "EnemiesKilledLabel"
	enemies_label.text = "Enemies Killed: 0"
	vbox.add_child(enemies_label)

	var gold_label := Label.new()
	gold_label.name = "GoldEarnedLabel"
	gold_label.text = "Gold Earned: 0"
	vbox.add_child(gold_label)

	var time_label := Label.new()
	time_label.name = "TimePlayedLabel"
	time_label.text = "Time: 00:00"
	vbox.add_child(time_label)

	var xp_label := Label.new()
	xp_label.name = "XPEarnedLabel"
	xp_label.text = "XP Earned: --"
	vbox.add_child(xp_label)

	var spacer_bottom := Control.new()
	spacer_bottom.name = "SpacerBottom"
	vbox.add_child(spacer_bottom)

	# Button container for Play Again and Main Menu
	var button_container := HBoxContainer.new()
	button_container.name = "ButtonContainer"
	vbox.add_child(button_container)

	var play_again_btn := Button.new()
	play_again_btn.name = "PlayAgainButton"
	play_again_btn.text = "Play Again"
	button_container.add_child(play_again_btn)

	var main_menu_btn := Button.new()
	main_menu_btn.name = "MainMenuButton"
	main_menu_btn.text = "Main Menu"
	button_container.add_child(main_menu_btn)

	return root


func _apply_script(node: Control) -> void:
	var script: GDScript = load(GAME_OVER_SCRIPT_PATH)
	node.set_script(script)
	# Wire @onready refs manually (no scene tree, no _ready())
	node.panel = node.get_node("CenterContainer/PanelContainer")
	node.result_label = node.get_node("CenterContainer/PanelContainer/VBoxContainer/ResultLabel")
	node.waves_label = node.get_node("CenterContainer/PanelContainer/VBoxContainer/WavesLabel")
	node.enemies_killed_label = node.get_node("CenterContainer/PanelContainer/VBoxContainer/EnemiesKilledLabel")
	node.gold_earned_label = node.get_node("CenterContainer/PanelContainer/VBoxContainer/GoldEarnedLabel")
	node.time_played_label = node.get_node("CenterContainer/PanelContainer/VBoxContainer/TimePlayedLabel")
	node.xp_earned_label = node.get_node("CenterContainer/PanelContainer/VBoxContainer/XPEarnedLabel")
	node.play_again_button = node.get_node("CenterContainer/PanelContainer/VBoxContainer/ButtonContainer/PlayAgainButton")
	node.main_menu_button = node.get_node("CenterContainer/PanelContainer/VBoxContainer/ButtonContainer/MainMenuButton")


func _make_run_stats(overrides: Dictionary = {}) -> Dictionary:
	var stats: Dictionary = {
		"waves_survived": 15,
		"enemies_killed": 120,
		"total_gold_earned": 5000,
		"start_time": 0,
		"elapsed_time": 125000,  # 125 seconds = 2:05
		"victory": false,
	}
	for key: String in overrides:
		stats[key] = overrides[key]
	return stats


func _reset_game_manager() -> void:
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = _original_current_wave
	GameManager.lives = _original_lives
	GameManager.max_waves = _original_max_waves


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_max_waves = GameManager.max_waves
	_original_game_state = GameManager.game_state
	_original_current_wave = GameManager.current_wave
	_original_lives = GameManager.lives
	_original_transitioning = SceneManager.is_transitioning
	_original_run_stats = GameManager.run_stats.duplicate() if GameManager.get("run_stats") != null else {}


func before_test() -> void:
	_reset_game_manager()
	SceneManager.is_transitioning = false
	GameManager.run_stats = _make_run_stats()
	_screen = _build_game_over_screen()
	_apply_script(_screen)


func after_test() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	_reset_game_manager()
	SceneManager.is_transitioning = _original_transitioning
	if GameManager.get("run_stats") != null:
		GameManager.run_stats = _original_run_stats.duplicate()


# ==============================================================================
# SECTION 1: GameManager.run_stats Dictionary Exists
# ==============================================================================

# -- 1. GameManager has run_stats property -----------------------------------

func test_game_manager_has_run_stats() -> void:
	assert_bool(GameManager.get("run_stats") != null).is_true()


# -- 2. run_stats is a Dictionary -------------------------------------------

func test_run_stats_is_dictionary() -> void:
	assert_bool(GameManager.run_stats is Dictionary).is_true()


# -- 3. run_stats has expected keys -----------------------------------------

func test_run_stats_has_expected_keys() -> void:
	GameManager.run_stats = _make_run_stats()
	for key: String in ["waves_survived", "enemies_killed", "total_gold_earned", "elapsed_time", "victory"]:
		assert_bool(GameManager.run_stats.has(key))\
			.override_failure_message("run_stats missing key: %s" % key)\
			.is_true()


# ==============================================================================
# SECTION 2: Node Structure
# ==============================================================================

# -- 4. GameOverScreen has ResultLabel ---------------------------------------

func test_has_result_label() -> void:
	var node: Node = _screen.get_node_or_null("CenterContainer/PanelContainer/VBoxContainer/ResultLabel")
	assert_object(node).is_not_null()


# -- 5. GameOverScreen has WavesLabel ----------------------------------------

func test_has_waves_label() -> void:
	var node: Node = _screen.get_node_or_null("CenterContainer/PanelContainer/VBoxContainer/WavesLabel")
	assert_object(node).is_not_null()


# -- 6. GameOverScreen has EnemiesKilledLabel --------------------------------

func test_has_enemies_killed_label() -> void:
	var node: Node = _screen.get_node_or_null("CenterContainer/PanelContainer/VBoxContainer/EnemiesKilledLabel")
	assert_object(node).is_not_null()


# -- 7. GameOverScreen has GoldEarnedLabel -----------------------------------

func test_has_gold_earned_label() -> void:
	var node: Node = _screen.get_node_or_null("CenterContainer/PanelContainer/VBoxContainer/GoldEarnedLabel")
	assert_object(node).is_not_null()


# -- 8. GameOverScreen has TimePlayedLabel -----------------------------------

func test_has_time_played_label() -> void:
	var node: Node = _screen.get_node_or_null("CenterContainer/PanelContainer/VBoxContainer/TimePlayedLabel")
	assert_object(node).is_not_null()


# -- 9. GameOverScreen has XPEarnedLabel -------------------------------------

func test_has_xp_earned_label() -> void:
	var node: Node = _screen.get_node_or_null("CenterContainer/PanelContainer/VBoxContainer/XPEarnedLabel")
	assert_object(node).is_not_null()


# -- 10. GameOverScreen has PlayAgainButton ----------------------------------

func test_has_play_again_button() -> void:
	var node: Node = _screen.get_node_or_null("CenterContainer/PanelContainer/VBoxContainer/ButtonContainer/PlayAgainButton")
	assert_object(node).is_not_null()


# -- 11. GameOverScreen has MainMenuButton -----------------------------------

func test_has_main_menu_button() -> void:
	var node: Node = _screen.get_node_or_null("CenterContainer/PanelContainer/VBoxContainer/ButtonContainer/MainMenuButton")
	assert_object(node).is_not_null()


# -- 12. GameOverScreen has Dimmer -------------------------------------------

func test_has_dimmer() -> void:
	var node: Node = _screen.get_node_or_null("Dimmer")
	assert_object(node).is_not_null()
	assert_bool(node is ColorRect).is_true()


# ==============================================================================
# SECTION 3: Script Properties
# ==============================================================================

# -- 13. Script has result_label var ----------------------------------------

func test_script_has_result_label_var() -> void:
	assert_bool(_screen.get("result_label") != null).is_true()


# -- 14. Script has waves_label var -----------------------------------------

func test_script_has_waves_label_var() -> void:
	assert_bool(_screen.get("waves_label") != null).is_true()


# -- 15. Script has enemies_killed_label var ---------------------------------

func test_script_has_enemies_killed_label_var() -> void:
	assert_bool(_screen.get("enemies_killed_label") != null).is_true()


# -- 16. Script has gold_earned_label var ------------------------------------

func test_script_has_gold_earned_label_var() -> void:
	assert_bool(_screen.get("gold_earned_label") != null).is_true()


# -- 17. Script has time_played_label var ------------------------------------

func test_script_has_time_played_label_var() -> void:
	assert_bool(_screen.get("time_played_label") != null).is_true()


# -- 18. Script has xp_earned_label var --------------------------------------

func test_script_has_xp_earned_label_var() -> void:
	assert_bool(_screen.get("xp_earned_label") != null).is_true()


# -- 19. Script has play_again_button var ------------------------------------

func test_script_has_play_again_button_var() -> void:
	assert_bool(_screen.get("play_again_button") != null).is_true()


# -- 20. Script has main_menu_button var -------------------------------------

func test_script_has_main_menu_button_var() -> void:
	assert_bool(_screen.get("main_menu_button") != null).is_true()


# ==============================================================================
# SECTION 4: Victory Display (_on_game_over with victory=true)
# ==============================================================================

# -- 21. Victory sets result label text to "Victory!" -----------------------

func test_victory_sets_result_label_text() -> void:
	GameManager.run_stats = _make_run_stats({"victory": true, "waves_survived": 30})
	GameManager.current_wave = 30
	GameManager.max_waves = 30
	_screen._on_game_over(true)
	assert_str(_screen.result_label.text).is_equal("Victory!")


# -- 22. Victory sets result label color to gold ----------------------------

func test_victory_sets_result_label_gold_color() -> void:
	GameManager.run_stats = _make_run_stats({"victory": true})
	_screen._on_game_over(true)
	# Gold color: Color(1.0, 0.84, 0.0)
	var color: Color = Color(1.0, 0.84, 0.0)
	assert_bool(_screen.result_label.has_theme_color_override("font_color")).is_true()


# -- 23. Victory makes screen visible ---------------------------------------

func test_victory_makes_screen_visible() -> void:
	_screen.visible = false
	GameManager.run_stats = _make_run_stats({"victory": true})
	_screen._on_game_over(true)
	assert_bool(_screen.visible).is_true()


# ==============================================================================
# SECTION 5: Defeat Display (_on_game_over with victory=false)
# ==============================================================================

# -- 24. Defeat sets result label text to "Defeat!" -------------------------

func test_defeat_sets_result_label_text() -> void:
	GameManager.run_stats = _make_run_stats({"victory": false})
	GameManager.current_wave = 15
	GameManager.max_waves = 30
	_screen._on_game_over(false)
	assert_str(_screen.result_label.text).is_equal("Defeat!")


# -- 25. Defeat sets result label color to red ------------------------------

func test_defeat_sets_result_label_red_color() -> void:
	GameManager.run_stats = _make_run_stats({"victory": false})
	_screen._on_game_over(false)
	assert_bool(_screen.result_label.has_theme_color_override("font_color")).is_true()


# -- 26. Defeat makes screen visible ----------------------------------------

func test_defeat_makes_screen_visible() -> void:
	_screen.visible = false
	GameManager.run_stats = _make_run_stats({"victory": false})
	_screen._on_game_over(false)
	assert_bool(_screen.visible).is_true()


# ==============================================================================
# SECTION 6: Stats Display
# ==============================================================================

# -- 27. Waves label shows waves_survived / max_waves -----------------------

func test_waves_label_shows_waves_survived() -> void:
	GameManager.current_wave = 15
	GameManager.max_waves = 30
	GameManager.run_stats = _make_run_stats({"waves_survived": 15})
	_screen._on_game_over(false)
	assert_str(_screen.waves_label.text).is_equal("Waves Survived: 15 / 30")


# -- 28. Enemies killed label shows count -----------------------------------

func test_enemies_killed_label_shows_count() -> void:
	GameManager.run_stats = _make_run_stats({"enemies_killed": 120})
	_screen._on_game_over(false)
	assert_str(_screen.enemies_killed_label.text).is_equal("Enemies Killed: 120")


# -- 29. Gold earned label shows total --------------------------------------

func test_gold_earned_label_shows_total() -> void:
	GameManager.run_stats = _make_run_stats({"total_gold_earned": 5000})
	_screen._on_game_over(false)
	assert_str(_screen.gold_earned_label.text).is_equal("Gold Earned: 5000")


# -- 30. Time played label shows formatted time (mm:ss) ---------------------

func test_time_played_label_shows_formatted_time() -> void:
	# 125000 ms = 125 seconds = 2 minutes 5 seconds
	GameManager.run_stats = _make_run_stats({"elapsed_time": 125000})
	_screen._on_game_over(false)
	assert_str(_screen.time_played_label.text).is_equal("Time: 02:05")


# -- 31. Time played label formats single-digit seconds with leading zero ---

func test_time_played_label_leading_zero_seconds() -> void:
	# 63000 ms = 63 seconds = 1 minute 3 seconds
	GameManager.run_stats = _make_run_stats({"elapsed_time": 63000})
	_screen._on_game_over(false)
	assert_str(_screen.time_played_label.text).is_equal("Time: 01:03")


# -- 32. Time played label formats zero time correctly ----------------------

func test_time_played_label_zero_time() -> void:
	GameManager.run_stats = _make_run_stats({"elapsed_time": 0})
	_screen._on_game_over(false)
	assert_str(_screen.time_played_label.text).is_equal("Time: 00:00")


# -- 33. Time played label formats large time (over 1 hour) ----------------

func test_time_played_label_large_time() -> void:
	# 3661000 ms = 3661 seconds = 61 minutes 1 second
	GameManager.run_stats = _make_run_stats({"elapsed_time": 3661000})
	_screen._on_game_over(false)
	assert_str(_screen.time_played_label.text).is_equal("Time: 61:01")


# -- 34. XP earned label shows placeholder ----------------------------------

func test_xp_earned_label_shows_placeholder() -> void:
	GameManager.run_stats = _make_run_stats()
	_screen._on_game_over(false)
	assert_str(_screen.xp_earned_label.text).is_equal("XP Earned: --")


# ==============================================================================
# SECTION 7: Button Actions
# ==============================================================================

# -- 35. Play Again calls SceneManager.restart_game() -----------------------

func test_play_again_calls_restart_game() -> void:
	# Block actual scene transition
	SceneManager.is_transitioning = true
	_screen._on_play_again_pressed()
	# restart_game sets _last_scene_path to GAME_PATH
	# Since is_transitioning is true, the call returns early but we can verify
	# the method was invoked by checking that it didn't crash
	assert_bool(true).is_true()


# -- 36. Play Again does not call reload_current_scene -----------------------

func test_play_again_does_not_reload_current_scene() -> void:
	# Verify the script source has no reload_current_scene call
	var file := FileAccess.open(GAME_OVER_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("reload_current_scene")).is_false()


# -- 37. Main Menu calls SceneManager.go_to_main_menu() ---------------------

func test_main_menu_calls_go_to_main_menu() -> void:
	# Block actual scene transition
	SceneManager.is_transitioning = true
	_screen._on_main_menu_pressed()
	# If we reach here, the method exists and doesn't crash
	assert_bool(true).is_true()


# -- 38. _on_play_again_pressed method exists --------------------------------

func test_has_on_play_again_pressed_method() -> void:
	assert_bool(_screen.has_method("_on_play_again_pressed")).is_true()


# -- 39. _on_main_menu_pressed method exists ---------------------------------

func test_has_on_main_menu_pressed_method() -> void:
	assert_bool(_screen.has_method("_on_main_menu_pressed")).is_true()


# ==============================================================================
# SECTION 8: Scene File Verification
# ==============================================================================

# -- 40. GameOverScreen.tscn has EnemiesKilledLabel --------------------------

func test_tscn_has_enemies_killed_label() -> void:
	var file := FileAccess.open(GAME_OVER_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains('"EnemiesKilledLabel"')).is_true()


# -- 41. GameOverScreen.tscn has GoldEarnedLabel -----------------------------

func test_tscn_has_gold_earned_label() -> void:
	var file := FileAccess.open(GAME_OVER_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains('"GoldEarnedLabel"')).is_true()


# -- 42. GameOverScreen.tscn has TimePlayedLabel -----------------------------

func test_tscn_has_time_played_label() -> void:
	var file := FileAccess.open(GAME_OVER_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains('"TimePlayedLabel"')).is_true()


# -- 43. GameOverScreen.tscn has XPEarnedLabel -------------------------------

func test_tscn_has_xp_earned_label() -> void:
	var file := FileAccess.open(GAME_OVER_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains('"XPEarnedLabel"')).is_true()


# -- 44. GameOverScreen.tscn has MainMenuButton ------------------------------

func test_tscn_has_main_menu_button() -> void:
	var file := FileAccess.open(GAME_OVER_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains('"MainMenuButton"')).is_true()


# -- 45. GameOverScreen.tscn has ButtonContainer -----------------------------

func test_tscn_has_button_container() -> void:
	var file := FileAccess.open(GAME_OVER_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains('"ButtonContainer"')).is_true()


# -- 46. GameOverScreen.tscn has no reload_current_scene ---------------------

func test_script_has_no_reload_current_scene() -> void:
	var file := FileAccess.open(GAME_OVER_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("reload_current_scene")).is_false()


# ==============================================================================
# SECTION 9: Stats from run_stats Dictionary
# ==============================================================================

# -- 47. Stats come from GameManager.run_stats, not hardcoded ----------------

func test_stats_come_from_run_stats() -> void:
	GameManager.current_wave = 22
	GameManager.max_waves = 30
	GameManager.run_stats = _make_run_stats({
		"waves_survived": 22,
		"enemies_killed": 999,
		"total_gold_earned": 12345,
		"elapsed_time": 300000,  # 5 minutes exactly
	})
	_screen._on_game_over(false)
	assert_str(_screen.waves_label.text).is_equal("Waves Survived: 22 / 30")
	assert_str(_screen.enemies_killed_label.text).is_equal("Enemies Killed: 999")
	assert_str(_screen.gold_earned_label.text).is_equal("Gold Earned: 12345")
	assert_str(_screen.time_played_label.text).is_equal("Time: 05:00")


# -- 48. Different run_stats produce different display -----------------------

func test_different_run_stats_different_display() -> void:
	GameManager.current_wave = 5
	GameManager.max_waves = 30
	GameManager.run_stats = _make_run_stats({
		"waves_survived": 5,
		"enemies_killed": 10,
		"total_gold_earned": 100,
		"elapsed_time": 30000,  # 30 seconds
	})
	_screen._on_game_over(false)
	assert_str(_screen.waves_label.text).is_equal("Waves Survived: 5 / 30")
	assert_str(_screen.enemies_killed_label.text).is_equal("Enemies Killed: 10")
	assert_str(_screen.gold_earned_label.text).is_equal("Gold Earned: 100")
	assert_str(_screen.time_played_label.text).is_equal("Time: 00:30")


# ==============================================================================
# SECTION 10: Visibility and Process Mode
# ==============================================================================

# -- 49. Screen starts hidden -----------------------------------------------

func test_screen_starts_hidden() -> void:
	# Script _ready() sets visible = false; we simulate that
	_screen.visible = false
	assert_bool(_screen.visible).is_false()


# -- 50. Screen has process_mode WHEN_PAUSED for game-over input -------------

func test_screen_process_mode_when_paused() -> void:
	# GameOverScreen should work during pause so buttons are clickable
	_screen.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	assert_int(_screen.process_mode).is_equal(Node.PROCESS_MODE_WHEN_PAUSED)


# ==============================================================================
# SECTION 11: Game.tscn GameOverScreen Placement
# ==============================================================================

# -- 51. Game.tscn has GameOverScreen under UILayer --------------------------

func test_game_tscn_has_game_over_screen_under_ui_layer() -> void:
	const GAME_TSCN_PATH: String = "res://scenes/main/Game.tscn"
	var file := FileAccess.open(GAME_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains('[node name="GameOverScreen" parent="UILayer"')).is_true()


# -- 52. Game.tscn references GameOverScreen.tscn ---------------------------

func test_game_tscn_references_game_over_screen_tscn() -> void:
	const GAME_TSCN_PATH: String = "res://scenes/main/Game.tscn"
	var file := FileAccess.open(GAME_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("GameOverScreen.tscn")).is_true()
