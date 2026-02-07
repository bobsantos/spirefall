# Spirefall Agent Memory

## Architecture Overview
- 10 autoload managers: GameManager, GridManager, PathfindingSystem, TowerSystem, EnemySystem, EconomyManager, UIManager, AudioManager, FusionRegistry, ElementSynergy
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
- [x] P2-Task 11: Build menu expansion (all 6 base elements, styled buttons)
- [x] P2-Task 2: Tower upgrade tiers (Enhanced/Superior, 12 new .tres)
- [x] P2-Task 7: Flying enemy behavior (ignores maze)
- [x] P2-Task 6: New enemy types (Healer, Split, Stealth, Elemental)
- [x] P2-Task 14: Camera pan/zoom (WASD + mouse drag + scroll)
- [x] P2-Task 16: Ground effect system (lava pools, mud -- bundled into Task 4)
- [x] P2-Task 17: Tower disable mechanic (boss interaction)
- [x] P2-Task 3: Dual fusion system (15 Tier 2 towers + FusionRegistry)
- [x] P2-Task 4: Dual fusion abilities (15 unique specials)
- [x] P2-Task 5: Legendary fusion + abilities (6 Tier 3 towers)
- [x] P2-Task 10: Element synergy bonuses (3/5/8 thresholds)
- [x] P2-Task 9: 30-wave campaign config
- [x] P2-Task 8: Boss behaviors (Ember Titan, Glacial Wyrm, Chaos Elemental)
- [x] P2-Task 12: Tower info panel (full stats, tier, synergy, fuse/target mode, element styling)
- [x] P2-Task 13: Wave preview panel (enemy composition display during build phase)
- [x] P2-Task 15: Fusion UX flow in Game.gd (fuse_requested signal, partner highlighting, fusion click handler)

## File Locations
- `scripts/autoload/EnemySystem.gd` - wave spawning, enemy lifecycle
- `scripts/autoload/GameManager.gd` - game state machine, phase transitions
- `scripts/autoload/EconomyManager.gd` - gold, interest, income
- `scripts/enemies/Enemy.gd` - enemy movement, health, damage, status effects
- `scripts/enemies/EnemyData.gd` - enemy data resource definition
- `scripts/enemies/StatusEffect.gd` - RefCounted status effect (BURN, SLOW, FREEZE, STUN, WET)
- `scripts/effects/GroundEffect.gd` - persistent ground effects (lava_pool, slow_zone)
- `scenes/effects/GroundEffect.tscn` - ground effect scene (Node2D with custom _draw)
- `resources/waves/wave_config.json` - 30-wave campaign config (bosses at 10/20/30, income every 5)
- `scripts/projectiles/Projectile.gd` - projectile movement, hit logic, AoE, specials
- `scenes/projectiles/BaseProjectile.tscn` - projectile scene (Node2D + Sprite2D at 0.5 scale)
- `scripts/main/Game.gd` - wires tower projectile_spawned -> game_board.add_child
- `resources/enemies/*.tres` - normal, fast, armored, flying, swarm, boss_ember_titan, boss_glacial_wyrm, boss_chaos_elemental, ice_minion, healer, split, split_child, stealth, elemental
- `scripts/ui/BuildMenu.gd` - tower selection UI, shows all 6 base elements with styled buttons (element-colored backgrounds, sprite thumbnails, tooltips)
- `scripts/ui/GameOverScreen.gd` - game over overlay (victory/defeat), wired to GameManager.game_over
- `scenes/ui/GameOverScreen.tscn` - fullscreen overlay with dimmer, centered panel, result label, waves label, play again button
- `scripts/ui/TowerInfoPanel.gd` - tower info panel: full stats, tier, synergy, fuse/sell/upgrade buttons, target mode dropdown, element-colored styling, fuse_requested signal
- `scenes/ui/TowerInfoPanel.tscn` - anchored bottom-right (240x420), hidden by default, instanced in Game scene under UILayer. Nodes: NameLabel, TierLabel, ElementLabel, DamageLabel, SpeedLabel, RangeLabel, SpecialLabel, SynergyLabel, UpgradeCostLabel, SellValueLabel, TargetModeDropdown, ButtonRow(Upgrade+Sell), FuseButton
- `scripts/autoload/FusionRegistry.gd` - fusion lookup table, can_fuse()/can_fuse_legendary() validation, get_fusion_partners()/get_legendary_partners()
- `scripts/systems/ElementSynergy.gd` - element synergy autoload: tracks tower counts, provides damage/speed/range/chain/freeze/slow bonuses per element
- `resources/towers/fusions/*.tres` - 15 dual-element fusion tower data (tier 2)
- `resources/towers/legendaries/*.tres` - 6 triple-element legendary tower data (tier 3)
- `scripts/ui/WavePreviewPanel.gd` - wave preview panel: enemy composition, traits, boss banners
- `scenes/ui/WavePreviewPanel.tscn` - anchored top-right (220px wide, below HUD at y=48), hidden by default, mouse_filter=IGNORE

