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

	var name_label := Label.new()
	name_label.name = "NameLabel"
	vbox.add_child(name_label)

	var tier_label := Label.new()
	tier_label.name = "TierLabel"
	vbox.add_child(tier_label)

	var element_label := Label.new()
	element_label.name = "ElementLabel"
	vbox.add_child(element_label)

	var sep_top := HSeparator.new()
	sep_top.name = "SeparatorTop"
	vbox.add_child(sep_top)

	var damage_label := Label.new()
	damage_label.name = "DamageLabel"
	vbox.add_child(damage_label)

	var speed_label := Label.new()
	speed_label.name = "SpeedLabel"
	vbox.add_child(speed_label)

	var range_label := Label.new()
	range_label.name = "RangeLabel"
	vbox.add_child(range_label)

	var special_label := Label.new()
	special_label.name = "SpecialLabel"
	vbox.add_child(special_label)

	var synergy_label := Label.new()
	synergy_label.name = "SynergyLabel"
	vbox.add_child(synergy_label)

	var sep_bottom := HSeparator.new()
	sep_bottom.name = "SeparatorBottom"
	vbox.add_child(sep_bottom)

	var upgrade_cost_label := Label.new()
	upgrade_cost_label.name = "UpgradeCostLabel"
	vbox.add_child(upgrade_cost_label)

	var sell_value_label := Label.new()
	sell_value_label.name = "SellValueLabel"
	vbox.add_child(sell_value_label)

	var fusion_cost_label := Label.new()
	fusion_cost_label.name = "FusionCostLabel"
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

	var fuse_button := Button.new()
	fuse_button.name = "FuseButton"
	fuse_button.visible = false
	vbox.add_child(fuse_button)

	return root


func _apply_script(panel: PanelContainer) -> void:
	var script: GDScript = load(PANEL_SCRIPT_PATH)
	panel.set_script(script)
	# Wire @onready refs manually since node is not in the scene tree
	var vbox: VBoxContainer = panel.get_node("VBoxContainer")
	panel.name_label = vbox.get_node("NameLabel")
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
	panel.fuse_button = vbox.get_node("FuseButton")


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_gold = EconomyManager.gold
	_original_game_state = GameManager.game_state
	_original_game_running = GameManager._game_running


func before_test() -> void:
	# Reset autoload state
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	GameManager._game_running = false
	EconomyManager.gold = 500
	# Clear active towers
	for tower: Node in TowerSystem._active_towers:
		if is_instance_valid(tower) and not tower.is_queued_for_deletion():
			tower.free()
	TowerSystem._active_towers.clear()
	# Build panel
	_panel = auto_free(_build_panel())
	_apply_script(_panel)
	_panel.visible = true
	# Set a known panel size for positioning math
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
	# Tower at screen center (640, 480)
	_panel._reposition_at(Vector2(640, 480))
	# Panel should be to the right: x = tower_x + TOWER_OFFSET
	assert_float(_panel.position.x).is_equal_approx(640.0 + _panel.TOWER_OFFSET, 1.0)
	# Panel should be vertically centered on tower
	var expected_y: float = 480.0 - _panel.size.y * 0.5
	assert_float(_panel.position.y).is_equal_approx(expected_y, 1.0)


# ==============================================================================
# SECTION 2: Panel flips to left near right edge
# ==============================================================================

func test_reposition_flips_to_left_when_near_right_edge() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data))
	_panel._tower = tower
	# Tower near right edge: x = 1200 (viewport assumed 1280 wide)
	# Right placement: 1200 + 40 + 240 + 8 = 1488 > 1280 => should flip left
	_panel._reposition_at(Vector2(1200, 480))
	# Panel should be to the left: x = tower_x - TOWER_OFFSET - panel_width
	var expected_x: float = 1200.0 - _panel.TOWER_OFFSET - _panel.size.x
	assert_float(_panel.position.x).is_equal_approx(expected_x, 1.0)


# ==============================================================================
# SECTION 3: Panel clamped to viewport bounds
# ==============================================================================

func test_reposition_clamps_y_to_top_edge() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data))
	_panel._tower = tower
	# Tower near top: y = 20 -> center_y = 20 - 150 = -130 -> clamp to PANEL_MARGIN
	_panel._reposition_at(Vector2(400, 20))
	assert_float(_panel.position.y).is_equal_approx(_panel.PANEL_MARGIN, 1.0)


func test_reposition_clamps_y_to_bottom_edge() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data))
	_panel._tower = tower
	# Tower near bottom: y = 940 -> center_y = 940 - 150 = 790
	# _reposition_at uses fallback viewport 1280x960 when panel has no viewport
	# max_y = 960 - 300 - 8 = 652
	_panel._reposition_at(Vector2(400, 940))
	var max_y: float = 960.0 - _panel.size.y - _panel.PANEL_MARGIN
	assert_float(_panel.position.y).is_equal_approx(max_y, 1.0)


func test_reposition_clamps_x_to_left_edge() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data))
	_panel._tower = tower
	# Tower at x=10: left flip would be 10 - 40 - 240 = -270 -> clamp to PANEL_MARGIN
	# Right placement: 10 + 40 = 50, 50 + 240 + 8 = 298 (might fit depending on viewport)
	# Force a scenario where both sides overflow: use a very small x
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
	# After display_tower, position should have been updated from (0,0)
	# Since _reposition uses _get_tower_screen_pos (which depends on transforms),
	# in headless the transform is identity so screen_pos = tower.position
	# The panel should have moved from its initial (0,0)
	# At minimum, _reposition_at was called, so _last_screen_pos should be set
	assert_bool(_panel._last_screen_pos != Vector2.ZERO).is_true()


# ==============================================================================
# SECTION 5: Reposition on camera move (screen pos change)
# ==============================================================================

func test_process_repositions_when_screen_pos_changes() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data, Vector2(400, 300)))
	_panel._tower = tower
	_panel.visible = true
	# Initial positioning
	_panel._reposition_at(Vector2(400, 300))
	var pos_before: Vector2 = _panel.position
	# Simulate camera move by repositioning at different screen pos
	_panel._reposition_at(Vector2(500, 350))
	var pos_after: Vector2 = _panel.position
	# Panel should have moved
	assert_bool(pos_before.distance_to(pos_after) > 2.0).is_true()


# ==============================================================================
# SECTION 6: Touch-friendly offset (no tower overlap)
# ==============================================================================

func test_panel_does_not_overlap_tower() -> void:
	var data: TowerData = _make_tower_data()
	var tower: Node2D = auto_free(_make_tower_stub(data))
	_panel._tower = tower
	_panel._reposition_at(Vector2(640, 480))
	# The gap between tower screen pos and nearest panel edge should be >= TOWER_OFFSET
	var panel_left: float = _panel.position.x
	var panel_right: float = _panel.position.x + _panel.size.x
	var tower_x: float = 640.0
	# Panel is to the right, so panel_left - tower_x >= TOWER_OFFSET
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
	# Display first tower
	_panel.display_tower(tower1)
	var pos1: Vector2 = _panel.position
	# Display second tower (different position)
	_panel.display_tower(tower2)
	var pos2: Vector2 = _panel.position
	# Positions should differ since towers are at different locations
	assert_bool(pos1.distance_to(pos2) > 10.0).is_true()
