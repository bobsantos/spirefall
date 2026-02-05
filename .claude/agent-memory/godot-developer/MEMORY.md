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
- [x] Task 2: Limit to 10 waves (max_waves=10, fixed victory condition bug)
- [x] Task 3: Status effect system (StatusEffect.gd + Enemy.gd integration)
- [x] Task 4: Tower special abilities (burn/slow/aoe/freeze via TowerData.special_key)
- [x] Task 5: Damage resistance (EnemyData.physical_resist + Enemy._apply_resistance())
- [ ] Tasks 6-10: Not started

## File Locations
- `scripts/autoload/EnemySystem.gd` - wave spawning, enemy lifecycle
- `scripts/autoload/GameManager.gd` - game state machine, phase transitions
- `scripts/autoload/EconomyManager.gd` - gold, interest, income
- `scripts/enemies/Enemy.gd` - enemy movement, health, damage, status effects
- `scripts/enemies/EnemyData.gd` - enemy data resource definition
- `scripts/enemies/StatusEffect.gd` - RefCounted status effect (BURN, SLOW, FREEZE)
- `resources/waves/wave_config.json` - 10-wave config for Phase 1
- `resources/enemies/*.tres` - normal, fast, armored, flying, swarm, boss_ember_titan

## Gotchas
- StatusEffect is RefCounted (not Node), stored in Enemy._status_effects typed array
- Burn stacks independently (multiple burns tick); Slow/Freeze replace each other (not additive)
- Slow value is 0-1 fraction (0.3 = 30% slow), not percentage int
- Burn ticks once per second via elapsed accumulator, not every frame
- `apply_status()` is the public API; Tower._attack() calls it via `_apply_special_effect()` (Task 4)
- Tower specials are data-driven: TowerData has `special_key`, `special_value`, `special_duration`, `special_chance`, `aoe_radius_cells`
- AoE damage is applied before status effects in `_attack()`, uses `_calculate_damage()` per enemy for correct elemental multipliers
- Gale Tower ("multi") and Thunder Pylon ("chain") specials are Phase 2 -- leave `special_key` empty
- wave_config.json has no `spawn_interval` field per wave; EnemySystem defaults 0.5s normal, 1.5s boss
- (FIXED) GameManager victory condition was `current_wave > max_waves` (strict), which meant clearing the final wave counted as defeat. Changed to `>=` to match the trigger in `_on_wave_cleared()`
- Enemy.gd `_apply_enemy_data()` loads sprite by converting `enemy_name` to snake_case (spaces to underscores, lowercased)
- `_wave_finished_spawning` is set true in two places: `_spawn_next_enemy()` when queue empties
- Damage resistance is data-driven via `EnemyData.physical_resist` (0-1 float), checked in `Enemy._apply_resistance()`
- Physical resist only applies to "earth" element attacks; burn DOT bypasses resistance (no element passed)
