extends GdUnitTestSuite

## Unit tests for Projectile.gd (Node2D).
## Covers: single hit (damage + specials), AoE hit (radius filtering), chain hits
## (count limit, damage fraction, chain specials), cone AoE, pull+burn, pushback,
## earthquake (slow + stun), ground effect spawning (lava_pool, slow_zone,
## burning_ground), damage calculation (element multiplier, synergy), proc chance,
## movement tracking, and queue_free after hit.
##
## Projectile extends Node2D with @onready var sprite: Sprite2D = $Sprite2D.
## We build a lightweight projectile node in-memory to avoid loading sprite
## textures that fail in headless mode.


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
	p_fusion_elements: Array[String] = []
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
	return data


## Create a minimal enemy stub with the properties Projectile.gd reads:
## enemy_data (EnemyData with element), current_health, global_position,
## and methods: take_damage(), apply_status(), pull_toward(), push_back().
static var _enemy_stub_script: GDScript = null
func _make_enemy_stub(
	p_health: int = 100,
	p_element: String = "none",
	p_pos: Vector2 = Vector2.ZERO
) -> Node2D:
	if _enemy_stub_script == null:
		_enemy_stub_script = GDScript.new()
		_enemy_stub_script.source_code = """
extends Node2D

var enemy_data: EnemyData
var current_health: int = 100
var max_health: int = 100
var _status_effects_applied: Array = []
var _damage_taken: Array = []
var _pull_calls: Array = []
var _push_calls: Array = []

func apply_status(type: int, duration: float, value: float) -> void:
	_status_effects_applied.append({"type": type, "duration": duration, "value": value})

func take_damage(amount: int, element: String = "") -> void:
	_damage_taken.append({"amount": amount, "element": element})
	current_health -= amount

func pull_toward(target_pos: Vector2, max_dist: float) -> void:
	_pull_calls.append({"target_pos": target_pos, "max_dist": max_dist})

func push_back(steps: int) -> void:
	_push_calls.append({"steps": steps})
"""
		_enemy_stub_script.reload()

	var stub := Node2D.new()
	stub.set_script(_enemy_stub_script)

	var data := EnemyData.new()
	data.element = p_element
	stub.enemy_data = data
	stub.current_health = p_health
	stub.max_health = p_health
	stub.position = p_pos

	return stub


## Build a real Projectile node with the required Sprite2D child so @onready
## resolves. We skip _load_element_sprite() by setting element="" initially.
static var _projectile_script: GDScript = null
func _create_projectile() -> Node2D:
	if _projectile_script == null:
		_projectile_script = load("res://scripts/projectiles/Projectile.gd") as GDScript

	var proj := Node2D.new()

	# Add the Sprite2D child that @onready expects
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	proj.add_child(sprite)

	# Assign the real Projectile.gd script
	proj.set_script(_projectile_script)

	# Prevent _load_element_sprite from trying to load textures
	proj.element = ""

	return proj


## Configure a projectile for a specific hit type by setting all relevant fields.
func _setup_projectile(
	proj: Node2D,
	p_target: Node = null,
	p_damage: int = 100,
	p_element: String = "fire",
	p_tower_data: TowerData = null,
	p_is_aoe: bool = false,
	p_aoe_radius_px: float = 0.0,
	p_special_key: String = "",
	p_special_value: float = 0.0,
	p_special_duration: float = 0.0,
	p_special_chance: float = 1.0,
	p_chain_count: int = 0,
	p_chain_damage_fraction: float = 0.0,
	p_synergy_damage_mult: float = 1.0,
	p_synergy_freeze_chance_bonus: float = 0.0,
	p_synergy_slow_bonus: float = 0.0,
	p_tower_position: Vector2 = Vector2.ZERO,
	p_position: Vector2 = Vector2.ZERO
) -> void:
	proj.target = p_target
	proj.damage = p_damage
	proj.element = p_element
	proj.tower_data = p_tower_data
	proj.is_aoe = p_is_aoe
	proj.aoe_radius_px = p_aoe_radius_px
	proj.special_key = p_special_key
	proj.special_value = p_special_value
	proj.special_duration = p_special_duration
	proj.special_chance = p_special_chance
	proj.chain_count = p_chain_count
	proj.chain_damage_fraction = p_chain_damage_fraction
	proj.synergy_damage_mult = p_synergy_damage_mult
	proj.synergy_freeze_chance_bonus = p_synergy_freeze_chance_bonus
	proj.synergy_slow_bonus = p_synergy_slow_bonus
	proj.tower_position = p_tower_position
	proj.global_position = p_position
	if p_target != null and is_instance_valid(p_target):
		proj.target_last_pos = p_target.global_position
	else:
		proj.target_last_pos = p_position


