extends GdUnitTestSuite

## Integration tests for the fusion pipeline.
## Verifies that FusionRegistry, TowerSystem, and ElementSynergy work together
## correctly for both dual-element and legendary fusion flows.
##
## All nodes are constructed manually in-memory to avoid loading scene files
## that require sprite textures (which fail in headless mode).


# -- Helpers -------------------------------------------------------------------

## Create a minimal TowerData resource for testing.
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


## Returns a minimal GDScript that gives a Node2D the properties TowerSystem
## reads/writes (tower_data, grid_position, apply_tower_data). This avoids
## loading BaseTower.tscn which requires sprites, timers, and synergy autoloads.
static var _stub_script: GDScript = null
func _tower_stub_script() -> GDScript:
	if _stub_script != null:
		return _stub_script
	_stub_script = GDScript.new()
	_stub_script.source_code = """
extends Node2D

var tower_data: TowerData
var grid_position: Vector2i = Vector2i.ZERO

func apply_tower_data() -> void:
	pass
"""
	_stub_script.reload()
	return _stub_script


## Create a PackedScene that produces a Node2D with the tower stub script.
## Used to replace TowerSystem._tower_scene during tests.
func _create_tower_stub_scene() -> PackedScene:
	var scene := PackedScene.new()
	var node := Node2D.new()
	node.name = "StubTower"
	node.set_script(_tower_stub_script())
	scene.pack(node)
	node.free()
	return scene


## Create a tower stub Node2D manually (for tests that don't go through create_tower).
func _make_tower_stub(data: TowerData, grid_pos: Vector2i = Vector2i.ZERO) -> Node2D:
	var stub := Node2D.new()
	stub.set_script(_tower_stub_script())
	stub.tower_data = data
	stub.grid_position = grid_pos
	stub.position = GridManager.grid_to_world(grid_pos)
	return stub


## Reset GridManager to a clean all-buildable grid with no towers.
func _reset_grid_manager() -> void:
	GridManager._initialize_grid()
	GridManager._tower_map.clear()
	GridManager.spawn_points.clear()
	GridManager.exit_points.clear()


## Set up a minimal map with spawn at (0,0) and exit at (19,0).
func _setup_minimal_map() -> void:
	_reset_grid_manager()
	var spawn := Vector2i(0, 0)
	var exit_pt := Vector2i(19, 0)
	GridManager.spawn_points.append(spawn)
	GridManager.exit_points.append(exit_pt)
	GridManager.grid[spawn.x][spawn.y] = GridManager.CellType.SPAWN
	GridManager.grid[exit_pt.x][exit_pt.y] = GridManager.CellType.EXIT
	PathfindingSystem.recalculate()


## Place a tower stub onto the grid and register it with TowerSystem.
func _place_tower_on_grid(tower: Node2D, grid_pos: Vector2i) -> void:
	tower.grid_position = grid_pos
	tower.position = GridManager.grid_to_world(grid_pos)
	GridManager.grid[grid_pos.x][grid_pos.y] = GridManager.CellType.TOWER
	GridManager._tower_map[grid_pos] = tower
	TowerSystem._active_towers.append(tower)


func _reset_autoloads() -> void:
	# TowerSystem
	for tower: Node in TowerSystem._active_towers:
		if is_instance_valid(tower) and not tower.is_queued_for_deletion():
			tower.free()
	TowerSystem._active_towers.clear()
	# GameManager
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = 0
	GameManager.lives = GameManager.starting_lives
	GameManager._build_timer = 0.0
	GameManager._enemies_leaked_this_wave = 0
	# EconomyManager
	EconomyManager.reset()
	# ElementSynergy
	ElementSynergy._element_counts.clear()
	ElementSynergy._synergy_tiers.clear()
	# Grid
	_setup_minimal_map()


# Save/restore original tower scene to avoid polluting other test suites
var _original_tower_scene: PackedScene


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_tower_scene = TowerSystem._tower_scene


func before_test() -> void:
	_reset_autoloads()
	TowerSystem._tower_scene = _create_tower_stub_scene()
	GameManager.game_state = GameManager.GameState.BUILD_PHASE


func after_test() -> void:
	for tower: Node in TowerSystem._active_towers:
		if is_instance_valid(tower) and not tower.is_queued_for_deletion():
			tower.free()
	TowerSystem._active_towers.clear()
	TowerSystem._tower_scene = _original_tower_scene


func after() -> void:
	_stub_script = null


# ==============================================================================
# TEST 1: Full dual fusion flow -- two superior towers fuse into a tier 2 tower
# ==============================================================================

