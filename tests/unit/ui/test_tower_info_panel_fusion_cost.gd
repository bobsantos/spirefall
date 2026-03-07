extends GdUnitTestSuite

## Unit tests for FusionCostLabel in TowerInfoPanel.
## Covers: visibility, cost text for dual/legendary fusions, cost ranges,
## affordability coloring (gold vs red), hidden when no partners.

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
# SECTION 1: Hidden when not fusion eligible
# ==============================================================================

# -- 1. Label hidden when tower has upgrade_to (not Superior) ------------------

func test_fusion_cost_label_hidden_when_not_fusion_eligible() -> void:
	var enhanced_data: TowerData = _make_tower_data("Enhanced", "fire", 30, 1)
	enhanced_data.upgrade_to = _make_tower_data("Superior", "fire", 60, 1)
	var tower: Node2D = auto_free(_make_tower_stub(enhanced_data))
	_panel._tower = tower
	_panel._refresh()
	assert_bool(_panel.fusion_cost_label.visible).is_false()


# ==============================================================================
# SECTION 2: Shows cost for dual fusion
# ==============================================================================

# -- 2. Label shows "Fuse cost: Xg" for a Superior with one fusion partner ----

func test_fusion_cost_label_shows_cost_for_dual_fusion() -> void:
	# Create a Superior fire tower (tier 1, no upgrade_to)
	var fire_data: TowerData = _make_tower_data("Fire Superior", "fire", 60, 1)
	var fire_tower: Node2D = auto_free(_make_tower_stub(fire_data))
	# Create a Superior earth tower as partner
	var earth_data: TowerData = _make_tower_data("Earth Superior", "earth", 60, 1)
	var earth_tower: Node2D = auto_free(_make_tower_stub(earth_data))
	TowerSystem._active_towers.append(fire_tower)
	TowerSystem._active_towers.append(earth_tower)
	# Display the fire tower in the panel
	_panel._tower = fire_tower
	_panel._refresh()
	# Magma Forge (earth+fire) costs 130
	assert_bool(_panel.fusion_cost_label.visible).is_true()
	assert_str(_panel.fusion_cost_label.text).contains("130")
	assert_str(_panel.fusion_cost_label.text).contains("Fuse cost:")


# ==============================================================================
# SECTION 3: Shows range for multiple different costs
# ==============================================================================

# -- 3. Label shows "Fuse cost: X-Yg" when partners have different costs ------

func test_fusion_cost_label_shows_range_for_multiple_costs() -> void:
	# Create a Superior fire tower
	var fire_data: TowerData = _make_tower_data("Fire Superior", "fire", 60, 1)
	var fire_tower: Node2D = auto_free(_make_tower_stub(fire_data))
	# Create two partners with different elements (different fusion costs)
	var earth_data: TowerData = _make_tower_data("Earth Superior", "earth", 60, 1)
	var earth_tower: Node2D = auto_free(_make_tower_stub(earth_data))
	var water_data: TowerData = _make_tower_data("Water Superior", "water", 60, 1)
	var water_tower: Node2D = auto_free(_make_tower_stub(water_data))
	TowerSystem._active_towers.append(fire_tower)
	TowerSystem._active_towers.append(earth_tower)
	TowerSystem._active_towers.append(water_tower)
	_panel._tower = fire_tower
	_panel._refresh()
	# Magma Forge=130, Steam Engine=120 -> "Fuse cost: 120-130g"
	assert_bool(_panel.fusion_cost_label.visible).is_true()
	assert_str(_panel.fusion_cost_label.text).is_equal("Fuse cost: 120-130g")


# ==============================================================================
# SECTION 4: Gold color when affordable
# ==============================================================================

# -- 4. Label is gold color when player can afford minimum cost ----------------

func test_fusion_cost_label_gold_when_affordable() -> void:
	EconomyManager.gold = 500
	var fire_data: TowerData = _make_tower_data("Fire Superior", "fire", 60, 1)
	var fire_tower: Node2D = auto_free(_make_tower_stub(fire_data))
	var earth_data: TowerData = _make_tower_data("Earth Superior", "earth", 60, 1)
	var earth_tower: Node2D = auto_free(_make_tower_stub(earth_data))
	TowerSystem._active_towers.append(fire_tower)
	TowerSystem._active_towers.append(earth_tower)
	_panel._tower = fire_tower
	_panel._refresh()
	var color: Color = Color(1.0, 0.85, 0.2)
	assert_bool(_panel.fusion_cost_label.has_theme_color_override("font_color")).is_true()
	var actual: Color = _panel.fusion_cost_label.get_theme_color("font_color")
	assert_bool(actual.is_equal_approx(color)).is_true()


# ==============================================================================
# SECTION 5: Red color when unaffordable
# ==============================================================================

# -- 5. Label is red when player cannot afford minimum cost --------------------

func test_fusion_cost_label_red_when_unaffordable() -> void:
	EconomyManager.gold = 10
	var fire_data: TowerData = _make_tower_data("Fire Superior", "fire", 60, 1)
	var fire_tower: Node2D = auto_free(_make_tower_stub(fire_data))
	var earth_data: TowerData = _make_tower_data("Earth Superior", "earth", 60, 1)
	var earth_tower: Node2D = auto_free(_make_tower_stub(earth_data))
	TowerSystem._active_towers.append(fire_tower)
	TowerSystem._active_towers.append(earth_tower)
	_panel._tower = fire_tower
	_panel._refresh()
	var color: Color = Color(1.0, 0.4, 0.3)
	assert_bool(_panel.fusion_cost_label.has_theme_color_override("font_color")).is_true()
	var actual: Color = _panel.fusion_cost_label.get_theme_color("font_color")
	assert_bool(actual.is_equal_approx(color)).is_true()


# ==============================================================================
# SECTION 6: Hidden when no partners on map
# ==============================================================================

# -- 6. Label hidden when Superior tower has no partners on the map ------------

func test_fusion_cost_label_hidden_when_no_partners() -> void:
	var fire_data: TowerData = _make_tower_data("Fire Superior", "fire", 60, 1)
	var fire_tower: Node2D = auto_free(_make_tower_stub(fire_data))
	TowerSystem._active_towers.append(fire_tower)
	# No other towers on the map
	_panel._tower = fire_tower
	_panel._refresh()
	assert_bool(_panel.fusion_cost_label.visible).is_false()
