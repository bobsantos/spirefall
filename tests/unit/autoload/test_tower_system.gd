extends GdUnitTestSuite

## Unit tests for TowerSystem autoload.
## Covers: create_tower (gold, returns node, fails cases, adds to active, signal),
## upgrade_tower (success, cost, fails cases, signal), sell_tower (refund
## build/combat phase, removes from active, frees grid cell, signal),
## fuse_towers (success, cost, removes tower B, replaces tower A, fails cases, signal),
## fuse_legendary, get_active_towers.


# -- Helpers -------------------------------------------------------------------

## Create a minimal TowerData resource for testing without loading .tres files.
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


## Set up a minimal map with one spawn and one exit so PathfindingSystem
## can validate paths. Spawn at top-left, exit at top-right.
func _setup_minimal_map() -> void:
	_reset_grid_manager()
	var spawn := Vector2i(0, 0)
	var exit := Vector2i(19, 0)
	GridManager.spawn_points.append(spawn)
	GridManager.exit_points.append(exit)
	GridManager.grid[spawn.x][spawn.y] = GridManager.CellType.SPAWN
	GridManager.grid[exit.x][exit.y] = GridManager.CellType.EXIT
	PathfindingSystem.recalculate()


func _reset_tower_system() -> void:
	# Clean up any tower nodes still referenced
	for tower: Node in TowerSystem._active_towers:
		if is_instance_valid(tower) and not tower.is_queued_for_deletion():
			tower.queue_free()
	TowerSystem._active_towers.clear()


func _reset_game_manager() -> void:
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = 0
	GameManager.lives = GameManager.starting_lives
	GameManager._build_timer = 0.0
	GameManager._enemies_leaked_this_wave = 0


# -- Original scene reference (saved once, restored after each test) -----------

var _original_tower_scene: PackedScene


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	# Save the original tower scene once at suite start
	_original_tower_scene = TowerSystem._tower_scene


func before_test() -> void:
	_reset_tower_system()
	_reset_game_manager()
	_reset_grid_manager()
	EconomyManager.reset()
	# Replace tower scene with stub for all tests
	TowerSystem._tower_scene = _create_tower_stub_scene()
	# Set up minimal map so placement/path checks work
	_setup_minimal_map()
	# Default to BUILD_PHASE for most tests
	GameManager.game_state = GameManager.GameState.BUILD_PHASE


func after_test() -> void:
	# Clean up any towers created during the test
	_reset_tower_system()
	# Restore the original tower scene
	TowerSystem._tower_scene = _original_tower_scene


# -- 1. create_tower spends gold -----------------------------------------------

func test_create_tower_spends_gold() -> void:
	var data: TowerData = _make_tower_data("Fire", "fire", 30)
	var gold_before: int = EconomyManager.gold
	# Place at (5, 5) which is BUILDABLE and won't block the spawn-exit path on row 0
	TowerSystem.create_tower(data, Vector2i(5, 5))
	assert_int(EconomyManager.gold).is_equal(gold_before - 30)


# -- 2. create_tower returns node -----------------------------------------------

func test_create_tower_returns_node() -> void:
	var data: TowerData = _make_tower_data("Fire", "fire", 30)
	var tower: Node = TowerSystem.create_tower(data, Vector2i(5, 5))
	assert_object(tower).is_not_null()
	assert_object(tower.tower_data).is_same(data)
	tower.queue_free()


# -- 3. create_tower fails insufficient gold ------------------------------------

func test_create_tower_fails_insufficient_gold() -> void:
	var data: TowerData = _make_tower_data("Expensive", "fire", 9999)
	var gold_before: int = EconomyManager.gold
	var tower: Node = TowerSystem.create_tower(data, Vector2i(5, 5))
	assert_object(tower).is_null()
	assert_int(EconomyManager.gold).is_equal(gold_before)


# -- 4. create_tower fails unbuildable cell -------------------------------------

