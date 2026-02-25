extends GdUnitTestSuite

## Unit tests for Task C3: BuildMenu Element Filtering.
## Covers: draft mode filtering, element_drafted signal refresh, draft indicator,
## fusion tower filtering, and non-draft mode passthrough.

const BUILD_MENU_SCRIPT_PATH: String = "res://scripts/ui/BuildMenu.gd"

var _menu: Control
var _original_draft_active: bool
var _original_drafted_elements: Array[String]
var _original_gold: int


# -- Helpers -------------------------------------------------------------------

func _make_tower_data(tower_name: String, element: String, tier: int = 1, fusion_elements: Array[String] = []) -> TowerData:
	var td := TowerData.new()
	td.tower_name = tower_name
	td.element = element
	td.tier = tier
	td.cost = 30
	td.damage = 10
	td.attack_speed = 1.0
	td.range_cells = 3
	td.damage_type = element
	td.special_description = ""
	td.fusion_elements = fusion_elements
	return td


func _build_menu_node() -> Control:
	## Build a BuildMenu node tree manually matching BuildMenu.tscn structure.
	var root := Control.new()

	var panel_bg := Panel.new()
	panel_bg.name = "PanelBG"
	root.add_child(panel_bg)

	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	root.add_child(scroll)

	var hbox := HBoxContainer.new()
	hbox.name = "HBoxContainer"
	scroll.add_child(hbox)

	return root


func _apply_script(node: Control) -> void:
	## Apply the BuildMenu script and set @onready vars manually.
	node.set_script(load(BUILD_MENU_SCRIPT_PATH))
	node.button_container = node.get_node("ScrollContainer/HBoxContainer")
	# Create draft indicator like _ready() would
	node._create_draft_indicator()


func _inject_towers(menu: Control, towers: Array[TowerData]) -> void:
	## Inject tower data directly, bypassing file loading.
	menu._available_towers.clear()
	for td: TowerData in towers:
		menu._available_towers.append(td)


func _count_visible_buttons(menu: Control) -> int:
	var count: int = 0
	for btn: Button in menu._tower_buttons:
		if btn.visible:
			count += 1
	return count


func _get_visible_tower_names(menu: Control) -> Array[String]:
	var names: Array[String] = []
	for i: int in range(menu._available_towers.size()):
		if i < menu._tower_buttons.size() and menu._tower_buttons[i].visible:
			names.append(menu._available_towers[i].tower_name)
	return names


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_original_draft_active = DraftManager.is_draft_active
	_original_drafted_elements = DraftManager.drafted_elements.duplicate()
	_original_gold = EconomyManager.gold

	# Default: draft inactive
	DraftManager.is_draft_active = false
	DraftManager.drafted_elements.clear()
	EconomyManager.gold = 9999  # Enough to afford everything

	_menu = auto_free(_build_menu_node())
	_apply_script(_menu)


func after_test() -> void:
	DraftManager.is_draft_active = _original_draft_active
	DraftManager.drafted_elements = _original_drafted_elements
	EconomyManager.gold = _original_gold
	UIManager.build_menu = null

	_menu = null


# -- Section 1: Non-draft mode (all towers shown) -----------------------------

func test_no_draft_all_towers_visible() -> void:
	var towers: Array[TowerData] = [
		_make_tower_data("Flame Spire", "fire"),
		_make_tower_data("Tidal Obelisk", "water"),
		_make_tower_data("Stone Bastion", "earth"),
	]
	_inject_towers(_menu, towers)
	_menu._create_buttons()

	assert_int(_count_visible_buttons(_menu)).is_equal(3)


func test_no_draft_flag_false_by_default() -> void:
	assert_bool(DraftManager.is_draft_active).is_false()


func test_no_draft_all_elements_pass_filter() -> void:
	var towers: Array[TowerData] = []
	for el: String in ElementMatrix.ELEMENTS:
		towers.append(_make_tower_data(el.capitalize() + " Tower", el))
	_inject_towers(_menu, towers)
	_menu._create_buttons()

	assert_int(_count_visible_buttons(_menu)).is_equal(6)


# -- Section 2: Draft mode with 1 element -------------------------------------

func test_draft_one_element_only_matching_visible() -> void:
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["fire"] as Array[String]

	var towers: Array[TowerData] = [
		_make_tower_data("Flame Spire", "fire"),
		_make_tower_data("Tidal Obelisk", "water"),
		_make_tower_data("Stone Bastion", "earth"),
	]
	_inject_towers(_menu, towers)
	_menu._create_buttons()

	assert_int(_count_visible_buttons(_menu)).is_equal(1)
	var names: Array[String] = _get_visible_tower_names(_menu)
	assert_array(names).contains(["Flame Spire"])