func _reset_autoloads() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn.clear()
	TowerSystem._active_towers.clear()
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = 0
	GameManager.lives = GameManager.starting_lives
	GameManager._build_timer = 0.0
	GameManager._enemies_leaked_this_wave = 0
	EconomyManager.reset()
	# Reset the static ground effect scene cache so tests don't leak state
	Projectile._ground_effect_scene = null


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_reset_autoloads()


# ==============================================================================
# SINGLE HIT (2 tests)
# ==============================================================================

# -- 1. test_single_hit_applies_damage ----------------------------------------

func test_single_hit_applies_damage() -> void:
	var enemy: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(100.0, 100.0)))
	EnemySystem._active_enemies.append(enemy)

	var proj: Node2D = auto_free(_create_projectile())
	_setup_projectile(proj, enemy, 50, "fire", null, false, 0.0, "", 0.0, 0.0, 1.0)
	proj.global_position = Vector2(100.0, 100.0)

	# Call _apply_single_hit directly
	proj._apply_single_hit()

	# Enemy should have taken 50 damage
	assert_int(enemy._damage_taken.size()).is_equal(1)
	assert_int(enemy._damage_taken[0]["amount"]).is_equal(50)
	assert_str(enemy._damage_taken[0]["element"]).is_equal("fire")


# -- 2. test_single_hit_applies_special ----------------------------------------

func test_single_hit_applies_special() -> void:
	var enemy: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(100.0, 100.0)))
	EnemySystem._active_enemies.append(enemy)

	var proj: Node2D = auto_free(_create_projectile())
	_setup_projectile(proj, enemy, 50, "fire", null, false, 0.0,
		"burn", 15.0, 3.0, 1.0)
	proj.global_position = Vector2(100.0, 100.0)

	proj._apply_single_hit()

	# Should have taken damage AND received burn status
	assert_int(enemy._damage_taken.size()).is_equal(1)
	assert_int(enemy._status_effects_applied.size()).is_equal(1)
	assert_int(enemy._status_effects_applied[0]["type"]).is_equal(StatusEffect.Type.BURN)
	assert_float(enemy._status_effects_applied[0]["duration"]).is_equal(3.0)
	assert_float(enemy._status_effects_applied[0]["value"]).is_equal(15.0)


# ==============================================================================
# AOE HIT (2 tests)
# ==============================================================================

# -- 3. test_aoe_hit_damages_all_in_radius ------------------------------------

func test_aoe_hit_damages_all_in_radius() -> void:
	var e1: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(100.0, 100.0)))
	var e2: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(130.0, 100.0)))
	var e3: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(150.0, 100.0)))
	EnemySystem._active_enemies.append(e1)
	EnemySystem._active_enemies.append(e2)
	EnemySystem._active_enemies.append(e3)

	var td: TowerData = _make_tower_data("AoETower", "earth", 80, 1.0, 4, "aoe", 0.0, 0.0, 1.0, 0.0, 2.0)
	var proj: Node2D = auto_free(_create_projectile())
	_setup_projectile(proj, e1, 80, "earth", td, true, 128.0)
	proj.global_position = Vector2(100.0, 100.0)

	proj._apply_aoe_hit()

	# All 3 enemies are within 128px of impact at (100, 100):
	# e1=0px, e2=30px, e3=50px -- all within radius
	assert_int(e1._damage_taken.size()).is_equal(1)
	assert_int(e2._damage_taken.size()).is_equal(1)
	assert_int(e3._damage_taken.size()).is_equal(1)


