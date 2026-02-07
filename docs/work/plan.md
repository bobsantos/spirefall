# Spirefall Phase 3A: Automated Testing Plan

**Goal:** Establish comprehensive automated testing for all core game systems using GdUnit4, achieving at least 85% code coverage across gameplay logic. This hardens Phase 1 and Phase 2 implementations against regressions before Phase 3 feature development begins.

**Reference:** GDD Section 13.3 (Weeks 9-10: Polish and QA)

---

## Testing Framework Setup

### GdUnit4 v6.1.1

**What it is:** GdUnit4 is the most mature unit/integration testing framework for Godot 4.x GDScript. It provides assertion APIs, mocking/spying, scene runners for integration tests, signal monitoring, and a CLI runner for CI/CD.

**Installation status:** Installed at `addons/gdUnit4/` and enabled in `project.godot` under `[editor_plugins]`.

**Directory structure:**
```
tests/
  unit/
    autoload/           # GameManager, EconomyManager, GridManager, PathfindingSystem, TowerSystem, EnemySystem, FusionRegistry
    enemies/            # Enemy, EnemyData, StatusEffect
    towers/             # Tower, TowerData
    projectiles/        # Projectile
    systems/            # ElementMatrix, ElementSynergy
    effects/            # GroundEffect
  integration/          # Multi-system interaction tests
  resources/            # Test-specific .tres fixtures
```

**Running tests:**

From the Godot editor: open the GdUnit4 panel (via the bottom dock or Project > Tools > GdUnit4) and click Run All.

From the command line:
```bash
# Set GODOT_BIN to your Godot 4.6 binary path
export GODOT_BIN=/path/to/godot

# Run all tests
./addons/gdUnit4/runtest.sh --add tests/

# Run a specific test suite
./addons/gdUnit4/runtest.sh --add tests/unit/autoload/test_economy_manager.gd

# Run tests matching a pattern
./addons/gdUnit4/runtest.sh --add tests/unit/ -i "test_*"
```

**Test naming convention:**
- Test suite files: `test_{script_name}.gd` (e.g., `test_economy_manager.gd`)
- Test functions: `test_{behavior_under_test}` (e.g., `test_spend_gold_reduces_balance`)
- Mirrors source layout: `scripts/autoload/EconomyManager.gd` -> `tests/unit/autoload/test_economy_manager.gd`

**Test template:**
```gdscript
extends GdUnitTestSuite

# Runs once before all tests in this suite
func before() -> void:
    pass

# Runs before each individual test
func before_test() -> void:
    pass

# Runs after each individual test
func after_test() -> void:
    pass

# Runs once after all tests in this suite
func after() -> void:
    pass

func test_example_behavior() -> void:
    assert_int(42).is_equal(42)
```

### Testing Best Practices for Godot GDScript

1. **Isolate autoloads.** Autoloads persist across tests. Always reset state in `before_test()` (e.g., `EconomyManager.reset()`, clear active enemy/tower arrays). Alternatively, create local instances of the class under test to avoid cross-contamination.

2. **Use `auto_free()` for scene nodes.** Any Node created in a test must be freed. Wrap with `auto_free()` to ensure cleanup even if the test fails.

3. **Prefer pure logic tests over scene tests.** Test calculations, state transitions, and data transformations directly by calling methods on isolated objects. Reserve `scene_runner()` for integration tests that need `_process()` ticking.

4. **Avoid `randf()` in deterministic tests.** For tests involving random behavior (freeze chance, elemental assignment), seed the RNG or test boundary conditions (0% and 100% chance).

5. **Test data with `.tres` fixtures.** Create minimal test-specific `.tres` resources in `tests/resources/` rather than loading full production resources (avoids coupling tests to balance changes).

6. **Signal testing.** Use `monitor_signals()` + `assert_signal()` to verify signal emission without wiring up full scene trees.

7. **Keep tests fast.** Target < 1 second per test. Use `await_millis()` only for integration tests that need frame ticks. Most unit tests should be synchronous.

8. **One behavior per test.** Each `test_*` function verifies one specific behavior. Use descriptive names: `test_burn_damage_ticks_once_per_second`, not `test_burn`.

---

## Codebase Analysis: Coverage Targets

| Script | Lines | Testability | Target Coverage | Priority |
|--------|-------|-------------|----------------|----------|
| `EconomyManager.gd` | 56 | Pure logic, no scene deps | 95% | P0 |
| `StatusEffect.gd` | 49 | Pure RefCounted, no deps | 95% | P0 |
| `ElementMatrix.gd` | 71 | Static pure functions | 95% | P0 |
| `EnemyData.gd` | 28 | Data class, minimal logic | 90% | P0 |
| `TowerData.gd` | 24 | Data class, minimal logic | 90% | P0 |
| `GameManager.gd` | 98 | State machine, autoload deps | 90% | P0 |
| `GridManager.gd` | 113 | Grid logic, PathfindingSystem dep | 90% | P0 |
| `PathfindingSystem.gd` | 71 | AStarGrid2D wrapper | 85% | P0 |
| `EnemySystem.gd` | 314 | Wave spawning, scaling formulas | 85% | P1 |
| `TowerSystem.gd` | 116 | Factory pattern, autoload deps | 90% | P1 |
| `FusionRegistry.gd` | 144 | Pure lookup logic | 90% | P1 |
| `ElementSynergy.gd` | 259 | Counting + bonus calc | 85% | P1 |
| `Enemy.gd` | 517 | Scene node, complex behaviors | 80% | P1 |
| `Tower.gd` | 439 | Scene node, targeting/attacks | 80% | P1 |
| `Projectile.gd` | 370 | Scene node, damage/specials | 80% | P2 |
| `GroundEffect.gd` | 93 | Scene node, tick-based | 80% | P2 |
| `Game.gd` | 409 | Orchestrator, integration only | 70% | P3 |
| `BuildMenu.gd` | 235 | UI, visual-heavy | 50% | P3 |
| `TowerInfoPanel.gd` | 327 | UI, visual-heavy | 50% | P3 |
| `WavePreviewPanel.gd` | 212 | UI, visual-heavy | 50% | P3 |
| `HUD.gd` | 113 | UI, visual-heavy | 40% | P3 |
| `CodexPanel.gd` | 712 | UI, visual-heavy | 40% | P3 |
| `GameOverScreen.gd` | 34 | UI, trivial | 30% | P3 |
| `ForestClearing.gd` | 73 | Map setup, visual | 50% | P3 |
| `UIManager.gd` | 69 | Thin pass-through | 60% | P3 |
| `AudioManager.gd` | 43 | Stub, no behavior | Skip | -- |

**Weighted target: 85% coverage across P0+P1+P2 scripts (2,367 lines of core logic).**

---

## Implementation Tasks

### Task 1: EconomyManager Tests ✅ COMPLETE

**File:** `tests/unit/autoload/test_economy_manager.gd`
**Source:** `scripts/autoload/EconomyManager.gd` (56 lines)
**Effort:** Small
**Priority:** P0 -- pure logic, zero dependencies, ideal first test suite
**Status:** Complete - 18/18 tests implemented

