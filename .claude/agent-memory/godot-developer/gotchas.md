# Gotchas and Lessons Learned

## GdUnit4 Headless Mode
GdUnit4 v6.1.1 blocks headless execution by default (exit code 103). CI environments MUST pass `--ignoreHeadlessMode`. This is because Godot InputEvents don't work in headless mode, so UI interaction tests will silently fail. Unit tests and logic-only tests work fine.

## Godot CI Docker Images
- `barichello/godot-ci` is the standard community Docker image for Godot CI
- Tags follow Godot versions (e.g., `4.6`)
- The image provides `godot` binary at a known path
- Must run `godot --headless --import --quit` before tests to generate `.godot/` import cache

## GdUnit4 Report Paths
- Reports go to `<project>/reports/` by default
- JUnit XML and HTML reports are auto-generated via session hooks
- Use `-rd` flag to customize report directory
- Use `-rc` flag to control report history count

## Godot Import Step
Before running tests in CI, must import the project: `godot --headless --import --quit`
This generates the `.godot/` directory with imported resources. Without it, tests that load scenes or resources will fail.

## GdUnit4 Signal Testing Pattern for Autoloads
- `monitor_signals(autoload, false)` -- pass `false` for `auto_free` to avoid GdUnit4 freeing the autoload singleton
- Signal emission is synchronous: call `monitor_signals()`, then perform the action, then `await assert_signal().wait_until(500).is_emitted("signal_name", args)`
- `is_emitted()` and `is_not_emitted()` are async (require `await`), they poll the signal collector each process frame
- `assert_signal()` constructor also calls `register_emitter()`, so previously collected signals are found on the first frame poll

## GdUnit4 Script Validation
- `godot --check-only --script` does NOT load project autoloads/addons, so GdUnitTestSuite won't resolve
- Instead, validate with `godot --headless --path . --quit` which loads the full project and reports script errors
- Godot binary on this Mac: `/Applications/Godot.app/Contents/MacOS/Godot`

## Testing Autoloads Without reset()
- GameManager has no `reset()` method. Must manually reset all vars in `before_test()`: `game_state`, `current_wave`, `lives`, `_build_timer`, `_enemies_leaked_this_wave`
- For coupled autoloads (e.g., GameManager -> EnemySystem), reset the dependency's internal state too: `_active_enemies`, `_wave_finished_spawning`, `_enemies_to_spawn`
- To simulate wave cleared: set `EnemySystem._active_enemies.clear()`, `_wave_finished_spawning = true`, `_enemies_to_spawn.clear()`, then call `GameManager._process(delta)` to trigger the detection

## GridManager + PathfindingSystem Co-dependency
- GridManager calls `PathfindingSystem.is_path_valid()` in `would_block_path()` and `PathfindingSystem.recalculate()` in `place_tower()`/`remove_tower()`
- PathfindingSystem reads `GridManager.grid`, `.spawn_points`, `.exit_points`
- To test path-blocking behavior: set up a minimal map with spawn/exit points, call `PathfindingSystem.recalculate()`, then test placement
- Reset pattern: `_initialize_grid()` + clear `_tower_map`, `spawn_points`, `exit_points`
- For non-path tests (pure grid logic), no spawn/exit setup needed -- `would_block_path` won't be called if `is_cell_buildable` fails first
- `is_in_bounds` (public) and `_is_in_bounds` (private) are identical implementations -- the public one was added for external callers

## Stubbing Enemy Nodes for EnemySystem Tests
- EnemySystem methods (spawn_split_enemies, spawn_boss_minions, on_enemy_killed, etc.) read/write `enemy_data`, `path_points`, `_path_index`, and `position` on enemy nodes
- The real BaseEnemy.tscn tries to load sprite textures in `_ready()`, which fails in headless mode
- Solution: create a GDScript dynamically with just the needed properties, use `PackedScene.pack()` to make a stub scene, then swap `EnemySystem._enemy_scene` temporarily
- Pattern: `_create_stub_scene()` packs a Node2D with the stub script, `_make_enemy_stub()` creates individual stub nodes for lifecycle tests
- Always restore `EnemySystem._enemy_scene` after tests that replace it
- For lifecycle tests (on_enemy_killed, on_enemy_reached_exit), add the stub to `_active_enemies` and set `_wave_finished_spawning` before calling the method

