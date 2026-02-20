# Spirefall Agent Memory

## Project Structure
- Engine: Godot 4.6, GDScript, gl_compatibility renderer
- Grid: 20x15 cells, 64px each, 1280x960
- 8 autoload managers: GameManager, GridManager, PathfindingSystem, TowerSystem, EnemySystem, EconomyManager, UIManager, AudioManager
- Additional autoloads: FusionRegistry, ElementSynergy, SceneManager
- Main scene: `res://scenes/main/MainMenu.tscn` (changed from Game.tscn in Task A2)
- Remote: `git@github.com:bobsantos/spirefall.git`

## Testing Setup
- GdUnit4 v6.1.1 installed at `addons/gdUnit4/`
- Test root configured: `res://tests` (in project.godot under `[gdunit4]`)
- Test directories exist: `tests/unit/{autoload,effects,enemies,projectiles,systems,towers}`, `tests/integration/`, `tests/resources/`
- Task 1 complete: `tests/unit/autoload/test_economy_manager.gd` (18 tests)
- Task 2 complete: `tests/unit/enemies/test_status_effect.gd` (12 tests)
- Task 3 complete: `tests/unit/systems/test_element_matrix.gd` (17 tests)
- Task 4 complete: `tests/unit/autoload/test_game_manager.gd` (20 tests)
- Task 5 complete: `tests/unit/autoload/test_grid_manager.gd` (23 tests)
- Task 6 complete: `tests/unit/autoload/test_pathfinding_system.gd` (13 tests)
- Task 7 complete: `tests/unit/autoload/test_enemy_system.gd` (30 tests)
- Task 8 complete: `tests/unit/autoload/test_tower_system.gd` (27 tests)
- Task 9 complete: `tests/unit/autoload/test_fusion_registry.gd` (24 tests)
- Task 10 complete: `tests/unit/systems/test_element_synergy.gd` (24 tests)
- Task 11 complete: `tests/unit/enemies/test_enemy.gd` (39 tests)
- Task 12 complete: `tests/unit/towers/test_tower.gd` (27 tests)
- Task 13 complete: `tests/unit/projectiles/test_projectile.gd` (23 tests)
- Task 14 complete: `tests/unit/effects/test_ground_effect.gd` (8 tests)
- Task 15 complete: `tests/unit/test_resource_validation.gd` (19 tests)
- Task 16 complete: `tests/integration/test_combat_flow.gd` (12 tests)
- Task 17 complete: `tests/integration/test_fusion_flow.gd` (6 tests)
- Task 18 complete: `tests/integration/test_game_state.gd` (6 tests)
- Phase 3 Task A1 complete: `tests/unit/autoload/test_scene_manager.gd` (19 tests)
- Phase 3 Task A2 complete: `tests/unit/main/test_main_menu.gd` (31 tests)
- Comprehensive test plan: `docs/work/plan.md` (348 test cases across 18 tasks) -- ALL 18 TASKS COMPLETE
- CI: `.github/workflows/test.yml` runs GdUnit4 on push/PR to main (barichello/godot-ci:4.6 container)
- `.gitignore` exists at project root (covers .godot/, reports/, exports, OS files)

## GdUnit4 CI Details
- CLI runner: `addons/gdUnit4/bin/GdUnitCmdTool.gd`
- Shell script: `addons/gdUnit4/runtest.sh` (needs `GODOT_BIN` env var or `--godot_binary` flag)
- Headless mode: GdUnit4 blocks headless by default; use `--ignoreHeadlessMode` flag
- JUnit XML reports: auto-generated via `GdUnitXMLReporterTestSessionHook` (built-in)
- HTML reports: also auto-generated
- Report output: defaults to `res://reports/` (configurable with `-rd`)
- Exit codes: 0=success, 100=test failures, 101=warnings only (orphan nodes), 1=error, 103=headless not supported
- Run command: `godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/ --ignoreHeadlessMode`
- The `-d` flag on the Godot binary means debug mode (enables breakpoints, not needed for CI but used in runtest.sh)

## Key Gotchas
- See [gotchas.md](gotchas.md) for detailed notes
- **Critical**: Use `free()` not `queue_free()` for test nodes not in the scene tree (causes exit code 101 orphan leaks)
- **Critical**: Null out `static var` GDScript references in `after()` to prevent "resources still in use at exit"

## UI Panel Patterns
- See [ui-panels.md](ui-panels.md) for detailed notes