func test_create_tower_fails_unbuildable_cell() -> void:
	# Mark (5, 5) as unbuildable
	GridManager.grid[5][5] = GridManager.CellType.UNBUILDABLE
	var data: TowerData = _make_tower_data("Fire", "fire", 30)
	var gold_before: int = EconomyManager.gold
	var tower: Node = TowerSystem.create_tower(data, Vector2i(5, 5))
	assert_object(tower).is_null()
	assert_int(EconomyManager.gold).is_equal(gold_before)


# -- 5. create_tower fails blocks path ------------------------------------------

func test_create_tower_fails_blocks_path() -> void:
	# Place towers to create a situation where the next placement would block
	# the only path from spawn(0,0) to exit(19,0).
	# Block all of row 0 except spawn and exit to leave a narrow corridor.
	# Then block the last remaining cell to trigger would_block_path.
	# Row 0 path: (0,0)=SPAWN, (1,0)...(18,0)=BUILDABLE, (19,0)=EXIT.
	# Block cells (1,0) through (17,0) via TOWER or UNBUILDABLE so only (18,0) remains.
	for x: int in range(1, 18):
		GridManager.grid[x][0] = GridManager.CellType.TOWER
	# Also block row 1 to ensure the only path goes through (18,0)
	for x: int in range(0, 20):
		GridManager.grid[x][1] = GridManager.CellType.UNBUILDABLE
	PathfindingSystem.recalculate()

	var data: TowerData = _make_tower_data("Blocker", "fire", 30)
	var gold_before: int = EconomyManager.gold
	var tower: Node = TowerSystem.create_tower(data, Vector2i(18, 0))
	assert_object(tower).is_null()
	assert_int(EconomyManager.gold).is_equal(gold_before)


# -- 6. create_tower adds to active towers --------------------------------------

func test_create_tower_adds_to_active() -> void:
	var data: TowerData = _make_tower_data("Fire", "fire", 30)
	assert_int(TowerSystem.get_active_towers().size()).is_equal(0)
	var tower: Node = TowerSystem.create_tower(data, Vector2i(5, 5))
	assert_int(TowerSystem.get_active_towers().size()).is_equal(1)
	assert_bool(TowerSystem.get_active_towers().has(tower)).is_true()
	tower.queue_free()


# -- 7. create_tower emits signal -----------------------------------------------

func test_create_tower_emits_signal() -> void:
	var data: TowerData = _make_tower_data("Fire", "fire", 30)
	monitor_signals(TowerSystem, false)
	TowerSystem.create_tower(data, Vector2i(5, 5))
	await assert_signal(TowerSystem).wait_until(500).is_emitted("tower_created")


# -- 8. upgrade_tower success ---------------------------------------------------

func test_upgrade_tower_success() -> void:
	var upgrade_data: TowerData = _make_tower_data("FireEnhanced", "fire", 50)
	var base_data: TowerData = _make_tower_data("Fire", "fire", 30, 1, upgrade_data)
	var tower: Node2D = auto_free(_make_tower_stub(base_data, Vector2i(5, 5)))

	# Give enough gold for the upgrade (incremental cost = 50 - 30 = 20)
	EconomyManager.reset()  # 100 gold
	var result: bool = TowerSystem.upgrade_tower(tower)
	assert_bool(result).is_true()
	assert_object(tower.tower_data).is_same(upgrade_data)


# -- 9. upgrade_tower spends incremental cost -----------------------------------

func test_upgrade_tower_spends_incremental_cost() -> void:
	var upgrade_data: TowerData = _make_tower_data("FireEnhanced", "fire", 50)
	var base_data: TowerData = _make_tower_data("Fire", "fire", 30, 1, upgrade_data)
	var tower: Node2D = auto_free(_make_tower_stub(base_data, Vector2i(5, 5)))

	EconomyManager.reset()  # 100 gold
	var gold_before: int = EconomyManager.gold
	TowerSystem.upgrade_tower(tower)
	# Incremental cost = upgrade.cost - base.cost = 50 - 30 = 20
	assert_int(EconomyManager.gold).is_equal(gold_before - 20)


