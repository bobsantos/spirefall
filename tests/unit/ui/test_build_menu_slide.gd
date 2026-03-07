extends GdUnitTestSuite

## Unit tests for Task B2: BuildMenu bottom sheet slide behavior.
## Covers: _sheet_mode flag, slide_in/slide_out methods, mobile sizing bumps,
## drag handle, and auto-dismiss on tower selection.

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


func _apply_script_with_towers(node: Control) -> void:
	## Apply the BuildMenu script, set @onready vars, inject towers, and create UI.
	node.set_script(load(BUILD_MENU_SCRIPT_PATH))
	node.button_container = node.get_node("ScrollContainer/HBoxContainer")

	# Inject tower data directly, bypassing file loading
	node._available_towers.clear()
	var elements: Array[String] = ["fire", "water", "earth", "wind", "lightning", "ice"]
	var names: Array[String] = ["Flame Spire", "Tidal Obelisk", "Stone Bastion", "Gale Tower", "Thunder Pylon", "Frost Sentinel"]
	for i: int in range(elements.size()):
		node._available_towers.append(_make_tower_data(names[i], elements[i]))

	node._create_draft_indicator()
	node._create_buttons()
	node._create_cancel_button()


func _get_tower_button_hbox(btn: Button) -> HBoxContainer:
	for child: Node in btn.get_children():
		if child is HBoxContainer:
			return child as HBoxContainer
	return null


func _get_tower_button_name_label(btn: Button) -> Label:
	var hbox: HBoxContainer = _get_tower_button_hbox(btn)
	if hbox == null:
		return null
	for child: Node in hbox.get_children():
		if child is VBoxContainer:
			var vbox: VBoxContainer = child as VBoxContainer
			if vbox.get_child_count() > 0 and vbox.get_child(0) is Label:
				return vbox.get_child(0) as Label
	return null


func _get_tower_button_cost_label(btn: Button) -> Label:
	var hbox: HBoxContainer = _get_tower_button_hbox(btn)
	if hbox == null:
		return null
	for child: Node in hbox.get_children():
		if child is VBoxContainer:
			var vbox: VBoxContainer = child as VBoxContainer
			if vbox.get_child_count() > 1 and vbox.get_child(1) is HBoxContainer:
				var cost_row: HBoxContainer = vbox.get_child(1) as HBoxContainer
				for cost_child: Node in cost_row.get_children():
					if cost_child is Label:
						return cost_child as Label
	return null


func _get_tower_button_element_dot(btn: Button) -> ColorRect:
	var hbox: HBoxContainer = _get_tower_button_hbox(btn)
	if hbox == null:
		return null
	for child: Node in hbox.get_children():
		if child is VBoxContainer:
			var vbox: VBoxContainer = child as VBoxContainer
			if vbox.get_child_count() > 1 and vbox.get_child(1) is HBoxContainer:
				var cost_row: HBoxContainer = vbox.get_child(1) as HBoxContainer
				for cost_child: Node in cost_row.get_children():
					if cost_child is ColorRect:
						return cost_child as ColorRect
	return null


func _get_tower_button_thumbnail(btn: Button) -> TextureRect:
	var hbox: HBoxContainer = _get_tower_button_hbox(btn)
	if hbox == null:
		return null
	for child: Node in hbox.get_children():
		if child is TextureRect:
			return child as TextureRect
	return null


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_original_gold = EconomyManager.gold
	EconomyManager.gold = 9999
	DraftManager.is_draft_active = false
	DraftManager.drafted_elements.clear()

	_menu = _build_menu_node()
	add_child(_menu)
	_apply_script_with_towers(_menu)


func after_test() -> void:
	EconomyManager.gold = _original_gold
	UIManager.build_menu = null

	# Disconnect signals to avoid leaks
	if is_instance_valid(_menu):
		if UIManager.build_requested.is_connected(_menu._on_placement_started):
			UIManager.build_requested.disconnect(_menu._on_placement_started)
		if UIManager.placement_ended.is_connected(_menu._on_placement_ended):
			UIManager.placement_ended.disconnect(_menu._on_placement_ended)

		if _menu.is_inside_tree():
			remove_child(_menu)
		_menu.free()
	_menu = null


# -- Section 1: _sheet_mode defaults -------------------------------------------

func test_sheet_mode_false_by_default() -> void:
	## _sheet_mode should be false on desktop (no mobile sizing applied).
	assert_bool(_menu._sheet_mode).is_false()


func test_is_sheet_visible_false_by_default() -> void:
	## _is_sheet_visible should be false initially.
	assert_bool(_menu._is_sheet_visible).is_false()


# -- Section 2: _apply_mobile_sizing sets sheet mode ---------------------------

func test_sheet_mode_true_after_mobile_sizing() -> void:
	## After _apply_mobile_sizing(), _sheet_mode should be true.
	_menu._apply_mobile_sizing()
	assert_bool(_menu._sheet_mode).is_true()


func test_is_sheet_visible_false_after_mobile_sizing() -> void:
	## After _apply_mobile_sizing(), _is_sheet_visible should remain false.
	_menu._apply_mobile_sizing()
	assert_bool(_menu._is_sheet_visible).is_false()