func test_full_dual_fusion_flow() -> void:
	# Create two Superior (tier 1, no upgrade) towers of different elements
	var fire_superior: TowerData = _make_tower_data(
		"FireSuperior", "fire", 60, 1, null)
	var earth_superior: TowerData = _make_tower_data(
		"EarthSuperior", "earth", 70, 1, null)

	var tower_a: Node2D = auto_free(_make_tower_stub(fire_superior))
	var tower_b: Node2D = auto_free(_make_tower_stub(earth_superior))
	_place_tower_on_grid(tower_a, Vector2i(5, 5))
	_place_tower_on_grid(tower_b, Vector2i(7, 5))

	# Give enough gold for fusion
	EconomyManager.add_gold(500)

	# Perform the fusion via TowerSystem (exercises FusionRegistry.can_fuse +
	# get_fusion_result under the hood)
	var result: bool = TowerSystem.fuse_towers(tower_a, tower_b)
	assert_bool(result).is_true()

	# tower_a should now hold the Magma Forge fusion data (earth+fire)
	assert_str(tower_a.tower_data.tower_name).is_equal("Magma Forge")
	assert_int(tower_a.tower_data.tier).is_equal(2)
	# tower_a should still be in active towers
	assert_bool(TowerSystem._active_towers.has(tower_a)).is_true()


# ==============================================================================
# TEST 2: Full legendary fusion flow -- tier 2 + superior fuse into tier 3
# ==============================================================================

func test_full_legendary_fusion_flow() -> void:
	# Create a tier 2 Magma Forge (earth+fire) and a Superior water tower
	var tier2_data: TowerData = _make_tower_data(
		"MagmaForge", "earth", 130, 2, null, ["earth", "fire"] as Array[String])
	var water_superior: TowerData = _make_tower_data(
		"WaterSuperior", "water", 60, 1, null)

	var tower_tier2: Node2D = auto_free(_make_tower_stub(tier2_data))
	var tower_sup: Node2D = auto_free(_make_tower_stub(water_superior))
	_place_tower_on_grid(tower_tier2, Vector2i(5, 5))
	_place_tower_on_grid(tower_sup, Vector2i(7, 5))

	# Give enough gold for legendary fusion (Primordial Nexus costs 300)
	EconomyManager.add_gold(1000)

	# Perform legendary fusion via TowerSystem
	var result: bool = TowerSystem.fuse_legendary(tower_tier2, tower_sup)
	assert_bool(result).is_true()

	# tower_tier2 should now be the Primordial Nexus (tier 3, 3 elements)
	assert_str(tower_tier2.tower_data.tower_name).is_equal("Primordial Nexus")
	assert_int(tower_tier2.tower_data.tier).is_equal(3)
	assert_int(tower_tier2.tower_data.fusion_elements.size()).is_equal(3)
	assert_bool(tower_tier2.tower_data.fusion_elements.has("earth")).is_true()
	assert_bool(tower_tier2.tower_data.fusion_elements.has("fire")).is_true()
	assert_bool(tower_tier2.tower_data.fusion_elements.has("water")).is_true()


# ==============================================================================
# TEST 3: Fusion updates synergy element counts
# ==============================================================================

func test_fusion_updates_synergy_counts() -> void:
	# Place two Superior towers (fire + earth), each contributing 1 to their element
	var fire_superior: TowerData = _make_tower_data(
		"FireSuperior", "fire", 60, 1, null)
	var earth_superior: TowerData = _make_tower_data(
		"EarthSuperior", "earth", 70, 1, null)

	var tower_a: Node2D = auto_free(_make_tower_stub(fire_superior))
	var tower_b: Node2D = auto_free(_make_tower_stub(earth_superior))
	_place_tower_on_grid(tower_a, Vector2i(5, 5))
	_place_tower_on_grid(tower_b, Vector2i(7, 5))

	# Recalculate synergy before fusion
	ElementSynergy.recalculate()
	assert_int(ElementSynergy.get_element_count("fire")).is_equal(1)
	assert_int(ElementSynergy.get_element_count("earth")).is_equal(1)

	# Give enough gold and fuse
	EconomyManager.add_gold(500)
	TowerSystem.fuse_towers(tower_a, tower_b)

	# After fusion, tower_b is consumed and tower_a becomes Magma Forge (earth+fire).
	# The fusion tower contributes 1 to both earth and fire via fusion_elements.
	# tower_b is gone, so only tower_a remains.
	# ElementSynergy.recalculate() is triggered by TowerSystem.tower_fused signal.
	# Manually recalculate to be safe in case the signal hasn't fired synchronously.
	ElementSynergy.recalculate()

	# The single fusion tower contributes 1 earth + 1 fire
	assert_int(ElementSynergy.get_element_count("fire")).is_equal(1)
	assert_int(ElementSynergy.get_element_count("earth")).is_equal(1)

	# Add more fire towers to verify the fusion tower's elements stack with others
	var fire_extra: TowerData = _make_tower_data("FireExtra", "fire", 30, 1, null)
	var extra: Node2D = auto_free(_make_tower_stub(fire_extra))
	_place_tower_on_grid(extra, Vector2i(9, 5))
	ElementSynergy.recalculate()

	# Now: fusion tower (1 fire, 1 earth) + extra fire tower (1 fire) = 2 fire, 1 earth
	assert_int(ElementSynergy.get_element_count("fire")).is_equal(2)
	assert_int(ElementSynergy.get_element_count("earth")).is_equal(1)