This is the simplest autoload to test and establishes the testing pattern for all other suites.

**Test cases:**

| # | Test | Behavior |
|---|------|----------|
| 1 | `test_starting_gold_is_100` | `gold == 100` after `_ready()` |
| 2 | `test_reset_restores_starting_gold` | After spending, `reset()` returns gold to 100 |
| 3 | `test_add_gold_increases_balance` | `add_gold(50)` -> gold == 150 |
| 4 | `test_spend_gold_reduces_balance` | `spend_gold(30)` -> gold == 70, returns true |
| 5 | `test_spend_gold_fails_when_insufficient` | `spend_gold(200)` -> gold unchanged, returns false |
| 6 | `test_can_afford_true_when_enough` | `can_afford(100)` -> true |
| 7 | `test_can_afford_false_when_not_enough` | `can_afford(101)` -> false |
| 8 | `test_can_afford_exact_amount` | `can_afford(100)` -> true (edge case: exact balance) |
| 9 | `test_interest_at_100_gold` | 100g at 5% -> +5g (1 tier) |
| 10 | `test_interest_at_500_gold` | 500g at 25% cap -> +125g |
| 11 | `test_interest_at_600_gold_capped` | 600g still capped at 25% -> +150g |
| 12 | `test_interest_at_99_gold_zero` | 99g -> 0 tiers -> +0g |
| 13 | `test_interest_at_250_gold` | 250g at 10% -> +25g |
| 14 | `test_wave_bonus_base_formula` | `calculate_wave_bonus(5, 1)` -> 10 + 15 = 25 |
| 15 | `test_wave_bonus_no_leak_multiplier` | `calculate_wave_bonus(5, 0)` -> 25 * 1.25 = 31 |
| 16 | `test_wave_bonus_wave_1` | `calculate_wave_bonus(1, 0)` -> (10+3)*1.25 = 16 |
| 17 | `test_gold_changed_signal_on_add` | Signal emitted with correct value |
| 18 | `test_insufficient_funds_signal` | Signal emitted when spend fails |

**Acceptance:** All 18 tests pass. 100% function coverage of EconomyManager.

---

### Task 2: StatusEffect Tests ✅ COMPLETE

**File:** `tests/unit/enemies/test_status_effect.gd`
**Source:** `scripts/enemies/StatusEffect.gd` (49 lines)
**Effort:** Small
**Priority:** P0 -- pure RefCounted, no scene dependencies
**Status:** Complete - 12/12 tests implemented

**Test cases:**

| # | Test | Behavior |
|---|------|----------|
| 1 | `test_burn_creation` | Type, duration, value set correctly |
| 2 | `test_burn_tick_returns_damage_per_second` | `tick(1.0)` returns `value` (one full second) |
| 3 | `test_burn_tick_partial_no_damage` | `tick(0.5)` returns 0.0 (not yet 1s elapsed) |
| 4 | `test_burn_tick_accumulates` | `tick(0.6)` + `tick(0.6)` -> second tick returns value (1.2s total) |
| 5 | `test_slow_tick_returns_zero` | SLOW `tick()` always returns 0.0 |
| 6 | `test_freeze_tick_returns_zero` | FREEZE `tick()` always returns 0.0 |
| 7 | `test_stun_tick_returns_zero` | STUN `tick()` always returns 0.0 |
| 8 | `test_wet_tick_returns_zero` | WET `tick()` always returns 0.0 |
| 9 | `test_is_expired_false_while_active` | Duration 3.0 after tick(1.0) -> not expired |
| 10 | `test_is_expired_true_when_depleted` | Duration 1.0 after tick(1.0) -> expired |
| 11 | `test_is_expired_true_when_overshot` | Duration 1.0 after tick(2.0) -> expired |
| 12 | `test_type_to_string_all_types` | All 5 enum values map to correct strings |

**Acceptance:** 100% line coverage of StatusEffect.gd. All 12 tests pass.

---

### Task 3: ElementMatrix Tests

**File:** `tests/unit/systems/test_element_matrix.gd`
**Source:** `scripts/systems/ElementMatrix.gd` (71 lines)
**Effort:** Small
**Priority:** P0 -- static class, no dependencies

**Test cases:**

| # | Test | Behavior |
|---|------|----------|
| 1 | `test_get_multiplier_strong` | fire vs earth -> 1.5 |
| 2 | `test_get_multiplier_weak` | fire vs water -> 0.5 |
| 3 | `test_get_multiplier_neutral` | fire vs fire -> 1.0 |
| 4 | `test_get_multiplier_slight_strong` | wind vs earth -> 1.25 |
| 5 | `test_get_multiplier_slight_weak` | water vs lightning -> 0.75 |
| 6 | `test_get_multiplier_none_target` | fire vs "none" -> 1.0 |
| 7 | `test_get_multiplier_chaos_target` | fire vs "chaos" -> 1.0 |
| 8 | `test_get_multiplier_unknown_attacker` | "plasma" vs fire -> 1.0 |
| 9 | `test_matrix_symmetry_spot_checks` | Verify a few attacker/defender pairs for correctness per GDD |
| 10 | `test_all_36_combinations` | Iterate all 6x6 pairs and verify each matches MATRIX const |
| 11 | `test_get_elements_returns_6` | Array size == 6, contains all expected strings |
| 12 | `test_get_counter_fire` | Counter of fire is water |
| 13 | `test_get_counter_all_6` | All 6 elements have correct counters per COUNTERS const |
| 14 | `test_get_counter_unknown` | "none" -> "" |
| 15 | `test_get_color_fire` | Returns Color(1.0, 0.4, 0.2) |
| 16 | `test_get_color_unknown` | Returns Color.WHITE |
| 17 | `test_get_color_all_6` | All 6 elements return non-WHITE colors |

**Acceptance:** 100% coverage of ElementMatrix.gd.

---

### Task 4: GameManager Tests

**File:** `tests/unit/autoload/test_game_manager.gd`
**Source:** `scripts/autoload/GameManager.gd` (98 lines)
**Effort:** Medium
**Priority:** P0 -- state machine, but depends on EconomyManager and EnemySystem

GameManager is tightly coupled to EnemySystem (for wave finished checks) and EconomyManager (for interest/bonuses). Tests either use the real autoloads with careful reset, or mock the dependencies.

**Test cases:**

