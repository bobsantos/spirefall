extends GdUnitTestSuite

## Unit tests for Task D3: PauseMenu mobile sizing.
## Covers: button minimum heights/widths, font sizes, panel padding,
## and the _apply_mobile_sizing() method.

const PAUSE_MENU_SCRIPT_PATH: String = "res://scripts/ui/PauseMenu.gd"

var _menu: Control
var _original_game_state: int


# -- Helpers -------------------------------------------------------------------

func _build_pause_menu_node() -> Control:
	## Build a PauseMenu node tree manually matching PauseMenu.tscn structure.
	var root := Control.new()

	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	root.add_child(dimmer)

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "PanelContainer"
	panel.custom_minimum_size = Vector2(320, 332)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	panel.add_child(vbox)

	var spacer_top := Control.new()
	spacer_top.name = "SpacerTop"
	vbox.add_child(spacer_top)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Paused"
	vbox.add_child(title)

	var spacer_mid := Control.new()
	spacer_mid.name = "SpacerMid"
	vbox.add_child(spacer_mid)

	var btn_names: Array[String] = ["ResumeButton", "RestartButton", "SettingsButton", "CodexButton", "QuitButton"]
	for btn_name: String in btn_names:
		var btn := Button.new()
		btn.name = btn_name
		btn.custom_minimum_size = Vector2(200, 44)
		vbox.add_child(btn)

	var spacer_bottom := Control.new()
	spacer_bottom.name = "SpacerBottom"
	vbox.add_child(spacer_bottom)

	return root


func _get_buttons() -> Array[Button]:
	var vbox: VBoxContainer = _menu.get_node("CenterContainer/PanelContainer/VBoxContainer")
	var buttons: Array[Button] = []
	for child: Node in vbox.get_children():
		if child is Button:
			buttons.append(child as Button)
	return buttons


func _get_panel() -> PanelContainer:
	return _menu.get_node("CenterContainer/PanelContainer") as PanelContainer


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_original_game_state = GameManager.game_state
	_menu = _build_pause_menu_node()
	add_child(_menu)
	_menu.set_script(load(PAUSE_MENU_SCRIPT_PATH))
	# Manually set @onready vars since set_script() after add_child won't trigger _ready() @onready
	_menu.resume_button = _menu.get_node("CenterContainer/PanelContainer/VBoxContainer/ResumeButton")
	_menu.restart_button = _menu.get_node("CenterContainer/PanelContainer/VBoxContainer/RestartButton")
	_menu.settings_button = _menu.get_node("CenterContainer/PanelContainer/VBoxContainer/SettingsButton")
	_menu.codex_button = _menu.get_node("CenterContainer/PanelContainer/VBoxContainer/CodexButton")
	_menu.quit_button = _menu.get_node("CenterContainer/PanelContainer/VBoxContainer/QuitButton")
	_menu.panel_container = _menu.get_node("CenterContainer/PanelContainer")
	# Manually connect button signals since set_script() after add_child skips _ready()
	_menu.resume_button.pressed.connect(_menu._on_resume_pressed)


func after_test() -> void:
	GameManager.game_state = _original_game_state
	# Disconnect signals to avoid leaks
	if GameManager.paused_changed.is_connected(_menu._on_paused_changed):
		GameManager.paused_changed.disconnect(_menu._on_paused_changed)
	if is_instance_valid(_menu):
		if _menu.is_inside_tree():
			remove_child(_menu)
		_menu.free()
	_menu = null


# -- Section 1: _apply_mobile_sizing() method exists ---------------------------

func test_apply_mobile_sizing_method_exists() -> void:
	## PauseMenu must have an _apply_mobile_sizing() method.
	assert_bool(_menu.has_method("_apply_mobile_sizing")).is_true()


# -- Section 2: Button minimum heights on mobile ------------------------------