# -- 4. test_aoe_hit_skips_out_of_range ---------------------------------------

func test_aoe_hit_skips_out_of_range() -> void:
	var e_in: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(100.0, 100.0)))
	var e_out: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(400.0, 400.0)))
	EnemySystem._active_enemies.append(e_in)
	EnemySystem._active_enemies.append(e_out)

	var td: TowerData = _make_tower_data("AoETower", "earth", 80, 1.0, 4, "aoe", 0.0, 0.0, 1.0, 0.0, 2.0)
	var proj: Node2D = auto_free(_create_projectile())
	_setup_projectile(proj, e_in, 80, "earth", td, true, 128.0)
	proj.global_position = Vector2(100.0, 100.0)

	proj._apply_aoe_hit()

	# e_in is at 0px distance -> hit; e_out is ~424px away -> not hit
	assert_int(e_in._damage_taken.size()).is_equal(1)
	assert_int(e_out._damage_taken.size()).is_equal(0)


# ==============================================================================
# CHAIN HITS (3 tests)
# ==============================================================================

# -- 5. test_chain_hits_secondary_targets -------------------------------------

func test_chain_hits_secondary_targets() -> void:
	# Primary target at impact point
	var primary: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(100.0, 100.0)))
	# Secondary targets within chain radius (2 cells = 128px)
	var sec1: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(150.0, 100.0)))
	var sec2: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(100.0, 150.0)))
	EnemySystem._active_enemies.append(primary)
	EnemySystem._active_enemies.append(sec1)
	EnemySystem._active_enemies.append(sec2)

	var td: TowerData = _make_tower_data("ChainTower", "lightning", 100, 1.0, 4,
		"chain", 0.0, 0.0, 1.0, 0.5)
	var proj: Node2D = auto_free(_create_projectile())
	_setup_projectile(proj, primary, 100, "lightning", td,
		false, 0.0, "chain", 0.0, 0.0, 1.0, 3, 0.5)
	proj.global_position = Vector2(100.0, 100.0)

	proj._apply_chain_hits()

	# Both secondary targets should have been hit (chain_count=3 but only 2 secondaries)
	assert_int(sec1._damage_taken.size()).is_equal(1)
	assert_int(sec2._damage_taken.size()).is_equal(1)
	# Primary should NOT be hit by chain (excluded)
	assert_int(primary._damage_taken.size()).is_equal(0)


# -- 6. test_chain_respects_count_limit ---------------------------------------

func test_chain_respects_count_limit() -> void:
	var primary: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(100.0, 100.0)))
	var sec1: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(120.0, 100.0)))
	var sec2: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(100.0, 120.0)))
	var sec3: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(110.0, 110.0)))
	EnemySystem._active_enemies.append(primary)
	EnemySystem._active_enemies.append(sec1)
	EnemySystem._active_enemies.append(sec2)
	EnemySystem._active_enemies.append(sec3)

	var td: TowerData = _make_tower_data("ChainTower", "lightning", 100, 1.0, 4,
		"chain", 0.0, 0.0, 1.0, 0.5)
	var proj: Node2D = auto_free(_create_projectile())
	# chain_count=2 but 3 secondaries in range -> only 2 get hit
	_setup_projectile(proj, primary, 100, "lightning", td,
		false, 0.0, "chain", 0.0, 0.0, 1.0, 2, 0.5)
	proj.global_position = Vector2(100.0, 100.0)

	proj._apply_chain_hits()

	# Count how many secondary enemies were hit (should be exactly 2)
	var total_hit: int = 0
	for e: Node in [sec1, sec2, sec3]:
		if e._damage_taken.size() > 0:
			total_hit += 1
	assert_int(total_hit).is_equal(2)


# -- 7. test_chain_damage_fraction_applied ------------------------------------

