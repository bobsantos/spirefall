extends GdUnitTestSuite

## Unit tests for Task D2: TowerInfoPanel mobile sizing.
## Covers: action button heights, dropdown height, label font sizes,
## panel min width, and full-width bottom-dock layout on mobile.

const PANEL_SCRIPT_PATH: String = "res://scripts/ui/TowerInfoPanel.gd"

var _panel: PanelContainer
var _original_gold: int
var _original_game_state: int
var _original_game_running: bool
var _original_selected_tower: Node
var _original_tower_info_panel: Node

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


func after() -> void:
	EconomyManager.gold = _original_gold
	GameManager.game_state = _original_game_state
	GameManager._game_running = _original_game_running
	UIManager.selected_tower = _original_selected_tower
	UIManager.tower_info_panel = _original_tower_info_panel
	_stub_script = null


# ==============================================================================
# SECTION 1: Action buttons meet 56px minimum height on mobile
# ==============================================================================

func test_upgrade_button_height_at_least_56_after_mobile_sizing() -> void:
	_panel._apply_mobile_sizing()
	assert_bool(_panel.upgrade_button.custom_minimum_size.y >= 56.0).is_true()


func test_sell_button_height_at_least_56_after_mobile_sizing() -> void:
	_panel._apply_mobile_sizing()
	assert_bool(_panel.sell_button.custom_minimum_size.y >= 56.0).is_true()


func test_ascend_button_height_at_least_56_after_mobile_sizing() -> void:
	_panel._apply_mobile_sizing()
	assert_bool(_panel.ascend_button.custom_minimum_size.y >= 56.0).is_true()


func test_fuse_button_height_at_least_56_after_mobile_sizing() -> void:
	_panel._apply_mobile_sizing()
	assert_bool(_panel.fuse_button.custom_minimum_size.y >= 56.0).is_true()


# ==============================================================================
# SECTION 2: Target mode dropdown meets 56px minimum height on mobile
# ==============================================================================

func test_target_dropdown_height_at_least_56_after_mobile_sizing() -> void:
	_panel._apply_mobile_sizing()
	assert_bool(_panel.target_mode_dropdown.custom_minimum_size.y >= 56.0).is_true()


# ==============================================================================
# SECTION 3: All label font sizes >= 16 on mobile
# ==============================================================================

func test_tier_label_font_size_at_least_16_after_mobile_sizing() -> void:
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.tier_label.get_theme_font_size("font_size")
	assert_bool(font_size >= 16).is_true()


func test_element_label_font_size_at_least_16_after_mobile_sizing() -> void:
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.element_label.get_theme_font_size("font_size")
	assert_bool(font_size >= 16).is_true()


func test_damage_label_font_size_at_least_16_after_mobile_sizing() -> void:
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.damage_label.get_theme_font_size("font_size")
	assert_bool(font_size >= 16).is_true()


func test_speed_label_font_size_at_least_16_after_mobile_sizing() -> void:
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.speed_label.get_theme_font_size("font_size")
	assert_bool(font_size >= 16).is_true()


func test_range_label_font_size_at_least_16_after_mobile_sizing() -> void:
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.range_label.get_theme_font_size("font_size")
	assert_bool(font_size >= 16).is_true()


func test_special_label_font_size_at_least_16_after_mobile_sizing() -> void:
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.special_label.get_theme_font_size("font_size")
	assert_bool(font_size >= 16).is_true()


func test_synergy_label_font_size_at_least_16_after_mobile_sizing() -> void:
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.synergy_label.get_theme_font_size("font_size")
	assert_bool(font_size >= 16).is_true()


func test_upgrade_cost_label_font_size_at_least_16_after_mobile_sizing() -> void:
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.upgrade_cost_label.get_theme_font_size("font_size")
	assert_bool(font_size >= 16).is_true()


func test_sell_value_label_font_size_at_least_16_after_mobile_sizing() -> void:
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.sell_value_label.get_theme_font_size("font_size")
	assert_bool(font_size >= 16).is_true()


func test_fusion_cost_label_font_size_at_least_16_after_mobile_sizing() -> void:
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.fusion_cost_label.get_theme_font_size("font_size")
	assert_bool(font_size >= 16).is_true()


func test_ascend_cost_label_font_size_at_least_16_after_mobile_sizing() -> void:
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.ascend_cost_label.get_theme_font_size("font_size")
	assert_bool(font_size >= 16).is_true()


func test_name_label_font_size_at_least_16_after_mobile_sizing() -> void:
	# NameLabel is already 16 in the .tscn but verify it is not reduced
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.name_label.get_theme_font_size("font_size")
	assert_bool(font_size >= 16).is_true()


# ==============================================================================
# SECTION 4: Panel minimum width increased on mobile
# ==============================================================================

func test_panel_min_width_at_least_300_after_mobile_sizing() -> void:
	_panel._apply_mobile_sizing()
	assert_bool(_panel.custom_minimum_size.x >= 300.0).is_true()


func test_panel_min_width_unchanged_without_mobile_sizing() -> void:
	# Without calling _apply_mobile_sizing, panel should retain original 240
	assert_float(_panel.custom_minimum_size.x).is_equal_approx(240.0, 1.0)


# ==============================================================================
# SECTION 5: Bottom-dock spans full width minus margins on mobile
# ==============================================================================

func test_mobile_reposition_spans_full_width_minus_margins() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data, Vector2(400, 300)))
	_panel._tower = tower
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	_panel.visible = true
	_panel._reposition_mobile()
	# Panel width should be viewport width - 2 * PANEL_MARGIN
	var expected_width: float = 1280.0 - 2.0 * _panel.PANEL_MARGIN
	assert_float(_panel.custom_minimum_size.x).is_equal_approx(expected_width, 2.0)


func test_mobile_reposition_x_at_margin() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data, Vector2(400, 300)))
	_panel._tower = tower
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	_panel.visible = true
	_panel._reposition_mobile()
	# x should be at PANEL_MARGIN (left edge with margin)
	assert_float(_panel.position.x).is_equal_approx(_panel.PANEL_MARGIN, 2.0)


# ==============================================================================
# SECTION 6: Desktop mode is unaffected
# ==============================================================================

func test_desktop_buttons_retain_original_min_height() -> void:
	# Without _apply_mobile_sizing, buttons should have their default min height
	assert_float(_panel.upgrade_button.custom_minimum_size.y).is_less(56.0)
	assert_float(_panel.sell_button.custom_minimum_size.y).is_less(56.0)


func test_desktop_labels_retain_original_font_sizes() -> void:
	# Without _apply_mobile_sizing, labels should keep their .tscn font sizes (11 or 12)
	var font_size: int = _panel.tier_label.get_theme_font_size("font_size")
	assert_int(font_size).is_equal(11)


func test_desktop_panel_min_width_is_240() -> void:
	assert_float(_panel.custom_minimum_size.x).is_equal_approx(240.0, 1.0)
