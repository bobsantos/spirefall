extends GdUnitTestSuite

## Unit tests for Task B3: Build menu mobile sizing.
## Covers: tower button sizing, cancel button sizing, panel height, font sizes,
## element dot radius, tower sprite thumbnails, HBoxContainer separation, and
## consolidated _apply_mobile_sizing() method.

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
	## Get the inner HBoxContainer layout from a tower button.
	for child: Node in btn.get_children():
		if child is HBoxContainer:
			return child as HBoxContainer
	return null


func _get_tower_button_name_label(btn: Button) -> Label:
	## Get the name label from a tower button's inner layout.
	var hbox: HBoxContainer = _get_tower_button_hbox(btn)
	if hbox == null:
		return null
	# VBox is second child (after TextureRect)
	for child: Node in hbox.get_children():
		if child is VBoxContainer:
			var vbox: VBoxContainer = child as VBoxContainer
			# First child is name label
			if vbox.get_child_count() > 0 and vbox.get_child(0) is Label:
				return vbox.get_child(0) as Label
	return null


func _get_tower_button_cost_label(btn: Button) -> Label:
	## Get the cost label from a tower button's inner layout.
	var hbox: HBoxContainer = _get_tower_button_hbox(btn)
	if hbox == null:
		return null
	for child: Node in hbox.get_children():
		if child is VBoxContainer:
			var vbox: VBoxContainer = child as VBoxContainer
			# Second child is cost_row HBoxContainer, which contains dot + cost label
			if vbox.get_child_count() > 1 and vbox.get_child(1) is HBoxContainer:
				var cost_row: HBoxContainer = vbox.get_child(1) as HBoxContainer
				for cost_child: Node in cost_row.get_children():
					if cost_child is Label:
						return cost_child as Label
	return null


func _get_tower_button_element_dot(btn: Button) -> ColorRect:
	## Get the element dot ColorRect from a tower button's inner layout.
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
	## Get the TextureRect thumbnail from a tower button's inner layout.
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
	if UIManager.build_requested.is_connected(_menu._on_placement_started):
		UIManager.build_requested.disconnect(_menu._on_placement_started)
	if UIManager.placement_ended.is_connected(_menu._on_placement_ended):
		UIManager.placement_ended.disconnect(_menu._on_placement_ended)

	if is_instance_valid(_menu):
		if _menu.is_inside_tree():
			remove_child(_menu)
		_menu.free()
	_menu = null


# -- Section 1: _apply_mobile_sizing() method exists ---------------------------

func test_apply_mobile_sizing_method_exists() -> void:
	## BuildMenu must have an _apply_mobile_sizing() method.
	assert_bool(_menu.has_method("_apply_mobile_sizing")).is_true()


# -- Section 2: Tower button sizing on mobile ----------------------------------

func test_tower_button_min_size_on_mobile() -> void:
	## After _apply_mobile_sizing(), tower buttons must be at least 150x100.
	_menu._apply_mobile_sizing()
	for btn: Button in _menu._tower_buttons:
		assert_bool(btn.custom_minimum_size.x >= 150.0) \
			.override_failure_message("Tower button width %s < 150" % btn.custom_minimum_size.x) \
			.is_true()
		assert_bool(btn.custom_minimum_size.y >= 100.0) \
			.override_failure_message("Tower button height %s < 100" % btn.custom_minimum_size.y) \
			.is_true()


func test_tower_button_uses_uimanager_constant() -> void:
	## Tower button size should match UIManager.MOBILE_TOWER_BUTTON_MIN.
	_menu._apply_mobile_sizing()
	for btn: Button in _menu._tower_buttons:
		assert_vector(btn.custom_minimum_size).is_equal(UIManager.MOBILE_TOWER_BUTTON_MIN)


# -- Section 3: Cancel button sizing on mobile ---------------------------------

func test_cancel_button_min_size_on_mobile() -> void:
	## After _apply_mobile_sizing(), cancel button must be at least 130x100.
	_menu._apply_mobile_sizing()
	assert_bool(_menu._cancel_button.custom_minimum_size.x >= 130.0) \
		.override_failure_message("Cancel button width %s < 130" % _menu._cancel_button.custom_minimum_size.x) \
		.is_true()
	assert_bool(_menu._cancel_button.custom_minimum_size.y >= 100.0) \
		.override_failure_message("Cancel button height %s < 100" % _menu._cancel_button.custom_minimum_size.y) \
		.is_true()


