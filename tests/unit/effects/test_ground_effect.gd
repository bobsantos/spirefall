extends GdUnitTestSuite

## Unit tests for GroundEffect.gd (Node2D).
## Covers: lava_pool tick damage, slow_zone status application, fire_trail tower
## disable, burning_ground damage, effect expiration, fade in last 0.5s, tick
## interval enforcement, and out-of-radius exclusion.
##
## GroundEffect extends Node2D with no @onready children -- it uses _draw() for
## visuals and _process() for tick logic. We create the node directly and set
## its script to the real GroundEffect.gd. Since _ready() calls queue_redraw()
## only, it works fine in headless mode.


# -- Helpers -------------------------------------------------------------------

## Enemy stub: records take_damage and apply_status calls for assertion.
static var _enemy_stub_script: GDScript = null
func _make_enemy_stub(p_health: int = 100, p_pos: Vector2 = Vector2.ZERO) -> Node2D:
	if _enemy_stub_script == null:
		_enemy_stub_script = GDScript.new()
		_enemy_stub_script.source_code = """
extends Node2D

var current_health: int = 100
var _damage_taken: Array = []
var _status_effects_applied: Array = []

func take_damage(amount: int, element: String = "") -> void:
	_damage_taken.append({"amount": amount, "element": element})
	current_health -= amount

func apply_status(type: int, duration: float, value: float) -> void:
	_status_effects_applied.append({"type": type, "duration": duration, "value": value})
"""
		_enemy_stub_script.reload()

	var stub := Node2D.new()
	stub.set_script(_enemy_stub_script)
	stub.current_health = p_health
	stub.position = p_pos
	return stub


## Tower stub: records disable_for calls.
static var _tower_stub_script: GDScript = null
func _make_tower_stub(p_pos: Vector2 = Vector2.ZERO) -> Node2D:
	if _tower_stub_script == null:
		_tower_stub_script = GDScript.new()
		_tower_stub_script.source_code = """
extends Node2D

var disabled_duration: float = 0.0

func disable_for(duration: float) -> void:
	disabled_duration = duration
"""
		_tower_stub_script.reload()

	var stub := Node2D.new()
	stub.set_script(_tower_stub_script)
	stub.position = p_pos
	return stub


## Create a GroundEffect node with the real script attached.
static var _ground_effect_script: GDScript = null
func _create_ground_effect(
	p_type: String = "lava_pool",
	p_radius: float = 96.0,
	p_duration: float = 3.0,
	p_damage_per_second: float = 20.0,
	p_slow_fraction: float = 0.0,
	p_element: String = "fire",
	p_pos: Vector2 = Vector2.ZERO
) -> Node2D:
	if _ground_effect_script == null:
		_ground_effect_script = load("res://scripts/effects/GroundEffect.gd") as GDScript

	var effect := Node2D.new()
	effect.set_script(_ground_effect_script)

	# Set properties before adding to tree
	effect.effect_type = p_type
	effect.effect_radius_px = p_radius
	effect.effect_duration = p_duration
	effect.damage_per_second = p_damage_per_second
	effect.slow_fraction = p_slow_fraction
	effect.element = p_element
	effect.position = p_pos

	return effect


func _reset_autoloads() -> void:
	EnemySystem._active_enemies.clear()
	TowerSystem._active_towers.clear()


# -- Setup / Teardown ----------------------------------------------------------

func after() -> void:
	_enemy_stub_script = null
	_tower_stub_script = null
	_ground_effect_script = null


func before_test() -> void:
	_reset_autoloads()


# ==============================================================================
# TEST CASES (8 tests)
# ==============================================================================

# -- 1. test_lava_pool_deals_tick_damage ---------------------------------------

func test_lava_pool_deals_tick_damage() -> void:
	var effect: Node2D = auto_free(_create_ground_effect(
		"lava_pool", 96.0, 3.0, 20.0, 0.0, "fire", Vector2(100.0, 100.0)
	))

	# Enemy within radius (50px away < 96px)
	var enemy: Node2D = auto_free(_make_enemy_stub(100, Vector2(150.0, 100.0)))
	EnemySystem._active_enemies.append(enemy)

	# Simulate one full tick by advancing _tick_timer past _tick_interval (0.5s)
	# _process increments _tick_timer and calls _apply_effect when >= 0.5
	effect._process(0.5)

	# Expected tick damage: max(1, int(20.0 * 0.5)) = 10
	assert_int(enemy._damage_taken.size()).is_equal(1)
	assert_int(enemy._damage_taken[0]["amount"]).is_equal(10)
	assert_str(enemy._damage_taken[0]["element"]).is_equal("fire")


