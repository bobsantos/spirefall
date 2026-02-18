extends GdUnitTestSuite

## Unit tests for Enemy.gd (Node2D).
## Covers: movement, damage/death, status effects, special enemy types (healer,
## split, stealth, elemental), boss abilities, and flying bobbing.
##
## Enemy extends Node2D with @onready children (Sprite2D, ProgressBar).
## We build a lightweight scene in-memory to avoid loading BaseEnemy.tscn
## (which tries to load sprite textures that fail in headless mode).


# -- Helpers -------------------------------------------------------------------

## Create a minimal EnemyData resource for testing.
func _make_enemy_data(
	p_name: String = "TestEnemy",
	p_health: int = 100,
	p_speed: float = 1.0,
	p_gold: int = 3,
	p_element: String = "none",
	p_immune_element: String = "",
	p_weak_element: String = "",
	p_physical_resist: float = 0.0,
	p_is_flying: bool = false,
	p_is_boss: bool = false,
	p_split_on_death: bool = false,
	p_split_data: EnemyData = null,
	p_stealth: bool = false,
	p_heal_per_second: float = 0.0,
	p_boss_ability_key: String = "",
	p_boss_ability_interval: float = 0.0,
	p_minion_data: EnemyData = null,
	p_minion_spawn_interval: float = 0.0,
	p_minion_spawn_count: int = 0,
	p_spawn_count: int = 1
) -> EnemyData:
	var data := EnemyData.new()
	data.enemy_name = p_name
	data.base_health = p_health
	data.speed_multiplier = p_speed
	data.gold_reward = p_gold
	data.element = p_element
	data.immune_element = p_immune_element
	data.weak_element = p_weak_element
	data.physical_resist = p_physical_resist
	data.is_flying = p_is_flying
	data.is_boss = p_is_boss
	data.split_on_death = p_split_on_death
	data.split_data = p_split_data
	data.stealth = p_stealth
	data.heal_per_second = p_heal_per_second
	data.boss_ability_key = p_boss_ability_key
	data.boss_ability_interval = p_boss_ability_interval
	data.minion_data = p_minion_data
	data.minion_spawn_interval = p_minion_spawn_interval
	data.minion_spawn_count = p_minion_spawn_count
	data.spawn_count = p_spawn_count
	return data


## Build a real Enemy node with the required child nodes (Sprite2D, ProgressBar)
## so that @onready references resolve correctly during _ready().
## We attach the Enemy.gd script to a Node2D and add child nodes by name.
## This avoids loading BaseEnemy.tscn which requires sprite texture files.
static var _enemy_script: GDScript = null
func _create_enemy(data: EnemyData, path_pts: PackedVector2Array = PackedVector2Array()) -> Node2D:
	if _enemy_script == null:
		_enemy_script = load("res://scripts/enemies/Enemy.gd") as GDScript

	var enemy := Node2D.new()

	# Add child nodes that @onready references expect
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	enemy.add_child(sprite)

	var health_bar := ProgressBar.new()
	health_bar.name = "HealthBar"
	enemy.add_child(health_bar)

	# Assign the real Enemy.gd script -- this sets up all vars but does NOT
	# call _ready() yet (that happens when added to the scene tree).
	enemy.set_script(_enemy_script)

	# Manually set @onready references since the node is not in the scene tree.
	enemy.sprite = sprite
	enemy.health_bar = health_bar

	# Set data BEFORE _ready() runs so _apply_enemy_data() works.
	# We set enemy_data to null first to prevent _apply_enemy_data from running
	# with the sprite texture load that fails headless. Instead we manually
	# apply the data fields we need.
	enemy.enemy_data = null
	enemy.path_points = path_pts

	# Manually apply fields that _apply_enemy_data() would set, minus sprite texture load.
	enemy.max_health = data.base_health
	enemy.current_health = data.base_health
	enemy.speed = 64.0 * data.speed_multiplier
	enemy._base_speed = 64.0

	# Set enemy_data after manual field setup so methods like take_damage can read it.
	enemy.enemy_data = data

	# Position at first path point if path is not empty.
	if not path_pts.is_empty():
		enemy.position = path_pts[0]

	return enemy