# -- 10. upgrade_tower fails no upgrade -----------------------------------------

func test_upgrade_tower_fails_no_upgrade() -> void:
	# Tower with upgrade_to == null (fully upgraded / superior)
	var data: TowerData = _make_tower_data("Superior", "fire", 60)
	var tower: Node2D = auto_free(_make_tower_stub(data, Vector2i(5, 5)))

	var result: bool = TowerSystem.upgrade_tower(tower)
	assert_bool(result).is_false()


# -- 11. upgrade_tower fails insufficient gold ----------------------------------

func test_upgrade_tower_fails_insufficient_gold() -> void:
	var upgrade_data: TowerData = _make_tower_data("FireEnhanced", "fire", 9999)
	var base_data: TowerData = _make_tower_data("Fire", "fire", 30, 1, upgrade_data)
	var tower: Node2D = auto_free(_make_tower_stub(base_data, Vector2i(5, 5)))

	var gold_before: int = EconomyManager.gold
	var result: bool = TowerSystem.upgrade_tower(tower)
	assert_bool(result).is_false()
	assert_int(EconomyManager.gold).is_equal(gold_before)


# -- 12. upgrade_tower emits signal ---------------------------------------------

func test_upgrade_tower_emits_signal() -> void:
	var upgrade_data: TowerData = _make_tower_data("FireEnhanced", "fire", 50)
	var base_data: TowerData = _make_tower_data("Fire", "fire", 30, 1, upgrade_data)
	var tower: Node2D = auto_free(_make_tower_stub(base_data, Vector2i(5, 5)))

	monitor_signals(TowerSystem, false)
	TowerSystem.upgrade_tower(tower)
	await assert_signal(TowerSystem).wait_until(500).is_emitted("tower_upgraded")


# -- 13. sell_tower refund build phase (75%) ------------------------------------

func test_sell_tower_refund_build_phase() -> void:
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	var data: TowerData = _make_tower_data("Fire", "fire", 100)
	var tower: Node2D = auto_free(_make_tower_stub(data, Vector2i(5, 5)))
	TowerSystem._active_towers.append(tower)
	# Place tower on grid so remove_tower works
	GridManager.grid[5][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(5, 5)] = tower

	var gold_before: int = EconomyManager.gold
	TowerSystem.sell_tower(tower)
	# 75% of 100 = 75
	assert_int(EconomyManager.gold).is_equal(gold_before + 75)


# -- 14. sell_tower refund combat phase (50%) -----------------------------------

func test_sell_tower_refund_combat_phase() -> void:
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	var data: TowerData = _make_tower_data("Fire", "fire", 100)
	var tower: Node2D = auto_free(_make_tower_stub(data, Vector2i(5, 5)))
	TowerSystem._active_towers.append(tower)
	GridManager.grid[5][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(5, 5)] = tower

	var gold_before: int = EconomyManager.gold
	TowerSystem.sell_tower(tower)
	# 50% of 100 = 50
	assert_int(EconomyManager.gold).is_equal(gold_before + 50)


# -- 15. sell_tower removes from active -----------------------------------------

func test_sell_tower_removes_from_active() -> void:
	var data: TowerData = _make_tower_data("Fire", "fire", 30)
	var tower: Node2D = auto_free(_make_tower_stub(data, Vector2i(5, 5)))
	TowerSystem._active_towers.append(tower)
	GridManager.grid[5][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(5, 5)] = tower

	TowerSystem.sell_tower(tower)
	assert_bool(TowerSystem._active_towers.has(tower)).is_false()


# -- 16. sell_tower frees grid cell ---------------------------------------------

func test_sell_tower_frees_grid_cell() -> void:
	var data: TowerData = _make_tower_data("Fire", "fire", 30)
	var tower: Node2D = auto_free(_make_tower_stub(data, Vector2i(5, 5)))
	TowerSystem._active_towers.append(tower)
	GridManager.grid[5][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(5, 5)] = tower

	TowerSystem.sell_tower(tower)
	assert_int(GridManager.get_cell(Vector2i(5, 5))).is_equal(GridManager.CellType.BUILDABLE)


