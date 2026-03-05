extends GdUnitTestSuite

## Unit tests for BuildMenu cancel button during tower placement.
## Covers: button creation, visibility on placement start/end, cancel signal chain.

const BUILD_MENU_SCRIPT_PATH: String = "res://scripts/ui/BuildMenu.gd"

var _menu: Control
var _original_gold: int


# -- Helpers -------------------------------------------------------------------

func _make_tower_data(tower_name: String = "Flame Spire", element: String = "fire") -> TowerData:
	var td := TowerData.new()
	td.tower_name = tower_name
	td.element = element
	td.tier = 1
	td.cost = 30
	td.damage = 10
	td.attack_speed = 1.0
	td.range_cells = 3
	td.damage_type = element
	td.special_description = ""
	return td


func _build_menu_node() -> Control:
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
	node.set_script(load(BUILD_MENU_SCRIPT_PATH))
	node.button_container = node.get_node("ScrollContainer/HBoxContainer")
	node._create_draft_indicator()
	node._create_cancel_button()


func _inject_towers(menu: Control, towers: Array[TowerData]) -> void:
	menu._available_towers.clear()
	for td: TowerData in towers:
		menu._available_towers.append(td)


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_original_gold = EconomyManager.gold
	EconomyManager.gold = 9999
	DraftManager.is_draft_active = false
	DraftManager.drafted_elements.clear()

	_menu = _build_menu_node()
	add_child(_menu)
	_apply_script(_menu)


func after_test() -> void:
	EconomyManager.gold = _original_gold
	UIManager.build_menu = null

	# Disconnect signals to avoid leaks
	if UIManager.build_requested.is_connected(_menu._on_placement_started):
		UIManager.build_requested.disconnect(_menu._on_placement_started)
	if UIManager.placement_ended.is_connected(_menu._on_placement_ended):
		UIManager.placement_ended.disconnect(_menu._on_placement_ended)

	if is_instance_valid(_menu):
		if _menu.is_inside_tree():
			remove_child(_menu)
		_menu.free()
	_menu = null


# -- Section 1: Cancel button exists ------------------------------------------

func test_cancel_button_created() -> void:
	assert_object(_menu._cancel_button).is_not_null()


func test_cancel_button_is_in_container() -> void:
	assert_bool(_menu._cancel_button.get_parent() == _menu.button_container).is_true()


func test_cancel_button_text() -> void:
	assert_str(_menu._cancel_button.text).is_equal("X Cancel")


func test_cancel_button_hidden_by_default() -> void:
	assert_bool(_menu._cancel_button.visible).is_false()


func test_cancel_button_is_first_child() -> void:
	assert_int(_menu._cancel_button.get_index()).is_equal(0)


# -- Section 2: Cancel button visibility on placement state --------------------

func test_cancel_button_shows_on_placement_start() -> void:
	_menu._on_placement_started(_make_tower_data())
	assert_bool(_menu._cancel_button.visible).is_true()


func test_cancel_button_hides_on_placement_end() -> void:
	_menu._on_placement_started(_make_tower_data())
	assert_bool(_menu._cancel_button.visible).is_true()
	_menu._on_placement_ended()
	assert_bool(_menu._cancel_button.visible).is_false()


func test_cancel_button_shows_and_hides_cycle() -> void:
	# First placement
	_menu._on_placement_started(_make_tower_data())
	assert_bool(_menu._cancel_button.visible).is_true()
	_menu._on_placement_ended()
	assert_bool(_menu._cancel_button.visible).is_false()
	# Second placement
	_menu._on_placement_started(_make_tower_data("Tidal Obelisk", "water"))
	assert_bool(_menu._cancel_button.visible).is_true()
	_menu._on_placement_ended()
	assert_bool(_menu._cancel_button.visible).is_false()


# -- Section 3: Signal integration --------------------------------------------

func test_build_requested_signal_shows_cancel() -> void:
	UIManager.build_requested.connect(_menu._on_placement_started)
	UIManager.build_requested.emit(_make_tower_data())
	assert_bool(_menu._cancel_button.visible).is_true()
	UIManager.build_requested.disconnect(_menu._on_placement_started)


func test_placement_ended_signal_hides_cancel() -> void:
	UIManager.placement_ended.connect(_menu._on_placement_ended)
	_menu._cancel_button.visible = true
	UIManager.placement_ended.emit()
	assert_bool(_menu._cancel_button.visible).is_false()
	UIManager.placement_ended.disconnect(_menu._on_placement_ended)


func test_cancel_placement_emits_signal() -> void:
	var received: Array[bool] = [false]
	var callback: Callable = func() -> void: received[0] = true
	UIManager.placement_cancelled.connect(callback)
	UIManager.cancel_placement()
	assert_bool(received[0]).is_true()
	UIManager.placement_cancelled.disconnect(callback)


# -- Section 4: Cancel button styling -----------------------------------------

func test_cancel_button_has_red_style() -> void:
	var style: StyleBoxFlat = _menu._cancel_button.get_theme_stylebox("normal") as StyleBoxFlat
	assert_object(style).is_not_null()
	# Red-tinted background: R channel should be dominant
	assert_float(style.bg_color.r).is_greater(style.bg_color.g)
	assert_float(style.bg_color.r).is_greater(style.bg_color.b)


func test_cancel_button_has_hover_style() -> void:
	var style: StyleBoxFlat = _menu._cancel_button.get_theme_stylebox("hover") as StyleBoxFlat
	assert_object(style).is_not_null()


func test_cancel_button_has_pressed_style() -> void:
	var style: StyleBoxFlat = _menu._cancel_button.get_theme_stylebox("pressed") as StyleBoxFlat
	assert_object(style).is_not_null()


# -- Section 5: Mobile sizing -------------------------------------------------

func test_cancel_button_minimum_size_desktop() -> void:
	# On desktop (non-mobile), minimum size should be 80x64
	if not UIManager.is_mobile():
		assert_vector(_menu._cancel_button.custom_minimum_size).is_equal(Vector2(80, 64))


func test_cancel_button_focus_mode_none() -> void:
	assert_int(_menu._cancel_button.focus_mode).is_equal(Control.FOCUS_NONE)