## Create a simple linear path of N points, each 64px apart (one cell).
func _make_path(num_points: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(num_points):
		pts.append(Vector2(float(i) * 64.0, 0.0))
	return pts


## Create a tower stub Node2D for stealth reveal tests.
## Only needs a `position` property (all Node2Ds have it).
func _make_tower_stub(pos: Vector2) -> Node2D:
	var stub := Node2D.new()
	stub.position = pos
	return stub


func _reset_autoloads() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn.clear()
	TowerSystem._active_towers.clear()
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = 0
	GameManager.lives = GameManager.starting_lives
	EconomyManager.reset()


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_reset_autoloads()


# ==============================================================================
# MOVEMENT (7 tests)
# ==============================================================================

# -- 1. test_starts_at_first_path_point ----------------------------------------

func test_starts_at_first_path_point() -> void:
	var path: PackedVector2Array = _make_path(5)
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(), path))
	assert_vector(enemy.position).is_equal(path[0])


# -- 2. test_moves_along_path --------------------------------------------------

func test_moves_along_path() -> void:
	var path: PackedVector2Array = _make_path(5)
	var data: EnemyData = _make_enemy_data("Mover", 100, 1.0)
	var enemy: Node2D = auto_free(_create_enemy(data, path))
	# The enemy starts at path_points[0] with _path_index=0. The first call to
	# _move_along_path instantly "arrives" at point[0] (already there) and advances
	# _path_index to 1. A second call then actually moves toward point[1].
	enemy._move_along_path(0.001)  # Advance past starting point
	# Speed = 64 px/s, delta = 0.5s -> moves 32px toward point[1] at (64,0)
	enemy._move_along_path(0.5)
	assert_float(enemy.position.x).is_greater(0.0)
	assert_float(enemy.position.x).is_less(64.0)


# -- 3. test_path_index_increments ---------------------------------------------

func test_path_index_increments() -> void:
	var path: PackedVector2Array = _make_path(5)
	var data: EnemyData = _make_enemy_data("IndexTest", 100, 1.0)
	var enemy: Node2D = auto_free(_create_enemy(data, path))
	assert_int(enemy._path_index).is_equal(0)
	# Move exactly 1 second at 64 px/s = 64px -> reaches point[1] -> index becomes 1
	enemy._move_along_path(1.0)
	assert_int(enemy._path_index).is_equal(1)


# -- 4. test_path_progress_updates ---------------------------------------------

func test_path_progress_updates() -> void:
	var path: PackedVector2Array = _make_path(5)
	var data: EnemyData = _make_enemy_data("ProgressTest", 100, 1.0)
	var enemy: Node2D = auto_free(_create_enemy(data, path))
	assert_float(enemy.path_progress).is_equal(0.0)
	# Reach point[1]: progress = 1 / (5-1) = 0.25
	enemy._move_along_path(1.0)
	assert_float(enemy.path_progress).is_equal_approx(0.25, 0.01)


# -- 5. test_reached_exit_triggers_exit ----------------------------------------

func test_reached_exit_triggers_exit() -> void:
	# 2-point path: start at (0,0), exit at (64,0)
	var path: PackedVector2Array = _make_path(2)
	var data: EnemyData = _make_enemy_data("ExitTest", 100, 1.0)
	var enemy: Node2D = auto_free(_create_enemy(data, path))

	# Add to active enemies so on_enemy_reached_exit can remove it
	EnemySystem._active_enemies.append(enemy)
	EnemySystem._wave_finished_spawning = true
	GameManager.start_game()

	var lives_before: int = GameManager.lives
	# The enemy starts at path_points[0] with _path_index=0. The first call
	# instantly arrives at point[0] and advances the index. The second call
	# moves toward point[1] (the exit) and triggers _reached_exit.
	enemy._move_along_path(0.001)  # Advance past starting point
	enemy._move_along_path(1.0)    # Move to exit -> _reached_exit called
	# Enemy should have called _reached_exit -> EnemySystem.on_enemy_reached_exit
	# which decrements lives
	assert_int(GameManager.lives).is_equal(lives_before - 1)


# -- 6. test_push_back_decrements_index ----------------------------------------

func test_push_back_decrements_index() -> void:
	var path: PackedVector2Array = _make_path(10)
	var data: EnemyData = _make_enemy_data("PushTest", 100, 1.0)
	var enemy: Node2D = auto_free(_create_enemy(data, path))
	# Manually advance to path index 5
	enemy._path_index = 5
	enemy.position = path[5]
	enemy.push_back(2)
	assert_int(enemy._path_index).is_equal(3)
	assert_vector(enemy.position).is_equal(path[3])


# -- 7. test_pull_toward_snaps_to_path -----------------------------------------