| # | Test | Behavior |
|---|------|----------|
| 1 | `test_initial_state_is_menu` | `game_state == MENU` before `start_game()` |
| 2 | `test_start_game_transitions_to_build` | `start_game()` -> BUILD_PHASE, wave==1, lives==20 |
| 3 | `test_start_game_emits_phase_changed` | Signal emitted with BUILD_PHASE |
| 4 | `test_lose_life_decrements` | `lose_life(1)` -> lives == 19 |
| 5 | `test_lose_all_lives_triggers_game_over` | `lose_life(20)` -> GAME_OVER, lives==0 |
| 6 | `test_lose_life_clamps_at_zero` | `lose_life(25)` -> lives==0 |
| 7 | `test_record_enemy_leak_increments` | `record_enemy_leak()` increases `_enemies_leaked_this_wave` |
| 8 | `test_start_wave_early_from_build_phase` | Transitions to COMBAT_PHASE |
| 9 | `test_start_wave_early_bonus_gold` | Bonus = remaining_timer * 10, added to gold |
| 10 | `test_start_wave_early_emits_bonus_signal` | `early_wave_bonus` signal emitted |
| 11 | `test_start_wave_early_ignored_in_combat` | No state change if already in COMBAT |
| 12 | `test_wave_cleared_advances_to_build` | After combat, transitions to BUILD, wave increments |
| 13 | `test_wave_cleared_income_phase_every_5` | Wave 5, 10, 15... -> INCOME_PHASE -> BUILD_PHASE |
| 14 | `test_wave_cleared_at_max_waves_game_over` | Wave 30 cleared -> GAME_OVER victory |
| 15 | `test_game_over_victory_true_at_max` | `game_over` signal emitted with `victory=true` |
| 16 | `test_game_over_victory_false_on_death` | Losing all lives mid-game -> `victory=false` |
| 17 | `test_build_timer_set_on_build_phase` | `_build_timer == build_phase_duration` |
| 18 | `test_wave_1_no_auto_start` | Wave 1 build timer does not decrement in `_process()` |
| 19 | `test_combat_phase_emits_wave_started` | `wave_started` signal with correct wave number |
| 20 | `test_wave_completed_signal_emitted` | `wave_completed` emitted on clear |

**Acceptance:** All state transitions, signals, and edge cases covered. 90%+ coverage.

---

### Task 5: GridManager Tests

**File:** `tests/unit/autoload/test_grid_manager.gd`
**Source:** `scripts/autoload/GridManager.gd` (113 lines)
**Effort:** Medium
**Priority:** P0 -- grid logic is foundational

**Test cases:**

| # | Test | Behavior |
|---|------|----------|
| 1 | `test_initial_grid_all_buildable` | After init, every cell is BUILDABLE |
| 2 | `test_grid_dimensions` | 20 columns, 15 rows |
| 3 | `test_get_cell_in_bounds` | Returns correct CellType |
| 4 | `test_get_cell_out_of_bounds` | Returns UNBUILDABLE |
| 5 | `test_get_cell_negative_coords` | Returns UNBUILDABLE |
| 6 | `test_is_cell_buildable_true` | BUILDABLE cell returns true |
| 7 | `test_is_cell_buildable_false_tower` | TOWER cell returns false |
| 8 | `test_is_cell_buildable_false_path` | PATH cell returns false |
| 9 | `test_load_map_data_sets_spawns_exits` | Spawn/exit points populated |
| 10 | `test_load_map_data_marks_spawn_cells` | Grid cell at spawn == SPAWN |
| 11 | `test_place_tower_sets_cell` | Cell becomes TOWER after placement |
| 12 | `test_place_tower_stores_reference` | `get_tower_at()` returns the tower node |
| 13 | `test_place_tower_fails_on_unbuildable` | Returns false, grid unchanged |
| 14 | `test_place_tower_fails_if_blocks_path` | Returns false when placement would block |
| 15 | `test_remove_tower_restores_buildable` | Cell reverts to BUILDABLE |
| 16 | `test_remove_tower_clears_reference` | `get_tower_at()` returns null |
| 17 | `test_grid_to_world_conversion` | (0,0) -> (32, 32), (1,1) -> (96, 96) |
| 18 | `test_world_to_grid_conversion` | (32, 32) -> (0, 0), (100, 100) -> (1, 1) |
| 19 | `test_is_in_bounds_edges` | (0,0)=true, (19,14)=true, (20,14)=false, (-1,0)=false |
| 20 | `test_can_place_tower_combines_checks` | Buildable + won't block path |
| 21 | `test_tower_placed_signal_emitted` | Signal on successful placement |
| 22 | `test_tower_removed_signal_emitted` | Signal on removal |
| 23 | `test_grid_updated_signal_emitted` | Signal on placement and removal |

**Acceptance:** All grid operations validated. 90%+ coverage.

---

### Task 6: PathfindingSystem Tests

**File:** `tests/unit/autoload/test_pathfinding_system.gd`
**Source:** `scripts/autoload/PathfindingSystem.gd` (71 lines)
**Effort:** Medium
**Priority:** P0 -- pathfinding correctness is critical

Depends on GridManager being set up with spawn/exit points. Tests should set up a minimal grid configuration.

**Test cases:**

| # | Test | Behavior |
|---|------|----------|
| 1 | `test_path_exists_on_clear_grid` | Spawn to exit has a non-empty path |
| 2 | `test_path_blocked_returns_empty` | Solid wall across grid -> empty path |
| 3 | `test_recalculate_updates_solids` | Place tower -> recalculate -> path routes around |
| 4 | `test_is_path_valid_true` | Open grid has valid path |
| 5 | `test_is_path_valid_false_blocked` | Blocking wall -> invalid |
| 6 | `test_get_world_path_converts_coords` | Grid points converted to world pixel coords |
| 7 | `test_get_enemy_path_uses_first_spawn_exit` | Returns path from spawn_points[0] to exit_points[0] |
| 8 | `test_get_enemy_path_empty_when_no_spawns` | Returns empty array |
| 9 | `test_get_flying_path_returns_two_points` | Straight line: spawn world coords, exit world coords |
| 10 | `test_get_flying_path_ignores_towers` | Same result regardless of tower placement |
| 11 | `test_path_recalculated_signal` | Signal emitted on recalculate() |
| 12 | `test_diagonal_mode_never` | Path never takes diagonal steps |
| 13 | `test_no_path_through_unbuildable` | UNBUILDABLE cells treated as solid |

**Acceptance:** Pathfinding correctness verified. 85%+ coverage.

---

### Task 7: EnemySystem Tests

**File:** `tests/unit/autoload/test_enemy_system.gd`
**Source:** `scripts/autoload/EnemySystem.gd` (314 lines)
**Effort:** Large
**Priority:** P1 -- wave spawning and scaling are core mechanics

**Test cases:**