# -- 2. test_slow_zone_applies_slow -------------------------------------------

func test_slow_zone_applies_slow() -> void:
	var effect: Node2D = auto_free(_create_ground_effect(
		"slow_zone", 96.0, 5.0, 0.0, 0.3, "earth", Vector2(200.0, 200.0)
	))

	# Enemy within radius (40px away < 96px)
	var enemy: Node2D = auto_free(_make_enemy_stub(100, Vector2(240.0, 200.0)))
	EnemySystem._active_enemies.append(enemy)

	# Tick past the interval to trigger _apply_effect
	effect._process(0.5)

	# Should have applied SLOW status
	assert_int(enemy._status_effects_applied.size()).is_equal(1)
	var applied: Dictionary = enemy._status_effects_applied[0]
	assert_int(applied["type"]).is_equal(StatusEffect.Type.SLOW)
	# Duration = _tick_interval + 0.1 = 0.6
	assert_float(applied["duration"]).is_equal_approx(0.6, 0.01)
	# Value = slow_fraction = 0.3
	assert_float(applied["value"]).is_equal_approx(0.3, 0.01)
	# No damage should have been dealt
	assert_int(enemy._damage_taken.size()).is_equal(0)


# -- 3. test_fire_trail_disables_towers ----------------------------------------

func test_fire_trail_disables_towers() -> void:
	var effect: Node2D = auto_free(_create_ground_effect(
		"fire_trail", 96.0, 5.0, 30.0, 0.0, "fire", Vector2(300.0, 300.0)
	))

	# Tower within 64px (GridManager.CELL_SIZE)
	var tower_near: Node2D = auto_free(_make_tower_stub(Vector2(350.0, 300.0)))  # 50px away
	# Tower outside 64px but within effect_radius
	var tower_far: Node2D = auto_free(_make_tower_stub(Vector2(400.0, 300.0)))  # 100px away
	TowerSystem._active_towers.append(tower_near)
	TowerSystem._active_towers.append(tower_far)

	# Also need an enemy in radius for the damage portion to execute (but we
	# mainly care about tower disable here). Add one to ensure full path runs.
	var enemy: Node2D = auto_free(_make_enemy_stub(200, Vector2(320.0, 300.0)))
	EnemySystem._active_enemies.append(enemy)

	# Tick past interval
	effect._process(0.5)

	# Near tower (50px <= 64px) should be disabled for 2.0s
	assert_float(tower_near.disabled_duration).is_equal(2.0)
	# Far tower (100px > 64px) should NOT be disabled
	assert_float(tower_far.disabled_duration).is_equal(0.0)


# -- 4. test_burning_ground_deals_damage ---------------------------------------

func test_burning_ground_deals_damage() -> void:
	var effect: Node2D = auto_free(_create_ground_effect(
		"burning_ground", 96.0, 3.0, 40.0, 0.0, "fire", Vector2(100.0, 100.0)
	))

	var enemy: Node2D = auto_free(_make_enemy_stub(200, Vector2(140.0, 100.0)))
	EnemySystem._active_enemies.append(enemy)

	# Tick past interval
	effect._process(0.5)

	# Expected damage: max(1, int(40.0 * 0.5)) = 20
	assert_int(enemy._damage_taken.size()).is_equal(1)
	assert_int(enemy._damage_taken[0]["amount"]).is_equal(20)
	assert_str(enemy._damage_taken[0]["element"]).is_equal("fire")


# -- 5. test_effect_expires_after_duration -------------------------------------

func test_effect_expires_after_duration() -> void:
	var effect: Node2D = auto_free(_create_ground_effect(
		"lava_pool", 96.0, 2.0, 10.0, 0.0, "fire"
	))

	# Advance _lifetime to just under duration: should NOT free
	effect._process(1.9)
	assert_bool(effect.is_queued_for_deletion()).is_false()

	# Advance past duration: should queue_free
	effect._process(0.2)
	assert_bool(effect.is_queued_for_deletion()).is_true()