# -- 17. sell_tower emits signal ------------------------------------------------

func test_sell_tower_emits_signal() -> void:
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	var data: TowerData = _make_tower_data("Fire", "fire", 80)
	var tower: Node2D = auto_free(_make_tower_stub(data, Vector2i(5, 5)))
	TowerSystem._active_towers.append(tower)
	GridManager.grid[5][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(5, 5)] = tower

	monitor_signals(TowerSystem, false)
	TowerSystem.sell_tower(tower)
	# Signal: tower_sold(tower, refund) -- refund = 80 * 0.75 = 60
	await assert_signal(TowerSystem).wait_until(500).is_emitted("tower_sold", [tower, 60])


# -- 18. fuse_towers success ----------------------------------------------------

func test_fuse_towers_success() -> void:
	# Load the real fusion .tres to verify end-to-end
	var fire_superior: TowerData = _make_tower_data(
		"FireSuperior", "fire", 60, 1, null)
	var earth_superior: TowerData = _make_tower_data(
		"EarthSuperior", "earth", 70, 1, null)

	var tower_a: Node2D = auto_free(_make_tower_stub(fire_superior, Vector2i(5, 5)))
	var tower_b: Node2D = auto_free(_make_tower_stub(earth_superior, Vector2i(7, 5)))
	TowerSystem._active_towers.append(tower_a)
	TowerSystem._active_towers.append(tower_b)
	GridManager.grid[5][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(5, 5)] = tower_a
	GridManager.grid[7][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(7, 5)] = tower_b

	# Fusion cost is the result tower's cost (Magma Forge = 130)
	EconomyManager.add_gold(500)  # Ensure enough gold

	var result: bool = TowerSystem.fuse_towers(tower_a, tower_b)
	assert_bool(result).is_true()
	# tower_a should now have the fusion TowerData
	assert_str(tower_a.tower_data.tower_name).is_equal("Magma Forge")
	assert_int(tower_a.tower_data.tier).is_equal(2)


# -- 19. fuse_towers spends fusion cost -----------------------------------------

func test_fuse_towers_spends_fusion_cost() -> void:
	var fire_superior: TowerData = _make_tower_data(
		"FireSuperior", "fire", 60, 1, null)
	var earth_superior: TowerData = _make_tower_data(
		"EarthSuperior", "earth", 70, 1, null)

	var tower_a: Node2D = auto_free(_make_tower_stub(fire_superior, Vector2i(5, 5)))
	var tower_b: Node2D = auto_free(_make_tower_stub(earth_superior, Vector2i(7, 5)))
	TowerSystem._active_towers.append(tower_a)
	TowerSystem._active_towers.append(tower_b)
	GridManager.grid[5][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(5, 5)] = tower_a
	GridManager.grid[7][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(7, 5)] = tower_b

	EconomyManager.add_gold(500)
	var gold_before: int = EconomyManager.gold
	TowerSystem.fuse_towers(tower_a, tower_b)
	# Magma Forge cost is 130
	assert_int(EconomyManager.gold).is_equal(gold_before - 130)


# -- 20. fuse_towers removes tower B -------------------------------------------

func test_fuse_towers_removes_tower_b() -> void:
	var fire_superior: TowerData = _make_tower_data(
		"FireSuperior", "fire", 60, 1, null)
	var earth_superior: TowerData = _make_tower_data(
		"EarthSuperior", "earth", 70, 1, null)

	var tower_a: Node2D = auto_free(_make_tower_stub(fire_superior, Vector2i(5, 5)))
	var tower_b: Node2D = auto_free(_make_tower_stub(earth_superior, Vector2i(7, 5)))
	TowerSystem._active_towers.append(tower_a)
	TowerSystem._active_towers.append(tower_b)
	GridManager.grid[5][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(5, 5)] = tower_a
	GridManager.grid[7][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(7, 5)] = tower_b

	EconomyManager.add_gold(500)
	TowerSystem.fuse_towers(tower_a, tower_b)
	# tower_b should be removed from active towers
	assert_bool(TowerSystem._active_towers.has(tower_b)).is_false()
	# tower_b's grid cell should be freed
	assert_int(GridManager.get_cell(Vector2i(7, 5))).is_equal(GridManager.CellType.BUILDABLE)


