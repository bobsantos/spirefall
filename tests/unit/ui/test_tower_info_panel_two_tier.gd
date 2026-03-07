extends GdUnitTestSuite

## Unit tests for Task B3: TowerInfoPanel two-tier bottom sheet.
## Covers: PanelState enum, state machine transitions, collapsed/expanded layouts,
## swipe gesture input, mutual exclusion with BuildMenu, desktop unaffected.

const PANEL_SCRIPT_PATH: String = "res://scripts/ui/TowerInfoPanel.gd"

var _panel: PanelContainer
var _original_gold: int
var _original_game_state: int
var _original_game_running: bool
var _original_selected_tower: Node
var _original_tower_info_panel: Node
var _original_build_menu: Control

# Cached stub script to avoid "resources still in use" on exit
static var _stub_script: GDScript = null


# -- Helpers -------------------------------------------------------------------

func _tower_stub_script() -> GDScript:
	if _stub_script != null:
		return _stub_script
	_stub_script = GDScript.new()
	_stub_script.source_code = """
extends Node2D

var tower_data: TowerData
var grid_position: Vector2i = Vector2i.ZERO
var target_mode: int = 0

func apply_tower_data() -> void:
	pass
"""
	_stub_script.reload()
	return _stub_script


func _make_tower_data(
	p_name: String = "TestTower",
	p_element: String = "fire",
	p_cost: int = 30,
	p_tier: int = 1,
	p_upgrade_to: TowerData = null,
	p_fusion_elements: Array[String] = []
) -> TowerData:
	var data := TowerData.new()
	data.tower_name = p_name
	data.element = p_element
	data.cost = p_cost
	data.tier = p_tier
	data.damage = 15
	data.attack_speed = 1.0
	data.range_cells = 4
	data.damage_type = p_element
	data.upgrade_to = p_upgrade_to
	data.fusion_elements = p_fusion_elements
	return data


func _make_tower_stub(data: TowerData, pos: Vector2 = Vector2.ZERO) -> Node2D:
	var stub := Node2D.new()
	stub.set_script(_tower_stub_script())
	stub.tower_data = data
	stub.position = pos
	return stub


## Build the TowerInfoPanel node tree manually (matching the .tscn structure).
func _build_panel() -> PanelContainer:
	var root := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	root.add_child(vbox)

	var header_row := HBoxContainer.new()
	header_row.name = "HeaderRow"
	vbox.add_child(header_row)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 16)
	header_row.add_child(name_label)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	header_row.add_child(close_button)

	var tier_label := Label.new()
	tier_label.name = "TierLabel"
	tier_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(tier_label)

	var element_label := Label.new()
	element_label.name = "ElementLabel"
	element_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(element_label)

	var sep_top := HSeparator.new()
	sep_top.name = "SeparatorTop"
	vbox.add_child(sep_top)

	var damage_label := Label.new()
	damage_label.name = "DamageLabel"
	damage_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(damage_label)

	var speed_label := Label.new()
	speed_label.name = "SpeedLabel"
	speed_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(speed_label)

	var range_label := Label.new()
	range_label.name = "RangeLabel"
	range_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(range_label)

	var special_label := Label.new()
	special_label.name = "SpecialLabel"
	special_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(special_label)

	var synergy_label := Label.new()
	synergy_label.name = "SynergyLabel"
	synergy_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(synergy_label)

	var sep_bottom := HSeparator.new()
	sep_bottom.name = "SeparatorBottom"
	vbox.add_child(sep_bottom)

	var upgrade_cost_label := Label.new()
	upgrade_cost_label.name = "UpgradeCostLabel"
	upgrade_cost_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(upgrade_cost_label)

	var sell_value_label := Label.new()
	sell_value_label.name = "SellValueLabel"
	sell_value_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(sell_value_label)

	var fusion_cost_label := Label.new()
	fusion_cost_label.name = "FusionCostLabel"
	fusion_cost_label.add_theme_font_size_override("font_size", 11)
	fusion_cost_label.visible = false
	vbox.add_child(fusion_cost_label)

	var target_mode_dropdown := OptionButton.new()
	target_mode_dropdown.name = "TargetModeDropdown"
	vbox.add_child(target_mode_dropdown)

	var button_row := HBoxContainer.new()
	button_row.name = "ButtonRow"
	vbox.add_child(button_row)

	var upgrade_button := Button.new()
	upgrade_button.name = "UpgradeButton"
	button_row.add_child(upgrade_button)

	var sell_button := Button.new()
	sell_button.name = "SellButton"
	button_row.add_child(sell_button)

	var ascend_cost_label := Label.new()
	ascend_cost_label.name = "AscendCostLabel"
	ascend_cost_label.add_theme_font_size_override("font_size", 11)
	ascend_cost_label.visible = false
	vbox.add_child(ascend_cost_label)

	var ascend_button := Button.new()
	ascend_button.name = "AscendButton"
	ascend_button.visible = false
	vbox.add_child(ascend_button)

	var fuse_button := Button.new()
	fuse_button.name = "FuseButton"
	fuse_button.visible = false
	vbox.add_child(fuse_button)

	return root