| # | Test | Behavior |
|---|------|----------|
| 1 | `test_wave_config_loads_successfully` | `_wave_config` is not empty after `_ready()` |
| 2 | `test_get_wave_config_returns_data` | `get_wave_config(1)` has "enemies" array |
| 3 | `test_get_wave_config_missing_wave` | `get_wave_config(999)` returns empty dict |
| 4 | `test_get_enemy_template_loads_tres` | `get_enemy_template("normal")` returns valid EnemyData |
| 5 | `test_get_enemy_template_caches` | Second call returns same reference |
| 6 | `test_get_enemy_template_invalid` | Unknown type returns null |
| 7 | `test_scaling_hp_wave_1` | 100 * (1 + 0.15*1)^2 = 132 |
| 8 | `test_scaling_hp_wave_10` | 100 * (1 + 0.15*10)^2 = 625 |
| 9 | `test_scaling_hp_wave_30` | 100 * (1 + 0.15*30)^2 = 3025 |
| 10 | `test_scaling_speed_wave_10` | 1.0 * (1 + 0.02*10) = 1.2 |
| 11 | `test_scaling_speed_capped_at_2x` | Wave 60: min(1 + 0.02*60, 2.0) = 2.0 |
| 12 | `test_scaling_gold_wave_10` | 3 * (1 + 0.08*10) = 5 (int truncated from 5.4) |
| 13 | `test_build_wave_queue_correct_count` | Wave 1: 8 normal enemies |
| 14 | `test_swarm_multiplies_by_spawn_count` | Swarm count 3 * spawn_count 3 = 9 |
| 15 | `test_boss_wave_uses_boss_spawn_interval` | `_spawn_interval == BOSS_SPAWN_INTERVAL` |
| 16 | `test_spawn_wave_sets_queue` | After `spawn_wave()`, `_enemies_to_spawn` is non-empty |
| 17 | `test_is_wave_finished_false_during_spawn` | While queue has items -> false |
| 18 | `test_is_wave_finished_true_when_done` | After all spawned -> true |
| 19 | `test_get_active_enemy_count` | Matches `_active_enemies.size()` |
| 20 | `test_on_enemy_killed_awards_gold` | Gold increases by enemy gold_reward |
| 21 | `test_on_enemy_killed_emits_signal` | `enemy_killed` signal emitted |
| 22 | `test_on_enemy_reached_exit_loses_life` | GameManager.lives decremented |
| 23 | `test_wave_cleared_signal_when_all_dead` | Signal emitted when last enemy removed |
| 24 | `test_split_enemies_spawn_two_children` | After split, 2 children added to active |
| 25 | `test_split_children_continue_from_parent_index` | `_path_index` matches parent |
| 26 | `test_split_awards_parent_gold` | Parent gold rewarded before children spawn |
| 27 | `test_boss_minions_spawn_at_boss_position` | Minions positioned near boss |
| 28 | `test_fallback_queue_for_unknown_wave` | Generates reasonable fallback |
| 29 | `test_create_scaled_enemy_copies_all_fields` | All EnemyData fields are copied |
| 30 | `test_enemy_spawned_signal` | Signal emitted with enemy node |

**Acceptance:** All spawning, scaling, and lifecycle logic validated. 85%+ coverage.

---

### Task 8: TowerSystem Tests

**File:** `tests/unit/autoload/test_tower_system.gd`
**Source:** `scripts/autoload/TowerSystem.gd` (116 lines)
**Effort:** Medium
**Priority:** P1 -- factory for all tower operations

**Test cases:**

| # | Test | Behavior |
|---|------|----------|
| 1 | `test_create_tower_spends_gold` | Gold reduced by tower cost |
| 2 | `test_create_tower_returns_node` | Non-null node with correct tower_data |
| 3 | `test_create_tower_fails_insufficient_gold` | Returns null, gold unchanged |
| 4 | `test_create_tower_fails_unbuildable_cell` | Returns null |
| 5 | `test_create_tower_fails_blocks_path` | Returns null |
| 6 | `test_create_tower_adds_to_active` | `get_active_towers()` includes new tower |
| 7 | `test_create_tower_emits_signal` | `tower_created` signal emitted |
| 8 | `test_upgrade_tower_success` | tower_data updated to upgrade_to |
| 9 | `test_upgrade_tower_spends_incremental_cost` | Gold reduced by (upgrade.cost - current.cost) |
| 10 | `test_upgrade_tower_fails_no_upgrade` | Returns false when upgrade_to==null |
| 11 | `test_upgrade_tower_fails_insufficient_gold` | Returns false, no changes |
| 12 | `test_upgrade_tower_emits_signal` | `tower_upgraded` signal emitted |
| 13 | `test_sell_tower_refund_build_phase` | 75% refund during BUILD_PHASE |
| 14 | `test_sell_tower_refund_combat_phase` | 50% refund during COMBAT_PHASE |
| 15 | `test_sell_tower_removes_from_active` | Tower no longer in `get_active_towers()` |
| 16 | `test_sell_tower_frees_grid_cell` | Grid cell reverts to BUILDABLE |
| 17 | `test_sell_tower_emits_signal` | `tower_sold` signal with tower and refund |
| 18 | `test_fuse_towers_success` | Result tower has correct fusion data |
| 19 | `test_fuse_towers_spends_fusion_cost` | Gold reduced by result.cost |
| 20 | `test_fuse_towers_removes_tower_b` | Tower B freed, removed from active |
| 21 | `test_fuse_towers_replaces_tower_a` | Tower A has new tower_data |
| 22 | `test_fuse_towers_fails_invalid_combo` | Returns false |
| 23 | `test_fuse_towers_fails_insufficient_gold` | Returns false |
| 24 | `test_fuse_towers_emits_signal` | `tower_fused` signal emitted |
| 25 | `test_fuse_legendary_success` | Tier 2 + Superior -> Tier 3 |
| 26 | `test_fuse_legendary_fails_invalid` | Returns false for wrong tier combo |
| 27 | `test_get_active_towers_returns_list` | Matches internal `_active_towers` |

**Acceptance:** All creation, upgrade, sell, and fusion paths tested. 90%+ coverage.

---

### Task 9: FusionRegistry Tests

**File:** `tests/unit/autoload/test_fusion_registry.gd`
**Source:** `scripts/autoload/FusionRegistry.gd` (144 lines)
**Effort:** Medium
**Priority:** P1 -- fusion lookup correctness is critical

**Test cases:**

| # | Test | Behavior |
|---|------|----------|
| 1 | `test_all_15_dual_fusions_registered` | `_dual_fusions.size() == 15` |
| 2 | `test_all_6_legendary_fusions_registered` | `_legendary_fusions.size() == 6` |
| 3 | `test_make_key_sorts_alphabetically` | `_make_key("water", "fire")` == `"fire+water"` |
| 4 | `test_make_legendary_key_sorts` | `_make_legendary_key(["wind", "fire", "earth"])` == `"earth+fire+wind"` |
| 5 | `test_get_fusion_result_fire_water` | Returns Steam Engine TowerData |
| 6 | `test_get_fusion_result_reversed_order` | `get_fusion_result("water", "fire")` == same result |
| 7 | `test_get_fusion_result_all_15` | Each of the 15 element pairs returns non-null |
| 8 | `test_get_fusion_result_invalid_combo` | Same element or unknown -> null |
| 9 | `test_get_legendary_result_fire_water_earth` | Returns Primordial Nexus |
| 10 | `test_get_legendary_result_all_6` | Each triple-element combo returns non-null |
| 11 | `test_get_legendary_result_invalid` | Nonexistent triple -> null |
| 12 | `test_can_fuse_both_superior` | Two tier-1 no-upgrade towers of different elements -> true |
| 13 | `test_can_fuse_fails_same_element` | Same element -> false |
| 14 | `test_can_fuse_fails_not_superior` | upgrade_to != null -> false |
| 15 | `test_can_fuse_fails_wrong_tier` | tier != 1 -> false |
| 16 | `test_can_fuse_legendary_valid` | Tier 2 + Superior of third element -> true |
| 17 | `test_can_fuse_legendary_fails_element_already_in_fusion` | Third element in fusion_elements -> false |
| 18 | `test_can_fuse_legendary_fails_not_tier2` | Non-tier-2 -> false |
| 19 | `test_can_fuse_legendary_fails_not_superior` | Tower with upgrade_to -> false |
| 20 | `test_get_fusion_partners_finds_valid` | Returns list of compatible towers |
| 21 | `test_get_fusion_partners_excludes_self` | Source tower not in results |
| 22 | `test_get_legendary_partners_bidirectional` | Works from tier2 or superior perspective |
| 23 | `test_get_all_dual_fusions_returns_dict` | Returns dict with 15 entries |
| 24 | `test_get_all_legendary_fusions_returns_dict` | Returns dict with 6 entries |