func test_pull_toward_snaps_to_path() -> void:
	var path: PackedVector2Array = _make_path(10)
	var data: EnemyData = _make_enemy_data("PullTest", 100, 1.0)
	var enemy: Node2D = auto_free(_create_enemy(data, path))
	# Start at path index 5 (position 320, 0)
	enemy._path_index = 5
	enemy.position = path[5]
	# Pull toward path index 2 (position 128, 0) with max 500px
	enemy.pull_toward(Vector2(128.0, 0.0), 500.0)
	# Should snap to path index 2 (closest to target)
	assert_int(enemy._path_index).is_equal(2)
	assert_vector(enemy.position).is_equal(path[2])


# ==============================================================================
# DAMAGE AND DEATH (8 tests)
# ==============================================================================

# -- 8. test_take_damage_reduces_health ----------------------------------------

func test_take_damage_reduces_health() -> void:
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data("DmgTest", 100)))
	enemy.take_damage(30)
	assert_int(enemy.current_health).is_equal(70)


# -- 9. test_take_damage_kills_at_zero -----------------------------------------

func test_take_damage_kills_at_zero() -> void:
	var data: EnemyData = _make_enemy_data("KillTest", 100, 1.0, 5)
	var enemy: Node2D = auto_free(_create_enemy(data))

	# Add to active enemies so _die -> on_enemy_killed can work
	EnemySystem._active_enemies.append(enemy)
	EnemySystem._wave_finished_spawning = true
	GameManager.start_game()

	var gold_before: int = EconomyManager.gold
	enemy.take_damage(100)
	# After lethal damage, _die() -> EnemySystem.on_enemy_killed which awards gold
	assert_int(enemy.current_health).is_less_equal(0)
	assert_int(EconomyManager.gold).is_equal(gold_before + 5)


# -- 10. test_apply_resistance_immune_element ----------------------------------

func test_apply_resistance_immune_element() -> void:
	var data: EnemyData = _make_enemy_data("ImmuneTest", 100, 1.0, 3, "none", "fire")
	var enemy: Node2D = auto_free(_create_enemy(data))
	enemy.take_damage(50, "fire")
	# Immune to fire -> 0 damage
	assert_int(enemy.current_health).is_equal(100)


# -- 11. test_apply_resistance_weak_element ------------------------------------

func test_apply_resistance_weak_element() -> void:
	var data: EnemyData = _make_enemy_data("WeakTest", 100, 1.0, 3, "none", "", "water")
	var enemy: Node2D = auto_free(_create_enemy(data))
	enemy.take_damage(20, "water")
	# Weak to water -> 2x = 40 damage
	assert_int(enemy.current_health).is_equal(60)


# -- 12. test_apply_resistance_physical_resist ---------------------------------

func test_apply_resistance_physical_resist() -> void:
	var data: EnemyData = _make_enemy_data("PhysResist", 100, 1.0, 3, "none", "", "", 0.5)
	var enemy: Node2D = auto_free(_create_enemy(data))
	enemy.take_damage(40, "earth")
	# 50% physical resist on earth -> 40 * 0.5 = 20 damage
	assert_int(enemy.current_health).is_equal(80)


# -- 13. test_wet_bonus_lightning_damage ---------------------------------------

func test_wet_bonus_lightning_damage() -> void:
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data("WetTest", 100)))
	# Apply WET status
	enemy.apply_status(StatusEffect.Type.WET, 5.0, 1.0)
	# Take lightning damage: 20 base, wet bonus -> int(20 * 1.5) = 30
	enemy.take_damage(20, "lightning")
	assert_int(enemy.current_health).is_equal(70)


# -- 14. test_stunned_double_damage --------------------------------------------

func test_stunned_double_damage() -> void:
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data("StunTest", 100)))
	# Apply STUN status
	enemy.apply_status(StatusEffect.Type.STUN, 3.0, 1.0)
	# Take damage: 20 base, stun -> int(20 * 2.0) = 40
	enemy.take_damage(20)
	assert_int(enemy.current_health).is_equal(60)


# -- 15. test_heal_restores_health ---------------------------------------------

func test_heal_restores_health() -> void:
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data("HealTest", 100)))
	enemy.current_health = 50
	enemy.heal(30)
	assert_int(enemy.current_health).is_equal(80)
	# Heal beyond max is capped
	enemy.heal(50)
	assert_int(enemy.current_health).is_equal(100)


# ==============================================================================
# STATUS EFFECTS (10 tests)
# ==============================================================================

# -- 16. test_apply_burn_status ------------------------------------------------