# ==============================================================================
# TEST 4: Fusion tower has both source elements in fusion_elements
# ==============================================================================

func test_fusion_tower_has_both_elements() -> void:
	# Fuse fire + water -> Steam Engine
	var fire_superior: TowerData = _make_tower_data(
		"FireSuperior", "fire", 60, 1, null)
	var water_superior: TowerData = _make_tower_data(
		"WaterSuperior", "water", 60, 1, null)

	var tower_a: Node2D = auto_free(_make_tower_stub(fire_superior))
	var tower_b: Node2D = auto_free(_make_tower_stub(water_superior))
	_place_tower_on_grid(tower_a, Vector2i(5, 5))
	_place_tower_on_grid(tower_b, Vector2i(7, 5))

	EconomyManager.add_gold(500)
	TowerSystem.fuse_towers(tower_a, tower_b)

	# The result (Steam Engine) should have both fire and water in fusion_elements
	assert_str(tower_a.tower_data.tower_name).is_equal("Steam Engine")
	assert_int(tower_a.tower_data.fusion_elements.size()).is_equal(2)
	assert_bool(tower_a.tower_data.fusion_elements.has("fire")).is_true()
	assert_bool(tower_a.tower_data.fusion_elements.has("water")).is_true()

	# Verify the grid position is preserved (tower_a stays at its original position)
	assert_int(tower_a.grid_position.x).is_equal(5)
	assert_int(tower_a.grid_position.y).is_equal(5)
	assert_int(GridManager.get_cell(Vector2i(5, 5))).is_equal(GridManager.CellType.TOWER)


# ==============================================================================
# TEST 5: Fusion cost is deducted from gold
# ==============================================================================

func test_fusion_cost_deducted() -> void:
	var fire_superior: TowerData = _make_tower_data(
		"FireSuperior", "fire", 60, 1, null)
	var earth_superior: TowerData = _make_tower_data(
		"EarthSuperior", "earth", 70, 1, null)

	var tower_a: Node2D = auto_free(_make_tower_stub(fire_superior))
	var tower_b: Node2D = auto_free(_make_tower_stub(earth_superior))
	_place_tower_on_grid(tower_a, Vector2i(5, 5))
	_place_tower_on_grid(tower_b, Vector2i(7, 5))

	EconomyManager.add_gold(500)
	var gold_before: int = EconomyManager.gold

	TowerSystem.fuse_towers(tower_a, tower_b)

	# Magma Forge costs 130 gold (the result tower's cost is deducted as fusion fee)
	assert_int(EconomyManager.gold).is_equal(gold_before - 130)


# ==============================================================================
# TEST 6: Consumed tower is removed from grid and freed
# ==============================================================================

func test_fusion_consumed_tower_freed() -> void:
	var fire_superior: TowerData = _make_tower_data(
		"FireSuperior", "fire", 60, 1, null)
	var earth_superior: TowerData = _make_tower_data(
		"EarthSuperior", "earth", 70, 1, null)

	var tower_a: Node2D = auto_free(_make_tower_stub(fire_superior))
	var tower_b: Node2D = auto_free(_make_tower_stub(earth_superior))
	_place_tower_on_grid(tower_a, Vector2i(5, 5))
	_place_tower_on_grid(tower_b, Vector2i(7, 5))

	EconomyManager.add_gold(500)

	# Verify tower_b is on the grid before fusion
	assert_int(GridManager.get_cell(Vector2i(7, 5))).is_equal(GridManager.CellType.TOWER)
	assert_bool(TowerSystem._active_towers.has(tower_b)).is_true()

	TowerSystem.fuse_towers(tower_a, tower_b)

	# tower_b should be removed from active towers
	assert_bool(TowerSystem._active_towers.has(tower_b)).is_false()
	# tower_b's grid cell should be reverted to BUILDABLE
	assert_int(GridManager.get_cell(Vector2i(7, 5))).is_equal(GridManager.CellType.BUILDABLE)
	# tower_b should be queued for deletion
	assert_bool(tower_b.is_queued_for_deletion()).is_true()
	# tower_a's grid cell should still be TOWER
	assert_int(GridManager.get_cell(Vector2i(5, 5))).is_equal(GridManager.CellType.TOWER)