func test_chain_damage_fraction_applied() -> void:
	var primary: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(100.0, 100.0)))
	var secondary: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(120.0, 100.0)))
	EnemySystem._active_enemies.append(primary)
	EnemySystem._active_enemies.append(secondary)

	# Tower does 100 base damage, chain fraction = 0.4
	# Secondary element is "none" -> multiplier 1.0, synergy 1.0
	# Chain damage = int(100 * 1.0 * 1.0 * 0.4) = 40
	var td: TowerData = _make_tower_data("ChainTower", "lightning", 100, 1.0, 4,
		"chain", 0.0, 0.0, 1.0, 0.4)
	var proj: Node2D = auto_free(_create_projectile())
	_setup_projectile(proj, primary, 100, "lightning", td,
		false, 0.0, "chain", 0.0, 0.0, 1.0, 3, 0.4)
	proj.global_position = Vector2(100.0, 100.0)

	proj._apply_chain_hits()

	assert_int(secondary._damage_taken.size()).is_equal(1)
	assert_int(secondary._damage_taken[0]["amount"]).is_equal(40)


# ==============================================================================
# CONE AOE (1 test)
# ==============================================================================

# -- 8. test_cone_aoe_angle_check ---------------------------------------------

func test_cone_aoe_angle_check() -> void:
	# Tower at (0, 0), projectile lands at (200, 0) -> cone direction is right (+X)
	# 90-degree cone = 45 degrees each side of the +X axis
	# Enemy in cone: at (220, 10) -> within angle and range
	# Enemy out of cone: at (0, 200) -> perpendicular to cone direction
	var e_in: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(220.0, 10.0)))
	var e_out: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(0.0, 200.0)))
	EnemySystem._active_enemies.append(e_in)
	EnemySystem._active_enemies.append(e_out)

	var td: TowerData = _make_tower_data("BlizzardTower", "ice", 80, 1.0, 6,
		"cone_slow", 0.3, 3.0, 1.0, 0.0, 5.0)
	var proj: Node2D = auto_free(_create_projectile())
	_setup_projectile(proj, e_in, 80, "ice", td,
		true, 320.0, "cone_slow", 0.3, 3.0, 1.0,
		0, 0.0, 1.0, 0.0, 0.0, Vector2.ZERO, Vector2(200.0, 0.0))

	proj._apply_cone_aoe_hit()

	# e_in at (220,10): distance from tower (0,0) = ~220px (within 320px radius),
	# angle from +X axis is very small -> inside cone -> should be hit
	assert_int(e_in._damage_taken.size()).is_equal(1)
	# e_out at (0,200): distance = 200px (within radius) but angle from +X is 90 degrees
	# which is > 45 degree half-angle -> outside cone -> should NOT be hit
	assert_int(e_out._damage_taken.size()).is_equal(0)

	# e_in should also receive SLOW status from cone_slow
	assert_int(e_in._status_effects_applied.size()).is_equal(1)
	assert_int(e_in._status_effects_applied[0]["type"]).is_equal(StatusEffect.Type.SLOW)


# ==============================================================================
# PULL + BURN (1 test)
# ==============================================================================

# -- 9. test_pull_burn_pulls_then_damages -------------------------------------

func test_pull_burn_pulls_then_damages() -> void:
	var enemy: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(150.0, 100.0)))
	EnemySystem._active_enemies.append(enemy)

	var td: TowerData = _make_tower_data("InfernoVortex", "fire", 100, 1.0, 4,
		"pull_burn", 20.0, 3.0, 1.0, 0.0, 3.0)
	var proj: Node2D = auto_free(_create_projectile())
	_setup_projectile(proj, enemy, 100, "fire", td,
		true, 192.0, "pull_burn", 20.0, 3.0, 1.0,
		0, 0.0, 1.0, 0.0, 0.0, Vector2.ZERO, Vector2(100.0, 100.0))

	proj._apply_pull_burn_hit()

	# Enemy should have been pulled toward impact (100, 100)
	assert_int(enemy._pull_calls.size()).is_equal(1)
	assert_vector2(enemy._pull_calls[0]["target_pos"]).is_equal(Vector2(100.0, 100.0))
	assert_float(enemy._pull_calls[0]["max_dist"]).is_equal(64.0)  # PULL_DISTANCE_PX

	# Enemy should also have taken damage
	assert_int(enemy._damage_taken.size()).is_equal(1)

	# Enemy should have received BURN status
	assert_int(enemy._status_effects_applied.size()).is_equal(1)
	assert_int(enemy._status_effects_applied[0]["type"]).is_equal(StatusEffect.Type.BURN)
	assert_float(enemy._status_effects_applied[0]["value"]).is_equal(20.0)