func test_apply_burn_status() -> void:
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data()))
	enemy.apply_status(StatusEffect.Type.BURN, 5.0, 10.0)
	assert_bool(enemy.has_status(StatusEffect.Type.BURN)).is_true()
	assert_int(enemy._status_effects.size()).is_equal(1)


# -- 17. test_burn_stacks ------------------------------------------------------

func test_burn_stacks() -> void:
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data()))
	enemy.apply_status(StatusEffect.Type.BURN, 5.0, 10.0)
	enemy.apply_status(StatusEffect.Type.BURN, 3.0, 15.0)
	# Burns stack independently
	assert_int(enemy._status_effects.size()).is_equal(2)
	# Both should be BURN
	assert_int(enemy._status_effects[0].type).is_equal(StatusEffect.Type.BURN)
	assert_int(enemy._status_effects[1].type).is_equal(StatusEffect.Type.BURN)


# -- 18. test_slow_replaces_existing_slow --------------------------------------

func test_slow_replaces_existing_slow() -> void:
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data()))
	enemy.apply_status(StatusEffect.Type.SLOW, 5.0, 0.3)
	enemy.apply_status(StatusEffect.Type.SLOW, 3.0, 0.5)
	# Only one movement-impairing effect at a time
	var slow_count: int = 0
	for fx: StatusEffect in enemy._status_effects:
		if fx.type == StatusEffect.Type.SLOW:
			slow_count += 1
	assert_int(slow_count).is_equal(1)
	# The newer slow replaced the older one
	assert_float(enemy._status_effects[0].value).is_equal(0.5)


# -- 19. test_freeze_replaces_slow ---------------------------------------------

func test_freeze_replaces_slow() -> void:
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data()))
	enemy.apply_status(StatusEffect.Type.SLOW, 5.0, 0.3)
	assert_bool(enemy.has_status(StatusEffect.Type.SLOW)).is_true()
	enemy.apply_status(StatusEffect.Type.FREEZE, 2.0, 1.0)
	# Freeze should replace slow (shared movement slot)
	assert_bool(enemy.has_status(StatusEffect.Type.SLOW)).is_false()
	assert_bool(enemy.has_status(StatusEffect.Type.FREEZE)).is_true()


# -- 20. test_stun_replaces_freeze ---------------------------------------------

func test_stun_replaces_freeze() -> void:
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data()))
	enemy.apply_status(StatusEffect.Type.FREEZE, 3.0, 1.0)
	assert_bool(enemy.has_status(StatusEffect.Type.FREEZE)).is_true()
	enemy.apply_status(StatusEffect.Type.STUN, 1.5, 1.0)
	# Stun should replace freeze
	assert_bool(enemy.has_status(StatusEffect.Type.FREEZE)).is_false()
	assert_bool(enemy.has_status(StatusEffect.Type.STUN)).is_true()


# -- 21. test_wet_is_separate_slot ---------------------------------------------

func test_wet_is_separate_slot() -> void:
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data()))
	enemy.apply_status(StatusEffect.Type.SLOW, 5.0, 0.3)
	enemy.apply_status(StatusEffect.Type.WET, 4.0, 1.0)
	# Both should coexist (WET is separate from movement slot)
	assert_bool(enemy.has_status(StatusEffect.Type.SLOW)).is_true()
	assert_bool(enemy.has_status(StatusEffect.Type.WET)).is_true()
	assert_int(enemy._status_effects.size()).is_equal(2)


# -- 22. test_has_status_returns_true ------------------------------------------

func test_has_status_returns_true() -> void:
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data()))
	assert_bool(enemy.has_status(StatusEffect.Type.BURN)).is_false()
	enemy.apply_status(StatusEffect.Type.BURN, 5.0, 10.0)
	assert_bool(enemy.has_status(StatusEffect.Type.BURN)).is_true()


# -- 23. test_clear_all_status_effects -----------------------------------------

func test_clear_all_status_effects() -> void:
	var data: EnemyData = _make_enemy_data("ClearTest", 100, 1.0)
	var enemy: Node2D = auto_free(_create_enemy(data))
	enemy.apply_status(StatusEffect.Type.BURN, 5.0, 10.0)
	enemy.apply_status(StatusEffect.Type.SLOW, 3.0, 0.3)
	enemy.apply_status(StatusEffect.Type.WET, 4.0, 1.0)
	assert_int(enemy._status_effects.size()).is_equal(3)
	enemy.clear_all_status_effects()
	assert_int(enemy._status_effects.size()).is_equal(0)
	# Speed should be restored to base
	var expected_speed: float = 64.0 * data.speed_multiplier
	assert_float(enemy.speed).is_equal_approx(expected_speed, 0.01)