func test_draft_one_element_others_hidden() -> void:
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["water"] as Array[String]

	var towers: Array[TowerData] = [
		_make_tower_data("Flame Spire", "fire"),
		_make_tower_data("Tidal Obelisk", "water"),
		_make_tower_data("Stone Bastion", "earth"),
	]
	_inject_towers(_menu, towers)
	_menu._create_buttons()

	var names: Array[String] = _get_visible_tower_names(_menu)
	assert_array(names).contains(["Tidal Obelisk"])
	assert_array(names).not_contains(["Flame Spire"])
	assert_array(names).not_contains(["Stone Bastion"])


# -- Section 3: Draft mode with 2 elements ------------------------------------

func test_draft_two_elements_both_visible() -> void:
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["fire", "earth"] as Array[String]

	var towers: Array[TowerData] = [
		_make_tower_data("Flame Spire", "fire"),
		_make_tower_data("Tidal Obelisk", "water"),
		_make_tower_data("Stone Bastion", "earth"),
		_make_tower_data("Gale Tower", "wind"),
	]
	_inject_towers(_menu, towers)
	_menu._create_buttons()

	assert_int(_count_visible_buttons(_menu)).is_equal(2)
	var names: Array[String] = _get_visible_tower_names(_menu)
	assert_array(names).contains(["Flame Spire"])
	assert_array(names).contains(["Stone Bastion"])


# -- Section 4: Draft mode with all elements -----------------------------------

func test_draft_all_elements_all_visible() -> void:
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["fire", "water", "earth", "wind", "lightning", "ice"] as Array[String]

	var towers: Array[TowerData] = []
	for el: String in ElementMatrix.ELEMENTS:
		towers.append(_make_tower_data(el.capitalize() + " Tower", el))
	_inject_towers(_menu, towers)
	_menu._create_buttons()

	assert_int(_count_visible_buttons(_menu)).is_equal(6)


# -- Section 5: element_drafted signal triggers refresh ------------------------

func test_element_drafted_signal_refreshes_buttons() -> void:
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["fire"] as Array[String]

	var towers: Array[TowerData] = [
		_make_tower_data("Flame Spire", "fire"),
		_make_tower_data("Tidal Obelisk", "water"),
	]
	_inject_towers(_menu, towers)
	_menu._create_buttons()

	# Connect to the signal like _ready() would
	_menu._connect_draft_signals()

	# Initially only fire visible
	assert_int(_count_visible_buttons(_menu)).is_equal(1)

	# Simulate drafting water
	DraftManager.drafted_elements.append("water")
	DraftManager.element_drafted.emit("water")

	# Now both should be visible
	assert_int(_count_visible_buttons(_menu)).is_equal(2)

	# Cleanup: disconnect signal
	_menu._disconnect_draft_signals()


func test_disconnect_draft_signals_stops_refresh() -> void:
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["fire"] as Array[String]

	var towers: Array[TowerData] = [
		_make_tower_data("Flame Spire", "fire"),
		_make_tower_data("Tidal Obelisk", "water"),
	]
	_inject_towers(_menu, towers)
	_menu._create_buttons()

	_menu._connect_draft_signals()
	_menu._disconnect_draft_signals()

	# After disconnect, signal should not refresh
	DraftManager.drafted_elements.append("water")
	DraftManager.element_drafted.emit("water")

	# Still only fire visible because refresh was not triggered
	assert_int(_count_visible_buttons(_menu)).is_equal(1)


# -- Section 6: Draft indicator display ----------------------------------------

func test_draft_indicator_hidden_when_no_draft() -> void:
	DraftManager.is_draft_active = false

	var towers: Array[TowerData] = [_make_tower_data("Flame Spire", "fire")]
	_inject_towers(_menu, towers)
	_menu._create_buttons()

	var indicator: Control = _menu._draft_indicator
	assert_bool(indicator.visible).is_false()


func test_draft_indicator_visible_when_draft_active() -> void:
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["fire"] as Array[String]

	var towers: Array[TowerData] = [_make_tower_data("Flame Spire", "fire")]
	_inject_towers(_menu, towers)
	_menu._create_buttons()

	var indicator: Control = _menu._draft_indicator
	assert_bool(indicator.visible).is_true()


