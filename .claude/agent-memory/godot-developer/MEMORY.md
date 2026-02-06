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

## Phase 1 Implementation Status (COMPLETE)
- [x] P1-Task 1: Wave config wired up (EnemySystem.gd loads wave_config.json)
- [x] P1-Task 2: Limit to 10 waves (max_waves=10)
- [x] P1-Task 3: Status effect system (StatusEffect.gd + Enemy.gd)
- [x] P1-Task 4: Tower special abilities (burn/slow/aoe/freeze)
- [x] P1-Task 5: Damage resistance (EnemyData.physical_resist)
- [x] P1-Task 6: Projectile visuals (fire-and-forget projectiles)
- [x] P1-Task 7: Build menu filter (fire/water/earth tier-1 only)
- [x] P1-Task 8: Wave clear bonuses (leak tracking + no-leak bonus)
- [x] P1-Task 9: Ghost tower preview (green/red tint)
- [x] P1-Task 10: Game over screen (victory/defeat + play again)

## Phase 2 Implementation Status (IN PROGRESS)
- Plan: `docs/work/plan.md` -- 18 tasks, ~4 weeks estimated
- [ ] P2-Task 18: Refactor element matrix (centralize duplicated 6x6 matrix)
- [x] P2-Task 1: Wind/Lightning specials (multi-target + chain)
- [ ] P2-Task 11: Build menu expansion (all 6 base elements)
- [ ] P2-Task 2: Tower upgrade tiers (Enhanced/Superior, 12 new .tres)
- [ ] P2-Task 7: Flying enemy behavior (ignores maze)
- [ ] P2-Task 6: New enemy types (Healer, Split, Stealth, Elemental)
- [ ] P2-Task 14: Camera pan/zoom (WASD + mouse drag + scroll)
- [ ] P2-Task 16: Ground effect system (lava pools, mud, fire trail)
- [ ] P2-Task 17: Tower disable mechanic (boss interaction)
- [ ] P2-Task 3: Dual fusion system (15 Tier 2 towers + FusionRegistry)
- [ ] P2-Task 4: Dual fusion abilities (15 unique specials)
- [ ] P2-Task 5: Legendary fusion + abilities (6 Tier 3 towers)
- [ ] P2-Task 10: Element synergy bonuses (3/5/8 thresholds)
- [ ] P2-Task 9: 30-wave campaign config
- [ ] P2-Task 8: Boss behaviors (Ember Titan, Glacial Wyrm, Chaos Elemental)
- [ ] P2-Task 12: Tower info panel (stats + upgrade + sell + fusion + targeting)
- [ ] P2-Task 13: Wave preview panel
- [ ] P2-Task 15: Fusion UX flow in Game.gd

## File Locations
- `scripts/autoload/EnemySystem.gd` - wave spawning, enemy lifecycle
- `scripts/autoload/GameManager.gd` - game state machine, phase transitions
- `scripts/autoload/EconomyManager.gd` - gold, interest, income
- `scripts/enemies/Enemy.gd` - enemy movement, health, damage, status effects
- `scripts/enemies/EnemyData.gd` - enemy data resource definition
- `scripts/enemies/StatusEffect.gd` - RefCounted status effect (BURN, SLOW, FREEZE)
- `resources/waves/wave_config.json` - 10-wave config for Phase 1
- `scripts/projectiles/Projectile.gd` - projectile movement, hit logic, AoE, specials
- `scenes/projectiles/BaseProjectile.tscn` - projectile scene (Node2D + Sprite2D at 0.5 scale)
- `scripts/main/Game.gd` - wires tower projectile_spawned -> game_board.add_child
- `resources/enemies/*.tres` - normal, fast, armored, flying, swarm, boss_ember_titan
- `scripts/ui/BuildMenu.gd` - tower selection UI, filtered by PHASE_1_ELEMENTS const
- `scripts/ui/GameOverScreen.gd` - game over overlay (victory/defeat), wired to GameManager.game_over
- `scenes/ui/GameOverScreen.tscn` - fullscreen overlay with dimmer, centered panel, result label, waves label, play again button

