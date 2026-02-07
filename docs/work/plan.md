# Spirefall Phase 2: Core Systems Implementation Plan

**Goal:** Complete element and tower systems -- all 6 base elements, dual-element fusion (15 towers), triple-element legendaries (6 towers), full enemy roster (10 types), 30-wave Classic mode with scaling, tower upgrade tiers, element synergy bonuses, and essential UI/UX improvements.

**Reference:** GDD Section 13.2 (Weeks 5-8: Core Systems)

---

## Current State Assessment

### What Phase 1 Delivered

**Codebase:** ~1,773 lines of GDScript across 18 scripts, 8 autoload managers, component-based architecture.

**Working towers (6 Tier 1 base towers defined as .tres):**
- Flame Spire (fire, burn 5 dmg/s 3s, 100% proc) -- fully functional
- Tidal Obelisk (water, slow 30% 2s, 100% proc) -- fully functional
- Stone Bastion (earth, AoE 2-cell radius) -- fully functional
- Frost Sentinel (ice, freeze 20% chance 1.5s) -- fully functional
- Thunder Pylon (lightning) -- .tres exists but `special_key` is empty, chain special not implemented
- Gale Tower (wind) -- .tres exists but `special_key` is empty, multi-target special not implemented

**Working enemies (6 defined as .tres):**
- Normal (100 HP, 1.0x speed, 3g) -- fully functional
- Fast (60 HP, 1.8x, 2g) -- fully functional
- Armored (200 HP, 0.6x, 5g, 50% physical resist) -- fully functional
- Flying (80 HP, 1.2x, 4g) -- .tres has `is_flying = true` but flying behavior not implemented (uses ground path)
- Swarm (30 HP, 1.4x, 1g, spawns 3x) -- fully functional
- Boss Ember Titan (5000 HP, 0.5x, 100g) -- .tres exists but fire immunity and fire trail not implemented

**Working systems:**
- Grid (20x15, 64px cells) with A* pathfinding (AStarGrid2D) and dynamic recalculation
- Tower factory (TowerSystem) with create, upgrade (via `upgrade_to` TowerData chain), sell (75% build / 50% combat)
- Economy (starting gold 100, wave income 10+wave*3, no-leak +25%, interest 5%/100g capped 25%)
- Game state machine (BUILD_PHASE -> COMBAT_PHASE -> INCOME_PHASE or BUILD_PHASE -> GAME_OVER)
- HUD (wave/lives/gold/timer/start wave button)
- Build menu (filtered to tier==1 && element in fire/water/earth)
- Elemental damage matrix (6x6 in Tower.gd and Projectile.gd)
- Status effects (BURN, SLOW, FREEZE) with sprite tinting
- Projectile system with single-target and AoE support
- Ghost tower preview with valid/invalid tinting (green/red)
- Game over screen (Victory/Defeat + Play Again)
- 10-wave campaign from wave_config.json with scaling formulas

**Existing data fields ready for Phase 2 (already in code, unused):**
- `TowerData.tier` (supports 1/2/3), `TowerData.fusion_elements: Array[String]`, `TowerData.upgrade_to: TowerData`
- `EnemyData.is_flying`, `.split_on_death`, `.split_data`, `.stealth`, `.heal_per_second`
- `Tower.TargetMode` enum has FIRST, LAST, STRONGEST, WEAKEST, CLOSEST (all implemented in `_find_target()`)
- `UIManager.show_wave_preview()` stub exists (pass-through)
- `UIManager.register_tower_info_panel()` exists but TowerInfoPanel has no script attached
- TowerInfoPanel.tscn exists with labels (Name, Element, Damage, Speed, Range) and Upgrade/Sell buttons but no wired logic

### What Phase 2 Must Deliver

1. Wind and Lightning tower specials (chain + multi-target)
2. Tower upgrade tiers: Enhanced (T1+) and Superior (T1++) for all 6 elements
3. Dual-element fusion system (15 Tier 2 towers)
4. Triple-element legendary fusion system (6 Tier 3 towers)
5. Four new enemy types: Healer, Split, Stealth, Elemental
6. Flying enemy behavior (ignores maze, uses direct spawn-to-exit path)
7. Boss behaviors: Ember Titan fire immunity/trail, Glacial Wyrm freeze/minions, Chaos Elemental cycling
8. 30-wave campaign config with GDD-accurate compositions
9. Element synergy bonuses (3/5/8 tower thresholds)
10. Tower targeting mode UI (player-selectable: First/Last/Strongest/Weakest/Closest)
11. Tower info panel with full stats, upgrade, sell, and fusion UI
12. Build menu expansion (show all 6 base elements)
13. Wave preview panel (show upcoming enemy types before combat)
14. Camera pan/zoom controls (WASD + mouse drag + scroll wheel)
15. Raise max_waves from 10 to 30

---

## Implementation Tasks

### Task 1: Wind and Lightning Tower Specials

**Files:** Modified: `scripts/towers/Tower.gd`, `scripts/projectiles/Projectile.gd`, `resources/towers/gale_tower.tres`, `resources/towers/thunder_pylon.tres`

Implement the two remaining base tower special abilities that have data (.tres) but no behavior code.

**Gale Tower -- "multi" special (hits 2 targets):**
- Add `special_key = "multi"` and `special_value = 2.0` to `gale_tower.tres`
- In `Tower._attack()`, when `special_key == "multi"`: find up to `special_value` targets in range, spawn one projectile per target
- Each projectile deals full damage independently (not split damage)
- Targeting uses the same `_find_target()` logic but collects the top N candidates

**Thunder Pylon -- "chain" special (chains to 3 targets at 60% damage):**
- Add `special_key = "chain"`, `special_value = 3.0`, and a new field or convention for chain damage fraction (60% = 0.6)
- Add `chain_count: int` and `chain_damage_fraction: float` to Projectile.gd
- On Projectile._hit() for single-target with chain: after hitting the primary target, find up to `chain_count` additional enemies within a chain radius (e.g., 2 cells) of the impact point, excluding already-hit enemies
- Each chain bounce deals `damage * chain_damage_fraction` and can apply the same special effects
- Visual: chain projectiles can be instant (line effect) or reuse the same projectile sprite at increased speed

**Implementation details:**
- Tower.gd `_attack()` currently calls `_spawn_projectile(target)` unconditionally -- add a pre-check for multi-target to spawn multiple projectiles
- Projectile.gd `_hit()` needs a chain path: after `_apply_single_hit()`, if `chain_count > 0`, iterate nearby enemies and apply chain damage
- The elemental damage matrix already handles lightning vs any element, so chain hits get correct multipliers per target