func test_cancel_button_exact_mobile_size() -> void:
	## Cancel button should be exactly 140x128 on mobile.
	_menu._apply_mobile_sizing()
	assert_vector(_menu._cancel_button.custom_minimum_size).is_equal(Vector2(140, 128))


# -- Section 4: Build menu panel height on mobile ------------------------------

func test_panel_height_on_mobile() -> void:
	## After _apply_mobile_sizing(), custom_minimum_size.y must be at least 140.
	_menu._apply_mobile_sizing()
	assert_bool(_menu.custom_minimum_size.y >= 140.0) \
		.override_failure_message("Panel height %s < 140" % _menu.custom_minimum_size.y) \
		.is_true()


func test_panel_height_uses_uimanager_constant() -> void:
	## Panel height should match UIManager.MOBILE_BUILD_MENU_HEIGHT.
	_menu._apply_mobile_sizing()
	assert_int(int(_menu.custom_minimum_size.y)).is_equal(UIManager.MOBILE_BUILD_MENU_HEIGHT)


func test_panel_position_y_at_bottom_on_mobile() -> void:
	## On mobile (sheet mode), position.y should be at viewport bottom (960).
	_menu._apply_mobile_sizing()
	assert_float(_menu.position.y).is_equal(960.0)


# -- Section 5: Font sizes on mobile ------------------------------------------

func test_tower_name_font_size_on_mobile() -> void:
	## After _apply_mobile_sizing(), tower name labels must have font_size >= 14.
	_menu._apply_mobile_sizing()
	for btn: Button in _menu._tower_buttons:
		var label: Label = _get_tower_button_name_label(btn)
		assert_object(label).is_not_null()
		var font_size: int = label.get_theme_font_size("font_size")
		assert_bool(font_size >= 14) \
			.override_failure_message("Name font size %d < 14" % font_size) \
			.is_true()


func test_tower_cost_font_size_on_mobile() -> void:
	## After _apply_mobile_sizing(), cost labels must have font_size >= 13.
	_menu._apply_mobile_sizing()
	for btn: Button in _menu._tower_buttons:
		var label: Label = _get_tower_button_cost_label(btn)
		assert_object(label).is_not_null()
		var font_size: int = label.get_theme_font_size("font_size")
		assert_bool(font_size >= 13) \
			.override_failure_message("Cost font size %d < 13" % font_size) \
			.is_true()


# -- Section 6: Element dot radius on mobile -----------------------------------

func test_element_dot_diameter_on_mobile() -> void:
	## After _apply_mobile_sizing(), element dots must be at least 16px diameter (radius 8).
	_menu._apply_mobile_sizing()
	for btn: Button in _menu._tower_buttons:
		var dot: ColorRect = _get_tower_button_element_dot(btn)
		assert_object(dot).is_not_null()
		assert_bool(dot.custom_minimum_size.x >= 16.0) \
			.override_failure_message("Dot width %s < 16" % dot.custom_minimum_size.x) \
			.is_true()
		assert_bool(dot.custom_minimum_size.y >= 16.0) \
			.override_failure_message("Dot height %s < 16" % dot.custom_minimum_size.y) \
			.is_true()


# -- Section 7: Tower sprite thumbnail on mobile ------------------------------

func test_tower_thumbnail_size_on_mobile() -> void:
	## After _apply_mobile_sizing(), thumbnails must be at least 40x40.
	_menu._apply_mobile_sizing()
	for btn: Button in _menu._tower_buttons:
		var tex_rect: TextureRect = _get_tower_button_thumbnail(btn)
		assert_object(tex_rect).is_not_null()
		assert_bool(tex_rect.custom_minimum_size.x >= 40.0) \
			.override_failure_message("Thumbnail width %s < 40" % tex_rect.custom_minimum_size.x) \
			.is_true()
		assert_bool(tex_rect.custom_minimum_size.y >= 40.0) \
			.override_failure_message("Thumbnail height %s < 40" % tex_rect.custom_minimum_size.y) \
			.is_true()


# -- Section 8: HBoxContainer separation on mobile ----------------------------

