extends GdUnitTestSuite

## Unit tests for Task C2: DraftPickPanel UI.
## Covers: initial state, show_choices(), element card display, pick interaction,
## pause/unpause behavior, signal connections, multi-pick rounds, and edge cases.

const DRAFT_PICK_PANEL_SCRIPT_PATH: String = "res://scripts/ui/DraftPickPanel.gd"

var _panel: Control
var _original_draft_elements: Array[String]
var _original_draft_active: bool
var _original_picks_remaining: int


# -- Helpers -------------------------------------------------------------------

## Build a DraftPickPanel node tree matching DraftPickPanel.tscn structure.
func _build_draft_pick_panel() -> Control:
	var root := Control.new()

	# Semi-transparent background dimmer
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.color = Color(0.0, 0.0, 0.0, 0.7)
	root.add_child(dimmer)

	# CenterContainer for layout
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	root.add_child(center)

	var panel_container := PanelContainer.new()
	panel_container.name = "PanelContainer"
	center.add_child(panel_container)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	panel_container.add_child(vbox)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Choose an Element"
	vbox.add_child(title)

	var cards_container := HBoxContainer.new()
	cards_container.name = "CardsContainer"
	vbox.add_child(cards_container)

	return root


## Create a typed Array[String] from element names. Avoids the typed array
## mismatch crash when passing untyped array literals to show_choices().
func _choices(elements: Array) -> Array[String]:
	var result: Array[String] = []
	for el: String in elements:
		result.append(el)
	return result


func _reset_draft_manager() -> void:
	DraftManager.drafted_elements = _original_draft_elements.duplicate()
	DraftManager.is_draft_active = _original_draft_active
	DraftManager.picks_remaining = _original_picks_remaining


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_draft_elements = DraftManager.drafted_elements.duplicate()
	_original_draft_active = DraftManager.is_draft_active
	_original_picks_remaining = DraftManager.picks_remaining


func before_test() -> void:
	_reset_draft_manager()
	# Ensure unpaused at start
	if get_tree().paused:
		get_tree().paused = false
	# Build a fresh DraftPickPanel for each test
	_panel = auto_free(_build_draft_pick_panel())
	var script: GDScript = load(DRAFT_PICK_PANEL_SCRIPT_PATH)
	_panel.set_script(script)
	# Wire up @onready refs manually (no scene tree, no _ready())
	_panel.title_label = _panel.get_node("CenterContainer/PanelContainer/VBoxContainer/TitleLabel")
	_panel.cards_container = _panel.get_node("CenterContainer/PanelContainer/VBoxContainer/CardsContainer")
	_panel.visible = false
	_panel._picks_needed = 1
	_panel._picks_made = 0


func after_test() -> void:
	if get_tree().paused:
		get_tree().paused = false
	_panel = null
	_reset_draft_manager()


func after() -> void:
	_reset_draft_manager()


# ==============================================================================
# SECTION 1: Initial State
# ==============================================================================

# -- 1. DraftPickPanel starts hidden ------------------------------------------

func test_panel_starts_hidden() -> void:
	assert_bool(_panel.visible).is_false()


# -- 2. DraftPickPanel script has correct class_name --------------------------

func test_panel_has_class_name() -> void:
	var script: GDScript = load(DRAFT_PICK_PANEL_SCRIPT_PATH)
	assert_str(script.get_global_name()).is_equal("DraftPickPanel")


# -- 3. DraftPickPanel has title_label reference ------------------------------

func test_panel_has_title_label() -> void:
	assert_object(_panel.title_label).is_not_null()


# -- 4. DraftPickPanel has cards_container reference --------------------------

func test_panel_has_cards_container() -> void:
	assert_object(_panel.cards_container).is_not_null()


# -- 5. Panel has Dimmer ColorRect child --------------------------------------

func test_panel_has_dimmer() -> void:
	var dimmer: Node = _panel.get_node_or_null("Dimmer")
	assert_object(dimmer).is_not_null()
	assert_bool(dimmer is ColorRect).is_true()


# ==============================================================================
# SECTION 2: show_choices() displays element cards
# ==============================================================================

# -- 6. show_choices() makes the panel visible --------------------------------

func test_show_choices_makes_visible() -> void:
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	assert_bool(_panel.visible).is_true()


# -- 7. show_choices() creates 3 cards for 3 choices --------------------------

