extends GdUnitTestSuite

## Integration tests for tower-enemy combat flow.
## Verifies that multiple systems (Tower, Projectile, Enemy, EnemySystem,
## TowerSystem, EconomyManager, GameManager, GridManager, PathfindingSystem)
## work together correctly during combat.
##
## All nodes are constructed manually in-memory to avoid loading scene files
## that require sprite textures (which fail in headless mode).


# -- Helpers -------------------------------------------------------------------

## Create a minimal TowerData resource for testing.
func _make_tower_data(
	p_name: String = "TestTower",
	p_element: String = "fire",
	p_damage: int = 100,
	p_attack_speed: float = 1.0,
	p_range_cells: int = 4,
	p_special_key: String = "",
	p_special_value: float = 0.0,
	p_special_duration: float = 0.0,
	p_special_chance: float = 1.0,
	p_chain_damage_fraction: float = 0.0,
	p_aoe_radius_cells: float = 0.0,
	p_tier: int = 1,
	p_cost: int = 30,
	p_fusion_elements: Array[String] = [],
	p_upgrade_to: TowerData = null
) -> TowerData:
	var data := TowerData.new()
	data.tower_name = p_name
	data.element = p_element
	data.damage = p_damage
	data.attack_speed = p_attack_speed
	data.range_cells = p_range_cells
	data.damage_type = p_element
	data.special_key = p_special_key
	data.special_value = p_special_value
	data.special_duration = p_special_duration
	data.special_chance = p_special_chance
	data.chain_damage_fraction = p_chain_damage_fraction
	data.aoe_radius_cells = p_aoe_radius_cells
	data.tier = p_tier
	data.cost = p_cost
	data.fusion_elements = p_fusion_elements
	data.upgrade_to = p_upgrade_to
	return data


## Create a minimal EnemyData resource for testing.
func _make_enemy_data(
	p_name: String = "TestEnemy",
	p_health: int = 100,
	p_speed: float = 1.0,
	p_gold: int = 3,
	p_element: String = "none",
	p_immune_element: String = "",
	p_weak_element: String = ""
) -> EnemyData:
	var data := EnemyData.new()
	data.enemy_name = p_name
	data.base_health = p_health
	data.speed_multiplier = p_speed
	data.gold_reward = p_gold
	data.element = p_element
	data.immune_element = p_immune_element
	data.weak_element = p_weak_element
	data.spawn_count = 1
	return data


## Build a real Tower node with child nodes (Sprite2D, CollisionShape2D, Timer)
## so @onready references resolve. Avoids loading BaseTower.tscn.
static var _tower_script: GDScript = null
func _create_tower(data: TowerData) -> Area2D:
	if _tower_script == null:
		_tower_script = load("res://scripts/towers/Tower.gd") as GDScript

	var tower := Area2D.new()

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	tower.add_child(sprite)

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = 256.0
	collision.shape = shape
	tower.add_child(collision)

	var timer := Timer.new()
	timer.name = "AttackCooldown"
	timer.one_shot = true
	tower.add_child(timer)

	tower.set_script(_tower_script)

	# Prevent _ready() from calling apply_tower_data (texture load)
	tower.tower_data = null

	# Set synergy defaults to bypass ElementSynergy queries
	tower._synergy_damage_mult = 1.0
	tower._synergy_attack_speed_bonus = 0.0
	tower._synergy_range_bonus_cells = 0
	tower._synergy_chain_bonus = 0
	tower._synergy_freeze_chance_bonus = 0.0
	tower._synergy_slow_bonus = 0.0
	tower._synergy_color = Color.WHITE

	tower.tower_data = data

	# Manually apply stats (skip texture load in apply_tower_data)
	var effective_range_cells: float = data.range_cells + tower._synergy_range_bonus_cells
	tower._range_pixels = effective_range_cells * GridManager.CELL_SIZE
	var range_shape := CircleShape2D.new()
	range_shape.radius = tower._range_pixels
	collision.shape = range_shape
	if data.attack_speed > 0.0:
		var effective_speed: float = data.attack_speed * (1.0 + tower._synergy_attack_speed_bonus)
		timer.wait_time = 1.0 / effective_speed
		timer.one_shot = true
	tower._ability_timer = 0.0
	if data.special_key == "geyser":
		tower._ability_interval = data.special_duration
	elif data.special_key == "stun_amplify":
		tower._ability_interval = 8.0
	else:
		tower._ability_interval = 0.0

	return tower