## Gotchas -> see `gotchas.md` for full list
- StatusEffect is RefCounted (not Node). Burn stacks; Slow/Freeze/STUN share movement-impairing slot; WET is separate.
- Tower specials data-driven: TowerData.special_key/value/duration/chance/aoe_radius_cells
- "multi"/"chain" handled structurally (not via _try_apply_special). "multi" = N projectiles from Tower._attack(); "chain" = fractional hits in Projectile._apply_chain_hits()
- Projectile is fire-and-forget: carries all damage/special data, no back-reference to Tower
- Ghost tower preview: bare Sprite2D on game_board, uses camera.get_global_mouse_position(), hidden outside grid bounds
- FusionRegistry keys: alphabetically sorted element pairs. Fusion eligibility = both Superior (upgrade_to==null), different elements.
- Fusion specials (15 dual, 6 legendary): see MEMORY sections below or `gotchas.md`
- Autoloads persist across scene reloads -- must call EconomyManager.reset() before reload_current_scene()

## New Enemy Types (P2-Task 6)
- Healer: heal_per_second > 0 triggers _heal_nearby(delta) in _process(). Heals allies within 2 cells (128px), NOT self. Green flash (0.15s) on healed allies via _heal_flash_timer.
- Split: split_on_death=true + split_data points to split_child.tres. _die() calls EnemySystem.spawn_split_enemies() which spawns 2 children at parent position, continuing from parent's _path_index. Children added to _active_enemies BEFORE parent removed to prevent premature wave_cleared.
- Stealth: stealth=true in EnemyData. Enemy starts at 0.15 alpha, _is_revealed=false. Untargetable by towers (filtered in Tower._get_in_range_enemies()). Revealed permanently when any tower is within 2 cells. _original_modulate tracks alpha for status visual resets.
- Elemental: immune_element/weak_element assigned randomly in _apply_enemy_data() when enemy_name=="Elemental". Seeded RNG per instance (wave*1000 + instance_id). Immune element -> 0 damage. Weak element -> 2x damage. Checked in _apply_resistance() before physical_resist. Sprite tinted to immune element color.
- EnemyData.gd has immune_element/weak_element fields. _create_scaled_enemy() copies them. Elemental assignment happens in Enemy.gd after scaling.
- ELEMENT_COUNTERS maps immune->weak: fire->water, water->earth, earth->wind, wind->lightning, lightning->fire, ice->fire. split.tres uses ext_resource to reference split_child.tres.

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

## Flying Enemy Behavior (P2-Task 7)
- PathfindingSystem.get_flying_path() returns 2-point PackedVector2Array (spawn->exit world coords). Straight line, ignores maze.
- EnemySystem._spawn_next_enemy() checks enemy_data.is_flying to pick flying vs ground path
- Enemy._apply_enemy_data() sets z_index=1 and _is_flying=true for flying enemies (render above ground)
- Bobbing effect: sine wave on sprite.position.y and health_bar.position.y (BOB_AMPLITUDE=6px, BOB_FREQUENCY=2.5Hz)
- Bobbing applies to child nodes only, NOT to Enemy.position -- keeps targeting/collision on the actual path
- HealthBar uses offset_top=-40 in .tscn for baseline positioning; bobbing adds to position.y (separate from offsets)
- Flying path is only 2 points, so _move_along_path() lerps in a straight line from spawn to exit
- push_back/pull_toward still work on flying enemies (they snap to path points, which are just start/end)
- Towers already target flying enemies (no is_flying filter in Tower._get_in_range_enemies()) -- anti-air is Phase 3
- flying.tres: 80 HP, 1.2x speed, 4 gold, element="none", is_flying=true. Used in waves 8 and 9.

