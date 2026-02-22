# Gotchas and Lessons Learned

## queue_free() vs free() for Nodes Not in the Scene Tree
- `queue_free()` marks a node for deletion at the end of the current frame, but ONLY works when the node is in the SceneTree. If the node is NOT in the tree, the deferred deletion never processes and the node leaks.
- In tests, most nodes (tower stubs, enemy stubs, projectiles captured via signal) are never added to the scene tree. Always use `free()` for immediate cleanup of these nodes.
- GdUnit4 exit code 101 = orphan node warnings (leaked nodes). Each leaked Node2D = 1 CanvasItem RID. Projectiles (Node2D + Sprite2D child) = 2 CanvasItems each.
- Pattern: use `free()` in `before_test()` / `after_test()` cleanup loops, and for manually cleaning up nodes in test bodies. Only use `queue_free()` when the node is actually in the scene tree.

## EnemySystem._process() Autoload Spawning During Tests
- EnemySystem is a live autoload with `_process(delta)` that spawns enemies from `_enemies_to_spawn` queue every frame.
- Any test that calls `GameManager.start_wave_early()` or `EnemySystem.spawn_wave()` populates this queue.
- Between test statements (especially during `await` calls), EnemySystem._process() fires and instantiates real enemy nodes from `_enemy_scene`. These nodes go into `_active_enemies` but are never cleaned up by the test.
- **Fix**: Immediately clear `EnemySystem._enemies_to_spawn.clear()` after any call to `start_wave_early()` or `spawn_wave()` in tests that don't need actual spawning.
- **Fix**: Add `after_test()` cleanup that frees all nodes in `EnemySystem._active_enemies` and clears `_enemies_to_spawn`.
- **Fix**: In test suites that don't directly test EnemySystem (e.g., test_tower_system.gd), add `_reset_enemy_system()` to both `before_test()` and `after_test()` to prevent cross-suite contamination.

## GdUnit4 Orphan Detection Timing
- GdUnit4 detects orphan nodes BEFORE `after_test()` runs. The execution order is: `before_test()` -> test body -> orphan detection -> `after_test()`.
- Nodes created during the test must be freed within the test body (or registered via `auto_free()`) to avoid orphan detection.
- `auto_free(node)` registers the node for cleanup during GdUnit4's internal cleanup phase, which happens before orphan counting.
- For production functions like `TowerSystem.create_tower()` that return new nodes, wrap with `auto_free()`: `var tower = auto_free(TowerSystem.create_tower(data, pos))`
- `after_test()` cleanup still needed for array state reset (clearing `_active_towers`, etc.), but node freeing should happen via `auto_free()` or explicit `free()` within the test body.

## Static GDScript Variables Leak at Process Exit
- `static var` on GDScript classes persist for the entire Godot process lifetime. At exit, any GDScript objects still referenced by static vars are reported as "resources still in use."
- Fix: add an `after()` method (GdUnit4 suite-level teardown, runs once after all tests) that nulls out all static vars:
  ```gdscript
  func after() -> void:
      _stub_script = null
      _enemy_script = null
  ```
- This applies to cached GDScript stubs (`GDScript.new()` with `.reload()`) and loaded scripts (`load()` as GDScript).

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
- **WARNING**: `monitor_signals`/`await assert_signal` is unreliable for synchronous signal emissions on autoload singletons in CI. Prefer direct signal connection with `Array[int]` counter pattern:
  ```gdscript
  var signal_count: Array[int] = [0]
  var _conn: Callable = func(_arg: Node) -> void: signal_count[0] += 1
  SomeAutoload.some_signal.connect(_conn)
  SomeAutoload.do_thing()
  SomeAutoload.some_signal.disconnect(_conn)
  assert_int(signal_count[0]).is_equal(1)
  ```
- **GDScript lambda capture gotcha**: lambdas cannot properly capture and mutate primitive `bool`/`int` variables from enclosing scope. Use `Array[int]` as a mutable container workaround.

## GdUnit4 API: assert_vector (NOT assert_vector2)
- GdUnit4 provides `assert_vector()` for Vector2/Vector3/Vector4 assertions. There is NO `assert_vector2()` method.