**Acceptance:** All fusion lookup and validation logic covered. 90%+ coverage.

---

### Task 10: ElementSynergy Tests

**File:** `tests/unit/systems/test_element_synergy.gd`
**Source:** `scripts/systems/ElementSynergy.gd` (259 lines)
**Effort:** Large
**Priority:** P1 -- synergy bonus calculations affect all tower damage

Tests require mock tower nodes with tower_data. Create minimal stub tower objects with the necessary properties.

**Test cases:**

| # | Test | Behavior |
|---|------|----------|
| 1 | `test_calculate_tier_thresholds` | 0->0, 3->1, 5->2, 8->3 |
| 2 | `test_calculate_tier_between_thresholds` | 4->1, 7->2, 10->3 |
| 3 | `test_element_count_single_tower` | 1 fire tower -> fire count == 1 |
| 4 | `test_element_count_fusion_tower` | fire+water fusion -> fire=1, water=1 |
| 5 | `test_element_count_ignores_none` | "none" element not counted |
| 6 | `test_synergy_bonus_tier_0` | 0 towers -> 1.0x damage |
| 7 | `test_synergy_bonus_tier_1` | 3 fire towers -> 1.1x |
| 8 | `test_synergy_bonus_tier_2` | 5 fire towers -> 1.2x |
| 9 | `test_synergy_bonus_tier_3` | 8 fire towers -> 1.3x |
| 10 | `test_best_synergy_bonus_fusion_tower` | fire+water tower with 5 fire, 3 water -> 1.2x (best of fire) |
| 11 | `test_attack_speed_bonus_fire_tier2` | 5 fire -> +0.10 |
| 12 | `test_attack_speed_bonus_fire_tier3` | 8 fire -> +0.20 |
| 13 | `test_attack_speed_bonus_wind_tier2` | 5 wind -> +0.15 |
| 14 | `test_range_bonus_earth_tier2` | 5 earth -> +1 cell |
| 15 | `test_range_bonus_earth_tier3` | 8 earth -> +2 cells |
| 16 | `test_chain_bonus_lightning_tier2` | 5 lightning -> +1 chain |
| 17 | `test_freeze_chance_bonus_ice_tier2` | 5 ice -> +0.10 |
| 18 | `test_slow_bonus_water_tier2` | 5 water -> +0.10 |
| 19 | `test_no_aura_bonus_below_tier2` | 3 fire -> attack_speed_bonus == 0 |
| 20 | `test_synergy_color_at_tier0` | Returns Color.WHITE |
| 21 | `test_synergy_color_at_tier1` | Returns lerp(WHITE, element_color, 0.15) |
| 22 | `test_synergy_changed_signal_on_tier_change` | Signal emitted when tier transitions |
| 23 | `test_synergy_changed_not_emitted_when_same_tier` | No signal if adding tower doesn't change tier |
| 24 | `test_recalculate_clears_old_counts` | Selling towers decrements correctly |

**Acceptance:** All synergy tier, bonus, and aura calculations validated. 85%+ coverage.

---

### Task 11: Enemy Behavior Tests

**File:** `tests/unit/enemies/test_enemy.gd`
**Source:** `scripts/enemies/Enemy.gd` (517 lines)
**Effort:** X-Large
**Priority:** P1 -- most complex script, many behaviors

Tests require scene instantiation since Enemy extends Node2D with @onready children. Use `auto_free()` and minimal scene setup.

**Test cases (grouped by subsystem):**

**Movement (7 tests):**

| # | Test | Behavior |
|---|------|----------|
| 1 | `test_starts_at_first_path_point` | `position == path_points[0]` after _ready |
| 2 | `test_moves_along_path` | After ticking, position approaches second point |
| 3 | `test_path_index_increments` | Reaching a point advances `_path_index` |
| 4 | `test_path_progress_updates` | `path_progress` reflects fractional position |
| 5 | `test_reached_exit_triggers_exit` | Moving past last point calls `_reached_exit()` |
| 6 | `test_push_back_decrements_index` | `push_back(2)` moves enemy backward |
| 7 | `test_pull_toward_snaps_to_path` | `pull_toward()` snaps to nearest path point |

**Damage and Death (8 tests):**

| # | Test | Behavior |
|---|------|----------|
| 8 | `test_take_damage_reduces_health` | 100 HP - 30 dmg = 70 HP |
| 9 | `test_take_damage_kills_at_zero` | Lethal damage triggers `_die()` |
| 10 | `test_apply_resistance_immune_element` | Immune element -> 0 damage |
| 11 | `test_apply_resistance_weak_element` | Weak element -> 2x damage |
| 12 | `test_apply_resistance_physical_resist` | 50% resist on earth -> half damage |
| 13 | `test_wet_bonus_lightning_damage` | WET + lightning -> 1.5x damage |
| 14 | `test_stunned_double_damage` | STUN -> 2x damage from all sources |
| 15 | `test_heal_restores_health` | `heal(50)` caps at max_health |

**Status Effects (10 tests):**

| # | Test | Behavior |
|---|------|----------|
| 16 | `test_apply_burn_status` | Burn added to _status_effects |
| 17 | `test_burn_stacks` | Multiple burns accumulate independently |
| 18 | `test_slow_replaces_existing_slow` | New slow replaces old (shared slot) |
| 19 | `test_freeze_replaces_slow` | Freeze replaces slow in movement slot |
| 20 | `test_stun_replaces_freeze` | Stun replaces freeze in movement slot |
| 21 | `test_wet_is_separate_slot` | WET does not replace slow/freeze |
| 22 | `test_has_status_returns_true` | `has_status(BURN)` after applying burn |
| 23 | `test_clear_all_status_effects` | All effects removed, speed restored |
| 24 | `test_speed_zero_when_frozen` | FREEZE -> speed == 0 |
| 25 | `test_speed_reduced_when_slowed` | 30% slow -> speed * 0.7 |

**Special Enemy Types (8 tests):**