# -- 21. fuse_towers replaces tower A ------------------------------------------

func test_fuse_towers_replaces_tower_a() -> void:
	var fire_superior: TowerData = _make_tower_data(
		"FireSuperior", "fire", 60, 1, null)
	var earth_superior: TowerData = _make_tower_data(
		"EarthSuperior", "earth", 70, 1, null)

	var tower_a: Node2D = auto_free(_make_tower_stub(fire_superior, Vector2i(5, 5)))
	var tower_b: Node2D = auto_free(_make_tower_stub(earth_superior, Vector2i(7, 5)))
	TowerSystem._active_towers.append(tower_a)
	TowerSystem._active_towers.append(tower_b)
	GridManager.grid[5][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(5, 5)] = tower_a
	GridManager.grid[7][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(7, 5)] = tower_b

	EconomyManager.add_gold(500)
	TowerSystem.fuse_towers(tower_a, tower_b)
	# tower_a should still be in active towers with updated data
	assert_bool(TowerSystem._active_towers.has(tower_a)).is_true()
	assert_str(tower_a.tower_data.tower_name).is_equal("Magma Forge")


# -- 22. fuse_towers fails invalid combo ---------------------------------------

func test_fuse_towers_fails_invalid_combo() -> void:
	# Same element -- cannot fuse
	var fire_a: TowerData = _make_tower_data("FireA", "fire", 60, 1, null)
	var fire_b: TowerData = _make_tower_data("FireB", "fire", 60, 1, null)

	var tower_a: Node2D = auto_free(_make_tower_stub(fire_a, Vector2i(5, 5)))
	var tower_b: Node2D = auto_free(_make_tower_stub(fire_b, Vector2i(7, 5)))
	TowerSystem._active_towers.append(tower_a)
	TowerSystem._active_towers.append(tower_b)

	EconomyManager.add_gold(500)
	var result: bool = TowerSystem.fuse_towers(tower_a, tower_b)
	assert_bool(result).is_false()


# -- 23. fuse_towers fails insufficient gold ------------------------------------

func test_fuse_towers_fails_insufficient_gold() -> void:
	var fire_superior: TowerData = _make_tower_data(
		"FireSuperior", "fire", 60, 1, null)
	var earth_superior: TowerData = _make_tower_data(
		"EarthSuperior", "earth", 70, 1, null)

	var tower_a: Node2D = auto_free(_make_tower_stub(fire_superior, Vector2i(5, 5)))
	var tower_b: Node2D = auto_free(_make_tower_stub(earth_superior, Vector2i(7, 5)))
	TowerSystem._active_towers.append(tower_a)
	TowerSystem._active_towers.append(tower_b)
	GridManager.grid[5][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(5, 5)] = tower_a
	GridManager.grid[7][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(7, 5)] = tower_b

	# Set gold to 0 so we can't afford the fusion
	EconomyManager.spend_gold(EconomyManager.gold)
	var gold_before: int = EconomyManager.gold
	var result: bool = TowerSystem.fuse_towers(tower_a, tower_b)
	assert_bool(result).is_false()
	assert_int(EconomyManager.gold).is_equal(gold_before)


# -- 24. fuse_towers emits signal -----------------------------------------------