# ==============================================================================
# PUSHBACK (1 test)
# ==============================================================================

# -- 10. test_pushback_moves_enemies_back -------------------------------------

func test_pushback_moves_enemies_back() -> void:
	var enemy: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(120.0, 100.0)))
	EnemySystem._active_enemies.append(enemy)

	var td: TowerData = _make_tower_data("TsunamiShrine", "water", 80, 1.0, 4,
		"pushback", 3.0, 0.0, 1.0, 0.0, 3.0)
	var proj: Node2D = auto_free(_create_projectile())
	# special_value=3.0 -> push_back(3), special_chance=1.0 -> always
	_setup_projectile(proj, enemy, 80, "water", td,
		true, 192.0, "pushback", 3.0, 0.0, 1.0,
		0, 0.0, 1.0, 0.0, 0.0, Vector2.ZERO, Vector2(100.0, 100.0))

	proj._apply_pushback_hit()

	# Enemy should have taken damage
	assert_int(enemy._damage_taken.size()).is_equal(1)

	# Enemy should have been pushed back 3 steps
	assert_int(enemy._push_calls.size()).is_equal(1)
	assert_int(enemy._push_calls[0]["steps"]).is_equal(3)


# ==============================================================================
# EARTHQUAKE (1 test)
# ==============================================================================

# -- 11. test_earthquake_slow_and_stun ----------------------------------------

func test_earthquake_slow_and_stun() -> void:
	var enemy: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(120.0, 100.0)))
	EnemySystem._active_enemies.append(enemy)

	var td: TowerData = _make_tower_data("TectonicDynamo", "earth", 120, 1.0, 4,
		"earthquake", 0.4, 2.0, 1.0, 0.0, 3.0)
	var proj: Node2D = auto_free(_create_projectile())
	# special_value=0.4 (slow amount), special_duration=2.0, special_chance=1.0 (stun always)
	_setup_projectile(proj, enemy, 120, "earth", td,
		true, 192.0, "earthquake", 0.4, 2.0, 1.0,
		0, 0.0, 1.0, 0.0, 0.0, Vector2.ZERO, Vector2(100.0, 100.0))

	proj._apply_earthquake_hit()

	# Enemy should have taken damage
	assert_int(enemy._damage_taken.size()).is_equal(1)

	# Enemy should have SLOW and STUN status (chance=1.0 -> always)
	var has_slow: bool = false
	var has_stun: bool = false
	for effect: Dictionary in enemy._status_effects_applied:
		if effect["type"] == StatusEffect.Type.SLOW:
			has_slow = true
			assert_float(effect["value"]).is_equal_approx(0.4, 0.01)
		elif effect["type"] == StatusEffect.Type.STUN:
			has_stun = true
	assert_bool(has_slow).is_true()
	assert_bool(has_stun).is_true()


# ==============================================================================
# GROUND EFFECTS (3 tests)
# ==============================================================================

## Create a stub GroundEffect scene that can be instantiated in headless mode.
func _make_ground_effect_stub_scene() -> PackedScene:
	var stub_script := GDScript.new()
	stub_script.source_code = """
extends Node2D

var effect_type: String = ""
var effect_radius_px: float = 0.0
var effect_duration: float = 0.0
var element: String = ""
var damage_per_second: float = 0.0
var slow_fraction: float = 0.0
"""
	stub_script.reload()

	var node := Node2D.new()
	node.name = "StubGroundEffect"
	node.set_script(stub_script)

	var scene := PackedScene.new()
	scene.pack(node)
	node.free()

	return scene


# -- 12. test_ground_effect_spawned_lava_pool ---------------------------------