## Godot 4.6 Variant Type Inference Warning
- `auto_free()` returns `Variant` type. Using `:=` with it causes "Variant type inference" warning treated as error in Godot 4.6.
- Fix: use explicit type annotation: `var x: Type = auto_free(Node2D.new())` instead of `var x := auto_free(Node2D.new())`
- Same applies to any expression returning Variant (e.g., `var x = some_dict[key]`)

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

## Testing Tower.gd (Scene-Based Area2D)
- Tower.gd extends Area2D with `@onready var sprite: Sprite2D = $Sprite2D`, `@onready var collision: CollisionShape2D = $CollisionShape2D`, `@onready var attack_cooldown: Timer = $AttackCooldown`
- Cannot use BaseTower.tscn in headless mode because `apply_tower_data()` calls `load()` for sprite textures
- Solution: build Area2D manually with Sprite2D, CollisionShape2D, and Timer children by name, then `set_script()` with real Tower.gd
- Set `tower_data = null` first to prevent `_ready()` from calling `apply_tower_data()`, then assign tower_data and manually apply stats (range, collision shape, timer wait_time, ability intervals)
- Must also manually set all `_synergy_*` vars to defaults (1.0/0.0/0/WHITE) to bypass `_refresh_synergy_bonuses()` which queries ElementSynergy autoload
- Enemy stubs for targeting tests need: `enemy_data` (EnemyData with element, stealth), `current_health`, `path_progress`, `position`, `_is_revealed`
- Enemy stubs for aura tests need: `apply_status()` and `take_damage()` methods that record calls for assertion
- Tower.gd `_process()` gates on `GameManager.game_state == COMBAT_PHASE` -- must set game state before calling `_process()`
- `_tick_aura(delta)` and `_tick_periodic_ability(delta)` can be called directly for isolated tests without going through `_process()`
- `_find_target()` and `_find_multiple_targets(N)` can be called directly for targeting mode tests
- `_calculate_damage(target)` can be called directly for damage formula tests
- `_attack(target)` fires `projectile_spawned` signal -- capture with signal connect or monitor_signals
- For `_attack()` tests, captured projectiles must be freed manually (they are instantiated PackedScenes)
- `disable_for()` uses `maxf()` for extending to longer durations; the disable timer only counts down during `_process()` in COMBAT_PHASE

## Testing Enemy.gd (Scene-Based Node)
- Enemy.gd extends Node2D with `@onready var sprite: Sprite2D = $Sprite2D` and `@onready var health_bar: ProgressBar = $HealthBar`
- Cannot use BaseEnemy.tscn in headless mode because `_apply_enemy_data()` calls `load()` for sprite textures which fails
- Solution: build enemy nodes manually: create Node2D, add Sprite2D and ProgressBar children by name, then `set_script()` with the real Enemy.gd script
- **Must manually set `enemy.sprite = sprite` and `enemy.health_bar = health_bar` after `set_script()`** because `@onready` only resolves when node enters scene tree via `_ready()`
- Set `enemy_data = null` first, manually assign `max_health`, `current_health`, `speed`, `_base_speed`, then set `enemy_data` after -- this avoids `_apply_enemy_data()` texture load while preserving data access for `take_damage`, `_apply_resistance`, etc.
- For methods that read `path_points` and `_path_index` (movement, push/pull), set them before calling the method under test
- **Movement gotcha**: `_move_along_path()` processes ONE step per call. Enemy starts at `path_points[0]` with `_path_index=0`, so the first call instantly "arrives" at point[0] (already there) and increments index to 1 without actual movement. Need two calls to see position change: first to advance past starting point, second to actually move.
- `_move_along_path()` can be called directly to test movement without full `_process()` overhead
- `_heal_nearby()` reads `EnemySystem.get_active_enemies()` -- register both healer and allies in `_active_enemies` before calling
- `_check_stealth_reveal()` reads `TowerSystem.get_active_towers()` -- add tower stubs to `_active_towers`
- `_boss_fire_trail()` has a static `_ground_effect_scene` var that persists -- must inject a stub PackedScene and restore after test
- `_boss_tower_freeze()` calls `tower.disable_for(3.0)` on towers -- tower stubs need a `disable_for()` method
- `_boss_element_cycle()` modifies `enemy_data.immune_element`/`weak_element` directly and calls `_recalculate_speed()`
- `_tick_boss_ability()` handles both the main ability timer and the separate minion spawn timer in one method
- For flying bobbing tests, set `_is_flying = true` and `_bob_time = 0.0`, then compute the expected sine offset manually

