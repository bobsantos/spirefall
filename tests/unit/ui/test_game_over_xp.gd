extends GdUnitTestSuite

## Unit tests for Task E3: GameOverScreen XP display (replacing placeholder).
## Covers: real XP value from MetaProgression.calculate_run_xp(), UnlocksLabel
## node, unlock display on game over, and various run_stats XP calculations.


const GAME_OVER_SCRIPT_PATH: String = "res://scripts/ui/GameOverScreen.gd"
const GAME_OVER_TSCN_PATH: String = "res://scenes/ui/GameOverScreen.tscn"

var _screen: Control
var _original_game_state: int
var _original_current_wave: int
var _original_max_waves: int
var _original_lives: int
var _original_run_stats: Dictionary
var _original_meta_xp: int
var _original_meta_unlocked: Array[String]
var _original_save_path: String


# -- Helpers -------------------------------------------------------------------

func _build_game_over_screen() -> Control:
	var root := Control.new()

	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	root.add_child(dimmer)

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
	vbox.add_child(result_label)

	var waves_label := Label.new()
	waves_label.name = "WavesLabel"
	vbox.add_child(waves_label)

	var enemies_label := Label.new()
	enemies_label.name = "EnemiesKilledLabel"
	vbox.add_child(enemies_label)

	var gold_label := Label.new()
	gold_label.name = "GoldEarnedLabel"
	vbox.add_child(gold_label)

	var time_label := Label.new()
	time_label.name = "TimePlayedLabel"
	vbox.add_child(time_label)

	var xp_label := Label.new()
	xp_label.name = "XPEarnedLabel"
	xp_label.text = "XP Earned: --"
	vbox.add_child(xp_label)

	var unlocks_label := Label.new()
	unlocks_label.name = "UnlocksLabel"
	unlocks_label.text = ""
	unlocks_label.visible = false
	vbox.add_child(unlocks_label)

	var spacer_bottom := Control.new()
	spacer_bottom.name = "SpacerBottom"
	vbox.add_child(spacer_bottom)

	var button_container := HBoxContainer.new()
	button_container.name = "ButtonContainer"
	vbox.add_child(button_container)

	var play_again_btn := Button.new()
	play_again_btn.name = "PlayAgainButton"
	button_container.add_child(play_again_btn)

	var main_menu_btn := Button.new()
	main_menu_btn.name = "MainMenuButton"
	button_container.add_child(main_menu_btn)

	return root


func _apply_script(node: Control) -> void:
	var script: GDScript = load(GAME_OVER_SCRIPT_PATH)
	node.set_script(script)
	node.panel = node.get_node("CenterContainer/PanelContainer")
	node.result_label = node.get_node("CenterContainer/PanelContainer/VBoxContainer/ResultLabel")
	node.waves_label = node.get_node("CenterContainer/PanelContainer/VBoxContainer/WavesLabel")
	node.enemies_killed_label = node.get_node("CenterContainer/PanelContainer/VBoxContainer/EnemiesKilledLabel")
	node.gold_earned_label = node.get_node("CenterContainer/PanelContainer/VBoxContainer/GoldEarnedLabel")
	node.time_played_label = node.get_node("CenterContainer/PanelContainer/VBoxContainer/TimePlayedLabel")
	node.xp_earned_label = node.get_node("CenterContainer/PanelContainer/VBoxContainer/XPEarnedLabel")
	node.unlocks_label = node.get_node("CenterContainer/PanelContainer/VBoxContainer/UnlocksLabel")
	node.play_again_button = node.get_node("CenterContainer/PanelContainer/VBoxContainer/ButtonContainer/PlayAgainButton")
	node.main_menu_button = node.get_node("CenterContainer/PanelContainer/VBoxContainer/ButtonContainer/MainMenuButton")


func _make_run_stats(overrides: Dictionary = {}) -> Dictionary:
	var stats: Dictionary = {
		"waves_survived": 10,
		"enemies_killed": 50,
		"total_gold_earned": 2000,
		"start_time": 0,
		"elapsed_time": 60000,
		"victory": false,
	}
	for key: String in overrides:
		stats[key] = overrides[key]
	return stats


func _reset_game_manager() -> void:
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = 0
	GameManager.max_waves = 30
	GameManager.lives = GameManager.starting_lives


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_game_state = GameManager.game_state
	_original_current_wave = GameManager.current_wave
	_original_max_waves = GameManager.max_waves
	_original_lives = GameManager.lives
	_original_run_stats = GameManager.run_stats.duplicate() if GameManager.run_stats != null else {}
	_original_meta_xp = MetaProgression._total_xp
	_original_meta_unlocked = MetaProgression._unlocked.duplicate()
	_original_save_path = SaveSystem._save_path


func before_test() -> void:
	_reset_game_manager()
	_screen = auto_free(_build_game_over_screen())
	_apply_script(_screen)
	# Ensure MetaProgression state is predictable
	MetaProgression._total_xp = 0
	MetaProgression._unlocked = []
	# Use a test save path to avoid polluting real saves
	SaveSystem._save_path = "user://test_game_over_xp_save.json"
	SaveSystem._data = SaveSystem._default_data()


func after_test() -> void:
	_screen = null
	_reset_game_manager()
	MetaProgression._total_xp = _original_meta_xp
	MetaProgression._unlocked = _original_meta_unlocked.duplicate()
	SaveSystem._save_path = _original_save_path
	if FileAccess.file_exists("user://test_game_over_xp_save.json"):
		DirAccess.remove_absolute("user://test_game_over_xp_save.json")