func test_ground_effect_spawned_lava_pool() -> void:
	var proj: Node2D = auto_free(_create_projectile())
	_setup_projectile(proj, null, 100, "fire", null,
		true, 128.0, "lava_pool", 30.0, 5.0, 1.0)
	proj.global_position = Vector2(200.0, 200.0)

	# Inject stub scene
	Projectile._ground_effect_scene = _make_ground_effect_stub_scene()

	# Capture the signal emission
	var captured_effects: Array = []
	proj.ground_effect_spawned.connect(func(effect: Node) -> void:
		captured_effects.append(effect)
	)

	proj._spawn_ground_effect()

	assert_int(captured_effects.size()).is_equal(1)
	var effect: Node = captured_effects[0]
	assert_str(effect.effect_type).is_equal("lava_pool")
	assert_float(effect.damage_per_second).is_equal(30.0)
	assert_float(effect.effect_duration).is_equal(5.0)
	assert_str(effect.element).is_equal("fire")
	effect.queue_free()


# -- 13. test_ground_effect_spawned_slow_zone ---------------------------------

func test_ground_effect_spawned_slow_zone() -> void:
	var proj: Node2D = auto_free(_create_projectile())
	_setup_projectile(proj, null, 80, "water", null,
		true, 128.0, "slow_zone", 0.4, 4.0, 1.0)
	proj.global_position = Vector2(200.0, 200.0)

	Projectile._ground_effect_scene = _make_ground_effect_stub_scene()

	var captured_effects: Array = []
	proj.ground_effect_spawned.connect(func(effect: Node) -> void:
		captured_effects.append(effect)
	)

	proj._spawn_ground_effect()

	assert_int(captured_effects.size()).is_equal(1)
	var effect: Node = captured_effects[0]
	assert_str(effect.effect_type).is_equal("slow_zone")
	assert_float(effect.slow_fraction).is_equal(0.4)
	assert_float(effect.effect_duration).is_equal(4.0)
	assert_str(effect.element).is_equal("water")
	effect.queue_free()


# -- 14. test_ground_effect_spawned_burning_ground ----------------------------

func test_ground_effect_spawned_burning_ground() -> void:
	var proj: Node2D = auto_free(_create_projectile())
	_setup_projectile(proj, null, 100, "fire", null,
		true, 128.0, "burning_ground", 25.0, 6.0, 1.0)
	proj.global_position = Vector2(200.0, 200.0)

	Projectile._ground_effect_scene = _make_ground_effect_stub_scene()

	var captured_effects: Array = []
	proj.ground_effect_spawned.connect(func(effect: Node) -> void:
		captured_effects.append(effect)
	)

	proj._spawn_ground_effect()

	assert_int(captured_effects.size()).is_equal(1)
	var effect: Node = captured_effects[0]
	assert_str(effect.effect_type).is_equal("burning_ground")
	assert_float(effect.damage_per_second).is_equal(25.0)
	assert_str(effect.element).is_equal("fire")
	effect.queue_free()


# ==============================================================================
# DAMAGE CALCULATION (2 tests)
# ==============================================================================

# -- 15. test_calculate_damage_per_target_element -----------------------------

func test_calculate_damage_per_target_element() -> void:
	# Tower deals 100 base damage as fire
	var td: TowerData = _make_tower_data("FireTower", "fire", 100)

	var proj: Node2D = auto_free(_create_projectile())
	_setup_projectile(proj, null, 100, "fire", td)

	# fire vs earth -> 1.5x -> 150
	var earth_enemy: Node2D = auto_free(_make_enemy_stub(300, "earth"))
	var dmg_earth: int = proj._calculate_damage(earth_enemy)
	assert_int(dmg_earth).is_equal(150)

	# fire vs water -> 0.5x -> 50
	var water_enemy: Node2D = auto_free(_make_enemy_stub(300, "water"))
	var dmg_water: int = proj._calculate_damage(water_enemy)
	assert_int(dmg_water).is_equal(50)

	# fire vs none -> 1.0x -> 100
	var none_enemy: Node2D = auto_free(_make_enemy_stub(300, "none"))
	var dmg_none: int = proj._calculate_damage(none_enemy)
	assert_int(dmg_none).is_equal(100)


