# Spirefall Agent Memory

## Architecture Overview
- 8 autoload managers: GameManager, GridManager, PathfindingSystem, TowerSystem, EnemySystem, EconomyManager, UIManager, AudioManager
- All autoloads use `class_name` suffix `Class` (e.g., `EnemySystemClass`)
- Autoloads reference each other directly by name (e.g., `EnemySystem.spawn_wave()`)

## Key Patterns
- Enemy data: `.tres` Resource files in `resources/enemies/`, keyed by snake_case type name
- Wave config: `resources/waves/wave_config.json` with `waves` array, each entry has `wave`, `enemies[]`, optional `is_boss_wave`, `is_income_wave`
- Enemy .tres naming: filename matches wave_config type (e.g., `"boss_ember_titan"` -> `boss_ember_titan.tres`)
- Boss enemy_name in .tres is "Ember Titan" (no "Boss" prefix) but file is `boss_ember_titan.tres`
- Swarm enemies have `spawn_count = 3` -- multiply config count by spawn_count for actual units
- Tower data: `.tres` in `resources/towers/`

## Scaling Formulas (GDD)
- HP: `base * (1 + 0.15 * wave)^2`
- Speed: `base * min(1 + 0.02 * wave, 2.0)` (capped at 2x)
- Gold: `base * (1 + 0.08 * wave)` (int truncated)

## Implementation Status
- [x] Task 1: Wave config wired up (EnemySystem.gd loads wave_config.json, spawns correct types/counts)
- [ ] Task 2: Limit to 10 waves (GameManager.max_waves still 30)
- [ ] Tasks 3-10: Not started

## File Locations
- `scripts/autoload/EnemySystem.gd` - wave spawning, enemy lifecycle
- `scripts/autoload/GameManager.gd` - game state machine, phase transitions
- `scripts/autoload/EconomyManager.gd` - gold, interest, income
- `scripts/enemies/Enemy.gd` - enemy movement, health, damage
- `scripts/enemies/EnemyData.gd` - enemy data resource definition
- `resources/waves/wave_config.json` - 10-wave config for Phase 1
- `resources/enemies/*.tres` - normal, fast, armored, flying, swarm, boss_ember_titan

## Gotchas
- wave_config.json has no `spawn_interval` field per wave; EnemySystem defaults 0.5s normal, 1.5s boss
- GameManager checks `current_wave >= max_waves` for victory, and `current_wave > max_waves` for the game_over emit -- slight inconsistency
- Enemy.gd `_apply_enemy_data()` loads sprite by converting `enemy_name` to snake_case (spaces to underscores, lowercased)
- `_wave_finished_spawning` is set true in two places: `_spawn_next_enemy()` when queue empties