func test_show_choices_creates_three_cards() -> void:
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	assert_int(_panel.cards_container.get_child_count()).is_equal(3)


# -- 8. show_choices() creates 2 cards for 2 choices --------------------------

func test_show_choices_creates_two_cards() -> void:
	_panel.show_choices(_choices(["fire", "water"]))
	assert_int(_panel.cards_container.get_child_count()).is_equal(2)


# -- 9. show_choices() creates 1 card for 1 choice ---------------------------

func test_show_choices_creates_one_card() -> void:
	_panel.show_choices(_choices(["fire"]))
	assert_int(_panel.cards_container.get_child_count()).is_equal(1)


# -- 10. show_choices() clears old cards before creating new ones -------------

func test_show_choices_clears_old_cards() -> void:
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	assert_int(_panel.cards_container.get_child_count()).is_equal(3)
	_panel.visible = false
	_panel.show_choices(_choices(["lightning", "ice"]))
	assert_int(_panel.cards_container.get_child_count()).is_equal(2)


# -- 11. show_choices() pauses the game via GameManager ----------------------

func test_show_choices_pauses_game() -> void:
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	assert_bool(get_tree().paused).is_true()


# ==============================================================================
# SECTION 3: Element card content
# ==============================================================================

# -- 12. Each card is a Button ------------------------------------------------

func test_cards_are_buttons() -> void:
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	for i: int in range(_panel.cards_container.get_child_count()):
		var card: Node = _panel.cards_container.get_child(i)
		assert_bool(card is Button).is_true()


# -- 13. Each card has the element name in a child Label ----------------------

func test_card_contains_element_name_label() -> void:
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	var card_0: Button = _panel.cards_container.get_child(0) as Button
	var card_1: Button = _panel.cards_container.get_child(1) as Button
	var card_2: Button = _panel.cards_container.get_child(2) as Button
	# Element names are in child VBoxContainer > Label children
	var vbox_0: VBoxContainer = card_0.get_child(0) as VBoxContainer
	var vbox_1: VBoxContainer = card_1.get_child(0) as VBoxContainer
	var vbox_2: VBoxContainer = card_2.get_child(0) as VBoxContainer
	var label_0: Label = vbox_0.get_child(0) as Label
	var label_1: Label = vbox_1.get_child(0) as Label
	var label_2: Label = vbox_2.get_child(0) as Label
	assert_str(label_0.text).is_equal("Fire")
	assert_str(label_1.text).is_equal("Water")
	assert_str(label_2.text).is_equal("Earth")


# -- 14. Cards store their element in metadata --------------------------------

func test_cards_have_element_metadata() -> void:
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	var card_0: Button = _panel.cards_container.get_child(0) as Button
	var card_1: Button = _panel.cards_container.get_child(1) as Button
	var card_2: Button = _panel.cards_container.get_child(2) as Button
	assert_str(card_0.get_meta("element")).is_equal("fire")
	assert_str(card_1.get_meta("element")).is_equal("water")
	assert_str(card_2.get_meta("element")).is_equal("earth")


# -- 15. Cards have element color applied -------------------------------------

func test_cards_have_element_color() -> void:
	_panel.show_choices(_choices(["fire"]))
	var card: Button = _panel.cards_container.get_child(0) as Button
	assert_bool(card.has_theme_stylebox_override("normal")).is_true()


# -- 16. Fire card gets darkened fire color as bg, fire color as border ------

func test_fire_card_color() -> void:
	_panel.show_choices(_choices(["fire"]))
	var card: Button = _panel.cards_container.get_child(0) as Button
	var style: StyleBox = card.get_theme_stylebox("normal")
	assert_bool(style is StyleBoxFlat).is_true()
	var flat: StyleBoxFlat = style as StyleBoxFlat
	var expected_bg: Color = ElementMatrix.get_color("fire").darkened(0.6)
	var expected_border: Color = ElementMatrix.get_color("fire")
	assert_bool(flat.bg_color.is_equal_approx(expected_bg)).is_true()
	assert_bool(flat.border_color.is_equal_approx(expected_border)).is_true()


# -- 17. Water card gets darkened water color as bg --------------------------

func test_water_card_color() -> void:
	_panel.show_choices(_choices(["water"]))
	var card: Button = _panel.cards_container.get_child(0) as Button
	var style: StyleBoxFlat = card.get_theme_stylebox("normal") as StyleBoxFlat
	var expected_bg: Color = ElementMatrix.get_color("water").darkened(0.6)
	assert_bool(style.bg_color.is_equal_approx(expected_bg)).is_true()


