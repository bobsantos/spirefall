# Spirefall Agent Memory

## Architecture Overview
- 9 autoload managers: GameManager, GridManager, PathfindingSystem, TowerSystem, EnemySystem, EconomyManager, UIManager, AudioManager, FusionRegistry
- All autoloads use `class_name` suffix `Class` (e.g., `EnemySystemClass`)
- Autoloads reference each other directly by name (e.g., `EnemySystem.spawn_wave()`)

## Key Patterns
- Enemy data: `.tres` Resource files in `resources/enemies/`, keyed by snake_case type name
- Wave config: `resources/waves/wave_config.json` with `waves` array, each entry has `wave`, `enemies[]`, optional `is_boss_wave`, `is_income_wave`
- Enemy .tres naming: filename matches wave_config type (e.g., `"boss_ember_titan"` -> `boss_ember_titan.tres`)
- Boss enemy_name in .tres is "Ember Titan" (no "Boss" prefix) but file is `boss_ember_titan.tres`
- Swarm enemies have `spawn_count = 3` -- multiply config count by spawn_count for actual units
- Tower data: `.tres` in `resources/towers/` (base/enhanced/superior), `resources/towers/fusions/` (dual-element tier 2), `resources/towers/legendaries/` (triple-element tier 3)

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
- [x] P2-Task 2: Tower upgrade tiers (Enhanced/Superior, 12 new .tres)
- [ ] P2-Task 7: Flying enemy behavior (ignores maze)
- [x] P2-Task 6: New enemy types (Healer, Split, Stealth, Elemental)
- [ ] P2-Task 14: Camera pan/zoom (WASD + mouse drag + scroll)
- [x] P2-Task 16: Ground effect system (lava pools, mud -- bundled into Task 4)
- [ ] P2-Task 17: Tower disable mechanic (boss interaction)
- [x] P2-Task 3: Dual fusion system (15 Tier 2 towers + FusionRegistry)
- [x] P2-Task 4: Dual fusion abilities (15 unique specials)
- [x] P2-Task 5: Legendary fusion + abilities (6 Tier 3 towers)
- [ ] P2-Task 10: Element synergy bonuses (3/5/8 thresholds)
- [ ] P2-Task 9: 30-wave campaign config
- [ ] P2-Task 8: Boss behaviors (Ember Titan, Glacial Wyrm, Chaos Elemental)
- [x] P2-Task 12: Tower info panel (stats + upgrade + sell buttons)
- [ ] P2-Task 13: Wave preview panel
- [ ] P2-Task 15: Fusion UX flow in Game.gd