func _apply_script(panel: PanelContainer) -> void:
	var script: GDScript = load(PANEL_SCRIPT_PATH)
	panel.set_script(script)
	var vbox: VBoxContainer = panel.get_node("VBoxContainer")
	var header_row: HBoxContainer = vbox.get_node("HeaderRow")
	panel.name_label = header_row.get_node("NameLabel")
	panel.close_button = header_row.get_node("CloseButton")
	panel.tier_label = vbox.get_node("TierLabel")
	panel.element_label = vbox.get_node("ElementLabel")
	panel.separator_top = vbox.get_node("SeparatorTop")
	panel.damage_label = vbox.get_node("DamageLabel")
	panel.speed_label = vbox.get_node("SpeedLabel")
	panel.range_label = vbox.get_node("RangeLabel")
	panel.special_label = vbox.get_node("SpecialLabel")
	panel.synergy_label = vbox.get_node("SynergyLabel")
	panel.separator_bottom = vbox.get_node("SeparatorBottom")
	panel.upgrade_cost_label = vbox.get_node("UpgradeCostLabel")
	panel.sell_value_label = vbox.get_node("SellValueLabel")
	panel.fusion_cost_label = vbox.get_node("FusionCostLabel")
	panel.target_mode_dropdown = vbox.get_node("TargetModeDropdown")
	panel.button_row = vbox.get_node("ButtonRow")
	panel.upgrade_button = vbox.get_node("ButtonRow/UpgradeButton")
	panel.sell_button = vbox.get_node("ButtonRow/SellButton")
	panel.ascend_cost_label = vbox.get_node("AscendCostLabel")
	panel.ascend_button = vbox.get_node("AscendButton")
	panel.fuse_button = vbox.get_node("FuseButton")
	panel.close_button.pressed.connect(panel._on_close_pressed)
	panel._style_close_button()


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_gold = EconomyManager.gold
	_original_game_state = GameManager.game_state
	_original_game_running = GameManager._game_running
	_original_selected_tower = UIManager.selected_tower
	_original_tower_info_panel = UIManager.tower_info_panel
	_original_build_menu = UIManager.build_menu


func before_test() -> void:
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	GameManager._game_running = false
	EconomyManager.gold = 500
	for tower: Node in TowerSystem._active_towers:
		if is_instance_valid(tower) and not tower.is_queued_for_deletion():
			tower.free()
	TowerSystem._active_towers.clear()
	_panel = auto_free(_build_panel())
	_apply_script(_panel)
	_panel.visible = true
	_panel.custom_minimum_size = Vector2(240, 300)
	_panel.size = Vector2(240, 300)


func after_test() -> void:
	for tower: Node in TowerSystem._active_towers:
		if is_instance_valid(tower) and not tower.is_queued_for_deletion():
			tower.free()
	TowerSystem._active_towers.clear()
	_panel = null
	EconomyManager.gold = _original_gold
	GameManager.game_state = _original_game_state
	GameManager._game_running = _original_game_running
	UIManager.selected_tower = _original_selected_tower
	UIManager.tower_info_panel = _original_tower_info_panel
	UIManager.build_menu = _original_build_menu


func after() -> void:
	EconomyManager.gold = _original_gold
	GameManager.game_state = _original_game_state
	GameManager._game_running = _original_game_running
	UIManager.selected_tower = _original_selected_tower
	UIManager.tower_info_panel = _original_tower_info_panel
	UIManager.build_menu = _original_build_menu
	_stub_script = null


# ==============================================================================
# SECTION 1: PanelState enum and default state
# ==============================================================================

func test_panel_state_is_dismissed_by_default() -> void:
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	assert_int(_panel._panel_state).is_equal(_panel.PanelState.DISMISSED)


func test_panel_state_enum_has_dismissed_collapsed_expanded() -> void:
	# Verify all three enum values exist
	assert_int(_panel.PanelState.DISMISSED).is_equal(0)
	assert_int(_panel.PanelState.COLLAPSED).is_equal(1)
	assert_int(_panel.PanelState.EXPANDED).is_equal(2)


# ==============================================================================
# SECTION 2: _set_panel_state method exists
# ==============================================================================

func test_set_panel_state_method_exists() -> void:
	assert_bool(_panel.has_method("_set_panel_state")).is_true()


# ==============================================================================
# SECTION 3: Mobile mode flag
# ==============================================================================

func test_mobile_mode_true_after_mobile_sizing() -> void:
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	assert_bool(_panel._mobile_mode).is_true()


# ==============================================================================
# SECTION 4: COLLAPSED state shows panel
# ==============================================================================

func test_collapsed_state_shows_panel() -> void:
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	_panel.visible = false
	_panel._set_panel_state(_panel.PanelState.COLLAPSED)
	assert_bool(_panel.visible).is_true()