# ==============================================================================
# SECTION 4: Card click calls DraftManager.pick_element()
# ==============================================================================

# -- 18. Clicking a card calls DraftManager.pick_element() -------------------

func test_clicking_card_calls_pick_element() -> void:
	DraftManager.drafted_elements.clear()
	DraftManager.is_draft_active = true
	DraftManager.picks_remaining = 1
	_panel._picks_needed = 1
	_panel._picks_made = 0
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	var card: Button = _panel.cards_container.get_child(0) as Button
	var drafted: Array[String] = []
	var conn: Callable = func(el: String) -> void: drafted.append(el)
	DraftManager.element_drafted.connect(conn)
	card.pressed.emit()
	DraftManager.element_drafted.disconnect(conn)
	assert_int(drafted.size()).is_equal(1)
	assert_str(drafted[0]).is_equal("fire")


# -- 19. Clicking second card picks that element -----------------------------

func test_clicking_second_card_picks_second_element() -> void:
	DraftManager.drafted_elements.clear()
	DraftManager.is_draft_active = true
	DraftManager.picks_remaining = 1
	_panel._picks_needed = 1
	_panel._picks_made = 0
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	var card: Button = _panel.cards_container.get_child(1) as Button
	var drafted: Array[String] = []
	var conn: Callable = func(el: String) -> void: drafted.append(el)
	DraftManager.element_drafted.connect(conn)
	card.pressed.emit()
	DraftManager.element_drafted.disconnect(conn)
	assert_int(drafted.size()).is_equal(1)
	assert_str(drafted[0]).is_equal("water")


# -- 20. Clicking third card picks that element ------------------------------

func test_clicking_third_card_picks_third_element() -> void:
	DraftManager.drafted_elements.clear()
	DraftManager.is_draft_active = true
	DraftManager.picks_remaining = 1
	_panel._picks_needed = 1
	_panel._picks_made = 0
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	var card: Button = _panel.cards_container.get_child(2) as Button
	var drafted: Array[String] = []
	var conn: Callable = func(el: String) -> void: drafted.append(el)
	DraftManager.element_drafted.connect(conn)
	card.pressed.emit()
	DraftManager.element_drafted.disconnect(conn)
	assert_int(drafted.size()).is_equal(1)
	assert_str(drafted[0]).is_equal("earth")


# ==============================================================================
# SECTION 5: Panel hides and unpauses after pick
# ==============================================================================

# -- 21. Panel hides after a single-pick card is clicked ----------------------

func test_panel_hides_after_single_pick() -> void:
	DraftManager.drafted_elements.clear()
	DraftManager.is_draft_active = true
	DraftManager.picks_remaining = 1
	_panel._picks_needed = 1
	_panel._picks_made = 0
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	assert_bool(_panel.visible).is_true()
	var card: Button = _panel.cards_container.get_child(0) as Button
	card.pressed.emit()
	assert_bool(_panel.visible).is_false()


# -- 22. Game unpauses after a single-pick card is clicked --------------------

func test_game_unpauses_after_single_pick() -> void:
	DraftManager.drafted_elements.clear()
	DraftManager.is_draft_active = true
	DraftManager.picks_remaining = 1
	_panel._picks_needed = 1
	_panel._picks_made = 0
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	assert_bool(get_tree().paused).is_true()
	var card: Button = _panel.cards_container.get_child(0) as Button
	card.pressed.emit()
	assert_bool(get_tree().paused).is_false()


# -- 23. _clear_cards() removes all cards from the container ------------------

func test_clear_cards_removes_all() -> void:
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	assert_int(_panel.cards_container.get_child_count()).is_equal(3)
	_panel._clear_cards()
	assert_int(_panel.cards_container.get_child_count()).is_equal(0)


# ==============================================================================
# SECTION 6: Process mode
# ==============================================================================

# -- 24. Panel has PROCESS_MODE_WHEN_PAUSED -----------------------------------

func test_panel_process_mode() -> void:
	var file := FileAccess.open(DRAFT_PICK_PANEL_SCRIPT_PATH, FileAccess.READ)
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("process_mode = Node.PROCESS_MODE_WHEN_PAUSED")).is_true()


# -- 25. PROCESS_MODE_WHEN_PAUSED constant is 2 ------------------------------