func test_hbox_separation_on_mobile() -> void:
	## After _apply_mobile_sizing(), button_container separation must be 10-12.
	_menu._apply_mobile_sizing()
	var sep: int = _menu.button_container.get_theme_constant("separation")
	assert_bool(sep >= 10) \
		.override_failure_message("HBox separation %d < 10" % sep) \
		.is_true()
	assert_bool(sep <= 12) \
		.override_failure_message("HBox separation %d > 12" % sep) \
		.is_true()


# -- Section 9: All buttons remain functional after mobile sizing --------------

func test_tower_buttons_still_emit_signal_after_mobile_sizing() -> void:
	## Tower selection must still work after _apply_mobile_sizing().
	_menu._apply_mobile_sizing()
	var received_data: Array = [null]
	var callback: Callable = func(td: TowerData) -> void: received_data[0] = td
	_menu.tower_build_selected.connect(callback)

	# Simulate pressing the first tower button (fire tower)
	assert_bool(_menu._tower_buttons.size() > 0).is_true()
	_menu._tower_buttons[0].pressed.emit()

	assert_object(received_data[0]).is_not_null()
	assert_str(received_data[0].element).is_equal("fire")
	_menu.tower_build_selected.disconnect(callback)


func test_cancel_button_still_works_after_mobile_sizing() -> void:
	## Cancel button must still emit placement_cancelled after _apply_mobile_sizing().
	_menu._apply_mobile_sizing()
	var cancelled: Array[bool] = [false]
	var callback: Callable = func() -> void: cancelled[0] = true
	UIManager.placement_cancelled.connect(callback)

	_menu._cancel_button.pressed.emit()

	assert_bool(cancelled[0]).is_true()
	UIManager.placement_cancelled.disconnect(callback)


# -- Section 10: Desktop sizes unchanged when not calling mobile sizing --------

func test_desktop_tower_button_size_unchanged() -> void:
	## Without _apply_mobile_sizing(), tower buttons should keep desktop size.
	# Note: we do NOT call _apply_mobile_sizing() here
	for btn: Button in _menu._tower_buttons:
		if not UIManager.is_mobile():
			assert_vector(btn.custom_minimum_size).is_equal(Vector2(120, 64))


func test_desktop_panel_height_unchanged() -> void:
	## Without _apply_mobile_sizing(), panel height should stay at desktop default.
	if not UIManager.is_mobile():
		# Desktop default: no custom_minimum_size.y override (stays 0)
		assert_float(_menu.custom_minimum_size.y).is_equal(0.0)


# -- Section 11: Draft indicator dot sizing on mobile --------------------------

func test_draft_indicator_dots_sized_on_mobile() -> void:
	## After _apply_mobile_sizing(), draft indicator dots should also be 16px.
	DraftManager.is_draft_active = true
	var typed_elements: Array[String] = ["fire", "water"]
	DraftManager.drafted_elements = typed_elements
	_menu._update_draft_indicator()
	_menu._apply_mobile_sizing()

	# Find dots in the draft indicator
	if _menu._draft_indicator.visible:
		for child: Node in _menu._draft_indicator.get_children():
			if child is HBoxContainer:
				for dot_child: Node in child.get_children():
					if dot_child is ColorRect:
						var dot: ColorRect = dot_child as ColorRect
						assert_bool(dot.custom_minimum_size.x >= 16.0) \
							.override_failure_message("Draft dot width %s < 16" % dot.custom_minimum_size.x) \
							.is_true()

	DraftManager.is_draft_active = false
	DraftManager.drafted_elements.clear()


# -- Section 12: Total layout width fits viewport -----------------------------

func test_total_button_width_fits_viewport() -> void:
	## All 6 tower buttons + cancel + spacing must fit within 1280px.
	_menu._apply_mobile_sizing()
	var total_width: float = 0.0
	# Tower buttons
	for btn: Button in _menu._tower_buttons:
		total_width += btn.custom_minimum_size.x
	# Cancel button
	total_width += _menu._cancel_button.custom_minimum_size.x
	# Spacing between buttons (7 buttons = 6 gaps)
	var sep: int = _menu.button_container.get_theme_constant("separation")
	total_width += sep * 6
	# Left and right margins from ScrollContainer offsets (8px each)
	total_width += 16.0

	assert_bool(total_width <= 1280.0) \
		.override_failure_message("Total button width %.0f > 1280" % total_width) \
		.is_true()