# -- 6. test_effect_fades_in_last_half_second ----------------------------------

func test_effect_fades_in_last_half_second() -> void:
	var effect: Node2D = auto_free(_create_ground_effect(
		"lava_pool", 96.0, 3.0, 10.0, 0.0, "fire"
	))

	# Before the fade window: alpha should be 1.0
	effect._process(2.0)
	assert_float(effect.modulate.a).is_equal_approx(1.0, 0.01)

	# Now at remaining = 0.3s (within last 0.5s): alpha = 0.3 / 0.5 = 0.6
	effect._process(0.2)
	# _lifetime is now 2.2, remaining = 3.0 - 2.2 = 0.8 -- still outside fade window
	# Let's push further: at _lifetime = 2.6, remaining = 0.4
	effect._process(0.4)
	# remaining = 3.0 - 2.6 = 0.4, alpha = 0.4 / 0.5 = 0.8
	assert_float(effect.modulate.a).is_equal_approx(0.8, 0.05)

	# Push to _lifetime = 2.8, remaining = 0.2
	effect._process(0.2)
	# alpha = 0.2 / 0.5 = 0.4
	assert_float(effect.modulate.a).is_equal_approx(0.4, 0.05)


# -- 7. test_tick_interval_respected -------------------------------------------

func test_tick_interval_respected() -> void:
	var effect: Node2D = auto_free(_create_ground_effect(
		"lava_pool", 96.0, 5.0, 20.0, 0.0, "fire", Vector2(100.0, 100.0)
	))

	var enemy: Node2D = auto_free(_make_enemy_stub(200, Vector2(150.0, 100.0)))
	EnemySystem._active_enemies.append(enemy)

	# Tick 0.3s -- below the 0.5s interval, no damage should be dealt
	effect._process(0.3)
	assert_int(enemy._damage_taken.size()).is_equal(0)

	# Tick another 0.1s -- cumulative 0.4s, still below
	effect._process(0.1)
	assert_int(enemy._damage_taken.size()).is_equal(0)

	# Tick another 0.1s -- cumulative 0.5s, should trigger one tick
	effect._process(0.1)
	assert_int(enemy._damage_taken.size()).is_equal(1)

	# Tick another 0.3s -- cumulative 0.8s since last tick (0.3s), no new tick
	effect._process(0.3)
	assert_int(enemy._damage_taken.size()).is_equal(1)

	# Tick another 0.2s -- cumulative 0.5s since last tick, triggers again
	effect._process(0.2)
	assert_int(enemy._damage_taken.size()).is_equal(2)


# -- 8. test_enemies_outside_radius_unaffected ---------------------------------

func test_enemies_outside_radius_unaffected() -> void:
	var effect: Node2D = auto_free(_create_ground_effect(
		"lava_pool", 96.0, 3.0, 20.0, 0.0, "fire", Vector2(100.0, 100.0)
	))

	# Enemy well outside radius (300px away > 96px)
	var far_enemy: Node2D = auto_free(_make_enemy_stub(100, Vector2(400.0, 100.0)))
	# Enemy just barely outside radius (97px away > 96px)
	var edge_enemy: Node2D = auto_free(_make_enemy_stub(100, Vector2(197.0, 100.0)))
	# Enemy inside radius for comparison (50px away < 96px)
	var near_enemy: Node2D = auto_free(_make_enemy_stub(100, Vector2(150.0, 100.0)))

	EnemySystem._active_enemies.append(far_enemy)
	EnemySystem._active_enemies.append(edge_enemy)
	EnemySystem._active_enemies.append(near_enemy)

	# Tick past interval
	effect._process(0.5)

	# Far enemy: no damage
	assert_int(far_enemy._damage_taken.size()).is_equal(0)
	# Edge enemy: no damage (97 > 96)
	assert_int(edge_enemy._damage_taken.size()).is_equal(0)
	# Near enemy: damaged
	assert_int(near_enemy._damage_taken.size()).is_equal(1)