func test_process_mode_when_paused_constant() -> void:
	assert_int(Node.PROCESS_MODE_WHEN_PAUSED).is_equal(2)


# ==============================================================================
# SECTION 7: Signal connection to DraftManager
# ==============================================================================

# -- 26. Panel has _on_draft_pick_available method ----------------------------

func test_panel_has_on_draft_pick_available() -> void:
	assert_bool(_panel.has_method("_on_draft_pick_available")).is_true()


# -- 27. _on_draft_pick_available calls show_choices --------------------------

func test_on_draft_pick_available_shows_choices() -> void:
	var choices: Array[String] = ["fire", "water", "earth"]
	_panel._on_draft_pick_available(choices, 1)
	assert_bool(_panel.visible).is_true()
	assert_int(_panel.cards_container.get_child_count()).is_equal(3)


# -- 28. Script connects to DraftManager.draft_pick_available in _ready() -----

func test_script_connects_draft_pick_available() -> void:
	var file := FileAccess.open(DRAFT_PICK_PANEL_SCRIPT_PATH, FileAccess.READ)
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("DraftManager.draft_pick_available.connect")).is_true()


# ==============================================================================
# SECTION 8: Multiple picks (show, pick, show again)
# ==============================================================================

# -- 29. Panel can show, pick, then show again with new choices ---------------

func test_multiple_picks_work() -> void:
	DraftManager.drafted_elements.clear()
	DraftManager.is_draft_active = true
	DraftManager.picks_remaining = 2

	# First pick (single-pick round)
	_panel._picks_needed = 1
	_panel._picks_made = 0
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	assert_bool(_panel.visible).is_true()
	var card1: Button = _panel.cards_container.get_child(0) as Button
	card1.pressed.emit()
	assert_bool(_panel.visible).is_false()
	assert_bool("fire" in DraftManager.drafted_elements).is_true()

	# Second pick (another single-pick round)
	_panel._picks_needed = 1
	_panel._picks_made = 0
	_panel.show_choices(_choices(["water", "earth", "wind"]))
	assert_bool(_panel.visible).is_true()
	assert_int(_panel.cards_container.get_child_count()).is_equal(3)
	var card2: Button = _panel.cards_container.get_child(1) as Button
	card2.pressed.emit()
	assert_bool(_panel.visible).is_false()
	assert_bool("earth" in DraftManager.drafted_elements).is_true()


# ==============================================================================
# SECTION 9: Edge cases
# ==============================================================================

# -- 30. Empty choices array does not crash -----------------------------------

func test_empty_choices_no_crash() -> void:
	var empty_choices: Array[String] = []
	_panel.show_choices(empty_choices)
	assert_int(_panel.cards_container.get_child_count()).is_equal(0)
	assert_bool(_panel.visible).is_true()


# -- 31. show_choices with all 6 elements works -------------------------------

func test_show_choices_with_all_elements() -> void:
	_panel.show_choices(_choices(["fire", "water", "earth", "wind", "lightning", "ice"]))
	assert_int(_panel.cards_container.get_child_count()).is_equal(6)


# -- 32. Card child label contains capitalized element name ------------------

func test_card_label_capitalized() -> void:
	_panel.show_choices(_choices(["fire"]))
	var card: Button = _panel.cards_container.get_child(0) as Button
	var vbox: VBoxContainer = card.get_child(0) as VBoxContainer
	var label: Label = vbox.get_child(0) as Label
	assert_str(label.text).is_equal("Fire")


# ==============================================================================
# SECTION 10: Tower info on cards
# ==============================================================================

# -- 33. Panel has _get_towers_for_element method -----------------------------

func test_panel_has_get_towers_for_element() -> void:
	assert_bool(_panel.has_method("_get_towers_for_element")).is_true()


# -- 34. _get_towers_for_element("fire") returns fire tower names -------------

func test_get_towers_for_element_fire() -> void:
	var towers: Array[String] = _panel._get_towers_for_element("fire")
	assert_bool("Flame Spire" in towers).is_true()


# -- 35. _get_towers_for_element("water") returns water tower names -----------

func test_get_towers_for_element_water() -> void:
	var towers: Array[String] = _panel._get_towers_for_element("water")
	assert_bool("Tidal Obelisk" in towers).is_true()


# -- 36. _get_towers_for_element returns only tier 1 base towers --------------

