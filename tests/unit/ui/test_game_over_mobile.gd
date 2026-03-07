extends GdUnitTestSuite

## Unit tests for Task D4: GameOverScreen mobile sizing.
## Covers: button minimum heights, font sizes for title and body labels,
## and the _apply_mobile_sizing() method.

const GAME_OVER_SCRIPT_PATH: String = "res://scripts/ui/GameOverScreen.gd"

var _screen: Control
var _original_game_state: int


# -- Helpers -------------------------------------------------------------------

func _build_game_over_node() -> Control:
	## Build a GameOverScreen node tree manually matching GameOverScreen.tscn structure.
	var root := Control.new()

	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	root.add_child(dimmer)

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "PanelContainer"
	panel.custom_minimum_size = Vector2(400, 320)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	panel.add_child(vbox)

	var spacer := Control.new()
	spacer.name = "Spacer"
	vbox.add_child(spacer)

	var result_label := Label.new()
	result_label.name = "ResultLabel"
	result_label.text = "Victory!"
	result_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(result_label)

	# Stats labels
	var label_names: Array[String] = ["WavesLabel", "EnemiesKilledLabel", "GoldEarnedLabel", "TimePlayedLabel", "XPEarnedLabel", "UnlocksLabel"]
	for label_name: String in label_names:
		var lbl := Label.new()
		lbl.name = label_name
		lbl.add_theme_font_size_override("font_size", 16)
		vbox.add_child(lbl)

	var spacer_bottom := Control.new()
	spacer_bottom.name = "SpacerBottom"
	vbox.add_child(spacer_bottom)

	var btn_container := HBoxContainer.new()
	btn_container.name = "ButtonContainer"
	vbox.add_child(btn_container)

	var play_again := Button.new()
	play_again.name = "PlayAgainButton"
	play_again.text = "Play Again"
	play_again.custom_minimum_size = Vector2(150, 44)
	btn_container.add_child(play_again)

	var main_menu := Button.new()
	main_menu.name = "MainMenuButton"
	main_menu.text = "Main Menu"
	main_menu.custom_minimum_size = Vector2(150, 44)
	btn_container.add_child(main_menu)

	return root


func _get_action_buttons() -> Array[Button]:
	var container: HBoxContainer = _screen.get_node("CenterContainer/PanelContainer/VBoxContainer/ButtonContainer")
	var buttons: Array[Button] = []
	for child: Node in container.get_children():
		if child is Button:
			buttons.append(child as Button)
	return buttons


func _get_stat_labels() -> Array[Label]:
	var vbox: VBoxContainer = _screen.get_node("CenterContainer/PanelContainer/VBoxContainer")
	var labels: Array[Label] = []
	var stat_names: Array[String] = ["WavesLabel", "EnemiesKilledLabel", "GoldEarnedLabel", "TimePlayedLabel", "XPEarnedLabel", "UnlocksLabel"]
	for stat_name: String in stat_names:
		var lbl: Label = vbox.get_node(stat_name) as Label
		if lbl:
			labels.append(lbl)
	return labels


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_original_game_state = GameManager.game_state
	_screen = _build_game_over_node()
	add_child(_screen)
	_screen.set_script(load(GAME_OVER_SCRIPT_PATH))
	# Manually set @onready vars
	_screen.panel = _screen.get_node("CenterContainer/PanelContainer")
	_screen.result_label = _screen.get_node("CenterContainer/PanelContainer/VBoxContainer/ResultLabel")
	_screen.waves_label = _screen.get_node("CenterContainer/PanelContainer/VBoxContainer/WavesLabel")
	_screen.enemies_killed_label = _screen.get_node("CenterContainer/PanelContainer/VBoxContainer/EnemiesKilledLabel")
	_screen.gold_earned_label = _screen.get_node("CenterContainer/PanelContainer/VBoxContainer/GoldEarnedLabel")
	_screen.time_played_label = _screen.get_node("CenterContainer/PanelContainer/VBoxContainer/TimePlayedLabel")
	_screen.xp_earned_label = _screen.get_node("CenterContainer/PanelContainer/VBoxContainer/XPEarnedLabel")
	_screen.unlocks_label = _screen.get_node("CenterContainer/PanelContainer/VBoxContainer/UnlocksLabel")
	_screen.play_again_button = _screen.get_node("CenterContainer/PanelContainer/VBoxContainer/ButtonContainer/PlayAgainButton")
	_screen.main_menu_button = _screen.get_node("CenterContainer/PanelContainer/VBoxContainer/ButtonContainer/MainMenuButton")