| # | Test | Behavior |
|---|------|----------|
| 26 | `test_healer_heals_nearby_allies` | Allies within 128px gain health |
| 27 | `test_healer_does_not_heal_self` | Healer's own HP unchanged |
| 28 | `test_healer_skips_full_health` | Full-health allies not healed |
| 29 | `test_split_on_death_spawns_children` | `_die()` with split_on_death calls EnemySystem |
| 30 | `test_stealth_starts_invisible` | `sprite.modulate.a == 0.15` |
| 31 | `test_stealth_untargetable_until_revealed` | `_is_revealed == false` initially |
| 32 | `test_stealth_reveals_near_tower` | Tower within 128px -> `_is_revealed = true` |
| 33 | `test_elemental_assigns_immune_weak` | Elemental enemy gets non-empty immune/weak elements |

**Boss Abilities (6 tests):**

| # | Test | Behavior |
|---|------|----------|
| 34 | `test_boss_fire_trail_spawns_ground_effect` | `ground_effect_spawned` signal emitted |
| 35 | `test_boss_tower_freeze_disables_towers` | Towers within radius get `disable_for()` |
| 36 | `test_boss_element_cycle_changes_immunity` | Each cycle rotates `immune_element` |
| 37 | `test_chaos_enrage_increases_speed` | `_chaos_cycle_count` multiplies speed |
| 38 | `test_boss_minion_spawn_timer` | Minion timer triggers EnemySystem.spawn_boss_minions |
| 39 | `test_flying_bobbing_effect` | Sprite position.y oscillates with sine wave |

**Acceptance:** 80%+ coverage across all Enemy subsystems. ~39 test cases.

---

### Task 12: Tower Behavior Tests

**File:** `tests/unit/towers/test_tower.gd`
**Source:** `scripts/towers/Tower.gd` (439 lines)
**Effort:** X-Large
**Priority:** P1 -- tower behavior is central to gameplay

**Test cases (grouped by subsystem):**

**Core Attack Loop (7 tests):**

| # | Test | Behavior |
|---|------|----------|
| 1 | `test_only_attacks_during_combat` | `_process()` skips if not COMBAT_PHASE |
| 2 | `test_find_target_first_mode` | Returns enemy with highest path_progress |
| 3 | `test_find_target_weakest_mode` | Returns enemy with lowest current_health |
| 4 | `test_find_target_closest_mode` | Returns closest enemy by distance |
| 5 | `test_find_target_excludes_stealth` | Unrevealed stealth enemies skipped |
| 6 | `test_find_target_returns_null_no_enemies` | No enemies in range -> null |
| 7 | `test_attack_spawns_projectile` | `projectile_spawned` signal emitted |

**Multi-target / Chain (3 tests):**

| # | Test | Behavior |
|---|------|----------|
| 8 | `test_multi_attack_spawns_n_projectiles` | special_key="multi" with value=2 -> 2 projectiles |
| 9 | `test_multi_attack_finds_multiple_targets` | `_find_multiple_targets()` returns up to N |
| 10 | `test_chain_projectile_has_chain_data` | Projectile gets chain_count and chain_damage_fraction |

**Damage Calculation (4 tests):**

| # | Test | Behavior |
|---|------|----------|
| 11 | `test_calculate_damage_base` | No multipliers -> base damage |
| 12 | `test_calculate_damage_with_element_multiplier` | fire vs earth -> 1.5x |
| 13 | `test_calculate_damage_with_synergy` | Synergy 1.2x applied on top of element |
| 14 | `test_storm_aoe_wave_scaling` | Damage increases with wave number |

**Special Abilities (6 tests):**

| # | Test | Behavior |
|---|------|----------|
| 15 | `test_freeze_burn_alternates` | Even attacks freeze, odd attacks burn |
| 16 | `test_aura_slow_applies_to_enemies` | slow_aura ticks apply SLOW to enemies in range |
| 17 | `test_thorn_aura_deals_damage` | Thorn aura does damage per tick |
| 18 | `test_blizzard_aura_slow_and_freeze` | Blizzard applies slow always + freeze chance |
| 19 | `test_periodic_geyser_burst` | Geyser deals AoE damage + slow on interval |
| 20 | `test_pure_aura_skips_projectile` | attack_speed == 0 -> no projectile fired |

**Disable Mechanic (4 tests):**

| # | Test | Behavior |
|---|------|----------|
| 21 | `test_disable_for_sets_flag` | `is_disabled()` returns true |
| 22 | `test_disabled_tower_skips_attacks` | No projectiles while disabled |
| 23 | `test_disable_timer_expires` | After duration, `is_disabled()` returns false |
| 24 | `test_disable_extends_to_longer_duration` | `disable_for(5)` then `disable_for(3)` -> stays 5s |

**Synergy Integration (3 tests):**

| # | Test | Behavior |
|---|------|----------|
| 25 | `test_synergy_refreshes_range` | Earth synergy adds range cells |
| 26 | `test_synergy_refreshes_speed` | Fire synergy adds attack speed |
| 27 | `test_on_synergy_changed_reapplies_data` | `synergy_changed` -> `apply_tower_data()` called |

**Acceptance:** 80%+ coverage. ~27 test cases.

---

### Task 13: Projectile Tests

**File:** `tests/unit/projectiles/test_projectile.gd`
**Source:** `scripts/projectiles/Projectile.gd` (370 lines)
**Effort:** Large
**Priority:** P2 -- complex hit logic

**Test cases:**

| # | Test | Behavior |
|---|------|----------|
| 1 | `test_single_hit_applies_damage` | Target takes correct damage |
| 2 | `test_single_hit_applies_special` | Burn/slow/freeze applied via _try_apply_special |
| 3 | `test_aoe_hit_damages_all_in_radius` | Multiple enemies within radius take damage |
| 4 | `test_aoe_hit_skips_out_of_range` | Enemies outside radius unaffected |
| 5 | `test_chain_hits_secondary_targets` | Chain damage applied to nearby non-primary enemies |
| 6 | `test_chain_respects_count_limit` | Only `chain_count` secondary targets hit |
| 7 | `test_chain_damage_fraction_applied` | Secondary damage = base * fraction |
| 8 | `test_cone_aoe_angle_check` | Only enemies within 90-degree cone take damage |
| 9 | `test_pull_burn_pulls_then_damages` | Enemies pulled toward impact, then burned |
| 10 | `test_pushback_moves_enemies_back` | Enemies pushed back along path |
| 11 | `test_earthquake_slow_and_stun` | AoE + slow to all + stun chance per enemy |
| 12 | `test_ground_effect_spawned_lava_pool` | `ground_effect_spawned` signal for lava_pool |
| 13 | `test_ground_effect_spawned_slow_zone` | `ground_effect_spawned` signal for slow_zone |
| 14 | `test_ground_effect_spawned_burning_ground` | `ground_effect_spawned` signal for burning_ground |
| 15 | `test_calculate_damage_per_target_element` | Different element enemies get different damage |
| 16 | `test_synergy_damage_mult_applied` | Synergy multiplier affects damage |
| 17 | `test_try_apply_special_proc_chance` | 0% chance -> no effect, 100% -> always applies |
| 18 | `test_wet_chain_applies_wet` | Storm Beacon chain applies WET status |
| 19 | `test_freeze_chain_attempts_freeze` | Cryo-Volt chain applies freeze with chance |
| 20 | `test_projectile_tracks_target` | Moves toward target position each frame |
| 21 | `test_projectile_uses_last_pos_if_target_dies` | Falls back to `target_last_pos` |
| 22 | `test_projectile_hits_at_threshold` | Within 8px triggers `_hit()` |
| 23 | `test_projectile_queue_frees_after_hit` | `queue_free()` called after `_hit()` |

