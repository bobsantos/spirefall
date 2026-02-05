# Spirefall Phase 1: Prototype Implementation Plan

**Goal:** Playable single-map TD with 3 towers, 3 enemy types, and a 10-wave scenario.

**Reference:** GDD Section 13.1 (pages 18)

---

## Current State Assessment

### Already Working
- Grid system (20x15, 64px cells) with tower placement and path validation
- A* pathfinding with dynamic recalculation (AStarGrid2D)
- Tower factory (TowerSystem) with creation, upgrading, selling
- Grid tile rendering (ForestClearing) with visual updates on grid changes
- Tower and enemy sprite loading from placeholder PNGs
- Economy system (starting gold, wave income, interest, sell refunds)
- Game state machine (BUILD_PHASE, COMBAT_PHASE, INCOME_PHASE, GAME_OVER)
- HUD (wave counter, lives, gold, timer, start wave button)
- Build menu (loads tower .tres files, shows cost, disables when unaffordable)
- Elemental damage matrix in Tower.gd

### Blocking Issues
- EnemySystem._build_wave_queue() ignores wave_config.json; only spawns Normal enemies
- Tower special effects (burn, slow, AoE) exist only as description text, not code
- Armored enemy 50% physical resist is not enforced in damage calculations
- Projectile system exists as a scene but is never used (towers deal instant damage)
- GameManager.max_waves = 30 but Phase 1 only has 10 waves defined

---

## Implementation Tasks

### Task 1: Wire Up Wave Configuration
**Files:** `scripts/autoload/EnemySystem.gd`, `resources/waves/wave_config.json`

Replace the placeholder `_build_wave_queue()` with proper JSON loading:
- Load and parse `wave_config.json` at `_ready()`
- `_build_wave_queue(wave_number)` reads wave entry from config
- For each enemy group in the wave, load the matching .tres from `resources/enemies/`
- Apply GDD scaling formula: HP = Base HP * (1 + 0.15 * wave)^2
- Apply speed scaling: Speed = Base * (1 + 0.02 * wave), capped at 2x
- Apply gold scaling: Gold = Base Gold * (1 + 0.08 * wave)
- Set `_spawn_interval` from wave config's `spawn_interval` field
- Handle boss_wave flag (Boss Ember Titan at wave 10)

**Acceptance:** Waves 1-10 spawn the correct enemy types and counts per wave_config.json.

---

### Task 2: Limit Phase 1 to 10 Waves
**Files:** `scripts/autoload/GameManager.gd`

- Change `max_waves` default from 30 to 10
- Verify victory triggers at wave 10 completion

**Acceptance:** Game ends in victory after surviving wave 10.

---

### Task 3: Implement Status Effect System
**Files:** New: `scripts/enemies/StatusEffect.gd`, Modified: `scripts/enemies/Enemy.gd`

Create a lightweight status effect system on Enemy:
- Add `_status_effects: Array` to Enemy.gd
- Add `apply_status(effect_type, duration, value)` method
- Process active effects in `_process()`:
  - **Burn:** Deals `value` damage per second for `duration` seconds
  - **Slow:** Reduces speed by `value`% for `duration` seconds (stacks replaced, not additive)
  - **Freeze:** Sets speed to 0 for `duration` seconds (20% chance per Frost Sentinel hit)
- Restore speed when slow/freeze expires
- Visual feedback: Modulate sprite color (red tint for burn, blue tint for slow/freeze)

**Acceptance:** Enemies can burn, slow, and freeze with visible feedback.

---

### Task 4: Implement Tower Special Abilities
**Files:** `scripts/towers/Tower.gd`, `scripts/towers/TowerData.gd`

Extend `_attack()` to apply element-specific effects based on tower data:

**Flame Spire (fire):**
- On hit: Apply burn status (5 dmg/s for 3s) to target

**Tidal Obelisk (water):**
- On hit: Apply slow status (30% slow for 2s) to target

**Stone Bastion (earth):**
- On hit: Deal damage to all enemies within 2-cell AoE radius centered on target
- Use `EnemySystem.get_active_enemies()` and distance check

**Implementation approach:**
- Add `special_key: String` field to TowerData (e.g. "burn", "slow", "aoe")
- Parse `special_description` or use element to determine behavior
- Keep it simple: switch on `tower_data.element` in `_attack()` to apply the right effect

**Acceptance:** Each of the 3 towers exhibits its unique special ability during combat.

---

### Task 5: Implement Damage Resistance
**Files:** `scripts/enemies/Enemy.gd`, `scripts/enemies/EnemyData.gd`

- Parse the `special` field on EnemyData for resistance info
- Armored: "50% physical resist" means earth (physical) damage is halved
- Add `take_damage(amount, element)` logic:
  - If enemy has physical resist and element is "earth": damage *= 0.5
  - Elemental multiplier from Tower.gd already handles fire/water/earth RPS
- Keep it simple for Phase 1: only Armored has a resist, hardcode the check

**Acceptance:** Armored enemies take 50% reduced damage from earth/physical attacks.

---

