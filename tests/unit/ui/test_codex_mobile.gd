extends GdUnitTestSuite

## Unit tests for Task D5: CodexPanel mobile sizing.
## Covers: close button size, tab button sizes, font sizes, and _apply_mobile_sizing().

const CODEX_SCRIPT_PATH: String = "res://scripts/ui/CodexPanel.gd"

var _panel: PanelContainer


# -- Helpers -------------------------------------------------------------------

func _build_codex_node() -> PanelContainer:
	## Build a CodexPanel node tree manually matching CodexPanel.tscn.
	var root := PanelContainer.new()

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	root.add_child(vbox)

	var header := HBoxContainer.new()
	header.name = "HeaderBar"
	vbox.add_child(header)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Codex"
	title.add_theme_font_size_override("font_size", 20)
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 32)
	header.add_child(close_btn)

	var tab_bar := HBoxContainer.new()
	tab_bar.name = "TabBar"
	vbox.add_child(tab_bar)

	var tab_names: Array[String] = ["TowersTab", "ElementsTab", "EnemiesTab", "ModesTab"]
	for tab_name: String in tab_names:
		var btn := Button.new()
		btn.name = tab_name
		tab_bar.add_child(btn)

	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.name = "ContentContainer"
	scroll.add_child(content)

	return root


func _get_tab_buttons() -> Array[Button]:
	var tab_bar: HBoxContainer = _panel.get_node("VBoxContainer/TabBar")
	var buttons: Array[Button] = []
	for child: Node in tab_bar.get_children():
		if child is Button:
			buttons.append(child as Button)
	return buttons


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_panel = _build_codex_node()
	add_child(_panel)
	_panel.set_script(load(CODEX_SCRIPT_PATH))
	# Manually set @onready vars
	_panel.content_container = _panel.get_node("VBoxContainer/ScrollContainer/ContentContainer")
	var typed_tabs: Array[Button] = [
		_panel.get_node("VBoxContainer/TabBar/TowersTab") as Button,
		_panel.get_node("VBoxContainer/TabBar/ElementsTab") as Button,
		_panel.get_node("VBoxContainer/TabBar/EnemiesTab") as Button,
		_panel.get_node("VBoxContainer/TabBar/ModesTab") as Button,
	]
	_panel.tab_buttons = typed_tabs
	_panel.close_button = _panel.get_node("VBoxContainer/HeaderBar/CloseButton")


func after_test() -> void:
	UIManager.codex_panel = null
	if is_instance_valid(_panel):
		if _panel.is_inside_tree():
			remove_child(_panel)
		_panel.free()
	_panel = null


# -- Section 1: _apply_mobile_sizing() method exists ---------------------------

func test_apply_mobile_sizing_method_exists() -> void:
	## CodexPanel must have an _apply_mobile_sizing() method.
	assert_bool(_panel.has_method("_apply_mobile_sizing")).is_true()


# -- Section 2: Close button size on mobile ------------------------------------

func test_close_button_min_height_on_mobile() -> void:
	## After _apply_mobile_sizing(), close button must have min height >= 48.
	_panel._apply_mobile_sizing()
	assert_bool(_panel.close_button.custom_minimum_size.y >= 48.0) \
		.override_failure_message("Close button height %s < 48" % _panel.close_button.custom_minimum_size.y) \
		.is_true()


func test_close_button_min_width_on_mobile() -> void:
	## After _apply_mobile_sizing(), close button must have min width >= 48.
	_panel._apply_mobile_sizing()
	assert_bool(_panel.close_button.custom_minimum_size.x >= 48.0) \
		.override_failure_message("Close button width %s < 48" % _panel.close_button.custom_minimum_size.x) \
		.is_true()


# -- Section 3: Tab button sizes on mobile -------------------------------------

func test_tab_buttons_min_height_on_mobile() -> void:
	## After _apply_mobile_sizing(), tab buttons must have min height >= 44.
	_panel._apply_mobile_sizing()
	for btn: Button in _get_tab_buttons():
		assert_bool(btn.custom_minimum_size.y >= 44.0) \
			.override_failure_message("Tab button '%s' height %s < 44" % [btn.name, btn.custom_minimum_size.y]) \
			.is_true()


func test_tab_button_font_size_at_least_14_on_mobile() -> void:
	## After _apply_mobile_sizing(), tab button font sizes must be >= 14.
	_panel._apply_mobile_sizing()
	for btn: Button in _get_tab_buttons():
		var font_size: int = btn.get_theme_font_size("font_size")
		assert_bool(font_size >= 14) \
			.override_failure_message("Tab button '%s' font size %d < 14" % [btn.name, font_size]) \
			.is_true()


func test_tab_button_font_size_uses_uimanager_constant() -> void:
	## Tab button font size should match UIManager.MOBILE_FONT_SIZE_LABEL.
	_panel._apply_mobile_sizing()
	for btn: Button in _get_tab_buttons():
		var font_size: int = btn.get_theme_font_size("font_size")
		assert_int(font_size).is_equal(UIManager.MOBILE_FONT_SIZE_LABEL)


# -- Section 4: Close button font size on mobile --------------------------------

func test_close_button_font_size_at_least_16_on_mobile() -> void:
	## After _apply_mobile_sizing(), close button font size must be >= 16.
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.close_button.get_theme_font_size("font_size")
	assert_bool(font_size >= 16) \
		.override_failure_message("Close button font size %d < 16" % font_size) \
		.is_true()


# -- Section 5: Desktop sizes unchanged when not calling mobile sizing ---------

func test_desktop_close_button_size_unchanged() -> void:
	## Without _apply_mobile_sizing(), close button should keep desktop size (32x32).
	assert_vector(_panel.close_button.custom_minimum_size).is_equal(Vector2(32, 32))


func test_desktop_tab_buttons_no_min_height() -> void:
	## Without _apply_mobile_sizing(), tab buttons should not have custom min height.
	for btn: Button in _get_tab_buttons():
		assert_float(btn.custom_minimum_size.y).is_equal(0.0)