func test_draft_indicator_shows_drafted_element_colors() -> void:
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["fire", "water"] as Array[String]

	var towers: Array[TowerData] = [_make_tower_data("Flame Spire", "fire")]
	_inject_towers(_menu, towers)
	_menu._create_buttons()

	# The indicator should contain colored icons for each drafted element
	var indicator: Control = _menu._draft_indicator
	# Count ColorRect children (element dots) inside the indicator's HBox
	var dot_count: int = 0
	for child: Node in indicator.get_children():
		if child is HBoxContainer:
			for dot: Node in child.get_children():
				if dot is ColorRect:
					dot_count += 1
	assert_int(dot_count).is_equal(2)


func test_draft_indicator_updates_on_new_element() -> void:
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["fire"] as Array[String]

	var towers: Array[TowerData] = [_make_tower_data("Flame Spire", "fire")]
	_inject_towers(_menu, towers)
	_menu._create_buttons()
	_menu._connect_draft_signals()

	# Initially 1 dot
	var indicator: Control = _menu._draft_indicator
	var _initial_dots: int = _count_indicator_dots(indicator)
	assert_int(_initial_dots).is_equal(1)

	# Draft another element
	DraftManager.drafted_elements.append("ice")
	DraftManager.element_drafted.emit("ice")

	var updated_dots: int = _count_indicator_dots(indicator)
	assert_int(updated_dots).is_equal(2)

	_menu._disconnect_draft_signals()


func _count_indicator_dots(indicator: Control) -> int:
	var count: int = 0
	for child: Node in indicator.get_children():
		if child is HBoxContainer:
			for dot: Node in child.get_children():
				if dot is ColorRect:
					count += 1
	return count


func test_draft_indicator_has_label() -> void:
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["earth"] as Array[String]

	var towers: Array[TowerData] = [_make_tower_data("Stone Bastion", "earth")]
	_inject_towers(_menu, towers)
	_menu._create_buttons()

	var indicator: Control = _menu._draft_indicator
	# Should contain a Label with "Draft:" text
	var has_label: bool = false
	for child: Node in indicator.get_children():
		if child is Label and child.text.begins_with("Draft"):
			has_label = true
	assert_bool(has_label).is_true()


# -- Section 7: Fusion tower filtering ----------------------------------------

func test_fusion_tower_needs_both_elements() -> void:
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["fire"] as Array[String]

	var fusion_elements: Array[String] = ["fire", "earth"]
	var towers: Array[TowerData] = [
		_make_tower_data("Flame Spire", "fire"),
		_make_tower_data("Magma Forge", "fire", 2, fusion_elements),
	]
	_inject_towers(_menu, towers)
	_menu._create_buttons()

	# Only Flame Spire visible, Magma Forge needs earth too
	assert_int(_count_visible_buttons(_menu)).is_equal(1)
	var names: Array[String] = _get_visible_tower_names(_menu)
	assert_array(names).contains(["Flame Spire"])
	assert_array(names).not_contains(["Magma Forge"])


func test_fusion_tower_visible_with_both_elements() -> void:
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["fire", "earth"] as Array[String]

	var fusion_elements: Array[String] = ["fire", "earth"]
	var towers: Array[TowerData] = [
		_make_tower_data("Flame Spire", "fire"),
		_make_tower_data("Stone Bastion", "earth"),
		_make_tower_data("Magma Forge", "fire", 2, fusion_elements),
	]
	_inject_towers(_menu, towers)
	_menu._create_buttons()

	assert_int(_count_visible_buttons(_menu)).is_equal(3)


func test_fusion_tower_no_draft_always_visible() -> void:
	DraftManager.is_draft_active = false

	var fusion_elements: Array[String] = ["fire", "earth"]
	var towers: Array[TowerData] = [
		_make_tower_data("Magma Forge", "fire", 2, fusion_elements),
	]
	_inject_towers(_menu, towers)
	_menu._create_buttons()

	assert_int(_count_visible_buttons(_menu)).is_equal(1)


# -- Section 8: Element group headers visibility follow buttons ----------------