### Task 6: Implement Projectile Visuals
**Files:** `scripts/towers/Tower.gd`, `scripts/projectiles/Projectile.gd`, `scenes/projectiles/BaseProjectile.tscn`

Replace instant damage with visible projectiles:
- Tower._attack() instantiates a Projectile scene instead of calling take_damage directly
- Projectile.gd: Moves toward target at a set speed (e.g. 400 px/s)
- On reaching target (distance < threshold): apply damage + status effect, then queue_free()
- If target dies mid-flight: hit the position anyway (AoE) or just despawn
- Load projectile sprite from `res://assets/sprites/projectiles/{element}.png`
- Projectile emitted via signal so Game.gd adds it to GameBoard

**Acceptance:** Visible projectiles travel from tower to target before damage is applied.

---

### Task 7: Build Menu - Filter to Phase 1 Towers
**Files:** `scripts/ui/BuildMenu.gd`

- Currently loads ALL .tres files from resources/towers/
- Filter to only show tier-1 towers for Fire, Water, and Earth (Phase 1 scope)
- Either filter by `tier == 1 && element in ["fire", "water", "earth"]`
- Or move non-Phase-1 tower .tres files to a subfolder

**Acceptance:** Build menu shows exactly 3 towers: Flame Spire (30g), Tidal Obelisk (30g), Stone Bastion (35g).

---

### Task 8: Wave Clear Bonuses
**Files:** `scripts/autoload/GameManager.gd`, `scripts/autoload/EconomyManager.gd`

Implement missing economy bonuses from GDD Section 8.1:
- **Wave Clear Bonus:** Award `10 + (wave * 3)` gold when a wave is cleared (already in wave income, verify it fires)
- **No-Leak Bonus:** If zero enemies reached exit during the wave, award +25% of wave clear bonus
- Track `_enemies_leaked_this_wave` counter in GameManager, reset on wave start

**Acceptance:** Players receive correct gold at wave start plus no-leak bonus when applicable.

---

### Task 9: Ghost Tower Preview
**Files:** `scripts/main/Game.gd`

Currently `_ghost_tower` is declared but never populated:
- When `_placing_tower` is set, create a semi-transparent Sprite2D following the mouse
- Snap ghost to grid cell center as mouse moves
- Tint green if cell is buildable and won't block path, red otherwise
- Destroy ghost on placement or cancel (Escape)
- Implement in `_process()` or `_unhandled_input()` with mouse motion

**Acceptance:** Players see a preview of where the tower will be placed with valid/invalid coloring.

---

### Task 10: Game Over Screen
**Files:** New: `scenes/ui/GameOverScreen.tscn`, `scripts/ui/GameOverScreen.gd`

Minimal game over handling:
- On GameManager.game_over signal, show overlay with:
  - "Victory!" or "Defeat!" text
  - Waves survived count
  - "Play Again" button (restarts scene)
- Wire into Game.gd or UIManager

**Acceptance:** Game shows result screen on victory (wave 10 cleared) or defeat (lives = 0) with restart option.

---

## Task Dependency Order

```
Task 2 (max_waves)           -- no dependencies, quick fix
Task 1 (wave config)         -- no dependencies, critical path
Task 3 (status effects)      -- no dependencies
Task 5 (damage resistance)   -- no dependencies
Task 4 (tower specials)      -- depends on Task 3 (status effects)
Task 6 (projectiles)         -- depends on Task 4 (tower specials)
Task 7 (build menu filter)   -- no dependencies, quick fix
Task 8 (wave bonuses)        -- no dependencies
Task 9 (ghost preview)       -- no dependencies
Task 10 (game over screen)   -- no dependencies
```

### Recommended Implementation Order

| Order | Task | Effort | Priority |
|-------|------|--------|----------|
| 1 | Task 2: Limit to 10 waves | Small | Critical |
| 2 | Task 1: Wire up wave config | Medium | Critical |
| 3 | Task 7: Filter build menu | Small | Critical |
| 4 | Task 3: Status effect system | Medium | High |
| 5 | Task 5: Damage resistance | Small | High |
| 6 | Task 4: Tower special abilities | Medium | High |
| 7 | Task 8: Wave clear bonuses | Small | Medium |
| 8 | Task 6: Projectile visuals | Medium | Medium |
| 9 | Task 9: Ghost tower preview | Medium | Medium |
| 10 | Task 10: Game over screen | Small | Medium |

---

## Out of Scope for Phase 1
Per GDD, these are deferred to Phase 2+:
- Wind, Lightning, Ice towers (Phase 2)
- Dual-element fusion system (Phase 2)
- Triple-element legendary towers (Phase 2)
- Fast, Flying, Swarm, Healer, Split, Stealth, Elemental enemies beyond Phase 1 set (Phase 2)
- Draft mode (Phase 3)
- Additional maps (Phase 3)
- Element synergy bonuses (Phase 2)
- Meta progression / XP system (Phase 3)
- Save/load system (Phase 3)
- Audio (Phase 3)
- Camera pan/zoom controls (Phase 2)
- Tower info panel functionality (Phase 2)
- Wave preview panel (Phase 2)
