extends GdUnitTestSuite

## Unit tests for Task D5: DraftPickPanel mobile sizing.
## Covers: element card minimum sizes, font sizes, and _apply_mobile_sizing() method.

const DRAFT_PICK_SCRIPT_PATH: String = "res://scripts/ui/DraftPickPanel.gd"

var _panel: Control


# -- Helpers -------------------------------------------------------------------

func _build_draft_pick_node() -> Control:
	## Build a DraftPickPanel node tree manually matching DraftPickPanel.tscn structure.
	var root := Control.new()

	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	root.add_child(dimmer)

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	root.add_child(center)

	var panel_container := PanelContainer.new()
	panel_container.name = "PanelContainer"
	panel_container.custom_minimum_size = Vector2(700, 400)
	center.add_child(panel_container)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	panel_container.add_child(vbox)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Choose an Element"
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	var cards := HBoxContainer.new()
	cards.name = "CardsContainer"
	vbox.add_child(cards)

	return root


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_panel = _build_draft_pick_node()
	add_child(_panel)
	_panel.set_script(load(DRAFT_PICK_SCRIPT_PATH))
	# Manually set @onready vars
	_panel.title_label = _panel.get_node("CenterContainer/PanelContainer/VBoxContainer/TitleLabel")
	_panel.cards_container = _panel.get_node("CenterContainer/PanelContainer/VBoxContainer/CardsContainer")


func after_test() -> void:
	# Disconnect DraftManager signals
	if DraftManager.draft_pick_available.is_connected(_panel._on_draft_pick_available):
		DraftManager.draft_pick_available.disconnect(_panel._on_draft_pick_available)
	if DraftManager.draft_started.is_connected(_panel._on_draft_started):
		DraftManager.draft_started.disconnect(_panel._on_draft_started)
	if is_instance_valid(_panel):
		if _panel.is_inside_tree():
			remove_child(_panel)
		_panel.free()
	_panel = null


# -- Section 1: _apply_mobile_sizing() method exists ---------------------------

func test_apply_mobile_sizing_method_exists() -> void:
	## DraftPickPanel must have an _apply_mobile_sizing() method.
	assert_bool(_panel.has_method("_apply_mobile_sizing")).is_true()


# -- Section 2: Card minimum sizes on mobile -----------------------------------

func test_card_min_size_100x100_on_mobile() -> void:
	## After _apply_mobile_sizing(), created cards must be at least 100x100.
	_panel._apply_mobile_sizing()
	# Create a card to verify its size
	var card: Button = _panel._create_element_card("fire")
	assert_bool(card.custom_minimum_size.x >= 100.0) \
		.override_failure_message("Card width %s < 100" % card.custom_minimum_size.x) \
		.is_true()
	assert_bool(card.custom_minimum_size.y >= 100.0) \
		.override_failure_message("Card height %s < 100" % card.custom_minimum_size.y) \
		.is_true()
	card.free()


# -- Section 3: Title font size on mobile --------------------------------------

func test_title_font_size_at_least_24_on_mobile() -> void:
	## After _apply_mobile_sizing(), title label must have font_size >= 24.
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.title_label.get_theme_font_size("font_size")
	assert_bool(font_size >= 24) \
		.override_failure_message("Title font size %d < 24" % font_size) \
		.is_true()


func test_title_font_size_uses_uimanager_constant() -> void:
	## Title label font size should match UIManager.MOBILE_FONT_SIZE_TITLE.
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.title_label.get_theme_font_size("font_size")
	assert_int(font_size).is_equal(UIManager.MOBILE_FONT_SIZE_TITLE)


# -- Section 4: Card name font size on mobile ----------------------------------

func test_card_name_font_size_at_least_16_on_mobile() -> void:
	## After _apply_mobile_sizing(), card name labels must have font_size >= 16.
	_panel._apply_mobile_sizing()
	var card: Button = _panel._create_element_card("fire")
	# Name label is the first Label child of the VBoxContainer inside the card
	var vbox: VBoxContainer = card.get_child(0) as VBoxContainer
	assert_object(vbox).is_not_null()
	var name_label: Label = vbox.get_child(0) as Label
	assert_object(name_label).is_not_null()
	var font_size: int = name_label.get_theme_font_size("font_size")
	assert_bool(font_size >= 16) \
		.override_failure_message("Card name font size %d < 16" % font_size) \
		.is_true()
	card.free()


# -- Section 5: Desktop sizes unchanged when not calling mobile sizing ---------

func test_desktop_card_size_unchanged() -> void:
	## Without _apply_mobile_sizing(), cards should keep desktop size (200x280).
	var card: Button = _panel._create_element_card("fire")
	assert_vector(card.custom_minimum_size).is_equal(Vector2(200, 280))
	card.free()


func test_desktop_title_font_size_unchanged() -> void:
	## Without _apply_mobile_sizing(), title label should keep desktop font (28).
	var font_size: int = _panel.title_label.get_theme_font_size("font_size")
	assert_int(font_size).is_equal(28)