## Stubbing Tower Nodes for TowerSystem Tests
- TowerSystem._tower_scene preloads BaseTower.tscn (Area2D with sprites, timers, synergy connections) -- fails in headless mode
- Tower stub needs: `tower_data: TowerData`, `grid_position: Vector2i`, `apply_tower_data()` method (called by upgrade_tower and fuse_towers)
- Pattern: save original in `before()`, swap `TowerSystem._tower_scene` with stub scene in `before_test()`, restore in `after_test()`
- For sell_tower tests: manually place the tower on the grid (`GridManager.grid[x][y] = TOWER`, `_tower_map[pos] = tower`) and add to `_active_towers`
- For fusion tests: both towers must be on grid and in _active_towers; FusionRegistry.can_fuse checks tier, upgrade_to, and element
- sell_tower calls `tower.queue_free()` -- use `auto_free()` for test stubs to avoid double-free issues
- Fusion tests that verify real fusion results (e.g. "Magma Forge") depend on FusionRegistry loading the .tres files at _ready() -- these are real resource loads, not stubs

## FusionRegistry Testing Patterns
- FusionRegistry is a pure lookup autoload -- no scene dependencies, straightforward to test
- `_make_key` and `_make_legendary_key` are accessible directly (not truly private in GDScript)
- `get_fusion_partners` and `get_legendary_partners` iterate `TowerSystem.get_active_towers()` -- must add stub towers to `TowerSystem._active_towers` before calling
- `can_fuse` and `can_fuse_legendary` access `tower.tower_data.tier`, `.upgrade_to`, `.element`, `.fusion_elements` -- stubs need these properties set correctly
- The 15 dual fusion .tres files and 6 legendary .tres files are loaded via `load()` in `get_fusion_result`/`get_legendary_result` -- these are real resource loads that work in headless mode

## ElementSynergy Testing Patterns
- ElementSynergy is an autoload (class_name `ElementSynergyClass`) that reads `TowerSystem.get_active_towers()`
- Reset pattern in `before_test()`: clear `TowerSystem._active_towers`, `ElementSynergy._element_counts`, `ElementSynergy._synergy_tiers`
- Tower stubs: same pattern as TowerSystem/FusionRegistry tests -- Node2D with stub script that has `tower_data`, `grid_position`, `apply_tower_data()`
- `_calculate_tier()` is accessible directly (not truly private in GDScript) for isolated unit testing
- For aura bonus tests (get_attack_speed_bonus, get_range_bonus_cells, etc.), pass a tower node from `_active_towers` -- it reads the tower's elements and checks the synergy tier
- Signal test: `synergy_changed` is only emitted when `_synergy_tiers` dict changes between recalculations (old vs new comparison)
- For `get_synergy_color()` tests, reference `ElementSynergyClass.ELEMENT_COLORS` (the class_name) for the const, since `ElementSynergy` is the autoload instance

## Testing Enemy.gd (Scene-Based Node)
- Enemy.gd extends Node2D with `@onready var sprite: Sprite2D = $Sprite2D` and `@onready var health_bar: ProgressBar = $HealthBar`
- Cannot use BaseEnemy.tscn in headless mode because `_apply_enemy_data()` calls `load()` for sprite textures which fails
- Solution: build enemy nodes manually: create Node2D, add Sprite2D and ProgressBar children by name, then `set_script()` with the real Enemy.gd script
- Set `enemy_data = null` first, manually assign `max_health`, `current_health`, `speed`, `_base_speed`, then set `enemy_data` after -- this avoids `_apply_enemy_data()` texture load while preserving data access for `take_damage`, `_apply_resistance`, etc.
- For methods that read `path_points` and `_path_index` (movement, push/pull), set them before calling the method under test
- `_move_along_path()` can be called directly to test movement without full `_process()` overhead
- `_heal_nearby()` reads `EnemySystem.get_active_enemies()` -- register both healer and allies in `_active_enemies` before calling
- `_check_stealth_reveal()` reads `TowerSystem.get_active_towers()` -- add tower stubs to `_active_towers`
- `_boss_fire_trail()` has a static `_ground_effect_scene` var that persists -- must inject a stub PackedScene and restore after test
- `_boss_tower_freeze()` calls `tower.disable_for(3.0)` on towers -- tower stubs need a `disable_for()` method
- `_boss_element_cycle()` modifies `enemy_data.immune_element`/`weak_element` directly and calls `_recalculate_speed()`
- `_tick_boss_ability()` handles both the main ability timer and the separate minion spawn timer in one method
- For flying bobbing tests, set `_is_flying = true` and `_bob_time = 0.0`, then compute the expected sine offset manually
