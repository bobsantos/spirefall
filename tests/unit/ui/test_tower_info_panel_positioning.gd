extends GdUnitTestSuite

## Unit tests for TowerInfoPanel dynamic positioning near selected tower.
## Covers: right-of-tower placement, left-flip near edge, viewport clamping,
## reposition on display_tower, reposition on camera move, no overlap with tower.

const PANEL_SCRIPT_PATH: String = "res://scripts/ui/TowerInfoPanel.gd"

var _panel: PanelContainer
var _original_gold: int
var _original_game_state: int
var _original_game_running: bool

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


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_gold = EconomyManager.gold
	_original_game_state = GameManager.game_state
	_original_game_running = GameManager._game_running


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


func after() -> void:
	EconomyManager.gold = _original_gold
	GameManager.game_state = _original_game_state
	GameManager._game_running = _original_game_running
	_stub_script = null


# ==============================================================================
# SECTION 1: Panel placed to right of tower
# ==============================================================================

func test_reposition_places_panel_right_of_tower() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data))
	_panel._tower = tower
	_panel._reposition_at(Vector2(640, 480))
	assert_float(_panel.position.x).is_equal_approx(640.0 + _panel.TOWER_OFFSET, 1.0)
	var expected_y: float = 480.0 - _panel.size.y * 0.5
	assert_float(_panel.position.y).is_equal_approx(expected_y, 1.0)


# ==============================================================================
# SECTION 2: Panel flips to left near right edge
# ==============================================================================

func test_reposition_flips_to_left_when_near_right_edge() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data))
	_panel._tower = tower
	_panel._reposition_at(Vector2(1200, 480))
	var expected_x: float = 1200.0 - _panel.TOWER_OFFSET - _panel.size.x
	assert_float(_panel.position.x).is_equal_approx(expected_x, 1.0)


# ==============================================================================
# SECTION 3: Panel clamped to viewport bounds
# ==============================================================================

func test_reposition_clamps_y_to_top_edge() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data))
	_panel._tower = tower
	_panel._reposition_at(Vector2(400, 20))
	assert_float(_panel.position.y).is_equal_approx(_panel.PANEL_MARGIN, 1.0)


func test_reposition_clamps_y_to_bottom_edge() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data))
	_panel._tower = tower
	_panel._reposition_at(Vector2(400, 940))
	var max_y: float = 960.0 - _panel.size.y - _panel.PANEL_MARGIN
	assert_float(_panel.position.y).is_equal_approx(max_y, 1.0)


func test_reposition_clamps_x_to_left_edge() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data))
	_panel._tower = tower
	_panel._reposition_at(Vector2(10, 400))
	assert_bool(_panel.position.x >= _panel.PANEL_MARGIN - 1.0).is_true()


# ==============================================================================
# SECTION 4: Reposition called on display_tower
# ==============================================================================

func test_reposition_called_on_display_tower() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data, Vector2(400, 300)))
	_panel.position = Vector2.ZERO
	_panel.display_tower(tower)
	assert_bool(_panel._last_screen_pos != Vector2.ZERO).is_true()


# ==============================================================================
# SECTION 5: Reposition on camera move (screen pos change)
# ==============================================================================

func test_process_repositions_when_screen_pos_changes() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data, Vector2(400, 300)))
	_panel._tower = tower
	_panel.visible = true
	_panel._reposition_at(Vector2(400, 300))
	var pos_before: Vector2 = _panel.position
	_panel._reposition_at(Vector2(500, 350))
	var pos_after: Vector2 = _panel.position
	assert_bool(pos_before.distance_to(pos_after) > 2.0).is_true()


# ==============================================================================
# SECTION 6: Touch-friendly offset (no tower overlap)
# ==============================================================================

func test_panel_does_not_overlap_tower() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data))
	_panel._tower = tower
	_panel._reposition_at(Vector2(640, 480))
	var panel_left: float = _panel.position.x
	var panel_right: float = _panel.position.x + _panel.size.x
	var tower_x: float = 640.0
	var gap: float = minf(absf(panel_left - tower_x), absf(panel_right - tower_x))
	assert_bool(gap >= _panel.TOWER_OFFSET - 1.0).is_true()


# ==============================================================================
# SECTION 7: Panel hides cleanly (no position artifacts)
# ==============================================================================

func test_last_screen_pos_resets_on_new_tower() -> void:
	var data1: TowerData = _make_tower_data("Tower1")
	var tower1: Node2D = auto_free(_make_tower_stub(data1, Vector2(200, 200)))
	var data2: TowerData = _make_tower_data("Tower2")
	var tower2: Node2D = auto_free(_make_tower_stub(data2, Vector2(800, 600)))
	_panel.display_tower(tower1)
	var pos1: Vector2 = _panel.position
	_panel.display_tower(tower2)
	var pos2: Vector2 = _panel.position
	assert_bool(pos1.distance_to(pos2) > 10.0).is_true()