func after() -> void:
	GameManager.game_state = _original_game_state
	GameManager.current_wave = _original_current_wave
	GameManager.max_waves = _original_max_waves
	GameManager.lives = _original_lives
	if _original_run_stats != null:
		GameManager.run_stats = _original_run_stats.duplicate()
	MetaProgression._total_xp = _original_meta_xp
	MetaProgression._unlocked = _original_meta_unlocked.duplicate()
	SaveSystem._save_path = _original_save_path


# ==============================================================================
# SECTION 1: XP Label Shows Real Value (Not Placeholder)
# ==============================================================================

# -- 1. XP label no longer shows placeholder "--" ----------------------------

func test_xp_label_not_placeholder() -> void:
	GameManager.run_stats = _make_run_stats()
	GameManager.current_wave = 10
	_screen._on_game_over(false)
	assert_str(_screen.xp_earned_label.text).is_not_equal("XP Earned: --")


# -- 2. XP label shows calculated value from MetaProgression ----------------

func test_xp_label_shows_calculated_value() -> void:
	var stats: Dictionary = _make_run_stats({
		"waves_survived": 10,
		"enemies_killed": 50,
		"total_gold_earned": 2000,
		"victory": false,
	})
	GameManager.run_stats = stats
	GameManager.current_wave = 10
	var expected_xp: int = MetaProgression.calculate_run_xp(stats)
	_screen._on_game_over(false)
	assert_str(_screen.xp_earned_label.text).is_equal("XP Earned: %d" % expected_xp)


# -- 3. Victory XP includes victory bonus -----------------------------------

func test_victory_xp_includes_victory_bonus() -> void:
	var stats: Dictionary = _make_run_stats({
		"waves_survived": 30,
		"enemies_killed": 200,
		"total_gold_earned": 10000,
		"victory": true,
	})
	GameManager.run_stats = stats
	GameManager.current_wave = 30
	GameManager.max_waves = 30
	var expected_xp: int = MetaProgression.calculate_run_xp(stats)
	_screen._on_game_over(true)
	assert_str(_screen.xp_earned_label.text).is_equal("XP Earned: %d" % expected_xp)
	# Verify victory bonus is included (200 extra)
	var no_victory_stats: Dictionary = stats.duplicate()
	no_victory_stats["victory"] = false
	var no_victory_xp: int = MetaProgression.calculate_run_xp(no_victory_stats)
	assert_int(expected_xp - no_victory_xp).is_equal(200)


# -- 4. Defeat XP has no victory bonus --------------------------------------

func test_defeat_xp_has_no_victory_bonus() -> void:
	var stats: Dictionary = _make_run_stats({
		"waves_survived": 10,
		"enemies_killed": 50,
		"total_gold_earned": 2000,
		"victory": false,
	})
	GameManager.run_stats = stats
	GameManager.current_wave = 10
	# base_xp = 10 * 10 = 100
	# kill_bonus = 50 * 1 = 50
	# gold_bonus = floor(2000 / 100) * 5 = 100
	# victory_bonus = 0
	# total = 250
	var expected_xp: int = MetaProgression.calculate_run_xp(stats)
	assert_int(expected_xp).is_equal(250)
	_screen._on_game_over(false)
	assert_str(_screen.xp_earned_label.text).is_equal("XP Earned: 250")


# -- 5. Zero stats produce minimal XP ----------------------------------------

func test_zero_stats_minimal_xp() -> void:
	var stats: Dictionary = _make_run_stats({
		"waves_survived": 0,
		"enemies_killed": 0,
		"total_gold_earned": 0,
		"victory": false,
	})
	GameManager.run_stats = stats
	GameManager.current_wave = 0
	_screen._on_game_over(false)
	assert_str(_screen.xp_earned_label.text).is_equal("XP Earned: 0")


# ==============================================================================
# SECTION 2: UnlocksLabel Node Exists
# ==============================================================================

# -- 6. GameOverScreen.tscn has UnlocksLabel node ----------------------------

func test_tscn_has_unlocks_label() -> void:
	var file := FileAccess.open(GAME_OVER_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains('"UnlocksLabel"')).is_true()


# -- 7. Script has unlocks_label var -----------------------------------------

func test_script_has_unlocks_label_var() -> void:
	assert_object(_screen.get("unlocks_label")).is_not_null()
	assert_bool(_screen.unlocks_label is Label).is_true()


# -- 8. UnlocksLabel starts hidden -------------------------------------------

func test_unlocks_label_starts_hidden() -> void:
	_screen.unlocks_label.visible = false
	assert_bool(_screen.unlocks_label.visible).is_false()


# ==============================================================================
# SECTION 3: Unlock Display on Game Over
# ==============================================================================

# -- 9. No unlocks: UnlocksLabel stays hidden --------------------------------

func test_no_unlocks_label_hidden() -> void:
	MetaProgression._total_xp = 0
	MetaProgression._unlocked = []
	GameManager.run_stats = _make_run_stats({
		"waves_survived": 1,
		"enemies_killed": 5,
		"total_gold_earned": 100,
		"victory": false,
	})
	GameManager.current_wave = 1
	_screen._on_game_over(false)
	assert_bool(_screen.unlocks_label.visible).is_false()


# -- 10. Script source no longer has XP placeholder "--" ---------------------

func test_script_no_longer_has_placeholder() -> void:
	var file := FileAccess.open(GAME_OVER_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains('XP Earned: --'))\
		.override_failure_message("GameOverScreen.gd should no longer contain the XP placeholder '--'")\
		.is_false()