# -- 16. test_synergy_damage_mult_applied -------------------------------------

func test_synergy_damage_mult_applied() -> void:
	var td: TowerData = _make_tower_data("FireTower", "fire", 100)

	var proj: Node2D = auto_free(_create_projectile())
	_setup_projectile(proj, null, 100, "fire", td,
		false, 0.0, "", 0.0, 0.0, 1.0,
		0, 0.0, 1.3)  # synergy_damage_mult = 1.3

	# fire vs earth -> 1.5x element, 1.3x synergy -> 100 * 1.5 * 1.3 = 195
	var enemy: Node2D = auto_free(_make_enemy_stub(300, "earth"))
	var dmg: int = proj._calculate_damage(enemy)
	assert_int(dmg).is_equal(195)


# ==============================================================================
# PROC CHANCE (1 test)
# ==============================================================================

# -- 17. test_try_apply_special_proc_chance -----------------------------------

func test_try_apply_special_proc_chance() -> void:
	# Test 0% chance -> no effect
	var enemy_no_proc: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(100.0, 100.0)))

	var proj_0: Node2D = auto_free(_create_projectile())
	_setup_projectile(proj_0, enemy_no_proc, 50, "fire", null,
		false, 0.0, "burn", 15.0, 3.0, 0.0)  # 0% chance

	proj_0._try_apply_special(enemy_no_proc)
	assert_int(enemy_no_proc._status_effects_applied.size()).is_equal(0)

	# Test 100% chance -> always applies
	var enemy_proc: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(100.0, 100.0)))

	var proj_100: Node2D = auto_free(_create_projectile())
	_setup_projectile(proj_100, enemy_proc, 50, "fire", null,
		false, 0.0, "burn", 15.0, 3.0, 1.0)  # 100% chance

	proj_100._try_apply_special(enemy_proc)
	assert_int(enemy_proc._status_effects_applied.size()).is_equal(1)
	assert_int(enemy_proc._status_effects_applied[0]["type"]).is_equal(StatusEffect.Type.BURN)


# ==============================================================================
# CHAIN SPECIALS (2 tests)
# ==============================================================================

# -- 18. test_wet_chain_applies_wet -------------------------------------------

func test_wet_chain_applies_wet() -> void:
	var chain_enemy: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(120.0, 100.0)))

	var proj: Node2D = auto_free(_create_projectile())
	_setup_projectile(proj, null, 80, "water", null,
		false, 0.0, "wet_chain", 0.0, 4.0, 1.0)

	proj._try_apply_chain_special(chain_enemy)

	# Storm Beacon chain always applies WET with 4.0 duration
	assert_int(chain_enemy._status_effects_applied.size()).is_equal(1)
	assert_int(chain_enemy._status_effects_applied[0]["type"]).is_equal(StatusEffect.Type.WET)
	assert_float(chain_enemy._status_effects_applied[0]["duration"]).is_equal(4.0)


# -- 19. test_freeze_chain_attempts_freeze ------------------------------------

func test_freeze_chain_attempts_freeze() -> void:
	var chain_enemy: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(120.0, 100.0)))

	var proj: Node2D = auto_free(_create_projectile())
	# special_chance=1.0 + synergy_freeze_chance_bonus=0.0 = 1.0 -> always freezes
	_setup_projectile(proj, null, 80, "ice", null,
		false, 0.0, "freeze_chain", 0.0, 2.0, 1.0,
		0, 0.0, 1.0, 0.0)  # synergy_freeze_chance_bonus = 0.0

	proj._try_apply_chain_special(chain_enemy)

	# With effective chance 1.0, freeze should always apply
	assert_int(chain_enemy._status_effects_applied.size()).is_equal(1)
	assert_int(chain_enemy._status_effects_applied[0]["type"]).is_equal(StatusEffect.Type.FREEZE)
	assert_float(chain_enemy._status_effects_applied[0]["duration"]).is_equal(2.0)