**Acceptance:** Gale Tower fires two projectiles per attack cycle at two different enemies. Thunder Pylon's projectile chains to up to 3 additional targets at 60% damage. Both display visible projectile/chain behavior.

---

### Task 2: Tower Upgrade Tiers (Enhanced and Superior)

**Files:** Modified: `scripts/towers/TowerData.gd`, `scripts/autoload/TowerSystem.gd`, `scripts/towers/Tower.gd`; Created: 12 new .tres files in `resources/towers/` (Enhanced and Superior for each of the 6 elements)

Create the Tier 1+ (Enhanced) and Tier 1++ (Superior) upgrade tiers for all 6 base elements per GDD Section 5.5.

**New TowerData fields (if needed):**
- `TowerData` already has `upgrade_to: TowerData` for chaining. Each base tower's .tres will point `upgrade_to` at its Enhanced version, and Enhanced points to Superior.
- Add `upgrade_cost: int` to TowerData (the incremental cost to upgrade, not the total value). Alternatively, `TowerSystem.upgrade_tower()` already computes `upgrade_data.cost - tower.tower_data.cost` as the incremental cost, so the `.cost` field on each .tres can represent the tower's total invested value. Keep this pattern.

**New .tres files (naming convention: `{element}_{tier_suffix}.tres`):**
- Enhanced (T1+): `flame_spire_enhanced.tres`, `tidal_obelisk_enhanced.tres`, `stone_bastion_enhanced.tres`, `frost_sentinel_enhanced.tres`, `thunder_pylon_enhanced.tres`, `gale_tower_enhanced.tres`
- Superior (T1++): `flame_spire_superior.tres`, `tidal_obelisk_superior.tres`, `stone_bastion_superior.tres`, `frost_sentinel_superior.tres`, `thunder_pylon_superior.tres`, `gale_tower_superior.tres`

**Stat scaling per GDD Section 5.5:**
- Enhanced: +40% damage, +10% range over base. Cost = 1.5x base cost.
- Superior: +100% damage, +20% range over base. Cost = 2x base cost. Unlocks/enhances special effect.

**Example -- Flame Spire line:**
| Tier | Cost | Damage | Range | Special |
|------|------|--------|-------|---------|
| Base | 30 | 15 | 4 | Burn 5 dmg/s 3s |
| Enhanced | 45 | 21 | 4 | Burn 5 dmg/s 3s |
| Superior | 60 | 30 | 5 | Burn 8 dmg/s 4s |

**Wire up upgrade chains:**
- Set `upgrade_to` on each base .tres to point at its Enhanced .tres
- Set `upgrade_to` on each Enhanced .tres to point at its Superior .tres
- Superior .tres has `upgrade_to = null` (fusion is handled separately)

**TowerSystem.upgrade_tower() changes:**
- Already works via `tower.tower_data.upgrade_to` chain and computes incremental cost
- Verify it calls `tower.apply_tower_data()` to refresh sprite, range, cooldown
- Add a `tier` field visual update (sprite may change per tier -- use naming convention `{base_name}_enhanced.png`, `{base_name}_superior.png`, or fall back to base sprite if upgrade sprites are not yet created)

**Acceptance:** Each of the 6 base towers can be upgraded twice (Base -> Enhanced -> Superior). Each upgrade costs the correct incremental amount, applies correct stat increases, and updates the tower's visuals/behavior. Superior tier towers have enhanced special effects.

---

### Task 3: Dual-Element Fusion System

**Files:** Modified: `scripts/autoload/TowerSystem.gd`, `scripts/towers/TowerData.gd`, `scripts/ui/BuildMenu.gd`; Created: 15 new .tres files in `resources/towers/fusions/`, New: `scripts/towers/FusionRegistry.gd`

Implement the core fusion mechanic: merging two Superior (T1++) towers of different elements to create a Tier 2 dual-element tower.

**FusionRegistry (new autoload or static class):**
- Create `FusionRegistry.gd` as a singleton/autoload (or a static helper class referenced by TowerSystem)
- Stores a lookup table: `Dictionary` mapping sorted element pairs to TowerData resource paths
  - Key format: sorted alphabetically, e.g., `"earth+fire"` -> `res://resources/towers/fusions/magma_forge.tres`
- `get_fusion_result(element_a: String, element_b: String) -> TowerData` -- returns the fusion TowerData or null if no valid combo
- `can_fuse(tower_a: Node, tower_b: Node) -> bool` -- both must be tier 1, both must have tier suffix "superior" (or `tier == 1` with no further `upgrade_to`), and they must be different elements with a valid fusion entry

**TowerSystem.fuse_towers(tower_a: Node, tower_b: Node) -> Node:**
- Validate via FusionRegistry.can_fuse()
- Fusion cost comes from the resulting TowerData.cost (this is the additional fusion fee, not cumulative)
- Check `EconomyManager.can_afford(fusion_cost)`
- Remove tower_b from grid (free it, refund nothing)
- Replace tower_a in-place: swap its tower_data to the fusion result, call `apply_tower_data()`
- Emit `tower_fused` signal (new signal on TowerSystem)

**Fusion UX flow:**
- Player selects a Superior tower -> TowerInfoPanel shows "Fuse" button if another Superior of a different element is adjacent (or anywhere on the map -- design decision, recommend "anywhere" for simpler UX)
- Player clicks "Fuse" -> enters fusion mode (similar to placement mode) -> clicks a second Superior tower of compatible element -> fusion executes
- Alternatively: TowerInfoPanel shows a dropdown/list of compatible fusion partners currently on the map

**15 Dual-Element Tower .tres files (in `resources/towers/fusions/`):**