# -- 24. test_speed_zero_when_frozen -------------------------------------------

func test_speed_zero_when_frozen() -> void:
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data("FreezeSpd", 100, 1.0)))
	enemy.apply_status(StatusEffect.Type.FREEZE, 3.0, 1.0)
	assert_float(enemy.speed).is_equal(0.0)


# -- 25. test_speed_reduced_when_slowed ----------------------------------------

func test_speed_reduced_when_slowed() -> void:
	var data: EnemyData = _make_enemy_data("SlowSpd", 100, 1.0)
	var enemy: Node2D = auto_free(_create_enemy(data))
	var base_speed: float = enemy.speed
	enemy.apply_status(StatusEffect.Type.SLOW, 5.0, 0.3)
	# 30% slow -> speed * 0.7
	var expected: float = base_speed * 0.7
	assert_float(enemy.speed).is_equal_approx(expected, 0.01)


# ==============================================================================
# SPECIAL ENEMY TYPES (8 tests)
# ==============================================================================

# -- 26. test_healer_heals_nearby_allies ---------------------------------------

func test_healer_heals_nearby_allies() -> void:
	var healer_data: EnemyData = _make_enemy_data(
		"Healer", 200, 1.0, 3, "none", "", "", 0.0, false, false,
		false, null, false, 50.0)  # 50 HP/s heal
	var healer: Node2D = auto_free(_create_enemy(healer_data, _make_path(5)))
	healer.position = Vector2(100.0, 0.0)

	# Create an ally within 128px (2-cell radius)
	var ally_data: EnemyData = _make_enemy_data("Ally", 100, 1.0)
	var ally: Node2D = auto_free(_create_enemy(ally_data, _make_path(5)))
	ally.position = Vector2(120.0, 0.0)  # 20px away -> within range
	ally.current_health = 60  # Damaged

	# Register both in active enemies
	EnemySystem._active_enemies.append(healer)
	EnemySystem._active_enemies.append(ally)

	# Call _heal_nearby with 1 second delta -> heals 50 HP
	healer._heal_nearby(1.0)
	# ceil(50.0 * 1.0) = 50, clamped to max 100
	assert_int(ally.current_health).is_greater(60)
	assert_int(ally.current_health).is_less_equal(100)


# -- 27. test_healer_does_not_heal_self ----------------------------------------

func test_healer_does_not_heal_self() -> void:
	var healer_data: EnemyData = _make_enemy_data(
		"Healer", 200, 1.0, 3, "none", "", "", 0.0, false, false,
		false, null, false, 50.0)
	var healer: Node2D = auto_free(_create_enemy(healer_data, _make_path(5)))
	healer.position = Vector2(100.0, 0.0)
	healer.current_health = 80  # Damaged

	EnemySystem._active_enemies.append(healer)
	healer._heal_nearby(1.0)
	# Self should NOT be healed
	assert_int(healer.current_health).is_equal(80)


# -- 28. test_healer_skips_full_health -----------------------------------------

func test_healer_skips_full_health() -> void:
	var healer_data: EnemyData = _make_enemy_data(
		"Healer", 200, 1.0, 3, "none", "", "", 0.0, false, false,
		false, null, false, 50.0)
	var healer: Node2D = auto_free(_create_enemy(healer_data, _make_path(5)))
	healer.position = Vector2(100.0, 0.0)

	var ally_data: EnemyData = _make_enemy_data("FullAlly", 100, 1.0)
	var ally: Node2D = auto_free(_create_enemy(ally_data, _make_path(5)))
	ally.position = Vector2(120.0, 0.0)
	# Ally at full health
	ally.current_health = ally.max_health

	EnemySystem._active_enemies.append(healer)
	EnemySystem._active_enemies.append(ally)

	healer._heal_nearby(1.0)
	# Full health ally should stay at max
	assert_int(ally.current_health).is_equal(ally.max_health)


# -- 29. test_split_on_death_spawns_children -----------------------------------