## Gotchas
- StatusEffect is RefCounted (not Node), stored in Enemy._status_effects typed array
- Burn stacks independently (multiple burns tick); Slow/Freeze replace each other (not additive)
- Slow value is 0-1 fraction (0.3 = 30% slow), not percentage int
- Burn ticks once per second via elapsed accumulator, not every frame
- `apply_status()` is the public API; Projectile._try_apply_special() calls it on impact (moved from Tower in Task 6)
- Tower specials are data-driven: TowerData has `special_key`, `special_value`, `special_duration`, `special_chance`, `aoe_radius_cells`
- AoE damage is applied before status effects in Projectile._apply_aoe_hit(), uses `_calculate_damage()` per enemy for correct elemental multipliers
- Gale Tower ("multi") special: Tower._attack() spawns N projectiles via _find_multiple_targets(). Each projectile is independent full-damage. Tower._find_multiple_targets() reuses _get_in_range_enemies() + _sort_by_target_mode().
- Thunder Pylon ("chain") special: Projectile._apply_chain_hits() deals fractional damage to nearby enemies after primary hit. Chain radius = 2 cells (128px). TowerData.chain_damage_fraction controls fraction (0.6 = 60%). Chain hits use per-target elemental multipliers.
- "multi" and "chain" are skipped in _try_apply_special() (same as "aoe") since they are handled structurally, not as status effects
- wave_config.json has no `spawn_interval` field per wave; EnemySystem defaults 0.5s normal, 1.5s boss
- (FIXED) GameManager victory condition was `current_wave > max_waves` (strict), which meant clearing the final wave counted as defeat. Changed to `>=` to match the trigger in `_on_wave_cleared()`
- Enemy.gd `_apply_enemy_data()` loads sprite by converting `enemy_name` to snake_case (spaces to underscores, lowercased)
- `_wave_finished_spawning` is set true in two places: `_spawn_next_enemy()` when queue empties
- Damage resistance is data-driven via `EnemyData.physical_resist` (0-1 float), checked in `Enemy._apply_resistance()`
- Physical resist only applies to "earth" element attacks; burn DOT bypasses resistance (no element passed)
- Projectile.gd has `class_name Projectile`; Tower.gd casts instantiated scene via `as Projectile`
- Tower emits `projectile_spawned(projectile)` signal; Game.gd connects via `TowerSystem.tower_created`
- Projectile carries all damage/special data so Tower is fire-and-forget (no back-reference)
- If target dies mid-flight: single-target projectile despawns harmlessly; AoE hits at last known position
- Projectile sprite loaded from `assets/sprites/projectiles/{element}.png` (fire, water, earth, etc.)
- Elemental damage matrix duplicated in Projectile.gd for AoE per-enemy recalculation (same as Tower.gd)
- (FIXED) Projectile class_name was missing from `.godot/global_script_class_cache.cfg` -- Godot doesn't always auto-detect new class_name scripts added outside the editor. Fix: manually add entry to cache, or delete `.godot/` and let Godot rebuild. Also add UID to ext_resource refs in .tscn files for proper linkage.
- (FIXED) Tower AttackCooldown Timer had `one_shot = false` -- a repeating timer never stops, so `is_stopped()` is always `false` after first `.start()`, meaning the tower only ever fires ONE projectile. Fix: set `one_shot = true` in both Tower.gd `apply_tower_data()` and BaseTower.tscn so timer stops after each cooldown, allowing `is_stopped()` to gate the next attack.
- (FIXED) Wave income was awarded in BUILD_PHASE transition (after current_wave++) meaning the bonus was calculated for the NEXT wave, not the one just cleared. Moved to `_on_wave_cleared()` where `current_wave` still reflects the cleared wave. Also means wave 1's first build phase no longer grants spurious income.
- Wave clear bonus flow: `_on_wave_cleared()` -> `EconomyManager.calculate_wave_bonus(wave, leaks)` -> `add_gold()`. Leak counter reset at COMBAT_PHASE start, incremented via `GameManager.record_enemy_leak()` called from `EnemySystem.on_enemy_reached_exit()`.
- GameOverScreen connects to GameManager.game_over signal in _ready(). Uses `get_tree().reload_current_scene()` for restart. Must call `EconomyManager.reset()` before reload since autoloads persist across scene reloads. GameManager.start_game() is called by Game._ready() on reload, which resets wave/lives state.
- Ghost tower preview: Game.gd creates a bare Sprite2D (not a full Tower scene) added to game_board. Uses same texture path convention as Tower.gd (`tower_name.to_lower().replace(" ", "_")`). Ghost checks `GridManager.can_place_tower()` which combines `is_cell_buildable()` + `would_block_path()`. Also checks `EconomyManager.can_afford()` so ghost turns red when player can't afford. Right-click also cancels placement (in addition to Escape). Ghost hidden when cursor is outside grid bounds via `GridManager.is_in_bounds()`.