| Elements | Tower Name | Cost | Damage | Speed | Range | Special |
|----------|-----------|------|--------|-------|-------|---------|
| Fire+Water | Steam Engine | 120 | 35 | 0.8/s | 5 | AoE burn fog |
| Fire+Earth | Magma Forge | 130 | 40 | 0.6/s | 4 | Lava pool 3s |
| Fire+Wind | Inferno Vortex | 110 | 30 | 1.0/s | 5 | Pull + burn AoE |
| Fire+Lightning | Plasma Cannon | 140 | 80 | 0.3/s | 6 | Single-target burst |
| Fire+Ice | Thermal Shock | 120 | 35 | 0.9/s | 4 | Freeze/burn cycle |
| Water+Earth | Mud Pit | 130 | 25 | 0.7/s | 4 | Slowing terrain |
| Water+Wind | Tsunami Shrine | 120 | 30 | 0.5/s | 5 | Pushback wave |
| Water+Lightning | Storm Beacon | 130 | 35 | 0.8/s | 5 | Chain + wet bonus |
| Water+Ice | Glacier Keep | 120 | 20 | 0.6/s | 5 | Slow aura + encase |
| Earth+Wind | Sandstorm Citadel | 120 | 25 | 0.7/s | 6 | Wide slow aura |
| Earth+Lightning | Seismic Coil | 130 | 35 | 0.6/s | 4 | Periodic stun |
| Earth+Ice | Permafrost Pillar | 130 | 30 | 0.5/s | 3 | Thorn damage |
| Wind+Lightning | Tempest Spire | 110 | 12 | 3.0/s | 5 | Hits 5 targets |
| Wind+Ice | Blizzard Tower | 120 | 28 | 0.7/s | 5 | Cone AoE slow |
| Lightning+Ice | Cryo-Volt Array | 130 | 35 | 0.8/s | 4 | Freeze + 3x chain |

Each .tres sets `tier = 2`, `fusion_elements` to the two elements, `special_key` to its unique key (e.g., "lava_pool", "pushback", "stun_pulse"), and `upgrade_to = null` (legendaries are a separate fusion, not a direct upgrade).

**Acceptance:** Two Superior towers of different elements can be fused into the correct Tier 2 tower. The fusion costs gold, removes the secondary tower, replaces the primary tower in-place. All 15 combinations produce the correct result. Invalid combinations (same element, non-Superior, insufficient gold) are rejected.

---

### Task 4: Dual-Element Tower Special Abilities

**Files:** Modified: `scripts/projectiles/Projectile.gd`, `scripts/towers/Tower.gd`, `scripts/enemies/Enemy.gd`, `scripts/enemies/StatusEffect.gd`; Created: optional helper scripts for complex specials (e.g., `scripts/effects/LavaPool.gd`, `scripts/effects/PushbackWave.gd`)

Implement the unique special abilities for all 15 Tier 2 fusion towers. These are more complex than Tier 1 specials and several require new mechanics.

**New status effect types needed:**
- STUN (speed = 0 like freeze, but distinct for interaction purposes; e.g., stunned enemies take 2x damage from Crystalline Monolith)
- WET (for Storm Beacon chain bonus)
- Possibly PULL (for Inferno Vortex)

**New mechanics to implement:**

*Ground effects (Magma Forge, Mud Pit):*
- Create a `GroundEffect` scene (Area2D + Timer + CollisionShape2D) that persists at a grid position for a duration
- Magma Forge: spawns a lava pool at impact point, deals burn damage to enemies passing through for 3s
- Mud Pit: spawns a slowing zone at impact point, enemies inside move at 50% speed and take +25% damage

*Pushback (Tsunami Shrine):*
- On hit, push affected enemies backward along their path by N path points (e.g., 2 cells worth)
- Implement as `Enemy.push_back(distance_px: float)` that decrements `_path_index` and sets position accordingly
- Cooldown-gated to prevent perma-lock: pushback has internal cooldown per enemy (e.g., 3s immunity after being pushed)

*Pull (Inferno Vortex):*
- Enemies within AoE range are slowly pulled toward the tower center over the effect duration
- Implement as a periodic force applied in Enemy._process() via a "pull" status or direct position manipulation from the tower

*Aura effects (Glacier Keep, Sandstorm Citadel):*
- Passive aura applied every 0.5s to enemies in range (not projectile-based)
- Add `has_aura: bool` and `aura_key: String` to TowerData
- Tower._process() applies aura effects to enemies in range on a separate timer from attacks

*Prioritized implementation:*
- Phase 2a (implement first, simpler): Steam Engine (AoE burn), Plasma Cannon (high single-target), Tempest Spire (multi-5), Thermal Shock (freeze+burn), Cryo-Volt Array (freeze+chain), Blizzard Tower (cone AoE slow)
- Phase 2b (implement second, require new systems): Magma Forge (ground effect), Mud Pit (ground effect), Inferno Vortex (pull), Tsunami Shrine (pushback), Storm Beacon (wet+chain), Glacier Keep (aura), Sandstorm Citadel (aura), Seismic Coil (stun pulse), Permafrost Pillar (thorn/melee range)

**Acceptance:** Each of the 15 Tier 2 towers exhibits its described special ability. Ground effects persist visually and mechanically. Aura towers affect nearby enemies passively. Pushback and pull manipulate enemy positions along the path.

---

### Task 5: Triple-Element Legendary Fusion System and Abilities

**Files:** Modified: `scripts/autoload/TowerSystem.gd`, `scripts/towers/FusionRegistry.gd`; Created: 6 new .tres files in `resources/towers/legendaries/`

Extend the fusion system to support Tier 3 legendary towers: merge a Tier 2 tower with a Superior (T1++) tower of the third element.

**FusionRegistry extension:**
- Add a second lookup for legendary fusions: a Tier 2 tower (which has `fusion_elements = ["fire", "water"]`) combined with a Superior tower of a third element (e.g., "earth") that is not already in the Tier 2's fusion_elements
- `get_legendary_result(tier2_elements: Array[String], third_element: String) -> TowerData`
- `can_fuse_legendary(tower_tier2: Node, tower_superior: Node) -> bool`

**TowerSystem.fuse_legendary(tower_tier2: Node, tower_superior: Node) -> Node:**
- Same pattern as dual fusion: validate, charge cost, remove superior tower, replace tier2 tower in-place

**6 Legendary Tower .tres files (in `resources/towers/legendaries/`):**

| Elements | Tower Name | Cost | Key Ability |
|----------|-----------|------|-------------|
| Fire+Water+Earth | Primordial Nexus | 300 | Geyser every 10s: massive AoE + slow |
| Fire+Wind+Lightning | Supercell Obelisk | 280 | Lightning storm AoE; scales with wave |
| Water+Wind+Ice | Arctic Maelstrom | 300 | Permanent blizzard: 50% slow + freeze chance |
| Earth+Lightning+Ice | Crystalline Monolith | 320 | Stun pulse every 8s; stunned take 2x |
| Fire+Earth+Wind | Volcanic Tempest | 280 | Magma projectiles create burning ground |
| Water+Earth+Lightning | Tectonic Dynamo | 300 | Earthquake: slow + damage + disruption |

