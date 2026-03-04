extends GdUnitTestSuite

## Unit tests for TowerSystem.fusion_failed signal emission on all fusion failure paths.
## Covers: fuse_towers invalid combo, fuse_towers cant afford, fuse_towers success (no signal),
## fuse_legendary invalid combo, fuse_legendary cant afford, fuse_legendary success (no signal).


# -- Signal capture state ------------------------------------------------------

var _last_fail_tower: Node = null
var _last_fail_reason: String = ""
var _fail_count: Array[int] = [0]


func _on_fusion_failed(tower: Node, reason: String) -> void:
	_last_fail_tower = tower
	_last_fail_reason = reason
	_fail_count[0] += 1


# -- Helpers (same pattern as test_tower_system.gd) ----------------------------

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


func _make_tower_stub(data: TowerData, grid_pos: Vector2i = Vector2i.ZERO) -> Node2D:
	var stub := Node2D.new()
	stub.set_script(_tower_stub_script())
	stub.tower_data = data
	stub.grid_position = grid_pos
	stub.position = GridManager.grid_to_world(grid_pos)
	return stub


func _reset_grid_manager() -> void:
	GridManager._initialize_grid()
	GridManager._tower_map.clear()
	GridManager.spawn_points.clear()
	GridManager.exit_points.clear()


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
	for tower: Node in TowerSystem._active_towers:
		if is_instance_valid(tower) and not tower.is_queued_for_deletion():
			tower.free()
	TowerSystem._active_towers.clear()


func _reset_game_manager() -> void:
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = 0
	GameManager.lives = GameManager.starting_lives
	GameManager._build_timer = 0.0
	GameManager._enemies_leaked_this_wave = 0


func _reset_enemy_system() -> void:
	for enemy: Node in EnemySystem._active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.free()
	EnemySystem._active_enemies.clear()
	EnemySystem._enemies_to_spawn.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._spawn_timer = 0.0


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_reset_tower_system()
	_reset_game_manager()
	_reset_grid_manager()
	_reset_enemy_system()
	EconomyManager.reset()
	_setup_minimal_map()
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	# Reset signal capture state
	_last_fail_tower = null
	_last_fail_reason = ""
	_fail_count[0] = 0
	# Connect signal listener
	TowerSystem.fusion_failed.connect(_on_fusion_failed)


func after_test() -> void:
	# Disconnect signal listener
	if TowerSystem.fusion_failed.is_connected(_on_fusion_failed):
		TowerSystem.fusion_failed.disconnect(_on_fusion_failed)
	_reset_tower_system()
	_reset_enemy_system()


func after() -> void:
	_stub_script = null


# -- 1. fuse_towers emits fusion_failed on invalid combo ----------------------

func test_fuse_towers_emits_fusion_failed_on_invalid_combo() -> void:
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
	assert_int(_fail_count[0]).is_equal(1)
	assert_object(_last_fail_tower).is_same(tower_a)
	assert_str(_last_fail_reason).is_equal(TowerSystem.FUSE_FAIL_INVALID_COMBO)


# -- 2. fuse_towers emits fusion_failed on cant afford ------------------------

func test_fuse_towers_emits_fusion_failed_on_cant_afford() -> void:
	var fire_superior: TowerData = _make_tower_data("FireSup", "fire", 60, 1, null)
	var earth_superior: TowerData = _make_tower_data("EarthSup", "earth", 70, 1, null)
	var tower_a: Node2D = auto_free(_make_tower_stub(fire_superior, Vector2i(5, 5)))
	var tower_b: Node2D = auto_free(_make_tower_stub(earth_superior, Vector2i(7, 5)))
	TowerSystem._active_towers.append(tower_a)
	TowerSystem._active_towers.append(tower_b)
	GridManager.grid[5][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(5, 5)] = tower_a
	GridManager.grid[7][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(7, 5)] = tower_b
	# Drain all gold
	EconomyManager.spend_gold(EconomyManager.gold)

	var result: bool = TowerSystem.fuse_towers(tower_a, tower_b)

	assert_bool(result).is_false()
	assert_int(_fail_count[0]).is_equal(1)
	assert_object(_last_fail_tower).is_same(tower_a)
	assert_str(_last_fail_reason).contains("Not enough gold")
	assert_str(_last_fail_reason).contains("130")