# ==============================================================================
# MOVEMENT TRACKING (2 tests)
# ==============================================================================

# -- 20. test_projectile_tracks_target ----------------------------------------

func test_projectile_tracks_target() -> void:
	var enemy: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(500.0, 100.0)))
	EnemySystem._active_enemies.append(enemy)

	var proj: Node2D = auto_free(_create_projectile())
	proj.target = enemy
	proj.target_last_pos = enemy.global_position
	proj.speed = 400.0
	proj.global_position = Vector2(100.0, 100.0)
	proj.damage = 50
	proj.element = "fire"

	var start_pos: Vector2 = proj.global_position

	# Simulate one _process frame (0.1 seconds)
	# Direction is (500-100, 0).normalized() = (1, 0)
	# Movement = 400 * 0.1 = 40px in +X direction
	proj._process(0.1)

	# Projectile should have moved toward the target
	assert_float(proj.global_position.x).is_greater(start_pos.x)
	assert_float(proj.global_position.x).is_equal_approx(140.0, 1.0)


# -- 21. test_projectile_uses_last_pos_if_target_dies -------------------------

func test_projectile_uses_last_pos_if_target_dies() -> void:
	var enemy: Node2D = _make_enemy_stub(200, "none", Vector2(500.0, 100.0))
	EnemySystem._active_enemies.append(enemy)

	var proj: Node2D = auto_free(_create_projectile())
	proj.target = enemy
	proj.target_last_pos = enemy.global_position
	proj.speed = 400.0
	proj.global_position = Vector2(100.0, 100.0)
	proj.damage = 50
	proj.element = "fire"

	# Simulate target dying by freeing it
	enemy.free()

	# _process should fall back to target_last_pos = (500, 100)
	proj._process(0.1)

	# Projectile should still move toward (500, 100)
	assert_float(proj.global_position.x).is_greater(100.0)
	assert_float(proj.global_position.x).is_equal_approx(140.0, 1.0)


# ==============================================================================
# HIT THRESHOLD AND CLEANUP (2 tests)
# ==============================================================================

# -- 22. test_projectile_hits_at_threshold ------------------------------------

func test_projectile_hits_at_threshold() -> void:
	# Place projectile within 8px of target -> should trigger hit
	var enemy: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(105.0, 100.0)))
	EnemySystem._active_enemies.append(enemy)

	var proj: Node2D = auto_free(_create_projectile())
	proj.target = enemy
	proj.target_last_pos = enemy.global_position
	proj.speed = 400.0
	proj.damage = 50
	proj.element = "fire"

	# Position projectile within HIT_THRESHOLD (8px) of target
	proj.global_position = Vector2(100.0, 100.0)
	# Distance = 5px < 8px threshold

	# Monitor for queue_free being called: check _hit by calling _process
	# with tiny delta that moves it closer and within threshold
	# The projectile at (100,100), target at (105,100), dist=5 < 8
	# _process will first update target_last_pos to (105,100), then check distance
	proj._process(0.001)

	# Since the projectile is within threshold on this frame, _hit() was called.
	# We verify via enemy taking damage (single hit path, no special_key/aoe/chain)
	assert_int(enemy._damage_taken.size()).is_equal(1)


# -- 23. test_projectile_queue_frees_after_hit --------------------------------

func test_projectile_queue_frees_after_hit() -> void:
	var enemy: Node2D = auto_free(_make_enemy_stub(200, "none", Vector2(100.0, 100.0)))
	EnemySystem._active_enemies.append(enemy)

	var proj: Node2D = _create_projectile()
	_setup_projectile(proj, enemy, 50, "fire", null, false, 0.0, "", 0.0, 0.0, 1.0)
	proj.global_position = Vector2(100.0, 100.0)
	proj.target_last_pos = Vector2(100.0, 100.0)

	# Add to scene tree so queue_free() can work
	add_child(proj)

	# Calling _hit() should call queue_free()
	proj._hit()

	# After _hit(), the node is queued for deletion.
	# Verify it is marked for deletion by checking is_queued_for_deletion()
	assert_bool(proj.is_queued_for_deletion()).is_true()
