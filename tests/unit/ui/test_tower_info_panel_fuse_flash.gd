extends GdUnitTestSuite

## Tests for fuse button flash on fusion failure.

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


func _make_tower_stub(data: TowerData) -> Node2D:
	var stub := Node2D.new()
	stub.set_script(_tower_stub_script())
	stub.tower_data = data
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


func after_test() -> void:
	# Clean up any towers left in active list
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
# SECTION 1: Flash sets fuse button modulate to red
# ==============================================================================

func test_flash_sets_fuse_button_modulate_red() -> void:
	_panel.visible = true
	_panel.fuse_button.visible = true
	# Confirm default modulate is white
	assert_bool(_panel.fuse_button.modulate.is_equal_approx(Color(1, 1, 1, 1))).is_true()
	# Trigger the fusion failed handler directly
	_panel._on_fusion_failed(null, "test")
	# Fuse button should now be red
	var expected_red: Color = Color(1.0, 0.3, 0.3, 1.0)
	assert_bool(_panel.fuse_button.modulate.is_equal_approx(expected_red)).is_true()


# ==============================================================================
# SECTION 2: Flash skipped when panel is hidden
# ==============================================================================

func test_flash_skipped_when_panel_hidden() -> void:
	_panel.visible = false
	_panel.fuse_button.visible = true
	# Trigger the fusion failed handler
	_panel._on_fusion_failed(null, "test")
	# Fuse button modulate should remain white (unchanged)
	assert_bool(_panel.fuse_button.modulate.is_equal_approx(Color(1, 1, 1, 1))).is_true()