## Tower Disable Mechanic (P2-Task 17)
- Tower.gd: `_is_disabled: bool`, `_disable_timer: float`, `disable_for(duration)`, `is_disabled() -> bool`
- When disabled: `_process()` returns early after decrementing timer (skips attacks, auras, periodic abilities)
- Visual: `sprite.modulate = Color(0.5, 0.5, 0.8, 0.7)` (blue-ish frozen tint); restored to synergy color on re-enable (not WHITE)
- `disable_for()` uses `maxf()` to extend if already disabled (doesn't reset shorter)
- Used by: Ember Titan fire_trail (via GroundEffect), Glacial Wyrm tower_freeze (direct), fire_trail tower disable radius = 1 cell (64px)

## Boss Ability System (P2-Task 8)
- EnemyData.gd: `boss_ability_key`, `boss_ability_interval`, `minion_data`, `minion_spawn_interval`, `minion_spawn_count`
- Enemy.gd: `_tick_boss_ability(delta)` called in `_process()` when `is_boss && boss_ability_key != ""`
- Enemy.gd emits `ground_effect_spawned(effect)` signal for fire trail (same pattern as Projectile)
- Game.gd connects `ground_effect_spawned` in `_on_enemy_spawned()` for all enemies (signal only emitted by bosses)
- EnemySystem.spawn_boss_minions(boss, template, count): spawns scaled minions at boss position + path_index
- Boss ability + minion spawn use separate timers (`_boss_ability_timer`, `_minion_spawn_timer`)

- Ember Titan (wave 10): fire_trail every 1s, immune fire, disables towers in 1 cell for 2s
- Glacial Wyrm (wave 20): tower_freeze every 8s (3 cells, 3s), spawns ice minions every 15s
- Chaos Elemental (wave 30): element_cycle every 10s, soft enrage +10% speed/cycle

## Element Synergy System (P2-Task 10)
- ElementSynergyClass autoload at `scripts/systems/ElementSynergy.gd`, registered as `ElementSynergy` in project.godot
- Thresholds: 3 towers = tier 1 (+10% dmg), 5 = tier 2 (+20% dmg + aura), 8 = tier 3 (+30% dmg + enhanced aura)
- Fusion towers (tier 2/3) count EACH element in fusion_elements toward synergy (e.g., fire+water fusion counts as 1 fire + 1 water)
- Element-specific aura bonuses at tier 2/3: fire/wind = attack speed, water = slow bonus, earth = range, lightning = chain bounces, ice = freeze chance
- Tier 3 doubles tier 2 aura values (e.g., fire: +10% -> +20% attack speed)
- Synergy recalculates on tower_created, tower_sold, tower_upgraded, tower_fused signals
- Only emits synergy_changed signal when tiers actually change (avoids unnecessary Tower.apply_tower_data() calls)
- Tower.gd caches synergy bonuses in _synergy_* vars, refreshed in _refresh_synergy_bonuses() called from apply_tower_data()
- Tower._on_synergy_changed() calls apply_tower_data() to re-apply range/speed/visual when tiers change
- Projectile carries synergy_damage_mult, synergy_freeze_chance_bonus, synergy_slow_bonus from Tower at spawn time
- Visual: subtle element-colored tint via Color.WHITE.lerp(element_color, 0.15 * tier) on tower sprite
- Synergy tint replaces disabled-state WHITE restore (re-enables to synergy color, not WHITE)

## Camera Pan/Zoom (P2-Task 14)
- All camera logic in Game.gd: WASD pan (_handle_camera_pan), middle-mouse drag, scroll zoom (_zoom_camera)
- Input actions: ui_pan_up/down/left/right (WASD) defined in project.godot. ui_sell (S) and ui_pan_down (S) share keycode -- acceptable tradeoff
- PAN_SPEED=400 px/s at 1x zoom, scaled inversely (PAN_SPEED / camera.zoom.x)
- Zoom: 0.5x-2.0x, step 0.1, zooms toward mouse position (preserves world point under cursor)
- _clamp_camera() keeps visible area within MAP bounds (0,0 to 1280,960) + 64px margin; centers axis if view > map
- Camera2D in Game.tscn: position=(640,480), position_smoothing_enabled=true, speed=12.0
- Ghost preview + click-to-place use camera.get_global_mouse_position() -- already camera-aware, no changes needed

## UI Panel Details -> see `ui-panels.md`
- Tower Info Panel (P2-Task 12): fuse_requested signal, element-colored styling, upgrade/sell/fuse buttons
- Wave Preview Panel (P2-Task 13): self-contained via phase_changed, shows enemy rows with icons + traits
- Fusion UX Flow (P2-Task 15): partner highlighting, bidirectional legendary fusion click handling