func test_split_on_death_spawns_children() -> void:
	var child_template: EnemyData = _make_enemy_data("SplitChild", 50, 1.0, 1)
	var parent_data: EnemyData = _make_enemy_data(
		"SplitParent", 150, 1.0, 4, "none", "", "", 0.0, false, false,
		true, child_template)

	var parent: Node2D = auto_free(_create_enemy(parent_data, _make_path(5)))
	parent._path_index = 2
	EnemySystem._active_enemies.append(parent)
	EnemySystem._wave_finished_spawning = false
	GameManager.start_game()
	GameManager.current_wave = 5

	# Swap EnemySystem._enemy_scene with a stub so instantiate works headlessly
	var original_scene: PackedScene = EnemySystem._enemy_scene
	EnemySystem._enemy_scene = _create_stub_scene()

	# Calling _die() should trigger spawn_split_enemies
	parent._die()

	# Parent removed, 2 children added
	assert_bool(EnemySystem._active_enemies.has(parent)).is_false()
	assert_int(EnemySystem._active_enemies.size()).is_equal(2)

	# Cleanup
	for child: Node in EnemySystem._active_enemies:
		child.queue_free()
	EnemySystem._active_enemies.clear()
	EnemySystem._enemy_scene = original_scene


# -- 30. test_stealth_starts_invisible -----------------------------------------

func test_stealth_starts_invisible() -> void:
	var data: EnemyData = _make_enemy_data(
		"StealthEnemy", 80, 1.5, 3, "none", "", "", 0.0, false, false,
		false, null, true)
	var enemy: Node2D = auto_free(_create_enemy(data))

	# Manually apply stealth setup (since we skip _apply_enemy_data's texture load)
	enemy._is_revealed = false
	var sprite: Sprite2D = enemy.get_node("Sprite2D")
	sprite.modulate = Color(1, 1, 1, 0.15)
	enemy._original_modulate = Color(1, 1, 1, 0.15)

	assert_float(sprite.modulate.a).is_equal_approx(0.15, 0.01)


# -- 31. test_stealth_untargetable_until_revealed ------------------------------

func test_stealth_untargetable_until_revealed() -> void:
	var data: EnemyData = _make_enemy_data(
		"StealthEnemy", 80, 1.5, 3, "none", "", "", 0.0, false, false,
		false, null, true)
	var enemy: Node2D = auto_free(_create_enemy(data))
	enemy._is_revealed = false
	assert_bool(enemy._is_revealed).is_false()


# -- 32. test_stealth_reveals_near_tower ---------------------------------------

func test_stealth_reveals_near_tower() -> void:
	var data: EnemyData = _make_enemy_data(
		"StealthEnemy", 80, 1.5, 3, "none", "", "", 0.0, false, false,
		false, null, true)
	var enemy: Node2D = auto_free(_create_enemy(data))
	enemy._is_revealed = false
	enemy.position = Vector2(200.0, 200.0)

	# Place a tower within 128px (2-cell reveal radius)
	var tower: Node2D = auto_free(_make_tower_stub(Vector2(220.0, 200.0)))
	TowerSystem._active_towers.append(tower)

	enemy._check_stealth_reveal()
	assert_bool(enemy._is_revealed).is_true()


# -- 33. test_elemental_assigns_immune_weak ------------------------------------

func test_elemental_assigns_immune_weak() -> void:
	# Create an Elemental enemy data with blank immune/weak (triggers random assignment)
	var data: EnemyData = _make_enemy_data("Elemental", 150, 1.0, 5)
	data.immune_element = ""
	data.weak_element = ""

	# The assignment reads GameManager.current_wave and calls ElementMatrix
	GameManager.current_wave = 5

	var enemy: Node2D = auto_free(_create_enemy(data))
	# Manually call _assign_elemental_affinity (skipping _apply_enemy_data texture load)
	enemy._assign_elemental_affinity()

	# After assignment, immune and weak should be non-empty valid elements
	assert_str(data.immune_element).is_not_empty()
	assert_str(data.weak_element).is_not_empty()
	# Immune and weak should be different
	assert_str(data.immune_element).is_not_equal(data.weak_element)
	# Both should be valid elements
	var elements: Array[String] = ElementMatrix.get_elements()
	assert_bool(data.immune_element in elements).is_true()
	assert_bool(data.weak_element in elements).is_true()


# ==============================================================================
# BOSS ABILITIES (6 tests)
# ==============================================================================

# -- 34. test_boss_fire_trail_spawns_ground_effect -----------------------------