## Testing Projectile.gd (Scene-Based Node2D)
- Projectile.gd extends Node2D with `@onready var sprite: Sprite2D = $Sprite2D`
- Cannot use the real Projectile scene in headless mode because `_load_element_sprite()` calls `load()` for PNG textures
- Solution: build Node2D manually with Sprite2D child by name, then `set_script()` with real Projectile.gd
- Set `element = ""` initially to prevent `_load_element_sprite()` from attempting texture load in `_ready()`
- `Projectile._ground_effect_scene` is a static var -- persists across tests. Must reset to `null` in `before_test()` and inject a stub scene for ground effect tests
- For ground effect tests: create a stub PackedScene with a Node2D that has the expected properties (effect_type, effect_radius_px, effect_duration, element, damage_per_second, slow_fraction)
- Enemy stubs for Projectile tests need additional methods vs Tower stubs: `pull_toward(target_pos, max_dist)` and `push_back(steps)` for pull_burn and pushback hit paths
- `_hit()` dispatches to different methods based on `special_key` first, then `is_aoe`, then single hit + chain. Ground effects spawn after damage.
- `_calculate_damage()` needs `tower_data` to be non-null; without it, returns raw `damage` field (no element multiplier or synergy)
- For movement tracking tests: call `_process(delta)` directly -- it updates `target_last_pos` from living target, then moves toward `move_target`
- For hit threshold tests: position projectile within 8px (HIT_THRESHOLD) of target_last_pos, then call `_process()` -- _hit() auto-triggers
- For queue_free test: add projectile to scene tree (`add_child(proj)`) so queue_free works, then check `is_queued_for_deletion()`
- Chain radius is hardcoded at `2.0 * GridManager.CELL_SIZE` = 128px (not configurable)

## Testing GroundEffect.gd (Simple Node2D)
- GroundEffect.gd extends Node2D with NO @onready children -- simplest scene-based script to test
- `_ready()` only calls `queue_redraw()` (no texture loads), so creating Node2D + `set_script()` works directly in headless mode
- No need to suppress `_ready()` behavior -- just create, set script, set properties, and call `_process()` directly
- `_apply_effect()` reads `EnemySystem.get_active_enemies()` and `TowerSystem.get_active_towers()` -- populate `_active_enemies`/`_active_towers` with stubs
- Enemy stubs need: `take_damage(amount, element)`, `apply_status(type, duration, value)`, `current_health`, `global_position`
- Tower stubs need: `disable_for(duration)`, `global_position`
- Uses `global_position` for distance checks -- equals `position` when node has no parent with transforms
- Tick damage formula: `max(1, int(damage_per_second * _tick_interval))` where `_tick_interval = 0.5`
- Fire trail tower disable radius is `GridManager.CELL_SIZE` (64px), NOT `effect_radius_px`
- For expiration test: call `_process()` with cumulative deltas exceeding `effect_duration`, then check `is_queued_for_deletion()`
- For fade test: advance `_lifetime` to within 0.5s of `effect_duration` via `_process()` calls, then check `modulate.a`

## Integration Test Patterns (Combat Flow)
- Integration tests in `tests/integration/` test multi-system interactions (Tower + Projectile + Enemy + autoloads)
- Same manual node construction patterns as unit tests -- no scene_runner needed for combat flow
- Must save/restore both `TowerSystem._tower_scene` AND `EnemySystem._enemy_scene` in before()/after_test()
- For tower-kill-awards-gold tests: fire projectile via `_attack()`, capture with signal, then call `proj._apply_single_hit()` to trigger damage -> _die() -> on_enemy_killed -> add_gold chain
- For wave clear bonus tests: set `_wave_finished_spawning = true`, add one enemy, kill it via `on_enemy_killed()` -> `_remove_enemy` -> `wave_cleared` signal. Then call `GameManager._process(0.016)` to detect wave clear and award bonus gold (GameManager polls, not signal-driven).
- Must set `GameManager._enemies_leaked_this_wave` before wave clear to test no-leak bonus vs leaked bonus
- **Income phase gotcha**: waves divisible by 5 trigger income phase (`current_wave % 5 == 0`), which applies interest. Use a non-multiple-of-5 wave number (e.g., 4) to avoid unintended interest gold in wave bonus tests.
- **Floating-point damage truncation**: `_calculate_damage` uses `int()` which truncates. Chained float multiplications like `1.5 * 1.2` yield `1.7999...` due to floating-point precision, so `int(100 * 1.5 * 1.2) = 179` not 180.
- For sell-tower-reopens-path tests: use `TowerSystem.create_tower()` (with stub scene) then `sell_tower()` to exercise the full GridManager/PathfindingSystem path
- Unlike unit tests, integration tests exercise the real signal chains between autoloads (e.g. EnemySystem.on_enemy_killed -> EconomyManager.add_gold)

