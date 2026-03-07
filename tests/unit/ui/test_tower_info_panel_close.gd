extends GdUnitTestSuite

## Unit tests for TowerInfoPanel close button and mobile bottom-docking.
## Covers: close button existence, press calls deselect_tower, mobile min size,
## mobile bottom-dock positioning, close button styling distinct from action buttons.

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
	header_row.add_child(name_label)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	header_row.add_child(close_button)

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
	panel.target_mode_dropdown = vbox.get_node("TargetModeDropdown")
	panel.button_row = vbox.get_node("ButtonRow")
	panel.upgrade_button = vbox.get_node("ButtonRow/UpgradeButton")
	panel.sell_button = vbox.get_node("ButtonRow/SellButton")
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
# SECTION 1: Close button exists in panel
# ==============================================================================

func test_close_button_exists_as_child_of_header_row() -> void:
	var vbox: VBoxContainer = _panel.get_node("VBoxContainer")
	var header_row: HBoxContainer = vbox.get_node("HeaderRow")
	assert_that(header_row).is_not_null()
	var close_btn: Button = header_row.get_node("CloseButton")
	assert_that(close_btn).is_not_null()
	assert_str(close_btn.text).is_equal("X")


func test_name_label_is_in_header_row() -> void:
	var vbox: VBoxContainer = _panel.get_node("VBoxContainer")
	var header_row: HBoxContainer = vbox.get_node("HeaderRow")
	var name_label: Label = header_row.get_node("NameLabel")
	assert_that(name_label).is_not_null()
	assert_bool(name_label.size_flags_horizontal & Control.SIZE_EXPAND_FILL != 0).is_true()


func test_close_button_has_text_x() -> void:
	assert_str(_panel.close_button.text).is_equal("X")


# ==============================================================================
# SECTION 2: Close button calls UIManager.deselect_tower()
# ==============================================================================

func test_close_button_press_calls_deselect_tower() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data))
	UIManager.selected_tower = tower
	UIManager.tower_info_panel = _panel
	_panel._tower = tower
	_panel.visible = true
	_panel.close_button.pressed.emit()
	assert_that(UIManager.selected_tower).is_null()


func test_close_button_press_hides_panel() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data))
	UIManager.selected_tower = tower
	UIManager.tower_info_panel = _panel
	_panel._tower = tower
	_panel.visible = true
	_panel.close_button.pressed.emit()
	assert_bool(_panel.visible).is_false()


func test_close_button_emits_tower_deselected_signal() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data))
	UIManager.selected_tower = tower
	UIManager.tower_info_panel = _panel
	_panel._tower = tower
	_panel.visible = true
	var signal_count: Array[int] = [0]
	var conn: Callable = func() -> void: signal_count[0] += 1
	UIManager.tower_deselected.connect(conn)
	_panel.close_button.pressed.emit()
	UIManager.tower_deselected.disconnect(conn)
	assert_int(signal_count[0]).is_equal(1)


# ==============================================================================
# SECTION 3: Close button mobile sizing
# ==============================================================================

func test_close_button_desktop_size() -> void:
	var close_btn: Button = _panel.close_button
	assert_float(close_btn.custom_minimum_size.x).is_equal_approx(28.0, 1.0)
	assert_float(close_btn.custom_minimum_size.y).is_equal_approx(28.0, 1.0)


func test_apply_mobile_sizing_sets_close_button_min_size() -> void:
	_panel._apply_mobile_sizing()
	var close_btn: Button = _panel.close_button
	assert_bool(close_btn.custom_minimum_size.x >= 64.0).is_true()
	assert_bool(close_btn.custom_minimum_size.y >= 64.0).is_true()


# ==============================================================================
# SECTION 4: Mobile bottom-dock positioning
# ==============================================================================

func test_mobile_reposition_docks_at_bottom() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data, Vector2(400, 300)))
	_panel._tower = tower
	_panel.visible = true
	_panel._reposition_mobile()
	var expected_y: float = 960.0 - _panel.size.y - _panel.PANEL_MARGIN
	assert_float(_panel.position.y).is_equal_approx(expected_y, 2.0)


func test_mobile_reposition_centers_horizontally() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data, Vector2(400, 300)))
	_panel._tower = tower
	_panel.visible = true
	_panel._reposition_mobile()
	var expected_x: float = (1280.0 - _panel.size.x) / 2.0
	assert_float(_panel.position.x).is_equal_approx(expected_x, 2.0)


func test_reposition_uses_mobile_path_when_mobile() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data, Vector2(400, 300)))
	_panel._tower = tower
	_panel.visible = true
	_panel._mobile_mode = true
	_panel._reposition()
	var expected_y: float = 960.0 - _panel.size.y - _panel.PANEL_MARGIN
	assert_float(_panel.position.y).is_equal_approx(expected_y, 2.0)


# ==============================================================================
# SECTION 5: Close button style does not compete with action buttons
# ==============================================================================

func test_close_button_has_neutral_style() -> void:
	var close_btn: Button = _panel.close_button
	assert_bool(close_btn.has_theme_stylebox_override("normal")).is_true()
	var style: StyleBox = close_btn.get_theme_stylebox("normal")
	assert_that(style).is_not_null()
	assert_bool(style is StyleBoxFlat).is_true()


func test_close_button_style_differs_from_upgrade_button() -> void:
	var close_btn: Button = _panel.close_button
	assert_bool(close_btn.has_theme_stylebox_override("normal")).is_true()
	var close_style: StyleBoxFlat = close_btn.get_theme_stylebox("normal") as StyleBoxFlat
	assert_that(close_style).is_not_null()
	assert_bool(close_style.bg_color.r < 0.5 and close_style.bg_color.g < 0.5 and close_style.bg_color.b < 0.5).is_true()


func test_close_button_focus_mode_is_none() -> void:
	assert_int(_panel.close_button.focus_mode).is_equal(Control.FOCUS_NONE)


# ==============================================================================
# SECTION 6: Display tower still works with header layout
# ==============================================================================

func test_display_tower_sets_name_in_header() -> void:
	var data: TowerData = _make_tower_data("Flame Tower", "fire")
	var tower: Node2D = auto_free(_make_tower_stub(data))
	_panel.display_tower(tower)
	assert_str(_panel.name_label.text).is_equal("Flame Tower")


func test_display_tower_positions_panel() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data, Vector2(500, 400)))
	_panel.position = Vector2.ZERO
	_panel.display_tower(tower)
	assert_bool(_panel._last_screen_pos != Vector2.ZERO).is_true()