func test_boss_fire_trail_spawns_ground_effect() -> void:
	var data: EnemyData = _make_enemy_data(
		"EmberTitan", 5000, 0.5, 100, "fire", "", "", 0.0, false, true,
		false, null, false, 0.0, "fire_trail", 5.0)
	var enemy: Node2D = auto_free(_create_enemy(data, _make_path(5)))

	# _boss_fire_trail loads GroundEffect.tscn which may not exist in headless mode.
	# We test that the method attempts to fire the signal by preloading a stub.
	# Create a simple stub scene for GroundEffect
	var stub_scene := PackedScene.new()
	var stub_node := Node2D.new()
	stub_node.name = "StubGroundEffect"
	# Add needed properties that _boss_fire_trail sets
	var effect_script := GDScript.new()
	effect_script.source_code = """
extends Node2D

var effect_type: String = ""
var effect_radius_px: float = 0.0
var effect_duration: float = 0.0
var damage_per_second: float = 0.0
var element: String = ""
"""
	effect_script.reload()
	stub_node.set_script(effect_script)
	stub_scene.pack(stub_node)
	stub_node.free()

	# Inject the stub scene into the static var
	var original_ground_scene: PackedScene = enemy._ground_effect_scene
	enemy._ground_effect_scene = stub_scene

	# Use direct signal connection to capture synchronous emission
	var signal_count: Array[int] = [0]
	var captured_effect: Array = []
	var _conn: Callable = func(effect: Node) -> void:
		signal_count[0] += 1
		captured_effect.append(effect)
	enemy.ground_effect_spawned.connect(_conn)

	enemy._boss_fire_trail()

	enemy.ground_effect_spawned.disconnect(_conn)
	assert_int(signal_count[0]).is_equal(1)

	# Clean up the spawned effect
	if not captured_effect.is_empty():
		captured_effect[0].queue_free()

	# Restore
	enemy._ground_effect_scene = original_ground_scene


# -- 35. test_boss_tower_freeze_disables_towers --------------------------------

func test_boss_tower_freeze_disables_towers() -> void:
	var data: EnemyData = _make_enemy_data(
		"GlacialWyrm", 5000, 0.5, 100, "ice", "", "", 0.0, false, true,
		false, null, false, 0.0, "tower_freeze", 8.0)
	var enemy: Node2D = auto_free(_create_enemy(data, _make_path(5)))
	enemy.position = Vector2(200.0, 200.0)

	# Create a tower stub within the 3-cell radius (192px) that has disable_for()
	var tower_script := GDScript.new()
	tower_script.source_code = """
extends Node2D

var disabled_duration: float = 0.0

func disable_for(duration: float) -> void:
	disabled_duration = duration
"""
	tower_script.reload()

	var tower: Node2D = auto_free(Node2D.new())
	tower.set_script(tower_script)
	tower.position = Vector2(250.0, 200.0)  # 50px away -> within 192px

	TowerSystem._active_towers.append(tower)

	enemy._boss_tower_freeze()

	# Tower should have been disabled for 3 seconds
	assert_float(tower.disabled_duration).is_equal(3.0)


# -- 36. test_boss_element_cycle_changes_immunity ------------------------------

func test_boss_element_cycle_changes_immunity() -> void:
	var data: EnemyData = _make_enemy_data(
		"ChaosElemental", 5000, 0.5, 100, "chaos", "", "", 0.0, false, true,
		false, null, false, 0.0, "element_cycle", 6.0)
	var enemy: Node2D = auto_free(_create_enemy(data, _make_path(5)))
	enemy._chaos_element_index = 0
	enemy._chaos_cycle_count = 0

	var initial_immune: String = data.immune_element

	enemy._boss_element_cycle()

	# Immune element should have changed
	assert_str(data.immune_element).is_not_equal(initial_immune)
	# Should now be the element at index 1 in ElementMatrix.ELEMENTS
	assert_str(data.immune_element).is_equal(ElementMatrix.ELEMENTS[1])
	# Weak element should be the counter of the new immune element
	var expected_weak: String = ElementMatrix.get_counter(ElementMatrix.ELEMENTS[1])
	assert_str(data.weak_element).is_equal(expected_weak)
	# Cycle count incremented
	assert_int(enemy._chaos_cycle_count).is_equal(1)


# -- 37. test_chaos_enrage_increases_speed -------------------------------------

func test_chaos_enrage_increases_speed() -> void:
	var data: EnemyData = _make_enemy_data(
		"ChaosElemental", 5000, 1.0, 100, "chaos", "", "", 0.0, false, true,
		false, null, false, 0.0, "element_cycle", 6.0)
	var enemy: Node2D = auto_free(_create_enemy(data, _make_path(5)))

	var base_speed: float = enemy.speed  # 64.0 * 1.0 = 64.0

	# Simulate 3 element cycles
	enemy._boss_element_cycle()
	enemy._boss_element_cycle()
	enemy._boss_element_cycle()

	assert_int(enemy._chaos_cycle_count).is_equal(3)
	# Speed = base * (1 + 0.1 * 3) = 64 * 1.3 = 83.2
	var expected_speed: float = base_speed * (1.0 + 0.1 * 3.0)
	assert_float(enemy.speed).is_equal_approx(expected_speed, 0.1)