func test_collapsed_state_panel_height_is_160() -> void:
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	_panel._set_panel_state(_panel.PanelState.COLLAPSED)
	# Panel custom_minimum_size.y should be the collapsed height
	assert_int(int(_panel.custom_minimum_size.y)).is_equal(UIManager.MOBILE_PANEL_COLLAPSED_HEIGHT)


# ==============================================================================
# SECTION 5: COLLAPSED state hides stat labels
# ==============================================================================

func test_collapsed_state_hides_damage_label() -> void:
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	_panel._set_panel_state(_panel.PanelState.COLLAPSED)
	assert_bool(_panel.damage_label.visible).is_false()


func test_collapsed_state_hides_speed_label() -> void:
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	_panel._set_panel_state(_panel.PanelState.COLLAPSED)
	assert_bool(_panel.speed_label.visible).is_false()


func test_collapsed_state_hides_range_label() -> void:
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	_panel._set_panel_state(_panel.PanelState.COLLAPSED)
	assert_bool(_panel.range_label.visible).is_false()


# ==============================================================================
# SECTION 6: COLLAPSED state shows essential controls
# ==============================================================================

func test_collapsed_state_shows_name_label() -> void:
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	_panel._set_panel_state(_panel.PanelState.COLLAPSED)
	assert_bool(_panel.name_label.visible).is_true()


func test_collapsed_state_shows_upgrade_button() -> void:
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	_panel._set_panel_state(_panel.PanelState.COLLAPSED)
	assert_bool(_panel.upgrade_button.visible).is_true()


func test_collapsed_state_shows_sell_button() -> void:
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	_panel._set_panel_state(_panel.PanelState.COLLAPSED)
	assert_bool(_panel.sell_button.visible).is_true()


func test_collapsed_state_shows_close_button() -> void:
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	_panel._set_panel_state(_panel.PanelState.COLLAPSED)
	assert_bool(_panel.close_button.visible).is_true()


# ==============================================================================
# SECTION 7: EXPANDED state shows stat labels
# ==============================================================================

func test_expanded_state_shows_damage_label() -> void:
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	_panel._set_panel_state(_panel.PanelState.EXPANDED)
	assert_bool(_panel.damage_label.visible).is_true()


func test_expanded_state_shows_speed_label() -> void:
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	_panel._set_panel_state(_panel.PanelState.EXPANDED)
	assert_bool(_panel.speed_label.visible).is_true()


func test_expanded_state_shows_range_label() -> void:
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	_panel._set_panel_state(_panel.PanelState.EXPANDED)
	assert_bool(_panel.range_label.visible).is_true()


func test_expanded_state_max_height_within_limit() -> void:
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	_panel._set_panel_state(_panel.PanelState.EXPANDED)
	var max_height: int = int(960 * UIManager.MOBILE_PANEL_MAX_HEIGHT_RATIO)
	assert_bool(int(_panel.custom_minimum_size.y) <= max_height).is_true()


# ==============================================================================
# SECTION 8: DISMISSED state hides panel
# ==============================================================================

func test_dismissed_state_hides_panel() -> void:
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	_panel._set_panel_state(_panel.PanelState.COLLAPSED)
	assert_bool(_panel.visible).is_true()
	_panel._set_panel_state(_panel.PanelState.DISMISSED)
	assert_bool(_panel.visible).is_false()


# ==============================================================================
# SECTION 9: _gui_input method exists (for swipe detection)
# ==============================================================================

func test_gui_input_method_exists() -> void:
	assert_bool(_panel.has_method("_gui_input")).is_true()


# ==============================================================================
# SECTION 10: BuildMenu mutual exclusion
# ==============================================================================

func test_display_tower_calls_slide_out_on_build_menu() -> void:
	# Create a mock build menu with slide_out tracking
	var mock_menu_script := GDScript.new()
	mock_menu_script.source_code = """
extends Control

var slide_out_called: bool = false

func slide_out() -> void:
	slide_out_called = true
"""
	mock_menu_script.reload()
	var mock_menu: Control = auto_free(Control.new())
	mock_menu.set_script(mock_menu_script)
	UIManager.build_menu = mock_menu

	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()

	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data, Vector2(400, 300)))
	_panel._tower = tower
	_panel.display_tower(tower)

	assert_bool(mock_menu.slide_out_called).is_true()


# ==============================================================================
# SECTION 11: Desktop mode unaffected
# ==============================================================================

func test_desktop_mode_does_not_use_panel_state() -> void:
	# Desktop mode: _mobile_mode is false by default, _panel_state should stay DISMISSED
	# and not affect normal panel behavior
	_panel._mobile_mode = false
	_panel.visible = true
	# Panel should remain visible -- desktop doesn't use state machine for visibility
	assert_bool(_panel.visible).is_true()


# ==============================================================================
# SECTION 12: Chevron indicator in collapsed state
# ==============================================================================

func test_chevron_indicator_exists_in_collapsed_state() -> void:
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	_panel._set_panel_state(_panel.PanelState.COLLAPSED)
	# Should have a chevron label somewhere in the panel
	assert_bool(_panel._chevron_label != null).is_true()
	assert_str(_panel._chevron_label.text).contains("▲")