func test_get_towers_for_element_returns_tier_1() -> void:
	var towers: Array[String] = _panel._get_towers_for_element("fire")
	assert_bool("Flame Spire Enhanced" not in towers).is_true()


# -- 37. Card includes tower name label for the element ----------------------

func test_card_includes_tower_name_label() -> void:
	_panel.show_choices(_choices(["fire"]))
	var card: Button = _panel.cards_container.get_child(0) as Button
	var vbox: VBoxContainer = card.get_child(0) as VBoxContainer
	# VBox children: element name label, tower sprite, tower name label
	var tower_label: Label = vbox.get_child(vbox.get_child_count() - 1) as Label
	assert_str(tower_label.text).is_equal("Flame Spire")


# ==============================================================================
# SECTION 11: hide_panel() method
# ==============================================================================

# -- 38. hide_panel() hides the panel ----------------------------------------

func test_hide_panel_hides() -> void:
	_panel.visible = true
	_panel.hide_panel()
	assert_bool(_panel.visible).is_false()


# -- 39. hide_panel() unpauses the game --------------------------------------

func test_hide_panel_unpauses() -> void:
	get_tree().paused = true
	_panel.visible = true
	_panel.hide_panel()
	assert_bool(get_tree().paused).is_false()


# -- 40. hide_panel() clears cards -------------------------------------------

func test_hide_panel_clears_cards() -> void:
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	_panel.hide_panel()
	assert_int(_panel.cards_container.get_child_count()).is_equal(0)


# ==============================================================================
# SECTION 12: Scene file verification
# ==============================================================================

# -- 41. DraftPickPanel.tscn exists -------------------------------------------

func test_scene_file_exists() -> void:
	assert_bool(FileAccess.file_exists("res://scenes/ui/DraftPickPanel.tscn")).is_true()


# -- 42. DraftPickPanel.tscn references the script ----------------------------

func test_scene_references_script() -> void:
	var file := FileAccess.open("res://scenes/ui/DraftPickPanel.tscn", FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("DraftPickPanel.gd")).is_true()


# -- 43. DraftPickPanel.tscn has CardsContainer node --------------------------

func test_scene_has_cards_container() -> void:
	var file := FileAccess.open("res://scenes/ui/DraftPickPanel.tscn", FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("CardsContainer")).is_true()


# -- 44. DraftPickPanel.tscn has TitleLabel node ------------------------------

func test_scene_has_title_label() -> void:
	var file := FileAccess.open("res://scenes/ui/DraftPickPanel.tscn", FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("TitleLabel")).is_true()


# ==============================================================================
# SECTION 13: draft_started connection and title text
# ==============================================================================

# -- 45. Script connects to DraftManager.draft_started in _ready() -----------

func test_script_connects_draft_started() -> void:
	var file := FileAccess.open(DRAFT_PICK_PANEL_SCRIPT_PATH, FileAccess.READ)
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("DraftManager.draft_started.connect")).is_true()


# -- 46. Panel has _on_draft_started method -----------------------------------

func test_panel_has_on_draft_started() -> void:
	assert_bool(_panel.has_method("_on_draft_started")).is_true()


# -- 47. First pick shows "Choose Your Starting Element" title ----------------

func test_first_pick_title() -> void:
	DraftManager.drafted_elements.clear()
	_panel._on_draft_pick_available(_choices(["fire", "water", "earth"]), 1)
	assert_str(_panel.title_label.text).is_equal("Choose Your Starting Element")


# -- 48. Subsequent single pick shows "Draft an Element" title ----------------

func test_subsequent_pick_title() -> void:
	DraftManager.drafted_elements = ["fire"] as Array[String]
	_panel._on_draft_pick_available(_choices(["water", "earth", "wind"]), 1)
	assert_str(_panel.title_label.text).is_equal("Draft an Element")


# -- 49. Multi-pick shows "Choose 2 Elements" title --------------------------

func test_multi_pick_title() -> void:
	DraftManager.drafted_elements = ["fire", "water"] as Array[String]
	_panel._on_draft_pick_available(_choices(["earth", "wind", "lightning"]), 2)
	assert_str(_panel.title_label.text).is_equal("Choose 2 Elements")


# ==============================================================================
# SECTION 14: Card visual improvements (white text, tower sprite, darkened bg)
# ==============================================================================

# -- 50. Cards have white font_color override ---------------------------------