func test_all_buttons_min_height_56_on_mobile() -> void:
	## After _apply_mobile_sizing(), all 5 buttons must have min height >= 56.
	_menu._apply_mobile_sizing()
	for btn: Button in _get_buttons():
		assert_bool(btn.custom_minimum_size.y >= 56.0) \
			.override_failure_message("Button '%s' height %s < 56" % [btn.name, btn.custom_minimum_size.y]) \
			.is_true()


func test_button_height_uses_uimanager_constant() -> void:
	## Button min height should match UIManager.MOBILE_ACTION_BUTTON_MIN_HEIGHT.
	_menu._apply_mobile_sizing()
	for btn: Button in _get_buttons():
		assert_float(btn.custom_minimum_size.y).is_equal(UIManager.MOBILE_ACTION_BUTTON_MIN_HEIGHT)


# -- Section 3: Button minimum widths on mobile --------------------------------

func test_all_buttons_min_width_280_on_mobile() -> void:
	## After _apply_mobile_sizing(), all buttons must have min width >= 280.
	_menu._apply_mobile_sizing()
	for btn: Button in _get_buttons():
		assert_bool(btn.custom_minimum_size.x >= 280.0) \
			.override_failure_message("Button '%s' width %s < 280" % [btn.name, btn.custom_minimum_size.x]) \
			.is_true()


# -- Section 4: Button font sizes on mobile ------------------------------------

func test_button_font_size_at_least_16_on_mobile() -> void:
	## After _apply_mobile_sizing(), all button font sizes must be >= 16.
	_menu._apply_mobile_sizing()
	for btn: Button in _get_buttons():
		var font_size: int = btn.get_theme_font_size("font_size")
		assert_bool(font_size >= 16) \
			.override_failure_message("Button '%s' font size %d < 16" % [btn.name, font_size]) \
			.is_true()


func test_button_font_size_uses_uimanager_constant() -> void:
	## Button font size should match UIManager.MOBILE_FONT_SIZE_BODY.
	_menu._apply_mobile_sizing()
	for btn: Button in _get_buttons():
		var font_size: int = btn.get_theme_font_size("font_size")
		assert_int(font_size).is_equal(UIManager.MOBILE_FONT_SIZE_BODY)


# -- Section 5: Panel padding on mobile ----------------------------------------

func test_panel_padding_increased_on_mobile() -> void:
	## After _apply_mobile_sizing(), the panel container should have increased padding.
	_menu._apply_mobile_sizing()
	var panel: PanelContainer = _get_panel()
	var style: StyleBox = panel.get_theme_stylebox("panel")
	assert_object(style).is_not_null()
	if style is StyleBoxFlat:
		var flat: StyleBoxFlat = style as StyleBoxFlat
		assert_bool(flat.content_margin_left >= 16.0) \
			.override_failure_message("Panel left margin %s < 16" % flat.content_margin_left) \
			.is_true()
		assert_bool(flat.content_margin_top >= 16.0) \
			.override_failure_message("Panel top margin %s < 16" % flat.content_margin_top) \
			.is_true()


# -- Section 6: Desktop sizes unchanged when not calling mobile sizing ---------

func test_desktop_button_height_unchanged() -> void:
	## Without _apply_mobile_sizing(), buttons should keep desktop height (44).
	for btn: Button in _get_buttons():
		assert_float(btn.custom_minimum_size.y).is_equal(44.0)


func test_desktop_button_width_unchanged() -> void:
	## Without _apply_mobile_sizing(), buttons should keep desktop width (200).
	for btn: Button in _get_buttons():
		assert_float(btn.custom_minimum_size.x).is_equal(200.0)


# -- Section 7: Buttons remain functional after mobile sizing ------------------

func test_resume_button_works_after_mobile_sizing() -> void:
	## Resume button must still hide the menu after _apply_mobile_sizing().
	_menu._apply_mobile_sizing()
	_menu.visible = true
	_menu.resume_button.pressed.emit()
	assert_bool(_menu.visible).is_false()