func test_element_header_hidden_when_all_towers_filtered() -> void:
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["fire"] as Array[String]

	var towers: Array[TowerData] = [
		_make_tower_data("Flame Spire", "fire"),
		_make_tower_data("Tidal Obelisk", "water"),
	]
	_inject_towers(_menu, towers)
	_menu._create_buttons()

	# Check that separator/header nodes for water element are hidden
	# The container should have: fire header, fire button, separator, water header, water button
	# Water header and separator before it should be hidden
	var container: HBoxContainer = _menu.button_container
	var fire_visible: bool = false
	var water_header_visible: bool = true  # We expect it to be hidden
	for child: Node in container.get_children():
		if child is VBoxContainer:
			# Element header -- check if it contains a label
			for sub: Node in child.get_children():
				if sub is Label:
					if sub.text == "F":
						fire_visible = child.visible
					elif sub.text == "W":
						water_header_visible = child.visible
	assert_bool(fire_visible).is_true()
	assert_bool(water_header_visible).is_false()


# -- Section 9: Refresh rebuilds button visibility correctly -------------------

func test_refresh_buttons_updates_visibility() -> void:
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["fire"] as Array[String]

	var towers: Array[TowerData] = [
		_make_tower_data("Flame Spire", "fire"),
		_make_tower_data("Tidal Obelisk", "water"),
	]
	_inject_towers(_menu, towers)
	_menu._create_buttons()

	assert_int(_count_visible_buttons(_menu)).is_equal(1)

	# Now add water to drafted
	DraftManager.drafted_elements.append("water")
	_menu._refresh_draft_filter()

	assert_int(_count_visible_buttons(_menu)).is_equal(2)


func test_refresh_hides_newly_unavailable_towers() -> void:
	# Edge case: if draft_elements were somehow reduced (reset scenario)
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["fire", "water"] as Array[String]

	var towers: Array[TowerData] = [
		_make_tower_data("Flame Spire", "fire"),
		_make_tower_data("Tidal Obelisk", "water"),
	]
	_inject_towers(_menu, towers)
	_menu._create_buttons()
	assert_int(_count_visible_buttons(_menu)).is_equal(2)

	# Remove water from drafted
	DraftManager.drafted_elements = ["fire"] as Array[String]
	_menu._refresh_draft_filter()

	assert_int(_count_visible_buttons(_menu)).is_equal(1)


# -- Section 10: Multiple towers per element -----------------------------------

func test_multiple_towers_same_element_all_filtered() -> void:
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["water"] as Array[String]

	var towers: Array[TowerData] = [
		_make_tower_data("Flame Spire", "fire"),
		_make_tower_data("Fire Bolt", "fire"),
		_make_tower_data("Tidal Obelisk", "water"),
		_make_tower_data("Aqua Surge", "water"),
	]
	_inject_towers(_menu, towers)
	_menu._create_buttons()

	assert_int(_count_visible_buttons(_menu)).is_equal(2)
	var names: Array[String] = _get_visible_tower_names(_menu)
	assert_array(names).contains(["Tidal Obelisk"])
	assert_array(names).contains(["Aqua Surge"])
	assert_array(names).not_contains(["Flame Spire"])
	assert_array(names).not_contains(["Fire Bolt"])


# -- Section 11: draft_started signal triggers refresh -------------------------

func test_draft_started_signal_refreshes_buttons() -> void:
	DraftManager.is_draft_active = false

	var towers: Array[TowerData] = [
		_make_tower_data("Flame Spire", "fire"),
		_make_tower_data("Tidal Obelisk", "water"),
		_make_tower_data("Stone Bastion", "earth"),
	]
	_inject_towers(_menu, towers)
	_menu._create_buttons()
	_menu._connect_draft_signals()

	# All visible when draft not active
	assert_int(_count_visible_buttons(_menu)).is_equal(3)

	# Simulate draft starting with fire as starting element
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["fire"] as Array[String]
	DraftManager.draft_started.emit("fire")

	# Now only fire tower visible
	assert_int(_count_visible_buttons(_menu)).is_equal(1)
	var names: Array[String] = _get_visible_tower_names(_menu)
	assert_array(names).contains(["Flame Spire"])

	_menu._disconnect_draft_signals()


# -- Section 12: _process still manages disabled state -------------------------

func test_process_still_disables_unaffordable_towers() -> void:
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["fire", "water"] as Array[String]
	EconomyManager.gold = 0  # Can't afford anything

	var towers: Array[TowerData] = [
		_make_tower_data("Flame Spire", "fire"),
		_make_tower_data("Tidal Obelisk", "water"),
	]
	_inject_towers(_menu, towers)
	_menu._create_buttons()
	_menu._process(0.016)

	# Both visible but disabled
	assert_int(_count_visible_buttons(_menu)).is_equal(2)
	for btn: Button in _menu._tower_buttons:
		assert_bool(btn.disabled).is_true()