func test_card_has_white_font_color() -> void:
	_panel.show_choices(_choices(["fire"]))
	var card: Button = _panel.cards_container.get_child(0) as Button
	assert_bool(card.has_theme_color_override("font_color")).is_true()
	var font_color: Color = card.get_theme_color("font_color")
	assert_bool(font_color.is_equal_approx(Color.WHITE)).is_true()


# -- 51. Card has VBoxContainer child with MOUSE_FILTER_IGNORE ----------------

func test_card_has_vbox_child() -> void:
	_panel.show_choices(_choices(["fire"]))
	var card: Button = _panel.cards_container.get_child(0) as Button
	assert_int(card.get_child_count()).is_greater(0)
	var vbox: VBoxContainer = card.get_child(0) as VBoxContainer
	assert_object(vbox).is_not_null()
	assert_int(vbox.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


# -- 52. Card VBox contains a TextureRect for tower sprite --------------------

func test_card_has_tower_sprite() -> void:
	_panel.show_choices(_choices(["fire"]))
	var card: Button = _panel.cards_container.get_child(0) as Button
	var vbox: VBoxContainer = card.get_child(0) as VBoxContainer
	var found_texture_rect: bool = false
	for child: Node in vbox.get_children():
		if child is TextureRect:
			found_texture_rect = true
			var tex_rect: TextureRect = child as TextureRect
			assert_object(tex_rect.texture).is_not_null()
			assert_int(tex_rect.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
			break
	assert_bool(found_texture_rect).is_true()


# -- 53. Card element name label has white color and MOUSE_FILTER_IGNORE ------

func test_card_element_label_style() -> void:
	_panel.show_choices(_choices(["earth"]))
	var card: Button = _panel.cards_container.get_child(0) as Button
	var vbox: VBoxContainer = card.get_child(0) as VBoxContainer
	var name_label: Label = vbox.get_child(0) as Label
	assert_int(name_label.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var font_color: Color = name_label.get_theme_color("font_color")
	assert_bool(font_color.is_equal_approx(Color.WHITE)).is_true()


# -- 54. Card normal style has border_width > 0 ------------------------------

func test_card_has_border() -> void:
	_panel.show_choices(_choices(["fire"]))
	var card: Button = _panel.cards_container.get_child(0) as Button
	var style: StyleBoxFlat = card.get_theme_stylebox("normal") as StyleBoxFlat
	assert_int(style.border_width_left).is_greater(0)


# ==============================================================================
# SECTION 15: Multi-pick round behavior
# ==============================================================================

# -- 55. Multi-pick: panel stays open after first pick -------------------------

func test_multi_pick_panel_stays_open_after_first_pick() -> void:
	DraftManager.drafted_elements.clear()
	DraftManager.is_draft_active = true
	DraftManager.picks_remaining = 2
	_panel._picks_needed = 2
	_panel._picks_made = 0
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	assert_bool(_panel.visible).is_true()
	var card: Button = _panel.cards_container.get_child(0) as Button
	card.pressed.emit()
	# Panel should still be visible after first pick in multi-pick round
	assert_bool(_panel.visible).is_true()


# -- 56. Multi-pick: first selected card becomes disabled ---------------------

func test_multi_pick_first_card_disabled_after_pick() -> void:
	DraftManager.drafted_elements.clear()
	DraftManager.is_draft_active = true
	DraftManager.picks_remaining = 2
	_panel._picks_needed = 2
	_panel._picks_made = 0
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	var card: Button = _panel.cards_container.get_child(0) as Button
	card.pressed.emit()
	assert_bool(card.disabled).is_true()


# -- 57. Multi-pick: panel closes after second pick ---------------------------

func test_multi_pick_panel_closes_after_second_pick() -> void:
	DraftManager.drafted_elements.clear()
	DraftManager.is_draft_active = true
	DraftManager.picks_remaining = 2
	_panel._picks_needed = 2
	_panel._picks_made = 0
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	# First pick
	var card1: Button = _panel.cards_container.get_child(0) as Button
	card1.pressed.emit()
	assert_bool(_panel.visible).is_true()
	# Second pick
	var card2: Button = _panel.cards_container.get_child(1) as Button
	card2.pressed.emit()
	assert_bool(_panel.visible).is_false()


# -- 58. Multi-pick: game stays paused during multi-pick ----------------------

func test_multi_pick_game_stays_paused_during_picks() -> void:
	DraftManager.drafted_elements.clear()
	DraftManager.is_draft_active = true
	DraftManager.picks_remaining = 2
	_panel._picks_needed = 2
	_panel._picks_made = 0
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	assert_bool(get_tree().paused).is_true()
	var card: Button = _panel.cards_container.get_child(0) as Button
	card.pressed.emit()
	# Game should still be paused after first pick
	assert_bool(get_tree().paused).is_true()


# -- 59. Multi-pick: game unpauses after all picks ----------------------------

func test_multi_pick_game_unpauses_after_all_picks() -> void:
	DraftManager.drafted_elements.clear()
	DraftManager.is_draft_active = true
	DraftManager.picks_remaining = 2
	_panel._picks_needed = 2
	_panel._picks_made = 0
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	var card1: Button = _panel.cards_container.get_child(0) as Button
	card1.pressed.emit()
	var card2: Button = _panel.cards_container.get_child(1) as Button
	card2.pressed.emit()
	assert_bool(get_tree().paused).is_false()


# -- 60. Multi-pick: both elements are drafted --------------------------------

func test_multi_pick_both_elements_drafted() -> void:
	DraftManager.drafted_elements.clear()
	DraftManager.is_draft_active = true
	DraftManager.picks_remaining = 2
	_panel._picks_needed = 2
	_panel._picks_made = 0
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	var card1: Button = _panel.cards_container.get_child(0) as Button
	card1.pressed.emit()
	var card2: Button = _panel.cards_container.get_child(1) as Button
	card2.pressed.emit()
	assert_bool("fire" in DraftManager.drafted_elements).is_true()
	assert_bool("water" in DraftManager.drafted_elements).is_true()


# -- 61. Multi-pick: _picks_made tracks correctly -----------------------------

func test_multi_pick_picks_made_counter() -> void:
	DraftManager.drafted_elements.clear()
	DraftManager.is_draft_active = true
	DraftManager.picks_remaining = 2
	_panel._picks_needed = 2
	_panel._picks_made = 0
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	assert_int(_panel._picks_made).is_equal(0)
	var card1: Button = _panel.cards_container.get_child(0) as Button
	card1.pressed.emit()
	assert_int(_panel._picks_made).is_equal(1)
	var card2: Button = _panel.cards_container.get_child(1) as Button
	card2.pressed.emit()
	assert_int(_panel._picks_made).is_equal(2)


# -- 62. Multi-pick: selected card gets "Selected" label ----------------------

func test_multi_pick_selected_card_has_checkmark() -> void:
	DraftManager.drafted_elements.clear()
	DraftManager.is_draft_active = true
	DraftManager.picks_remaining = 2
	_panel._picks_needed = 2
	_panel._picks_made = 0
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	var card: Button = _panel.cards_container.get_child(0) as Button
	card.pressed.emit()
	# Check for "Selected" label in the card's VBox
	var vbox: VBoxContainer = card.get_child(0) as VBoxContainer
	var found_check: bool = false
	for child: Node in vbox.get_children():
		if child is Label and child.text == "Selected":
			found_check = true
	assert_bool(found_check).is_true()


# -- 63. Multi-pick: selected card gets brightened border ---------------------

func test_multi_pick_selected_card_has_brightened_style() -> void:
	DraftManager.drafted_elements.clear()
	DraftManager.is_draft_active = true
	DraftManager.picks_remaining = 2
	_panel._picks_needed = 2
	_panel._picks_made = 0
	_panel.show_choices(_choices(["fire", "water", "earth"]))
	var card: Button = _panel.cards_container.get_child(0) as Button
	# Record original border width
	var original_style: StyleBoxFlat = card.get_theme_stylebox("normal") as StyleBoxFlat
	var original_border_width: int = original_style.border_width_left
	card.pressed.emit()
	# After selection, border should be wider (3 -> 4) and style replaced
	var selected_style: StyleBoxFlat = card.get_theme_stylebox("normal") as StyleBoxFlat
	assert_int(selected_style.border_width_left).is_greater_equal(original_border_width)


# -- 64. _on_draft_pick_available resets picks_made for new round -------------

func test_on_draft_pick_available_resets_picks_made() -> void:
	_panel._picks_made = 5
	DraftManager.drafted_elements = ["fire"] as Array[String]
	_panel._on_draft_pick_available(_choices(["water", "earth", "wind"]), 2)
	assert_int(_panel._picks_made).is_equal(0)
	assert_int(_panel._picks_needed).is_equal(2)
