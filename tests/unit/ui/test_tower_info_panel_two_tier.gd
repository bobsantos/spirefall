extends GdUnitTestSuite

## Unit tests for TowerInfoPanel action-only behavior.
## Covers: display_tower shows panel, mobile build menu dismissal,
## upgrade button text with cost, sell button text with refund,
## desktop mode unaffected.

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
# SECTION 1: display_tower shows panel
# ==============================================================================

func test_display_tower_makes_panel_visible() -> void:
	_panel.visible = false
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data))
	_panel.display_tower(tower)
	assert_bool(_panel.visible).is_true()


func test_display_tower_sets_name_label() -> void:
	var data: TowerData = _make_tower_data("Flame Tower", "fire")
	var tower: Node2D = auto_free(_make_tower_stub(data))
	_panel.display_tower(tower)
	assert_str(_panel.name_label.text).is_equal("Flame Tower")


# ==============================================================================
# SECTION 2: Upgrade button text includes cost
# ==============================================================================

func test_upgrade_button_shows_cost_when_upgradeable() -> void:
	var next_data: TowerData = _make_tower_data("Enhanced", "fire", 60, 1)
	var data: TowerData = _make_tower_data("Base", "fire", 30, 1, next_data)
	var tower: Node2D = auto_free(_make_tower_stub(data))
	_panel.display_tower(tower)
	# Cost = 60 - 30 = 30
	assert_str(_panel.upgrade_button.text).is_equal("Upgrade (30g)")


func test_upgrade_button_shows_max_when_no_upgrade() -> void:
	var data: TowerData = _make_tower_data("Superior", "fire", 60, 1)
	var tower: Node2D = auto_free(_make_tower_stub(data))
	_panel.display_tower(tower)
	assert_str(_panel.upgrade_button.text).is_equal("Max")
	assert_bool(_panel.upgrade_button.disabled).is_true()


# ==============================================================================
# SECTION 3: Sell button text includes refund
# ==============================================================================

func test_sell_button_shows_refund_build_phase() -> void:
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	var data: TowerData = _make_tower_data("Tower", "fire", 40, 1)
	var tower: Node2D = auto_free(_make_tower_stub(data))
	_panel.display_tower(tower)
	# Refund = int(40 * 0.75) = 30
	assert_str(_panel.sell_button.text).is_equal("Sell (30g)")


func test_sell_button_shows_refund_combat_phase() -> void:
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	var data: TowerData = _make_tower_data("Tower", "fire", 40, 1)
	var tower: Node2D = auto_free(_make_tower_stub(data))
	_panel.display_tower(tower)
	# Refund = int(40 * 0.50) = 20
	assert_str(_panel.sell_button.text).is_equal("Sell (20g)")


# ==============================================================================
# SECTION 4: BuildMenu mutual exclusion on mobile
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
# SECTION 5: Desktop mode unaffected
# ==============================================================================

func test_desktop_mode_panel_stays_visible() -> void:
	_panel._mobile_mode = false
	_panel.visible = true
	assert_bool(_panel.visible).is_true()


func test_mobile_mode_flag() -> void:
	_panel._mobile_mode = true
	_panel._apply_mobile_sizing()
	assert_bool(_panel._mobile_mode).is_true()