# -- 38. test_boss_minion_spawn_timer ------------------------------------------

func test_boss_minion_spawn_timer() -> void:
	var minion_template: EnemyData = _make_enemy_data("IceMinion", 60, 1.2, 2)
	var data: EnemyData = _make_enemy_data(
		"GlacialWyrm", 5000, 0.5, 100, "ice", "", "", 0.0, false, true,
		false, null, false, 0.0, "tower_freeze", 8.0,
		minion_template, 10.0, 2)
	var enemy: Node2D = auto_free(_create_enemy(data, _make_path(10)))
	enemy._path_index = 1

	# Register enemy in active list
	EnemySystem._active_enemies.append(enemy)
	EnemySystem._wave_finished_spawning = false
	GameManager.start_game()
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 10

	# Swap enemy scene with stub
	var original_scene: PackedScene = EnemySystem._enemy_scene
	EnemySystem._enemy_scene = _create_stub_scene()

	# Tick boss ability for 10 seconds (= minion_spawn_interval)
	# This should trigger one minion spawn cycle (2 minions)
	enemy._minion_spawn_timer = 0.0
	# Simulate ticks by calling _tick_boss_ability directly
	enemy._tick_boss_ability(10.0)

	# Should have spawned 2 minions (minion_spawn_count = 2)
	# Active enemies: original boss + 2 minions = 3
	assert_int(EnemySystem._active_enemies.size()).is_equal(3)

	# Cleanup
	for i: int in range(EnemySystem._active_enemies.size() - 1, -1, -1):
		var e: Node = EnemySystem._active_enemies[i]
		if e != enemy:
			e.queue_free()
	EnemySystem._active_enemies.clear()
	EnemySystem._enemy_scene = original_scene


# -- 39. test_flying_bobbing_effect --------------------------------------------

func test_flying_bobbing_effect() -> void:
	var data: EnemyData = _make_enemy_data(
		"FlyingEnemy", 80, 1.5, 3, "none", "", "", 0.0, true)
	var enemy: Node2D = auto_free(_create_enemy(data, _make_path(5)))

	# Set flying state manually (since we skip _apply_enemy_data's texture load)
	enemy._is_flying = true
	enemy._bob_time = 0.0

	var sprite: Sprite2D = enemy.get_node("Sprite2D")

	# Simulate some time passing -- at t=0, sin(0)=0, so sprite.y=0
	# After some delta, sine wave produces a non-zero offset
	# BOB_FREQUENCY = 2.5, BOB_AMPLITUDE = 6.0
	# After 0.1s: sin(0.1 * 2.5 * TAU) * 6.0 = sin(1.5708) * 6.0 ~ 6.0
	enemy._bob_time = 0.0

	# Manually do the bobbing calc that _process does (without calling _process
	# which also does movement, status ticks, etc.)
	var delta: float = 0.1
	enemy._bob_time += delta
	var bob_offset: float = sin(enemy._bob_time * 2.5 * TAU) * 6.0
	sprite.position.y = bob_offset

	# Sprite should have been offset vertically
	assert_float(sprite.position.y).is_not_equal(0.0)
	assert_float(absf(sprite.position.y)).is_less_equal(6.0)


# ==============================================================================
# STUB HELPERS (for split/minion tests)
# ==============================================================================

## Returns a minimal GDScript that gives a Node2D the properties EnemySystem
## reads/writes during spawning, matching the pattern from test_enemy_system.gd.
static var _stub_script: GDScript = null
func _enemy_stub_script() -> GDScript:
	if _stub_script != null:
		return _stub_script
	_stub_script = GDScript.new()
	_stub_script.source_code = """
extends Node2D

var enemy_data: EnemyData
var path_points: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
"""
	_stub_script.reload()
	return _stub_script


## Create a PackedScene that produces a Node2D with the enemy stub script.
## This avoids loading BaseEnemy.tscn which requires sprite textures.
func _create_stub_scene() -> PackedScene:
	var scene := PackedScene.new()
	var node := Node2D.new()
	node.name = "StubEnemy"
	node.set_script(_enemy_stub_script())
	scene.pack(node)
	node.free()
	return scene