func test_position_y_at_viewport_bottom_after_mobile_sizing() -> void:
	## After _apply_mobile_sizing(), position.y should be at or beyond 960 (viewport bottom).
	_menu._apply_mobile_sizing()
	assert_bool(_menu.position.y >= 960.0) \
		.override_failure_message("position.y %s < 960" % _menu.position.y) \
		.is_true()


# -- Section 3: slide_in / slide_out methods exist -----------------------------

func test_slide_in_method_exists() -> void:
	## BuildMenu must have a slide_in() method.
	assert_bool(_menu.has_method("slide_in")).is_true()


func test_slide_out_method_exists() -> void:
	## BuildMenu must have a slide_out() method.
	assert_bool(_menu.has_method("slide_out")).is_true()


# -- Section 4: slide_in / slide_out behavior ----------------------------------

func test_slide_in_sets_is_sheet_visible_true() -> void:
	## Calling slide_in() should set _is_sheet_visible to true.
	_menu._apply_mobile_sizing()
	_menu.slide_in()
	assert_bool(_menu._is_sheet_visible).is_true()


func test_slide_in_sets_visible_true() -> void:
	## Calling slide_in() should set visible to true.
	_menu._apply_mobile_sizing()
	_menu.visible = false
	_menu.slide_in()
	assert_bool(_menu.visible).is_true()


func test_slide_out_sets_is_sheet_visible_false() -> void:
	## Calling slide_out() should set _is_sheet_visible to false.
	_menu._apply_mobile_sizing()
	_menu.slide_in()
	_menu.slide_out()
	# _is_sheet_visible is set to false immediately on slide_out (not after tween)
	# because the tween callback may not fire in tests. The flag should still
	# be set to false at the start or upon completion.
	# We test the immediate state - slide_out sets _is_sheet_visible = false.
	assert_bool(_menu._is_sheet_visible).is_false()


# -- Section 5: Mobile sizing bumps -------------------------------------------

func test_thumbnail_48x48_on_mobile() -> void:
	## After _apply_mobile_sizing(), tower thumbnails should be 48x48.
	_menu._apply_mobile_sizing()
	for btn: Button in _menu._tower_buttons:
		var tex_rect: TextureRect = _get_tower_button_thumbnail(btn)
		assert_object(tex_rect).is_not_null()
		assert_vector(tex_rect.custom_minimum_size).is_equal(Vector2(48, 48))


func test_element_dots_20px_on_mobile() -> void:
	## After _apply_mobile_sizing(), element dots should be 20x20 (diameter 20).
	_menu._apply_mobile_sizing()
	for btn: Button in _menu._tower_buttons:
		var dot: ColorRect = _get_tower_button_element_dot(btn)
		assert_object(dot).is_not_null()
		assert_vector(dot.custom_minimum_size).is_equal(Vector2(20, 20))


func test_cancel_button_140x128_on_mobile() -> void:
	## After _apply_mobile_sizing(), cancel button should be 140x128.
	_menu._apply_mobile_sizing()
	assert_vector(_menu._cancel_button.custom_minimum_size).is_equal(Vector2(140, 128))


func test_name_font_size_20_on_mobile() -> void:
	## After _apply_mobile_sizing(), tower name labels should have font_size 20.
	_menu._apply_mobile_sizing()
	for btn: Button in _menu._tower_buttons:
		var label: Label = _get_tower_button_name_label(btn)
		assert_object(label).is_not_null()
		var font_size: int = label.get_theme_font_size("font_size")
		assert_int(font_size).is_equal(20)


func test_cost_font_size_18_on_mobile() -> void:
	## After _apply_mobile_sizing(), cost labels should have font_size 18.
	_menu._apply_mobile_sizing()
	for btn: Button in _menu._tower_buttons:
		var label: Label = _get_tower_button_cost_label(btn)
		assert_object(label).is_not_null()
		var font_size: int = label.get_theme_font_size("font_size")
		assert_int(font_size).is_equal(18)


func test_hbox_separation_12_on_mobile() -> void:
	## After _apply_mobile_sizing(), button_container separation should be 12.
	_menu._apply_mobile_sizing()
	var sep: int = _menu.button_container.get_theme_constant("separation")
	assert_int(sep).is_equal(12)


# -- Section 6: Drag handle ---------------------------------------------------

func test_drag_handle_exists_after_mobile_sizing() -> void:
	## After _apply_mobile_sizing(), a drag handle ColorRect should exist in the menu.
	_menu._apply_mobile_sizing()
	var found_handle: bool = false
	for child: Node in _menu.get_children():
		if child is ColorRect and child.custom_minimum_size == Vector2(40, 4):
			found_handle = true
			break
	assert_bool(found_handle) \
		.override_failure_message("No drag handle (40x4 ColorRect) found in menu children") \
		.is_true()


func test_drag_handle_color() -> void:
	## The drag handle should have a grey color (#666666).
	_menu._apply_mobile_sizing()
	for child: Node in _menu.get_children():
		if child is ColorRect and child.custom_minimum_size == Vector2(40, 4):
			# Check the color is approximately #666666 (0.4, 0.4, 0.4)
			assert_bool(child.color.r > 0.35 and child.color.r < 0.45) \
				.override_failure_message("Drag handle color.r = %s, expected ~0.4" % child.color.r) \
				.is_true()
			break