## File Locations
- `scripts/autoload/EnemySystem.gd` - wave spawning, enemy lifecycle
- `scripts/autoload/GameManager.gd` - game state machine, phase transitions
- `scripts/autoload/EconomyManager.gd` - gold, interest, income
- `scripts/enemies/Enemy.gd` - enemy movement, health, damage, status effects
- `scripts/enemies/EnemyData.gd` - enemy data resource definition
- `scripts/enemies/StatusEffect.gd` - RefCounted status effect (BURN, SLOW, FREEZE, STUN, WET)
- `scripts/effects/GroundEffect.gd` - persistent ground effects (lava_pool, slow_zone)
- `scenes/effects/GroundEffect.tscn` - ground effect scene (Node2D with custom _draw)
- `resources/waves/wave_config.json` - 10-wave config for Phase 1
- `scripts/projectiles/Projectile.gd` - projectile movement, hit logic, AoE, specials
- `scenes/projectiles/BaseProjectile.tscn` - projectile scene (Node2D + Sprite2D at 0.5 scale)
- `scripts/main/Game.gd` - wires tower projectile_spawned -> game_board.add_child
- `resources/enemies/*.tres` - normal, fast, armored, flying, swarm, boss_ember_titan, healer, split, split_child, stealth, elemental
- `scripts/ui/BuildMenu.gd` - tower selection UI, filtered by PHASE_1_ELEMENTS const
- `scripts/ui/GameOverScreen.gd` - game over overlay (victory/defeat), wired to GameManager.game_over
- `scenes/ui/GameOverScreen.tscn` - fullscreen overlay with dimmer, centered panel, result label, waves label, play again button
- `scripts/ui/TowerInfoPanel.gd` - tower info panel: stats display, upgrade/sell buttons, self-registers with UIManager
- `scenes/ui/TowerInfoPanel.tscn` - anchored bottom-right, hidden by default, instanced in Game scene under UILayer
- `scripts/autoload/FusionRegistry.gd` - fusion lookup table, can_fuse()/can_fuse_legendary() validation, get_fusion_partners()/get_legendary_partners()
- `resources/towers/fusions/*.tres` - 15 dual-element fusion tower data (tier 2)
- `resources/towers/legendaries/*.tres` - 6 triple-element legendary tower data (tier 3)

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
- Tower sprite fallback: Both Tower.gd `apply_tower_data()` and Game.gd ghost preview strip "_enhanced"/"_superior" suffixes to find base sprite if upgrade-specific sprite doesn't exist. Add dedicated sprites later for visual upgrade progression.
- Upgrade chain: base.tres -> enhanced.tres -> superior.tres via `upgrade_to = ExtResource("2")`. TowerSystem.upgrade_tower() reads upgrade_to, charges cost difference (new - old), swaps tower_data, and calls apply_tower_data(). Game.gd binds `ui_upgrade` input action to TowerSystem.upgrade_tower().
- Upgrade scaling: Enhanced = +40% dmg, +10% range, 1.5x cost. Superior = +100% dmg, +20% range, 2x cost (all over base). Superior also has enhanced specials (e.g., burn 8/4s, slow 40%/3s, aoe 3-cell, freeze 30%/2s, multi 3, chain 4/70%).
- range_cells is int in TowerData: +10%/+20% on small ints (3-5) means some tiers share the same range. Rounded values: base 3->enhanced 3->superior 4; base 4->4->5; base 5->6->6.
- FusionRegistry keys are alphabetically sorted element pairs: "earth+fire", "fire+water", etc. _make_key() handles sorting.
- Fusion eligibility: both towers must be tier 1 with upgrade_to == null (i.e., Superior tier). Different elements required.
- fuse_towers() flow: validate -> charge fusion_cost (result.cost) -> remove tower_b (no refund) -> swap tower_a data in-place -> emit tower_fused signal.
- Fusion .tres files use tier=2, element = first element alphabetically from pair, fusion_elements = both elements.
- All 15 fusion specials now implemented (Task 4 complete). Implementation patterns:
  - "freeze_burn" (Thermal Shock): Tower alternates proj.special_key between "freeze"/"burn" via _attack_parity toggle
  - "freeze_chain"/"wet_chain": Tower sets up chain_count/chain_damage_fraction; Projectile._try_apply_chain_special() applies freeze/WET to chain targets
  - "cone_slow" (Blizzard): dedicated _apply_cone_aoe_hit() with 90-degree cone filter from tower_position
  - "stun_pulse" (Seismic Coil): uses standard AoE + _try_apply_special() STUN handler (per-enemy chance roll)
  - "pushback" (Tsunami Shrine): dedicated _apply_pushback_hit() with per-enemy chance roll + Enemy.push_back()
  - "pull_burn" (Inferno Vortex): dedicated _apply_pull_burn_hit() with Enemy.pull_toward() + burn
  - "lava_pool"/"slow_zone": AoE damage on impact + _spawn_ground_effect() emits signal -> Game.gd adds to scene
  - "slow_aura"/"wide_slow"/"thorn": Tower._tick_aura() passive every 0.5s; projectiles get overridden special_key ("freeze" for slow_aura, "" for others)