Each .tres sets `tier = 3`, `fusion_elements` to all three elements.

**Legendary ability implementation:**
- Most legendary abilities are enhanced versions of Tier 2 mechanics (larger AoE, periodic pulses, persistent auras)
- Supercell Obelisk's wave-scaling: `bonus_damage = base_damage * (1 + 0.05 * GameManager.current_wave)`
- Crystalline Monolith's "stunned take 2x": requires Enemy.gd to check for STUN status in `take_damage()` and apply a 2x multiplier
- Arctic Maelstrom's permanent blizzard: continuous aura that never turns off (no attack projectile, just aura)

**Acceptance:** A Tier 2 tower can be fused with a compatible Superior tower to create the correct Tier 3 legendary. All 6 legendaries have distinct, powerful abilities. The fusion system correctly identifies valid triple-element combinations.

---

### Task 6: New Enemy Types (Healer, Split, Stealth, Elemental)

**Files:** Modified: `scripts/enemies/Enemy.gd`, `scripts/enemies/EnemyData.gd`, `scripts/autoload/EnemySystem.gd`, `scripts/towers/Tower.gd`; Created: 4 new .tres files in `resources/enemies/`

Implement the four missing enemy types from the GDD. EnemyData.gd already has the necessary fields; the behavior code needs to be added to Enemy.gd.

**Healer (healer.tres):**
- Stats: 120 HP, 0.8x speed, 6g, element "nature" or "none"
- `heal_per_second = 10.0` in .tres
- Enemy.gd `_process()`: if `enemy_data.heal_per_second > 0`, find all allies within 2-cell radius (128px) using `EnemySystem.get_active_enemies()` and heal them by `heal_per_second * delta` per frame
- Healer does NOT heal itself
- Visual: green pulse particle or tint on healed allies (brief green flash)
- Strategy consideration: healers should be high-priority targets; targeting mode "Strongest" won't necessarily find them. Consider adding a "Healer" targeting mode in a future task, or rely on player using "Weakest" (healers have moderate HP)

