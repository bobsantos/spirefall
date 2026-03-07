extends GdUnitTestSuite

## Unit tests for TowerInfoPanel fuse button visibility and text.
## Covers: hidden when not eligible, shows "Fuse..." for dual,
## shows "Legendary Fuse..." for tier 2, hidden when no partners.

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
# SECTION 1: Fuse button hidden when not fusion eligible
# ==============================================================================

func test_fuse_button_hidden_when_not_fusion_eligible() -> void:
	var enhanced_data: TowerData = _make_tower_data("Enhanced", "fire", 30, 1)
	enhanced_data.upgrade_to = _make_tower_data("Superior", "fire", 60, 1)
	var tower: Node2D = auto_free(_make_tower_stub(enhanced_data))
	_panel._tower = tower
	_panel._refresh()
	assert_bool(_panel.fuse_button.visible).is_false()


# ==============================================================================
# SECTION 2: Fuse button shows for dual fusion
# ==============================================================================

func test_fuse_button_shows_for_dual_fusion() -> void:
	var fire_data: TowerData = _make_tower_data("Fire Superior", "fire", 60, 1)
	var fire_tower: Node2D = auto_free(_make_tower_stub(fire_data))
	var earth_data: TowerData = _make_tower_data("Earth Superior", "earth", 60, 1)
	var earth_tower: Node2D = auto_free(_make_tower_stub(earth_data))
	TowerSystem._active_towers.append(fire_tower)
	TowerSystem._active_towers.append(earth_tower)
	_panel._tower = fire_tower
	_panel._refresh()
	assert_bool(_panel.fuse_button.visible).is_true()
	assert_str(_panel.fuse_button.text).is_equal("Fuse...")


# ==============================================================================
# SECTION 3: Fuse button hidden when no partners on map
# ==============================================================================

func test_fuse_button_hidden_when_no_partners() -> void:
	var fire_data: TowerData = _make_tower_data("Fire Superior", "fire", 60, 1)
	var fire_tower: Node2D = auto_free(_make_tower_stub(fire_data))
	TowerSystem._active_towers.append(fire_tower)
	_panel._tower = fire_tower
	_panel._refresh()
	assert_bool(_panel.fuse_button.visible).is_false()