func after_test() -> void:
	GameManager.game_state = _original_game_state
	# Disconnect game_over signal if connected
	if GameManager.game_over.is_connected(_screen._on_game_over):
		GameManager.game_over.disconnect(_screen._on_game_over)
	if is_instance_valid(_screen):
		if _screen.is_inside_tree():
			remove_child(_screen)
		_screen.free()
	_screen = null


# -- Section 1: _apply_mobile_sizing() method exists ---------------------------

func test_apply_mobile_sizing_method_exists() -> void:
	## GameOverScreen must have an _apply_mobile_sizing() method.
	assert_bool(_screen.has_method("_apply_mobile_sizing")).is_true()


# -- Section 2: Button minimum heights on mobile ------------------------------

func test_all_buttons_min_height_56_on_mobile() -> void:
	## After _apply_mobile_sizing(), both buttons must have min height >= 56.
	_screen._apply_mobile_sizing()
	for btn: Button in _get_action_buttons():
		assert_bool(btn.custom_minimum_size.y >= 56.0) \
			.override_failure_message("Button '%s' height %s < 56" % [btn.name, btn.custom_minimum_size.y]) \
			.is_true()


func test_button_height_uses_uimanager_constant() -> void:
	## Button min height should match UIManager.MOBILE_ACTION_BUTTON_MIN_HEIGHT.
	_screen._apply_mobile_sizing()
	for btn: Button in _get_action_buttons():
		assert_float(btn.custom_minimum_size.y).is_equal(UIManager.MOBILE_ACTION_BUTTON_MIN_HEIGHT)


# -- Section 3: Button font sizes on mobile ------------------------------------

func test_button_font_size_at_least_16_on_mobile() -> void:
	## After _apply_mobile_sizing(), all button font sizes must be >= 16.
	_screen._apply_mobile_sizing()
	for btn: Button in _get_action_buttons():
		var font_size: int = btn.get_theme_font_size("font_size")
		assert_bool(font_size >= 16) \
			.override_failure_message("Button '%s' font size %d < 16" % [btn.name, font_size]) \
			.is_true()


# -- Section 4: Title font size on mobile --------------------------------------

func test_title_font_size_at_least_24_on_mobile() -> void:
	## After _apply_mobile_sizing(), result label must have font_size >= 24.
	_screen._apply_mobile_sizing()
	var font_size: int = _screen.result_label.get_theme_font_size("font_size")
	assert_bool(font_size >= 24) \
		.override_failure_message("Title font size %d < 24" % font_size) \
		.is_true()


func test_title_font_size_uses_uimanager_constant() -> void:
	## Result label font size should match UIManager.MOBILE_FONT_SIZE_TITLE.
	_screen._apply_mobile_sizing()
	var font_size: int = _screen.result_label.get_theme_font_size("font_size")
	assert_int(font_size).is_equal(UIManager.MOBILE_FONT_SIZE_TITLE)


# -- Section 5: Stat label font sizes on mobile --------------------------------

func test_stat_label_font_size_at_least_16_on_mobile() -> void:
	## After _apply_mobile_sizing(), all stat labels must have font_size >= 16.
	_screen._apply_mobile_sizing()
	for lbl: Label in _get_stat_labels():
		var font_size: int = lbl.get_theme_font_size("font_size")
		assert_bool(font_size >= 16) \
			.override_failure_message("Label '%s' font size %d < 16" % [lbl.name, font_size]) \
			.is_true()


func test_stat_label_font_size_uses_uimanager_constant() -> void:
	## Stat label font sizes should match UIManager.MOBILE_FONT_SIZE_BODY.
	_screen._apply_mobile_sizing()
	for lbl: Label in _get_stat_labels():
		var font_size: int = lbl.get_theme_font_size("font_size")
		assert_int(font_size).is_equal(UIManager.MOBILE_FONT_SIZE_BODY)


# -- Section 6: Desktop sizes unchanged when not calling mobile sizing ---------

func test_desktop_button_height_unchanged() -> void:
	## Without _apply_mobile_sizing(), buttons should keep desktop height (44).
	for btn: Button in _get_action_buttons():
		assert_float(btn.custom_minimum_size.y).is_equal(44.0)


func test_desktop_title_font_size_unchanged() -> void:
	## Without _apply_mobile_sizing(), title label should keep desktop font (36).
	var font_size: int = _screen.result_label.get_theme_font_size("font_size")
	assert_int(font_size).is_equal(36)