**Split (split.tres):**
- Stats: 150 HP, 1.0x speed, 4g, element "none"
- `split_on_death = true`, `split_data` points to a "split_child" EnemyData resource (half HP, same speed, 1g each)
- Create `resources/enemies/split_child.tres`: 75 HP base (but actual HP will be 50% of parent's current max at time of split), 1.0x speed, 1g
- Enemy.gd `_die()`: if `enemy_data.split_on_death` and `enemy_data.split_data != null`, instead of just emitting killed signal, spawn 2 child enemies at the current position with the current `_path_index`
- EnemySystem needs a `spawn_split_enemy(data: EnemyData, position: Vector2, path_index: int)` method
- Children inherit the parent's path progress so they continue from the split point, not from spawn

**Stealth (stealth.tres):**
- Stats: 50 HP, 1.5x speed, 5g, element "none"
- `stealth = true` in .tres
- Enemy.gd: if `enemy_data.stealth`, set `sprite.modulate.a = 0.15` (nearly invisible) on spawn
- Stealth enemies are untargetable by towers until "revealed"
- Reveal condition: when a stealth enemy enters any tower's attack range, it becomes revealed
  - Toggle `_is_revealed: bool` on Enemy
  - Tower._find_target() skips enemies where `enemy.enemy_data.stealth and not enemy._is_revealed`
  - Each frame in Enemy._process(), check if any tower is within detection range: `TowerSystem.get_active_towers()` distance check
  - Once revealed, set `sprite.modulate.a = 1.0` and `_is_revealed = true` (stays revealed permanently once detected)
- Alternative simpler design: stealth enemies are invisible on the health bar and minimap but towers auto-reveal them when in range. This avoids tower targeting complexity.

**Elemental (elemental.tres):**
- Stats: 180 HP, 0.9x speed, 6g
- Immune to 1 random element, 2x weak to another
- Add `immune_element: String` and `weak_element: String` to EnemyData.gd
- On spawn (in `_create_scaled_enemy` or `_apply_enemy_data`), if enemy is elemental type, randomly assign immune and weak elements (ensure they differ)
- Enemy.gd `_apply_resistance()`: if `element == immune_element`, return 0 damage. If `element == weak_element`, return `amount * 2`
- Visual indicator: tint sprite to the immune element's color, and show a small icon for weakness
- The element assignment should be deterministic per wave (use wave number as seed) so retries produce the same challenge

**Acceptance:** All four enemy types function correctly: healers heal nearby allies, split enemies spawn two children on death that continue along the path, stealth enemies are nearly invisible until a tower reveals them, elemental enemies are immune to one element and take double from another.

---

### Task 7: Flying Enemy Behavior

**Files:** Modified: `scripts/enemies/Enemy.gd`, `scripts/autoload/PathfindingSystem.gd`, `scripts/autoload/EnemySystem.gd`

Implement flying enemies that ignore the maze (tower walls) and fly directly from spawn to exit.

**Path calculation:**
- PathfindingSystem gets a new method: `get_flying_path() -> PackedVector2Array` that returns a straight-line path from spawn to exit (just the two endpoints converted to world coordinates, or a few intermediate points for smoother movement)
- Alternatively, compute the A* path ignoring all TOWER cells (only UNBUILDABLE blocks flight). Add `get_flying_path(from: Vector2i, to: Vector2i) -> PackedVector2Array` that temporarily treats all TOWER cells as walkable.

**Enemy.gd changes:**
- In `_ready()`, after `_apply_enemy_data()`: if `enemy_data.is_flying`, request a flying path instead of the ground path
- EnemySystem._spawn_next_enemy(): set `enemy.path_points` to `PathfindingSystem.get_flying_path()` when the enemy data has `is_flying = true`
- Flying enemies should render above ground enemies: set `z_index = 1` or higher

**Visual:**
- Flying enemies could have a subtle shadow offset or bob up and down using a sine wave on `position.y` (cosmetic only, not affecting path progress calculation)
- Ensure the health bar stays aligned if a bobbing effect is added

**Acceptance:** Flying enemies travel in a straight line (or shortest direct path) from spawn to exit, ignoring tower maze walls. They render above ground enemies. Ground-targeting towers can still hit them (no targeting restriction in Phase 2; anti-air is a Phase 3 consideration).

---

### Task 8: Boss Behaviors

**Files:** Modified: `scripts/enemies/Enemy.gd`, `scripts/enemies/EnemyData.gd`; Created: `resources/enemies/boss_glacial_wyrm.tres`, `resources/enemies/boss_chaos_elemental.tres`; Optional: `scripts/enemies/BossAbility.gd`

Implement the three boss encounters described in GDD Section 7.3.

**Boss shared infrastructure:**
- Add `boss_ability_key: String` to EnemyData.gd (e.g., "fire_trail", "tower_freeze", "element_cycle")
- Add `boss_ability_interval: float` to EnemyData.gd (seconds between ability activations)
- Enemy.gd: if `enemy_data.is_boss and enemy_data.boss_ability_key != ""`, run a boss ability timer in `_process()`

**Wave 10 -- Ember Titan (fire_trail):**
- Update `boss_ember_titan.tres`: add `immune_element = "fire"`, `boss_ability_key = "fire_trail"`, `boss_ability_interval = 0.0` (continuous)
- Fire immunity: handled by Task 6's elemental resistance system (`immune_element` in `_apply_resistance()`)
- Fire trail: every 1s (or continuously), spawn a `GroundEffect` (from Task 4) at the boss's current position that deals burn damage to towers within 1 cell for 3s
- Tower damage: towers don't currently take damage. For Phase 2, simplify to "fire trail damages nearby enemies of the player" -> no, per GDD it damages towers. Add `Tower.take_damage(amount: int)` that reduces a tower's effectiveness or eventually disables it temporarily (e.g., 3s stun on the tower's attack timer). Keep this simple: fire trail applies a 2s attack cooldown pause to towers within 1 cell.

**Wave 20 -- Glacial Wyrm (tower_freeze):**
- Create `boss_glacial_wyrm.tres`: 12000 HP (scaled), 0.4x speed, 250g, ice element, `boss_ability_key = "tower_freeze"`, `boss_ability_interval = 8.0`
- Every 8s, freezes all towers within 3-cell radius for 3s (towers cannot attack)
- Tower.gd: add `_is_disabled: bool` and `disable_for(duration: float)` method; `_process()` skips targeting when disabled
- Spawns 2-3 ice minions (use Swarm-type data with ice element) every 15s
- EnemySystem needs `spawn_boss_minions(data: EnemyData, count: int, position: Vector2, path_index: int)` (similar to split spawn)

**Wave 30 -- Chaos Elemental (element_cycle):**
- Create `boss_chaos_elemental.tres`: 25000 HP (scaled), 0.3x speed, 500g, element "chaos", `boss_ability_key = "element_cycle"`, `boss_ability_interval = 10.0`
- Every 10s, cycles to a new element: becomes immune to that element and weak to its counter
- Enemy.gd: for chaos boss, maintain a `_current_element` state that rotates through all 6 elements
- Visual: sprite tint changes to match current element
- Must defeat before it cycles through all elements twice (soft enrage: gains 10% speed per cycle)

**Acceptance:** Ember Titan leaves a fire trail that disrupts nearby towers and is immune to fire. Glacial Wyrm periodically freezes towers and spawns ice minions. Chaos Elemental cycles through elements every 10s requiring the player to have diverse tower coverage.

---

### Task 9: 30-Wave Campaign Configuration

**Files:** Modified: `resources/waves/wave_config.json`, `scripts/autoload/GameManager.gd`

Expand the wave config from 10 to 30 waves following GDD Section 7.2 composition guidelines.

**GameManager change:**
- Set `max_waves = 30`

**Wave composition design (per GDD Section 7.2):**

*Waves 1-5 (Tutorial):*
- Already defined in current config. Keep waves 1-5 as-is (Normal, Fast, Swarm).

*Waves 6-10 (Early game):*
- Current waves 6-10 already have Armored, Flying, Swarm, and Boss Ember Titan.
- Add Elemental enemies starting wave 8 (per GDD: "appears wave 8+").
- Keep Boss Ember Titan at wave 10.

*Waves 11-15 (Mid game intro):*
- Wave 11: Normal (12), Fast (8), Healer (2) -- introduces Healer
- Wave 12: Armored (8), Split (4), Swarm (6) -- introduces Split
- Wave 13: Fast (10), Elemental (4), Healer (3)
- Wave 14: Normal (8), Flying (6), Stealth (3) -- introduces Stealth
- Wave 15: Mixed heavy + income wave

*Waves 16-20 (Mid game):*
- Increasing counts of all types
- Wave 20: Boss Glacial Wyrm + escort wave

*Waves 21-25 (Late game):*
- All enemy types in heavy compositions
- Multiple healers per wave, stealth squads, elemental variants

*Waves 26-30 (Endgame):*
- Maximum difficulty compositions
- Wave 30: Boss Chaos Elemental + all-type escort wave

**Scaling verification:**
- At wave 30, Normal enemy HP = 100 * (1 + 0.15*30)^2 = 100 * 5.5^2 = 3025 HP
- At wave 30, Normal speed = 1.0 * min(1 + 0.02*30, 2.0) = 1.6x (capped below 2.0)
- At wave 30, Normal gold = 3 * (1 + 0.08*30) = 3 * 3.4 = 10g
- Boss wave 30 HP = 25000 * (1 + 0.15*30)^2 = 25000 * 30.25 = 756,250 HP

**Acceptance:** All 30 waves are defined in wave_config.json with appropriate enemy types and counts. Game progresses through all 30 waves with bosses at waves 10, 20, and 30. Scaling formulas produce challenging but beatable compositions at each stage.

---

### Task 10: Element Synergy Bonuses

**Files:** Created: `scripts/systems/ElementSynergy.gd`; Modified: `scripts/autoload/TowerSystem.gd`, `scripts/towers/Tower.gd`

Implement the element synergy bonus system from GDD Section 6.3.

**Synergy thresholds:**
- 3 towers of same element: +10% damage for all towers of that element
- 5 towers of same element: +20% damage + element-specific aura effect
- 8 towers of same element: +30% damage + enhanced aura (larger radius, stronger)

**ElementSynergy.gd (new autoload or manager):**
- Track tower counts per element: `var _element_counts: Dictionary = {}` (element string -> int)
- On `TowerSystem.tower_created`, `tower_sold`, `tower_upgraded` (element might change on fusion): recalculate counts
- `get_synergy_bonus(element: String) -> float` returns the damage multiplier (1.0, 1.1, 1.2, or 1.3)
- `get_synergy_tier(element: String) -> int` returns 0, 1, 2, or 3

**Tower.gd integration:**
- In `_calculate_damage()`, multiply by `ElementSynergy.get_synergy_bonus(tower_data.element)`
- For Tier 2/3 towers with multiple elements (fusion_elements), use the highest bonus among their elements

**Aura effects (5+ and 8+ thresholds):**
- Fire 5+: nearby fire towers gain +10% attack speed
- Water 5+: water towers slow enemies 10% more
- Earth 5+: earth towers gain +1 cell range
- Wind 5+: wind towers gain +15% attack speed
- Lightning 5+: lightning chain bounces +1 additional target
- Ice 5+: ice freeze chance +10%
- At 8+: double the aura bonus values and increase radius

**Visual feedback:**
- Towers benefiting from synergy get a subtle colored glow/particle matching their element
- HUD or info panel shows current synergy tiers per element

**Acceptance:** Placing 3/5/8 towers of the same element correctly applies damage bonuses and aura effects to all towers of that element. Synergy bonuses update when towers are placed, sold, or fused. UI indicates active synergies.

---

### Task 11: Build Menu Expansion

**Files:** Modified: `scripts/ui/BuildMenu.gd`

Expand the build menu from 3 towers (fire/water/earth only) to all 6 base elements.

**Changes:**
- Remove the `PHASE_1_ELEMENTS` filter constant (or expand it to all 6 elements)
- `_load_available_towers()`: load all .tres where `tier == 1` (base towers only -- fusions are not buildable, they are crafted)
- Sort buttons by a canonical element order: fire, water, earth, wind, lightning, ice
- Group buttons visually by element with colored separators or element icons above each group
- Each button shows: tower name, cost, element icon (colored circle or small sprite)
- Consider adding a tab/filter system if the menu becomes crowded once upgrade tiers are visible

**Visual improvements:**
- Add element-colored borders or backgrounds to buttons (fire=red, water=blue, earth=brown, wind=green, lightning=yellow, ice=cyan)
- Show tower sprite thumbnail on the button if icon texture is available
- Tooltip on hover: show damage, speed, range, special description

**Acceptance:** Build menu displays all 6 base element towers. Buttons are visually grouped by element with clear color coding. Player can select and place any of the 6 base towers.

---

### Task 12: Tower Info Panel

**Files:** Created: `scripts/ui/TowerInfoPanel.gd`; Modified: `scenes/ui/TowerInfoPanel.tscn`, `scripts/autoload/UIManager.gd`

Wire up the existing TowerInfoPanel scene with a script that displays full tower stats, and provides upgrade, sell, fusion, and targeting mode controls.

**TowerInfoPanel.gd (new script):**
- `@onready` references to all labels (NameLabel, ElementLabel, DamageLabel, SpeedLabel, RangeLabel) and buttons (UpgradeButton, SellButton)
- `display_tower(tower: Node)` populates all labels from `tower.tower_data`
- Add new UI elements to the .tscn:
  - SpecialLabel: shows `tower_data.special_description`
  - TierLabel: shows "Tier 1" / "Enhanced" / "Superior" / "Fusion" / "Legendary"
  - UpgradeCostLabel: shows cost of next upgrade (or "Max" if no upgrade_to)
  - SellValueLabel: shows refund amount (75% build phase, 50% combat)
  - FuseButton: visible only when tower is Superior and a valid fusion partner exists
  - TargetModeDropdown (OptionButton): First / Last / Strongest / Weakest / Closest

**Upgrade button wiring:**
- UpgradeButton.pressed -> `TowerSystem.upgrade_tower(selected_tower)`
- Disable if `tower.tower_data.upgrade_to == null` or cannot afford
- After upgrade, refresh panel with new stats

**Sell button wiring:**
- SellButton.pressed -> `TowerSystem.sell_tower(selected_tower)` -> `UIManager.deselect_tower()`

**Fusion button wiring:**
- FuseButton.pressed -> enter fusion selection mode (emit signal to Game.gd)
- Game.gd enters a "fusion target selection" state similar to tower placement
- Player clicks a second tower -> `TowerSystem.fuse_towers()` or `fuse_legendary()`

**Target mode dropdown:**
- Connect OptionButton.item_selected signal
- Set `tower.target_mode` to the corresponding `Tower.TargetMode` enum value
- Initialize dropdown to the tower's current target_mode

**Acceptance:** Selecting a tower shows a panel with full stats, special description, tier, upgrade cost, and sell value. Upgrade and Sell buttons function correctly. Targeting mode can be changed via dropdown. Fusion button appears when applicable and initiates the fusion flow.

---

### Task 13: Wave Preview Panel

**Files:** Created: `scripts/ui/WavePreviewPanel.gd`, `scenes/ui/WavePreviewPanel.tscn`; Modified: `scripts/autoload/UIManager.gd`, `scripts/autoload/GameManager.gd`

Show upcoming enemy types during the build phase so the player can prepare strategically.

**WavePreviewPanel.tscn:**
- Small panel in the top-right or below the HUD
- Shows "Wave N" header
- Lists each enemy type in the upcoming wave with: icon/sprite, name, count, and any notable properties (flying, stealth, healer, etc.)
- For boss waves, show a "BOSS" indicator with the boss name

**WavePreviewPanel.gd:**
- `display_wave(wave_number: int)` -- reads wave_config.json data (already parsed in EnemySystem._wave_config)
- EnemySystem needs a public accessor: `get_wave_config(wave_number: int) -> Dictionary` that returns the wave entry
- For each enemy group, load the .tres to get the enemy name and look up its sprite
- Show enemy element if applicable (for Elemental types, show "Random Element")
- Show boss_wave indicator

**Timing:**
- Show at the start of BUILD_PHASE for the upcoming wave (current_wave, since current_wave was already incremented)
- GameManager.phase_changed signal triggers the preview update
- Hide during COMBAT_PHASE (or show a "Wave in progress..." message)

**Acceptance:** During build phase, a panel displays the upcoming wave's enemy composition including types, counts, and special properties. Boss waves are clearly marked. Panel updates each build phase.

---

### Task 14: Camera Pan and Zoom

**Files:** Modified: `scripts/main/Game.gd`

Implement camera controls per GDD Section 10.2: WASD pan, middle mouse drag, scroll wheel zoom.

**Camera2D setup:**
- The Camera2D already exists at `$Camera2D` in Game.gd
- Set `zoom` limits: min 0.5x (zoomed out to see full map), max 2.0x (zoomed in for detail)
- Set position limits to keep the map in view (0,0 to 1280,960 with padding)

**WASD panning:**
- In `_process()`, check `Input.is_action_pressed()` for ui_left/ui_right/ui_up/ui_down
- Move camera position by `pan_speed * delta` in the pressed direction
- `pan_speed` constant: ~400 px/s at 1x zoom, scale inversely with zoom level
- Clamp camera position to map bounds

**Middle mouse drag:**
- Track middle mouse button state in `_unhandled_input()`
- On middle mouse press: record start position
- On mouse motion while middle is held: offset camera by the motion delta (inverted for natural drag feel)
- On middle mouse release: stop dragging

**Scroll wheel zoom:**
- In `_unhandled_input()`, handle MOUSE_BUTTON_WHEEL_UP / MOUSE_BUTTON_WHEEL_DOWN
- Zoom toward/away from mouse position (not just screen center)
- Zoom step: 0.1x per scroll tick
- Clamp between min and max zoom
- Smooth zoom with a tween (optional, nice-to-have)

**Edge case handling:**
- Don't pan while placing a tower (or do -- design choice; recommend allowing it)
- Ghost tower preview must account for camera offset/zoom in `_update_ghost()`
- Grid position calculations in `_handle_click()` already use `camera.get_global_mouse_position()` which accounts for camera transform

**Acceptance:** Player can pan the camera with WASD keys and middle mouse drag. Scroll wheel zooms in/out centered on the mouse position. Camera is clamped to map bounds. Ghost tower preview and click-to-place work correctly at all zoom levels.

---

### Task 15: Fusion Mode UX in Game.gd

**Files:** Modified: `scripts/main/Game.gd`, `scripts/autoload/UIManager.gd`

Implement the user-facing fusion interaction flow that connects the TowerInfoPanel "Fuse" button to the TowerSystem fusion logic.

**Fusion mode state in Game.gd:**
- Add `_fusion_source: Node = null` (the tower that initiated fusion)
- When TowerInfoPanel emits a "fuse_requested" signal (via UIManager), set `_fusion_source` and enter fusion selection mode
- Show a visual indicator on all valid fusion targets (compatible Superior towers for dual fusion, or compatible towers for legendary fusion): highlight them with a pulsing outline or colored border
- Ghost-like behavior: as mouse hovers over valid targets, show the fusion result name/icon as a tooltip
- Left-click on a valid target: execute `TowerSystem.fuse_towers(_fusion_source, target)` or `fuse_legendary()`
- Right-click or Escape: cancel fusion mode
- After successful fusion: select the newly fused tower and show its info panel

**Validation display:**
- Invalid targets (wrong tier, same element, no valid combo) show no highlight
- If the player clicks an invalid target, show a brief error message (e.g., "Cannot fuse with this tower")
- If the player cannot afford the fusion cost, show "Not enough gold" and tint the cost red in the info panel

**Acceptance:** Player can initiate fusion from the tower info panel, select a compatible tower, and complete the fusion. Visual feedback clearly shows valid targets. Invalid actions show appropriate error messages. The flow works for both Tier 2 (dual) and Tier 3 (legendary) fusions.

---

### Task 16: Ground Effect System

**Files:** Created: `scripts/effects/GroundEffect.gd`, `scenes/effects/GroundEffect.tscn`; Modified: `scripts/main/Game.gd`

Build a reusable ground effect system used by Magma Forge (lava pools), Mud Pit (slowing terrain), boss fire trails, and Volcanic Tempest (burning ground patches).

**GroundEffect.tscn:**
- Area2D root with CircleShape2D collision
- Sprite2D for the visual (lava, mud, ice, etc.)
- Timer for duration (auto-despawn when expired)

**GroundEffect.gd:**
- `@export var effect_type: String = ""` (lava, mud, ice, fire_trail)
- `@export var duration: float = 3.0`
- `@export var damage_per_second: float = 0.0`
- `@export var slow_fraction: float = 0.0`
- `@export var radius_cells: float = 1.0`
- `_on_body_entered(body)` / `_on_body_exited(body)`: track enemies in the area
- `_process(delta)`: apply damage and/or status effects to enemies currently inside
- Auto-queue_free when duration timer expires
- Spawn method: `GroundEffect.create(type, position, duration, params) -> GroundEffect` static factory or just set properties after instantiation

**Integration with Game.gd:**
- Projectile or Tower emits a signal (or directly instantiates via a new signal: `ground_effect_spawned(effect: Node)`)
- Game.gd adds the ground effect to game_board as a child

**Acceptance:** Ground effects can be spawned at arbitrary positions, persist for a specified duration, apply damage/slow to enemies passing through, and despawn automatically. Visual representation is visible on the game board.

---

### Task 17: Tower Disable Mechanic (Boss Interaction)

**Files:** Modified: `scripts/towers/Tower.gd`

Add the ability for bosses to temporarily disable towers (used by Ember Titan fire trail and Glacial Wyrm tower freeze).

**Tower.gd additions:**
- `var _is_disabled: bool = false`
- `var _disable_timer: float = 0.0`
- `func disable_for(duration: float) -> void`: sets `_is_disabled = true`, `_disable_timer = duration`
- In `_process()`: if `_is_disabled`, decrement timer, skip targeting/attacking. When timer expires, restore.
- Visual feedback: disabled tower has a blue-ish frozen tint or grayed-out modulate (e.g., `sprite.modulate = Color(0.5, 0.5, 0.8, 0.7)` for frozen, restored to WHITE when re-enabled)

**Boss ability triggers:**
- Ember Titan fire trail (from Task 8): calls `tower.disable_for(2.0)` on towers within 1 cell of the trail
- Glacial Wyrm tower freeze (from Task 8): calls `tower.disable_for(3.0)` on all towers within 3 cells every 8s
- The boss ability logic in Enemy.gd iterates `TowerSystem.get_active_towers()` and checks distance

**Acceptance:** Towers can be temporarily disabled with visual feedback. During disable, towers do not attack. Timer restores normal function. Boss abilities correctly trigger tower disabling.

---

### Task 18: Refactor Elemental Damage Matrix

**Files:** Created: `scripts/systems/ElementMatrix.gd`; Modified: `scripts/towers/Tower.gd`, `scripts/projectiles/Projectile.gd`, `scripts/enemies/Enemy.gd`

The elemental damage matrix is currently duplicated in Tower.gd and Projectile.gd. Centralize it and extend it to support immunity, weakness, and synergy.

**ElementMatrix.gd (new autoload or static class):**
- Single source of truth for the 6x6 damage multiplier matrix
- `static func get_multiplier(attacker_element: String, target_element: String) -> float`
- `static func get_elements() -> Array[String]` returns canonical element list
- `static func get_counter(element: String) -> String` returns the element that deals 1.5x to the given element
- Supports "none" and "chaos" as target elements (return 1.0 for both)

**Enemy.gd resistance refactor:**
- Move elemental immunity/weakness checks into `_apply_resistance()` using ElementMatrix
- Support `immune_element` (returns 0 damage) and `weak_element` (returns 2x damage) from EnemyData
- Physical resist remains a separate check for earth element

**Remove duplication:**
- Tower.gd `_get_element_multiplier()` -> calls `ElementMatrix.get_multiplier()`
- Projectile.gd `_get_element_multiplier()` -> calls `ElementMatrix.get_multiplier()`

**Acceptance:** Elemental damage matrix exists in one place. All damage calculations (Tower, Projectile, Enemy resistance) reference the same source. Adding new elements or changing multipliers requires editing only one file.

---

## Task Dependency Order

```
Task 18 (element matrix refactor)     -- no dependencies, foundational
Task 1  (wind/lightning specials)      -- no dependencies
Task 2  (upgrade tiers)               -- no dependencies
Task 7  (flying enemies)              -- no dependencies
Task 11 (build menu expansion)        -- no dependencies
Task 14 (camera controls)             -- no dependencies
Task 6  (new enemy types)             -- depends on Task 18 (elemental enemy needs matrix)
Task 9  (30-wave config)              -- depends on Task 6 (needs all enemy types defined)
Task 3  (dual fusion system)          -- depends on Task 2 (needs Superior tier towers)
Task 16 (ground effect system)        -- no dependencies, but needed by Task 4 and Task 8
Task 4  (dual fusion abilities)       -- depends on Task 3 (needs fusion towers), Task 16 (ground effects)
Task 17 (tower disable)               -- no dependencies, but needed by Task 8
Task 8  (boss behaviors)              -- depends on Task 6, Task 16, Task 17
Task 5  (legendary fusion + abilities) -- depends on Task 3 (extends fusion system), Task 4 (builds on special patterns)
Task 10 (element synergy)             -- depends on Task 2 (needs upgrade tiers for tower counts to matter)
Task 12 (tower info panel)            -- depends on Task 2 (upgrade UI), Task 3 (fusion UI), Task 10 (synergy display)
Task 13 (wave preview)                -- depends on Task 9 (needs full wave config)
Task 15 (fusion UX)                   -- depends on Task 3, Task 5, Task 12
```

---

## Recommended Implementation Order

| Order | Task | Effort | Priority | Notes |
|-------|------|--------|----------|-------|
| 1 | Task 18: Refactor element matrix | Small | Critical | Eliminates duplication before adding more systems |
| 2 | Task 1: Wind/Lightning specials | Medium | Critical | Completes all 6 base tower behaviors |
| 3 | Task 11: Build menu expansion | Small | Critical | Unblocks player access to all 6 elements |
| 4 | Task 2: Tower upgrade tiers | Large | Critical | 12 new .tres files + stat scaling |
| 5 | Task 7: Flying enemy behavior | Small | High | Simple pathfinding change, needed for wave variety |
| 6 | Task 6: New enemy types | Large | Critical | 4 types with distinct behaviors |
| 7 | Task 14: Camera pan/zoom | Medium | Medium | Quality-of-life, no blockers |
| 8 | Task 16: Ground effect system | Medium | High | Needed by fusion abilities and bosses |
| 9 | Task 17: Tower disable mechanic | Small | High | Needed by boss behaviors |
| 10 | Task 3: Dual fusion system | Large | Critical | Centerpiece mechanic of Phase 2 |
| 11 | Task 4: Dual fusion abilities | X-Large | Critical | 15 unique specials, most complex task |
| 12 | Task 5: Legendary fusion + abilities | Large | High | 6 towers, extends fusion system |
| 13 | Task 10: Element synergy bonuses | Medium | High | Adds strategic depth |
| 14 | Task 9: 30-wave config | Medium | Critical | Requires all enemies, unlocks full game |
| 15 | Task 8: Boss behaviors | Large | High | 3 unique bosses with complex abilities |
| 16 | Task 12: Tower info panel | Medium | High | Essential UI for upgrades/fusion |
| 17 | Task 13: Wave preview panel | Small | Medium | Nice-to-have strategic info |
| 18 | Task 15: Fusion UX flow | Medium | High | Ties fusion system to player interaction |

**Parallelizable groups:**
- Tasks 18, 1, 11, 14 can all be done independently in parallel
- Tasks 2, 7 can be done in parallel after Task 18
- Tasks 6, 16, 17 can be done in parallel after Task 18
- Tasks 12, 13 can be done in parallel once their dependencies are met

**Estimated total effort:** ~4 weeks (1 developer), ~2 weeks (2 developers with parallel tracks)

---

## Out of Scope for Phase 2

Per GDD, these are deferred to Phase 3+:

- **Draft Mode** (Phase 3) -- element pick/ban system, alternating draft
- **Endless Mode** (Phase 3) -- infinite scaling waves after wave 30
- **Versus Mode** (Phase 3) -- PvP with send mechanics
- **Co-op Mode** (Phase 3) -- shared map with partner
- **Additional maps** (Phase 3) -- only ForestClearing in Phase 2
- **Anti-air targeting restriction** (Phase 3) -- all towers can hit flying in Phase 2
- **Meta progression / XP system** (Phase 3) -- persistent unlocks
- **Save/load system** (Phase 3) -- mid-game saves
- **Audio system** (Phase 3) -- music, SFX, AudioManager wiring
- **Particle effects / VFX polish** (Phase 3) -- placeholder tints/colors suffice for Phase 2
- **Touch input / mobile controls** (Phase 3) -- keyboard/mouse only in Phase 2
- **HTML5 / Android export optimization** (Phase 3)
- **Object pooling for enemies/projectiles** (Phase 3) -- instantiate/queue_free is acceptable for 30-wave scope
- **Localization** (Phase 4)
- **Leaderboards / online features** (Phase 4)