- Aura tower AoE exclusion: aoe_radius_cells on aura towers (AURA_KEYS) is for aura range only, NOT projectile AoE. Tower._spawn_projectile() skips AoE setup for AURA_KEYS.
- STUN: like FREEZE (speed=0) but separate type. Yellow tint. Shares movement-impairing slot with SLOW/FREEZE.
- WET: no speed effect. Enemies with WET take 1.5x lightning damage (checked in Enemy.take_damage). Teal tint. Separate replacement slot from movement effects.
- Enemy.push_back(cells): decrements _path_index, teleports to path point. Simple discrete step-back.
- Enemy.pull_toward(pos, px): moves toward pos, snaps to nearest path point. Searches all path points for closest.
- GroundEffect uses custom _draw() for visuals (draw_circle), fades in last 0.5s, ticks every 0.5s.
- Projectile.ground_effect_spawned signal connected in Game._on_projectile_spawned() for scene tree addition.

## New Enemy Types (P2-Task 6)
- Healer: heal_per_second > 0 triggers _heal_nearby(delta) in _process(). Heals allies within 2 cells (128px), NOT self. Green flash (0.15s) on healed allies via _heal_flash_timer.
- Split: split_on_death=true + split_data points to split_child.tres. _die() calls EnemySystem.spawn_split_enemies() which spawns 2 children at parent position, continuing from parent's _path_index. Children added to _active_enemies BEFORE parent removed to prevent premature wave_cleared.
- Stealth: stealth=true in EnemyData. Enemy starts at 0.15 alpha, _is_revealed=false. Untargetable by towers (filtered in Tower._get_in_range_enemies()). Revealed permanently when any tower is within 2 cells. _original_modulate tracks alpha for status visual resets.
- Elemental: immune_element/weak_element assigned randomly in _apply_enemy_data() when enemy_name=="Elemental". Seeded RNG per instance (wave*1000 + instance_id). Immune element -> 0 damage. Weak element -> 2x damage. Checked in _apply_resistance() before physical_resist. Sprite tinted to immune element color.
- EnemyData.gd has immune_element/weak_element fields. _create_scaled_enemy() copies them. Elemental assignment happens in Enemy.gd after scaling.
- ELEMENT_COUNTERS maps immune->weak: fire->water, water->earth, earth->wind, wind->lightning, lightning->fire, ice->fire.
- split.tres uses ext_resource to reference split_child.tres (Option B). load_steps=3 for the extra resource.

## Legendary Fusion System (P2-Task 5)
- 6 triple-element legendaries: Primordial Nexus, Supercell Obelisk, Arctic Maelstrom, Crystalline Monolith, Volcanic Tempest, Tectonic Dynamo
- FusionRegistry._legendary_fusions: keys are 3 sorted elements joined with "+". _make_legendary_key() handles sorting.
- Legendary eligibility: tier-2 tower + tier-1 Superior (upgrade_to==null), third element NOT in tier2's fusion_elements
- fuse_legendary() flow: same pattern as fuse_towers() -- validate, charge cost, remove superior, swap tier2 data in-place
- get_legendary_partners() works bidirectionally: finds partners whether given tower is tier2 or superior
- Tower.gd AURA_KEYS now includes "blizzard_aura" (Arctic Maelstrom pure aura tower, attack_speed=0.0)
- Tower.gd PERIODIC_KEYS: ["geyser", "stun_amplify"] -- periodic AoE abilities on separate timer, tower still fires normal projectiles
- Pure-aura towers (attack_speed==0.0): skip normal projectile attack in _process(), only run aura tick
- PERIODIC_KEYS towers: aoe_radius_cells is for ability range, NOT projectile AoE (excluded like AURA_KEYS)
- Periodic ability projectiles have special_key cleared to "" so they fire plain damage projectiles
- "storm_aoe" (Supercell Obelisk): wave-scaling damage bonus in BOTH Tower._calculate_damage() and Projectile._calculate_damage()
- "earthquake" (Tectonic Dynamo): dedicated Projectile._apply_earthquake_hit() -- AoE dmg + slow + stun chance per enemy
- "burning_ground" (Volcanic Tempest): AoE on impact + spawns GroundEffect with effect_type="burning_ground" (orange color, same tick damage as lava_pool)
- Stunned enemies take 2x damage from ALL sources (Enemy.take_damage checks STUN status) -- synergizes with Crystalline Monolith's stun_amplify
- GroundEffect now supports "burning_ground" as alias for lava_pool damage behavior with distinct orange color