## get_viewport() is Null Outside the Scene Tree
- `get_viewport()` returns `null` when a node has not been added to the scene tree. Calling any method on it (e.g. `set_input_as_handled()`) crashes immediately.
- Guard all `get_viewport()` calls with `if is_inside_tree():` in scripts that may be exercised outside the tree (unit tests, headless mode).
- Same rule applies to `get_tree()` (see below).

## Nodes Not in Scene Tree Cannot Call get_tree()
- Any node that has not been added to the scene tree returns `null` from `get_tree()`. Calling `.paused` on it crashes immediately.
- Pattern: delegate ALL pause/unpause calls to `GameManager.pause()` / `GameManager.unpause()` / `GameManager.is_paused()`. GameManager is an autoload and always lives in the tree.
- This is the same reason `PauseMenu.gd` already delegates to GameManager. Apply the same pattern to any UI script that needs to read or modify pause state.
- When adding `is_paused()` or similar helpers to GameManager, they can safely call `get_tree()` because GameManager is always in the tree.

## Codex Z-order Bug (and Fix Pattern)
- In Godot `CanvasLayer`, nodes are rendered in child order: later children draw on top. `CodexPanel` was declared before `PauseMenu` in `Game.tscn`, so PauseMenu rendered on top of Codex, making Codex invisible/unusable when opened from the pause menu.
- **Fix used**: Rather than reordering scene nodes or using z_index (which can cause other issues), PauseMenu hides itself when opening Codex, then restores via CodexPanel's `closed` signal using `CONNECT_ONE_SHOT`.
- `CodexPanel` gained a `closed` signal (emitted at end of `_close()`) and a `_was_paused_before_open` bool so it knows whether to unpause on close (only if it caused the pause, not when opened from PauseMenu).
- `CONNECT_ONE_SHOT` flag on `Signal.connect()` auto-disconnects after the first emission — ideal for "restore on close" pattern.

## Typed Array Assignment in Tests
- CodexPanel.tab_buttons is declared `Array[Button]`. Assigning a plain `Array` literal `[btn1, btn2]` fails at runtime with "Invalid assignment ... value of type 'Array'".
- Fix: declare a typed local first, then assign: `var typed_tabs: Array[Button] = [btn1 as Button, btn2 as Button]` then `panel.tab_buttons = typed_tabs`.

## Godot 4.x Theme Override API
- There is NO `get_theme_stylebox_override()` method on Control/Button. It does not exist.
- To CHECK if a stylebox override is set: `btn.has_theme_stylebox_override("hover")` (returns bool)
- To GET the stylebox (including overrides): `btn.get_theme_stylebox("hover")` (returns the override if set, otherwise the theme default)
- To SET: `btn.add_theme_stylebox_override("hover", style)` (this one does exist)
- Same pattern for color/font/font_size/constant overrides: `has_theme_*_override()` to check, `get_theme_*()` to get, `add_theme_*_override()` to set

## Resource Validation Test Patterns
- Resource .tres files load fine with `load()` in headless mode -- no texture issues since TowerData/EnemyData are pure Resource subclasses (no scene nodes)
- All tower tiers use `tier = 1` for base/enhanced/superior (upgrade chain is base -> enhanced -> superior via `upgrade_to` references). Fusions are `tier = 2`, legendaries are `tier = 3`
- Fusion towers have `fusion_elements` array of size 2; legendaries have size 3
- Superior towers have `upgrade_to == null` (end of upgrade chain)
- wave_config.json uses `"waves"` top-level key with array of 30 wave entries; boss waves marked with `"is_boss_wave": true`
- Use `override_failure_message()` in loops to identify which specific resource failed, since GdUnit4 only shows the assertion message
- `FileAccess.open()` + `JSON.parse_string()` works in headless mode for loading wave_config.json