**Acceptance:** All hit variants, specials, and ground effects covered. 80%+ coverage.

---

### Task 14: GroundEffect Tests

**File:** `tests/unit/effects/test_ground_effect.gd`
**Source:** `scripts/effects/GroundEffect.gd` (93 lines)
**Effort:** Small
**Priority:** P2

**Test cases:**

| # | Test | Behavior |
|---|------|----------|
| 1 | `test_lava_pool_deals_tick_damage` | Enemies in radius take burn damage per tick |
| 2 | `test_slow_zone_applies_slow` | Enemies in radius get SLOW status |
| 3 | `test_fire_trail_disables_towers` | Towers within 64px get `disable_for(2.0)` |
| 4 | `test_burning_ground_deals_damage` | Same as lava_pool but orange color |
| 5 | `test_effect_expires_after_duration` | `queue_free()` after `effect_duration` seconds |
| 6 | `test_effect_fades_in_last_half_second` | `modulate.a` decreases in final 0.5s |
| 7 | `test_tick_interval_respected` | Damage only applied every 0.5s |
| 8 | `test_enemies_outside_radius_unaffected` | Distant enemies take no damage |

**Acceptance:** 80%+ coverage of GroundEffect.gd.

---

### Task 15: Data Resource Validation Tests

**File:** `tests/unit/test_resource_validation.gd`
**Source:** All `.tres` files in `resources/`
**Effort:** Medium
**Priority:** P1 -- catches data entry errors early

**Test cases:**

| # | Test | Behavior |
|---|------|----------|
| 1 | `test_all_6_base_tower_tres_load` | Each base tower .tres loads without error |
| 2 | `test_all_12_enhanced_superior_load` | All enhanced/superior .tres load |
| 3 | `test_all_15_fusion_tres_load` | All fusion .tres load with tier==2 |
| 4 | `test_all_6_legendary_tres_load` | All legendary .tres load with tier==3 |
| 5 | `test_base_towers_have_upgrade_chain` | Base -> Enhanced -> Superior chain complete |
| 6 | `test_superior_towers_have_no_upgrade` | upgrade_to == null |
| 7 | `test_fusion_towers_have_fusion_elements` | fusion_elements.size() == 2 |
| 8 | `test_legendary_towers_have_fusion_elements` | fusion_elements.size() == 3 |
| 9 | `test_all_enemy_tres_load` | All 14 enemy .tres load correctly |
| 10 | `test_boss_enemies_have_abilities` | Bosses have non-empty boss_ability_key |
| 11 | `test_split_enemy_has_split_data` | split.tres has split_data pointing to split_child.tres |
| 12 | `test_healer_has_heal_per_second` | healer.tres heal_per_second > 0 |
| 13 | `test_flying_enemy_is_flying` | flying.tres is_flying == true |
| 14 | `test_stealth_enemy_is_stealth` | stealth.tres stealth == true |
| 15 | `test_wave_config_has_30_waves` | wave_config.json has entries for waves 1-30 |
| 16 | `test_wave_config_boss_waves` | Waves 10, 20, 30 have is_boss_wave == true |
| 17 | `test_wave_config_all_enemy_types_exist` | Every type referenced in waves has a .tres |
| 18 | `test_tower_cost_increases_with_tier` | Enhanced > Base, Superior > Enhanced |
| 19 | `test_tower_damage_increases_with_tier` | Enhanced > Base, Superior > Enhanced |

**Acceptance:** All data resources validated for correctness and consistency.

---

### Task 16: Integration Tests -- Tower-Enemy Combat

**File:** `tests/integration/test_combat_flow.gd`
**Source:** Tower, Projectile, Enemy, EnemySystem, TowerSystem interactions
**Effort:** Large
**Priority:** P2

These tests verify that multiple systems work together correctly. They use `scene_runner()` or manually tick `_process()` to simulate real gameplay frames.

**Test cases:**

| # | Test | Behavior |
|---|------|----------|
| 1 | `test_tower_kills_enemy_awards_gold` | Place tower, spawn enemy, simulate -> enemy dies, gold increases |
| 2 | `test_burn_tower_applies_dot_to_enemy` | Flame Spire projectile -> enemy takes burn damage over time |
| 3 | `test_slow_tower_reduces_enemy_speed` | Tidal Obelisk -> enemy speed reduced |
| 4 | `test_aoe_tower_hits_multiple_enemies` | Stone Bastion -> multiple enemies damaged |
| 5 | `test_chain_lightning_chains_to_secondaries` | Thunder Pylon -> primary + secondary targets hit |
| 6 | `test_multi_tower_fires_at_two_targets` | Gale Tower -> 2 projectiles spawned |
| 7 | `test_freeze_stops_enemy_movement` | Frost Sentinel freeze -> enemy speed == 0 |
| 8 | `test_tower_upgrade_increases_damage` | Upgrade -> subsequent attacks deal more damage |
| 9 | `test_selling_tower_reopens_path` | Sell -> grid cell reverts, pathfinding updates |
| 10 | `test_enemy_reaching_exit_loses_life` | Enemy walks full path -> GameManager.lives - 1 |
| 11 | `test_wave_clear_awards_bonus` | All enemies killed -> wave bonus gold added |
| 12 | `test_no_leak_bonus_25_percent` | Wave cleared with 0 leaks -> 25% bonus |

**Acceptance:** Core combat loop verified end-to-end.

---

### Task 17: Integration Tests -- Fusion Flow

**File:** `tests/integration/test_fusion_flow.gd`
**Source:** FusionRegistry, TowerSystem, ElementSynergy interactions
**Effort:** Medium
**Priority:** P2

**Test cases:**

| # | Test | Behavior |
|---|------|----------|
| 1 | `test_full_dual_fusion_flow` | Create 2 superior towers -> fuse -> result is tier 2 |
| 2 | `test_full_legendary_fusion_flow` | Create tier 2 + superior -> fuse -> result is tier 3 |
| 3 | `test_fusion_updates_synergy_counts` | Element counts recalculated after fusion |
| 4 | `test_fusion_tower_has_both_elements` | Fusion tower's fusion_elements matches source elements |
| 5 | `test_fusion_cost_deducted` | Gold reduced by result tower cost |
| 6 | `test_fusion_consumed_tower_freed` | Second tower removed from grid and freed |

**Acceptance:** End-to-end fusion verified for both dual and legendary paths.

---

### Task 18: Integration Tests -- Game State Flow