## Build a real Enemy node with child nodes (Sprite2D, ProgressBar)
## so @onready references resolve. Avoids loading BaseEnemy.tscn.
static var _enemy_script: GDScript = null
func _create_enemy(data: EnemyData, path_pts: PackedVector2Array = PackedVector2Array()) -> Node2D:
	if _enemy_script == null:
		_enemy_script = load("res://scripts/enemies/Enemy.gd") as GDScript

	var enemy := Node2D.new()

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	enemy.add_child(sprite)

	var health_bar := ProgressBar.new()
	health_bar.name = "HealthBar"
	enemy.add_child(health_bar)

	enemy.set_script(_enemy_script)

	# Manually set @onready references since the node is not in the scene tree.
	enemy.sprite = sprite
	enemy.health_bar = health_bar

	# Prevent _apply_enemy_data texture load
	enemy.enemy_data = null
	enemy.path_points = path_pts

	# Manually apply fields
	enemy.max_health = data.base_health
	enemy.current_health = data.base_health
	enemy.speed = 64.0 * data.speed_multiplier
	enemy._base_speed = 64.0

	enemy.enemy_data = data

	if not path_pts.is_empty():
		enemy.position = path_pts[0]

	return enemy


## Create a simple linear path of N points, each 64px apart.
func _make_path(num_points: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(num_points):
		pts.append(Vector2(float(i) * 64.0, 0.0))
	return pts


## Returns a minimal GDScript for tower stubs used with TowerSystem.
static var _tower_stub_script: GDScript = null
func _get_tower_stub_script() -> GDScript:
	if _tower_stub_script != null:
		return _tower_stub_script
	_tower_stub_script = GDScript.new()
	_tower_stub_script.source_code = """
extends Node2D

var tower_data: TowerData
var grid_position: Vector2i = Vector2i.ZERO

func apply_tower_data() -> void:
	pass
"""
	_tower_stub_script.reload()
	return _tower_stub_script


## Create a tower stub for TowerSystem operations (sell, etc.)
func _make_tower_stub(data: TowerData, grid_pos: Vector2i = Vector2i.ZERO) -> Node2D:
	var stub := Node2D.new()
	stub.set_script(_get_tower_stub_script())
	stub.tower_data = data
	stub.grid_position = grid_pos
	stub.position = GridManager.grid_to_world(grid_pos)
	return stub


## Create a PackedScene that produces a tower stub for TowerSystem._tower_scene.
func _create_tower_stub_scene() -> PackedScene:
	var scene := PackedScene.new()
	var node := Node2D.new()
	node.name = "StubTower"
	node.set_script(_get_tower_stub_script())
	scene.pack(node)
	node.free()
	return scene


## Returns a minimal GDScript for enemy stubs used with EnemySystem spawning.
static var _enemy_stub_gd: GDScript = null
func _get_enemy_stub_script() -> GDScript:
	if _enemy_stub_gd != null:
		return _enemy_stub_gd
	_enemy_stub_gd = GDScript.new()
	_enemy_stub_gd.source_code = """
extends Node2D

var enemy_data: EnemyData
var path_points: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
"""
	_enemy_stub_gd.reload()
	return _enemy_stub_gd


## Create a PackedScene for EnemySystem._enemy_scene swapping.
func _create_enemy_stub_scene() -> PackedScene:
	var scene := PackedScene.new()
	var node := Node2D.new()
	node.name = "StubEnemy"
	node.set_script(_get_enemy_stub_script())
	scene.pack(node)
	node.free()
	return scene


## Reset GridManager to a clean all-buildable grid.
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


func _reset_autoloads() -> void:
	# EnemySystem
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn.clear()
	# TowerSystem -- use free() since towers are not in the scene tree
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
	# Projectile static state
	Projectile._ground_effect_scene = null
	# Grid
	_setup_minimal_map()


# Save/restore original scenes to avoid polluting other test suites
var _original_tower_scene: PackedScene
var _original_enemy_scene: PackedScene


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_tower_scene = TowerSystem._tower_scene
	_original_enemy_scene = EnemySystem._enemy_scene


func before_test() -> void:
	_reset_autoloads()
	# Swap scenes with stubs for any tests that call TowerSystem/EnemySystem create
	TowerSystem._tower_scene = _create_tower_stub_scene()
	EnemySystem._enemy_scene = _create_enemy_stub_scene()


func after_test() -> void:
	# Clean up active lists -- use free() instead of queue_free() since these
	# nodes are not in the scene tree (queue_free requires tree frame processing)
	for tower: Node in TowerSystem._active_towers:
		if is_instance_valid(tower) and not tower.is_queued_for_deletion():
			tower.free()
	TowerSystem._active_towers.clear()
	for enemy: Node in EnemySystem._active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.free()
	EnemySystem._active_enemies.clear()
	# Restore original scenes
	TowerSystem._tower_scene = _original_tower_scene
	EnemySystem._enemy_scene = _original_enemy_scene


func after() -> void:
	# Clear static script caches to prevent resource leaks at process exit
	_tower_script = null
	_enemy_script = null
	_tower_stub_script = null
	_enemy_stub_gd = null


# ==============================================================================
# TEST 1: Tower kills enemy awards gold
# ==============================================================================

func test_tower_kills_enemy_awards_gold() -> void:
	# Set up combat phase
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 1

	# Create a weak enemy in range of a powerful tower
	var enemy_data: EnemyData = _make_enemy_data("Weakling", 50, 1.0, 10, "earth")
	var path: PackedVector2Array = _make_path(5)
	var enemy: Node2D = auto_free(_create_enemy(enemy_data, path))
	enemy.position = Vector2(210.0, 0.0)
	EnemySystem._active_enemies.append(enemy)
	EnemySystem._wave_finished_spawning = true

	# Create a fire tower that does 100 damage (fire vs earth = 1.5x = 150 > 50 HP)
	var tower_data: TowerData = _make_tower_data("FlameSpire", "fire", 100, 1.0, 10)
	var tower: Area2D = auto_free(_create_tower(tower_data))
	tower.position = Vector2(200.0, 0.0)

	var gold_before: int = EconomyManager.gold

	# Fire a projectile at the enemy via _attack -- the projectile carries
	# tower's calculated damage. We capture and manually trigger hit.
	var captured_projectiles: Array = []
	tower.projectile_spawned.connect(func(proj: Node) -> void: captured_projectiles.append(proj))
	tower._attack(enemy)

	assert_int(captured_projectiles.size()).is_equal(1)
	var proj: Node = captured_projectiles[0]

	# The projectile has calculated damage. Apply it via single hit.
	proj._apply_single_hit()

	# Enemy should be dead (150 damage > 50 HP), gold should increase by 10
	assert_int(enemy.current_health).is_less_equal(0)
	assert_int(EconomyManager.gold).is_equal(gold_before + enemy_data.gold_reward)

	proj.free()


# ==============================================================================
# TEST 2: Burn tower applies DOT to enemy
# ==============================================================================

func test_burn_tower_applies_dot_to_enemy() -> void:
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 1

	# Create an enemy with enough HP to survive the initial hit
	var enemy_data: EnemyData = _make_enemy_data("Tanky", 500, 1.0, 5, "none")
	var path: PackedVector2Array = _make_path(5)
	var enemy: Node2D = auto_free(_create_enemy(enemy_data, path))
	enemy.position = Vector2(210.0, 0.0)
	EnemySystem._active_enemies.append(enemy)
	EnemySystem._wave_finished_spawning = true

	# Create a fire tower with burn special (100% chance)
	var tower_data: TowerData = _make_tower_data(
		"FlameSpire", "fire", 50, 1.0, 10,
		"burn", 20.0, 3.0, 1.0)  # 20 dps burn for 3 seconds
	var tower: Area2D = auto_free(_create_tower(tower_data))
	tower.position = Vector2(200.0, 0.0)

	# Fire projectile and apply hit
	var captured_projectiles: Array = []
	tower.projectile_spawned.connect(func(proj: Node) -> void: captured_projectiles.append(proj))
	tower._attack(enemy)
	var proj: Node = captured_projectiles[0]
	proj._apply_single_hit()

	# Enemy should have BURN status
	assert_bool(enemy.has_status(StatusEffect.Type.BURN)).is_true()

	# Record health after initial hit
	var health_after_hit: int = enemy.current_health

	# Process status effects for 1 second -- burn should tick
	enemy._process_status_effects(1.0)

	# Health should have decreased further from burn DOT
	assert_int(enemy.current_health).is_less(health_after_hit)

	proj.free()


# ==============================================================================
# TEST 3: Slow tower reduces enemy speed
# ==============================================================================

func test_slow_tower_reduces_enemy_speed() -> void:
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 1

	# Create an enemy
	var enemy_data: EnemyData = _make_enemy_data("Runner", 500, 1.0, 5, "none")
	var path: PackedVector2Array = _make_path(10)
	var enemy: Node2D = auto_free(_create_enemy(enemy_data, path))
	enemy.position = Vector2(210.0, 0.0)
	EnemySystem._active_enemies.append(enemy)
	EnemySystem._wave_finished_spawning = true

	var base_speed: float = enemy.speed

	# Create a water tower with slow special (30% slow, 100% chance)
	var tower_data: TowerData = _make_tower_data(
		"TidalObelisk", "water", 50, 1.0, 10,
		"slow", 0.3, 3.0, 1.0)
	var tower: Area2D = auto_free(_create_tower(tower_data))
	tower.position = Vector2(200.0, 0.0)

	# Fire projectile and apply hit
	var captured_projectiles: Array = []
	tower.projectile_spawned.connect(func(proj: Node) -> void: captured_projectiles.append(proj))
	tower._attack(enemy)
	var proj: Node = captured_projectiles[0]
	proj._apply_single_hit()

	# Enemy should have SLOW status and reduced speed
	assert_bool(enemy.has_status(StatusEffect.Type.SLOW)).is_true()
	var expected_speed: float = base_speed * 0.7
	assert_float(enemy.speed).is_equal_approx(expected_speed, 0.01)

	proj.free()


# ==============================================================================
# TEST 4: AoE tower hits multiple enemies
# ==============================================================================

func test_aoe_tower_hits_multiple_enemies() -> void:
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 1

	# Create 3 enemies clustered together
	var path: PackedVector2Array = _make_path(10)
	var e1: Node2D = auto_free(_create_enemy(_make_enemy_data("E1", 200, 1.0, 3, "none"), path))
	var e2: Node2D = auto_free(_create_enemy(_make_enemy_data("E2", 200, 1.0, 3, "none"), path))
	var e3: Node2D = auto_free(_create_enemy(_make_enemy_data("E3", 200, 1.0, 3, "none"), path))
	e1.position = Vector2(200.0, 0.0)
	e2.position = Vector2(220.0, 0.0)
	e3.position = Vector2(200.0, 20.0)
	EnemySystem._active_enemies.append(e1)
	EnemySystem._active_enemies.append(e2)
	EnemySystem._active_enemies.append(e3)
	EnemySystem._wave_finished_spawning = true

	# Create an earth AoE tower (aoe_radius_cells=2 -> 128px radius)
	var tower_data: TowerData = _make_tower_data(
		"StoneBastion", "earth", 80, 1.0, 10,
		"", 0.0, 0.0, 1.0, 0.0, 2.0)
	var tower: Area2D = auto_free(_create_tower(tower_data))
	tower.position = Vector2(200.0, 0.0)

	# Fire projectile -- AoE should hit all 3 enemies
	var captured_projectiles: Array = []
	tower.projectile_spawned.connect(func(proj: Node) -> void: captured_projectiles.append(proj))
	tower._attack(e1)
	var proj: Node = captured_projectiles[0]

	# The tower sets is_aoe and aoe_radius_px on projectiles for AoE towers
	assert_bool(proj.is_aoe).is_true()

	# Position projectile at impact point (target position)
	proj.global_position = e1.position
	proj._apply_aoe_hit()

	# All 3 enemies within 128px should have taken damage
	assert_int(e1.current_health).is_less(200)
	assert_int(e2.current_health).is_less(200)
	assert_int(e3.current_health).is_less(200)

	proj.free()


# ==============================================================================
# TEST 5: Chain lightning chains to secondaries
# ==============================================================================

func test_chain_lightning_chains_to_secondaries() -> void:
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 1

	# Create primary target and 2 secondary targets in chain range (128px)
	var path: PackedVector2Array = _make_path(10)
	var primary: Node2D = auto_free(_create_enemy(
		_make_enemy_data("Primary", 300, 1.0, 3, "none"), path))
	var sec1: Node2D = auto_free(_create_enemy(
		_make_enemy_data("Sec1", 300, 1.0, 3, "none"), path))
	var sec2: Node2D = auto_free(_create_enemy(
		_make_enemy_data("Sec2", 300, 1.0, 3, "none"), path))
	primary.position = Vector2(200.0, 0.0)
	sec1.position = Vector2(240.0, 0.0)   # 40px from primary
	sec2.position = Vector2(200.0, 40.0)  # 40px from primary
	EnemySystem._active_enemies.append(primary)
	EnemySystem._active_enemies.append(sec1)
	EnemySystem._active_enemies.append(sec2)
	EnemySystem._wave_finished_spawning = true

	# Thunder Pylon: chain=3, chain_damage_fraction=0.5
	var tower_data: TowerData = _make_tower_data(
		"ThunderPylon", "lightning", 100, 1.0, 10,
		"chain", 3.0, 0.0, 1.0, 0.5)
	var tower: Area2D = auto_free(_create_tower(tower_data))
	tower.position = Vector2(200.0, 0.0)

	var captured_projectiles: Array = []
	tower.projectile_spawned.connect(func(proj: Node) -> void: captured_projectiles.append(proj))
	tower._attack(primary)
	var proj: Node = captured_projectiles[0]

	# Apply primary hit (single hit path)
	proj.global_position = primary.position
	proj._apply_single_hit()
	var primary_health_after: int = primary.current_health

	# Apply chain hits to secondaries
	proj._apply_chain_hits()

	# Primary took full damage from single hit
	assert_int(primary_health_after).is_less(300)
	# Secondaries took chain damage (50% of calculated chain damage)
	assert_int(sec1.current_health).is_less(300)
	assert_int(sec2.current_health).is_less(300)

	proj.free()


# ==============================================================================
# TEST 6: Multi tower fires at two targets
# ==============================================================================

func test_multi_tower_fires_at_two_targets() -> void:
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 1

	# Create 3 enemies in range
	var path: PackedVector2Array = _make_path(10)
	var e1: Node2D = auto_free(_create_enemy(
		_make_enemy_data("E1", 200, 1.0, 3, "none"), path))
	var e2: Node2D = auto_free(_create_enemy(
		_make_enemy_data("E2", 200, 1.0, 3, "none"), path))
	var e3: Node2D = auto_free(_create_enemy(
		_make_enemy_data("E3", 200, 1.0, 3, "none"), path))
	e1.position = Vector2(210.0, 0.0)
	e1.path_progress = 0.8
	e2.position = Vector2(220.0, 0.0)
	e2.path_progress = 0.5
	e3.position = Vector2(230.0, 0.0)
	e3.path_progress = 0.2
	EnemySystem._active_enemies.append(e1)
	EnemySystem._active_enemies.append(e2)
	EnemySystem._active_enemies.append(e3)
	EnemySystem._wave_finished_spawning = true

	# Gale Tower: special_key="multi", special_value=2 (fires at 2 targets)
	var tower_data: TowerData = _make_tower_data(
		"GaleTower", "wind", 80, 1.0, 10,
		"multi", 2.0)
	var tower: Area2D = auto_free(_create_tower(tower_data))
	tower.position = Vector2(200.0, 0.0)

	var captured_projectiles: Array = []
	tower.projectile_spawned.connect(func(proj: Node) -> void: captured_projectiles.append(proj))
	tower._attack(e1)

	# Multi tower should spawn 2 projectiles (one per target)
	assert_int(captured_projectiles.size()).is_equal(2)

	for proj: Node in captured_projectiles:
		proj.free()


# ==============================================================================
# TEST 7: Freeze stops enemy movement
# ==============================================================================

func test_freeze_stops_enemy_movement() -> void:
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 1

	# Create an enemy on a path
	var path: PackedVector2Array = _make_path(10)
	var enemy_data: EnemyData = _make_enemy_data("FreezeTarget", 500, 1.0, 5, "none")
	var enemy: Node2D = auto_free(_create_enemy(enemy_data, path))
	enemy.position = Vector2(210.0, 0.0)
	EnemySystem._active_enemies.append(enemy)
	EnemySystem._wave_finished_spawning = true

	# Create a frost tower with freeze special (100% chance)
	var tower_data: TowerData = _make_tower_data(
		"FrostSentinel", "ice", 50, 1.0, 10,
		"freeze", 1.0, 3.0, 1.0)
	var tower: Area2D = auto_free(_create_tower(tower_data))
	tower.position = Vector2(200.0, 0.0)

	var captured_projectiles: Array = []
	tower.projectile_spawned.connect(func(proj: Node) -> void: captured_projectiles.append(proj))
	tower._attack(enemy)
	var proj: Node = captured_projectiles[0]
	proj._apply_single_hit()

	# Enemy should have FREEZE status and speed == 0
	assert_bool(enemy.has_status(StatusEffect.Type.FREEZE)).is_true()
	assert_float(enemy.speed).is_equal(0.0)

	# Verify enemy does not move when frozen
	var pos_before: Vector2 = enemy.position
	enemy._move_along_path(0.5)
	assert_vector(enemy.position).is_equal(pos_before)

	proj.free()


# ==============================================================================
# TEST 8: Tower upgrade increases damage
# ==============================================================================

func test_tower_upgrade_increases_damage() -> void:
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 1

	# Create the upgrade data with higher damage
	var upgrade_data: TowerData = _make_tower_data(
		"FlameSpireEnhanced", "fire", 200, 1.0, 10,
		"", 0.0, 0.0, 1.0, 0.0, 0.0, 1, 50)
	var base_data: TowerData = _make_tower_data(
		"FlameSpire", "fire", 100, 1.0, 10,
		"", 0.0, 0.0, 1.0, 0.0, 0.0, 1, 30, [], upgrade_data)

	var tower: Area2D = auto_free(_create_tower(base_data))
	tower.position = Vector2(200.0, 0.0)

	# Create a "none" element enemy so multiplier is 1.0
	var path: PackedVector2Array = _make_path(5)
	var enemy: Node2D = auto_free(_create_enemy(
		_make_enemy_data("Target", 1000, 1.0, 5, "none"), path))
	enemy.position = Vector2(210.0, 0.0)
	EnemySystem._active_enemies.append(enemy)

	# Calculate damage before upgrade
	var dmg_before: int = tower._calculate_damage(enemy)
	assert_int(dmg_before).is_equal(100)

	# Upgrade the tower: swap tower_data and re-apply stats
	tower.tower_data = upgrade_data
	# Manually re-apply stats (like apply_tower_data minus texture load)
	tower._range_pixels = upgrade_data.range_cells * GridManager.CELL_SIZE

	# Calculate damage after upgrade
	var dmg_after: int = tower._calculate_damage(enemy)
	assert_int(dmg_after).is_equal(200)

	# Damage should have doubled
	assert_int(dmg_after).is_greater(dmg_before)


# ==============================================================================
# TEST 9: Selling tower reopens path
# ==============================================================================

func test_selling_tower_reopens_path() -> void:
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.BUILD_PHASE

	# Place a tower on the grid via TowerSystem
	var tower_data: TowerData = _make_tower_data("Fire", "fire", 30, 1, 4)
	var grid_pos := Vector2i(5, 5)

	# Use TowerSystem.create_tower with the stub scene
	var tower: Node = TowerSystem.create_tower(tower_data, grid_pos)
	assert_object(tower).is_not_null()

	# Verify the grid cell is now TOWER
	assert_int(GridManager.get_cell(grid_pos)).is_equal(GridManager.CellType.TOWER)

	# Sell the tower
	TowerSystem.sell_tower(tower)

	# Grid cell should revert to BUILDABLE
	assert_int(GridManager.get_cell(grid_pos)).is_equal(GridManager.CellType.BUILDABLE)

	# Path should still be valid (no blocking)
	assert_bool(PathfindingSystem.is_path_valid()).is_true()

	# Tower should be removed from active list
	assert_bool(TowerSystem.get_active_towers().has(tower)).is_false()


# ==============================================================================
# TEST 10: Enemy reaching exit loses life
# ==============================================================================

func test_enemy_reaching_exit_loses_life() -> void:
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 1

	var lives_before: int = GameManager.lives

	# Create a 2-point path (start -> exit immediately)
	var path: PackedVector2Array = _make_path(2)
	var enemy_data: EnemyData = _make_enemy_data("Leaker", 100, 1.0, 3, "none")
	var enemy: Node2D = auto_free(_create_enemy(enemy_data, path))
	EnemySystem._active_enemies.append(enemy)
	EnemySystem._wave_finished_spawning = true

	# Move the enemy along the path until it reaches the exit.
	# Path: (0,0) -> (64,0). Speed = 64 px/s. The enemy starts at point[0] with
	# _path_index=0, so the first call instantly arrives and advances the index.
	# The second call moves toward point[1] (the exit) and triggers _reached_exit.
	enemy._move_along_path(0.001)  # Advance past starting point
	enemy._move_along_path(1.0)    # Move to exit

	# Enemy should have reached exit, causing life loss
	assert_int(GameManager.lives).is_equal(lives_before - 1)


# ==============================================================================
# TEST 11: Wave clear awards bonus
# ==============================================================================

func test_wave_clear_awards_bonus() -> void:
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	# Use wave 4 (not divisible by 5) to avoid triggering income phase + interest
	GameManager.current_wave = 4
	GameManager._enemies_leaked_this_wave = 2  # Some enemies leaked

	# Create a single enemy and kill it to trigger wave clear
	var enemy_data: EnemyData = _make_enemy_data("LastEnemy", 50, 1.0, 5, "none")
	var path: PackedVector2Array = _make_path(5)
	var enemy: Node2D = auto_free(_create_enemy(enemy_data, path))
	EnemySystem._active_enemies.append(enemy)
	EnemySystem._wave_finished_spawning = true

	var gold_before: int = EconomyManager.gold

	# Kill the enemy -- on_enemy_killed awards kill gold and removes from active list.
	# GameManager detects wave clear via _process() polling, not via signal.
	EnemySystem.on_enemy_killed(enemy)

	# Trigger GameManager._process so it detects zero active enemies + wave finished
	# and calls _on_wave_cleared() which awards the wave bonus.
	GameManager._process(0.016)

	# Gold should increase by: enemy gold (5) + wave bonus
	# Wave 4 bonus with 2 leaks: base = 10 + (4 * 3) = 22 (no no-leak bonus)
	var expected_enemy_gold: int = 5
	var expected_wave_bonus: int = EconomyManager.calculate_wave_bonus(4, 2)
	assert_int(expected_wave_bonus).is_equal(22)

	var total_expected: int = gold_before + expected_enemy_gold + expected_wave_bonus
	assert_int(EconomyManager.gold).is_equal(total_expected)


# ==============================================================================
# TEST 12: No leak bonus 25%
# ==============================================================================

func test_no_leak_bonus_25_percent() -> void:
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	# Use wave 4 (not divisible by 5) to avoid triggering income phase + interest
	GameManager.current_wave = 4
	GameManager._enemies_leaked_this_wave = 0  # No leaks

	# Create a single enemy and kill it to trigger wave clear
	var enemy_data: EnemyData = _make_enemy_data("LastEnemy", 50, 1.0, 5, "none")
	var path: PackedVector2Array = _make_path(5)
	var enemy: Node2D = auto_free(_create_enemy(enemy_data, path))
	EnemySystem._active_enemies.append(enemy)
	EnemySystem._wave_finished_spawning = true

	var gold_before: int = EconomyManager.gold

	# Kill the enemy -- on_enemy_killed awards kill gold and removes from active list.
	EnemySystem.on_enemy_killed(enemy)

	# Trigger GameManager._process so it detects wave clear and awards wave bonus.
	GameManager._process(0.016)

	# Gold should increase by: enemy gold (5) + wave bonus with no-leak 25% bonus
	# Wave 4 bonus with 0 leaks: base = 10 + (4 * 3) = 22, * 1.25 = 27 (int truncation)
	var expected_enemy_gold: int = 5
	var expected_wave_bonus: int = EconomyManager.calculate_wave_bonus(4, 0)
	assert_int(expected_wave_bonus).is_equal(27)

	# Verify the no-leak bonus is 25% more than the leaked version
	var leaked_bonus: int = EconomyManager.calculate_wave_bonus(4, 2)
	assert_int(expected_wave_bonus).is_greater(leaked_bonus)

	var total_expected: int = gold_before + expected_enemy_gold + expected_wave_bonus
	assert_int(EconomyManager.gold).is_equal(total_expected)
