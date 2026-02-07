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