**File:** `tests/integration/test_game_state_flow.gd`
**Source:** GameManager, EnemySystem, EconomyManager interactions
**Effort:** Medium
**Priority:** P2

**Test cases:**

| # | Test | Behavior |
|---|------|----------|
| 1 | `test_full_wave_cycle` | BUILD -> COMBAT -> wave clear -> BUILD (wave+1) |
| 2 | `test_income_phase_every_5_waves` | Wave 5 -> INCOME -> interest applied -> BUILD |
| 3 | `test_game_over_on_zero_lives` | Enemy leaks reduce lives to 0 -> GAME_OVER defeat |
| 4 | `test_victory_at_wave_30` | Clear wave 30 -> GAME_OVER victory |
| 5 | `test_early_wave_start_bonus` | Start early with timer remaining -> bonus gold |
| 6 | `test_economy_reset_before_restart` | After game over restart, gold == 100 |

**Acceptance:** Complete game lifecycle tested.

---

## Task Dependency Order

```
Task 1  (EconomyManager tests)        -- no dependencies, foundational
Task 2  (StatusEffect tests)          -- no dependencies
Task 3  (ElementMatrix tests)         -- no dependencies
Task 4  (GameManager tests)           -- depends on Task 1 (economy signals)
Task 5  (GridManager tests)           -- depends on Task 6 (pathfinding)
Task 6  (PathfindingSystem tests)     -- depends on Task 5 (grid setup) -- co-dependent, test together
Task 7  (EnemySystem tests)           -- depends on Task 4 (game state), Task 2 (status effects)
Task 8  (TowerSystem tests)           -- depends on Task 1, Task 5
Task 9  (FusionRegistry tests)        -- no dependencies (pure lookup)
Task 10 (ElementSynergy tests)        -- depends on Task 8 (tower stubs)
Task 11 (Enemy tests)                 -- depends on Task 2, Task 3
Task 12 (Tower tests)                 -- depends on Task 3, Task 10
Task 13 (Projectile tests)            -- depends on Task 3, Task 11, Task 12
Task 14 (GroundEffect tests)          -- depends on Task 11 (enemy stubs)
Task 15 (Resource validation)         -- no dependencies
Task 16 (Integration: combat)         -- depends on Tasks 7, 8, 11, 12, 13
Task 17 (Integration: fusion)         -- depends on Tasks 8, 9, 10
Task 18 (Integration: game state)     -- depends on Tasks 4, 7, 1
```

---

## Recommended Implementation Order

| Order | Task | Test Count | Effort | Priority | Notes |
|-------|------|-----------|--------|----------|-------|
| 1 | Task 1: EconomyManager | 18 | Small | P0 | Easiest, establishes patterns |
| 2 | Task 2: StatusEffect | 12 | Small | P0 | Pure RefCounted, no scene deps |
| 3 | Task 3: ElementMatrix | 17 | Small | P0 | Static functions, fully isolated |
| 4 | Task 15: Resource validation | 19 | Medium | P1 | Catches data errors early |
| 5 | Task 9: FusionRegistry | 24 | Medium | P1 | Pure lookup, no scene deps |
| 6 | Task 4: GameManager | 20 | Medium | P0 | State machine, some autoload deps |
| 7 | Task 5: GridManager | 23 | Medium | P0 | Co-develop with PathfindingSystem |
| 8 | Task 6: PathfindingSystem | 13 | Medium | P0 | Needs grid setup |
| 9 | Task 7: EnemySystem | 30 | Large | P1 | Wave spawning, scaling formulas |
| 10 | Task 8: TowerSystem | 27 | Medium | P1 | Factory, needs grid + economy |
| 11 | Task 10: ElementSynergy | 24 | Large | P1 | Needs mock tower objects |
| 12 | Task 11: Enemy | 39 | X-Large | P1 | Scene-based, complex behaviors |
| 13 | Task 12: Tower | 27 | X-Large | P1 | Scene-based, targeting + attacks |
| 14 | Task 13: Projectile | 23 | Large | P2 | Hit logic, ground effects |
| 15 | Task 14: GroundEffect | 8 | Small | P2 | Tick-based effects |
| 16 | Task 16: Integration: combat | 12 | Large | P2 | Multi-system end-to-end |
| 17 | Task 17: Integration: fusion | 6 | Medium | P2 | Fusion pipeline |
| 18 | Task 18: Integration: game state | 6 | Medium | P2 | Full lifecycle |

**Total test cases: ~348**

**Parallelizable groups:**
- Tasks 1, 2, 3, 9, 15 can all be implemented independently in parallel
- Tasks 4, 5, 6 can be done in parallel after Task 1
- Tasks 7, 8 can be done in parallel after Tasks 4, 5, 6
- Tasks 11, 12 can be done in parallel after Tasks 2, 3, 10
- Tasks 16, 17, 18 can be done in parallel after their unit test dependencies

**Estimated total effort:** ~3 weeks (1 developer), ~1.5 weeks (2 developers with parallel tracks)

---

## CI/CD Integration (Optional)

### GitHub Actions Workflow

Create `.github/workflows/test.yml`:

```yaml
name: GdUnit4 Tests
on:
  push:
    branches: [main, phase2, phase3]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: barichello/godot-ci:4.6
    steps:
      - uses: actions/checkout@v4

      - name: Import project
        run: |
          mkdir -p ~/.local/share/godot/export_presets
          godot --headless --import --quit 2>/dev/null || true

      - name: Run tests
        run: |
          godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/ --junit-report=results/junit.xml
        timeout-minutes: 10

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: results/
```

### Pre-commit Hook

Add to `.git/hooks/pre-commit` (or use a pre-commit framework):

```bash
#!/bin/bash
# Run quick unit tests before committing
if command -v godot &> /dev/null; then
  godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --add tests/unit/ 2>&1 | tail -5
  exit $?
fi
echo "Warning: Godot not found, skipping tests"
```

### Coverage Tracking

GdUnit4 does not provide built-in code coverage (Godot 4.x lacks native coverage instrumentation). Track coverage manually:

1. **Function coverage:** Maintain a checklist of every public function per script. Mark each as tested.
2. **Branch coverage:** For functions with conditionals (match, if/elif), ensure tests exercise each branch.
3. **Periodic audit:** After completing all test tasks, run through each source file and verify every non-trivial branch has a corresponding test.

Target: update the coverage checklist in `docs/work/coverage.md` after each task.

---

## Out of Scope

- **UI visual regression tests** -- BuildMenu, TowerInfoPanel, CodexPanel, HUD, and WavePreviewPanel are primarily visual. Testing their layout and styling requires screenshot comparison tooling not available in GdUnit4. Defer to manual QA.
- **Performance benchmarks** -- Object pooling, pathfinding timing, and memory budgets are Phase 3 concerns. Tests validate correctness, not performance.
- **Audio tests** -- AudioManager is a stub with no behavior to test.
- **Touch/mobile input tests** -- Phase 3 scope, keyboard/mouse only in Phase 2.
- **Network/multiplayer tests** -- No multiplayer systems implemented.
- **Save/load tests** -- Save system is Phase 3.