func test_fuse_towers_emits_signal() -> void:
	var fire_superior: TowerData = _make_tower_data(
		"FireSuperior", "fire", 60, 1, null)
	var earth_superior: TowerData = _make_tower_data(
		"EarthSuperior", "earth", 70, 1, null)

	var tower_a: Node2D = auto_free(_make_tower_stub(fire_superior, Vector2i(5, 5)))
	var tower_b: Node2D = auto_free(_make_tower_stub(earth_superior, Vector2i(7, 5)))
	TowerSystem._active_towers.append(tower_a)
	TowerSystem._active_towers.append(tower_b)
	GridManager.grid[5][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(5, 5)] = tower_a
	GridManager.grid[7][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(7, 5)] = tower_b

	EconomyManager.add_gold(500)
	monitor_signals(TowerSystem, false)
	TowerSystem.fuse_towers(tower_a, tower_b)
	await assert_signal(TowerSystem).wait_until(500).is_emitted("tower_fused")


# -- 25. fuse_legendary success -------------------------------------------------

func test_fuse_legendary_success() -> void:
	# Tier 2 Magma Forge (earth+fire) + Superior water tower -> Primordial Nexus (tier 3)
	var tier2_data: TowerData = _make_tower_data(
		"MagmaForge", "earth", 130, 2, null, ["earth", "fire"] as Array[String])
	var superior_data: TowerData = _make_tower_data(
		"WaterSuperior", "water", 60, 1, null)

	var tower_tier2: Node2D = auto_free(_make_tower_stub(tier2_data, Vector2i(5, 5)))
	var tower_sup: Node2D = auto_free(_make_tower_stub(superior_data, Vector2i(7, 5)))
	TowerSystem._active_towers.append(tower_tier2)
	TowerSystem._active_towers.append(tower_sup)
	GridManager.grid[5][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(5, 5)] = tower_tier2
	GridManager.grid[7][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(7, 5)] = tower_sup

	EconomyManager.add_gold(1000)

	var result: bool = TowerSystem.fuse_legendary(tower_tier2, tower_sup)
	assert_bool(result).is_true()
	# tower_tier2 should now have Primordial Nexus data
	assert_str(tower_tier2.tower_data.tower_name).is_equal("Primordial Nexus")
	assert_int(tower_tier2.tower_data.tier).is_equal(3)
	# tower_sup should be removed from active
	assert_bool(TowerSystem._active_towers.has(tower_sup)).is_false()


# -- 26. fuse_legendary fails invalid -------------------------------------------

func test_fuse_legendary_fails_invalid() -> void:
	# Two tier 1 towers -- cannot do legendary fusion
	var fire_data: TowerData = _make_tower_data("FireSup", "fire", 60, 1, null)
	var water_data: TowerData = _make_tower_data("WaterSup", "water", 60, 1, null)

	var tower_a: Node2D = auto_free(_make_tower_stub(fire_data, Vector2i(5, 5)))
	var tower_b: Node2D = auto_free(_make_tower_stub(water_data, Vector2i(7, 5)))
	TowerSystem._active_towers.append(tower_a)
	TowerSystem._active_towers.append(tower_b)

	EconomyManager.add_gold(1000)
	var result: bool = TowerSystem.fuse_legendary(tower_a, tower_b)
	assert_bool(result).is_false()


# -- 27. get_active_towers returns list -----------------------------------------

func test_get_active_towers_returns_list() -> void:
	assert_int(TowerSystem.get_active_towers().size()).is_equal(0)

	var data_a: TowerData = _make_tower_data("A", "fire", 30)
	var data_b: TowerData = _make_tower_data("B", "water", 30)
	var tower_a: Node2D = auto_free(_make_tower_stub(data_a, Vector2i(5, 5)))
	var tower_b: Node2D = auto_free(_make_tower_stub(data_b, Vector2i(7, 5)))
	TowerSystem._active_towers.append(tower_a)
	TowerSystem._active_towers.append(tower_b)

	var active: Array[Node] = TowerSystem.get_active_towers()
	assert_int(active.size()).is_equal(2)
	assert_bool(active.has(tower_a)).is_true()
	assert_bool(active.has(tower_b)).is_true()