# -- 3. fuse_towers does NOT emit fusion_failed on success --------------------

func test_fuse_towers_no_signal_on_success() -> void:
	var fire_superior: TowerData = _make_tower_data("FireSup", "fire", 60, 1, null)
	var earth_superior: TowerData = _make_tower_data("EarthSup", "earth", 70, 1, null)
	var tower_a: Node2D = auto_free(_make_tower_stub(fire_superior, Vector2i(5, 5)))
	var tower_b: Node2D = auto_free(_make_tower_stub(earth_superior, Vector2i(7, 5)))
	TowerSystem._active_towers.append(tower_a)
	TowerSystem._active_towers.append(tower_b)
	GridManager.grid[5][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(5, 5)] = tower_a
	GridManager.grid[7][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(7, 5)] = tower_b
	EconomyManager.add_gold(500)

	var result: bool = TowerSystem.fuse_towers(tower_a, tower_b)

	assert_bool(result).is_true()
	assert_int(_fail_count[0]).is_equal(0)


# -- 4. fuse_legendary emits fusion_failed on invalid combo -------------------

func test_fuse_legendary_emits_fusion_failed_on_invalid_combo() -> void:
	# Two tier-1 towers -- cannot do legendary fusion
	var fire_data: TowerData = _make_tower_data("FireSup", "fire", 60, 1, null)
	var water_data: TowerData = _make_tower_data("WaterSup", "water", 60, 1, null)
	var tower_a: Node2D = auto_free(_make_tower_stub(fire_data, Vector2i(5, 5)))
	var tower_b: Node2D = auto_free(_make_tower_stub(water_data, Vector2i(7, 5)))
	TowerSystem._active_towers.append(tower_a)
	TowerSystem._active_towers.append(tower_b)
	EconomyManager.add_gold(1000)

	var result: bool = TowerSystem.fuse_legendary(tower_a, tower_b)

	assert_bool(result).is_false()
	assert_int(_fail_count[0]).is_equal(1)
	assert_object(_last_fail_tower).is_same(tower_a)
	assert_str(_last_fail_reason).is_equal(TowerSystem.FUSE_FAIL_INVALID_COMBO)


# -- 5. fuse_legendary emits fusion_failed on cant afford ---------------------

func test_fuse_legendary_emits_fusion_failed_on_cant_afford() -> void:
	# Tier 2 Magma Forge (earth+fire) + Superior water -> Primordial Nexus
	var tier2_data: TowerData = _make_tower_data(
		"MagmaForge", "earth", 130, 2, null, ["earth", "fire"] as Array[String])
	var superior_data: TowerData = _make_tower_data("WaterSup", "water", 60, 1, null)
	var tower_tier2: Node2D = auto_free(_make_tower_stub(tier2_data, Vector2i(5, 5)))
	var tower_sup: Node2D = auto_free(_make_tower_stub(superior_data, Vector2i(7, 5)))
	TowerSystem._active_towers.append(tower_tier2)
	TowerSystem._active_towers.append(tower_sup)
	GridManager.grid[5][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(5, 5)] = tower_tier2
	GridManager.grid[7][5] = GridManager.CellType.TOWER
	GridManager._tower_map[Vector2i(7, 5)] = tower_sup
	# Drain all gold
	EconomyManager.spend_gold(EconomyManager.gold)

	var result: bool = TowerSystem.fuse_legendary(tower_tier2, tower_sup)

	assert_bool(result).is_false()
	assert_int(_fail_count[0]).is_equal(1)
	assert_object(_last_fail_tower).is_same(tower_tier2)
	assert_str(_last_fail_reason).contains("Not enough gold")
	# Primordial Nexus cost should be in the message
	assert_str(_last_fail_reason).contains("g")


# -- 6. fuse_legendary does NOT emit fusion_failed on success -----------------

func test_fuse_legendary_no_signal_on_success() -> void:
	var tier2_data: TowerData = _make_tower_data(
		"MagmaForge", "earth", 130, 2, null, ["earth", "fire"] as Array[String])
	var superior_data: TowerData = _make_tower_data("WaterSup", "water", 60, 1, null)
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
	assert_int(_fail_count[0]).is_equal(0)
