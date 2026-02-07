# Spirefall Gotchas (detailed)

## Status Effects
- StatusEffect is RefCounted (not Node), stored in Enemy._status_effects typed array
- Burn stacks independently (multiple burns tick); Slow/Freeze replace each other (not additive)
- Slow value is 0-1 fraction (0.3 = 30% slow), not percentage int
- Burn ticks once per second via elapsed accumulator, not every frame
- `apply_status()` is the public API; Projectile._try_apply_special() calls it on impact
- STUN: like FREEZE (speed=0) but separate type. Yellow tint. Shares movement-impairing slot with SLOW/FREEZE.
- WET: no speed effect. Enemies with WET take 1.5x lightning damage. Teal tint. Separate replacement slot.

## Tower Specials
- Tower specials data-driven: TowerData has special_key, special_value, special_duration, special_chance, aoe_radius_cells
- AoE damage applied before status effects in Projectile._apply_aoe_hit()
- Gale Tower ("multi"): Tower._attack() spawns N projectiles via _find_multiple_targets()
- Thunder Pylon ("chain"): Projectile._apply_chain_hits() deals fractional damage. Chain radius = 2 cells (128px).
- "multi" and "chain" skipped in _try_apply_special() (handled structurally)
- Aura tower AoE exclusion: aoe_radius_cells on AURA_KEYS is for aura range only, NOT projectile AoE

## Projectile System
- Projectile.gd has class_name Projectile; Tower.gd casts via `as Projectile`
- Tower emits projectile_spawned signal; Game.gd connects via TowerSystem.tower_created
- Projectile is fire-and-forget: carries all damage/special data, no back-reference
- If target dies mid-flight: single-target despawns; AoE hits at last known position
- Sprite loaded from assets/sprites/projectiles/{element}.png
- Elemental damage matrix duplicated in Projectile.gd for AoE per-enemy recalculation

## Wave/Economy
- wave_config.json has no spawn_interval; EnemySystem defaults 0.5s normal, 1.5s boss
- Wave clear bonus flow: _on_wave_cleared() -> EconomyManager.calculate_wave_bonus() -> add_gold()
- Leak counter reset at COMBAT_PHASE start
- GameOverScreen uses get_tree().reload_current_scene(). Must call EconomyManager.reset() before reload.

## Ghost Tower Preview
- Bare Sprite2D (not full Tower scene) added to game_board
- Uses camera.get_global_mouse_position() -- camera-aware
- Checks GridManager.can_place_tower() + EconomyManager.can_afford()
- Hidden outside grid via GridManager.is_in_bounds(). Right-click/Escape cancels.
- Tower sprite fallback: strips "_enhanced"/"_superior" suffixes for base sprite

## Upgrades
- base.tres -> enhanced.tres -> superior.tres via upgrade_to ExtResource
- Enhanced = +40% dmg, +10% range, 1.5x cost. Superior = +100% dmg, +20% range, 2x cost.
- range_cells is int: +10%/+20% on small ints means some tiers share range

## Fusion
- FusionRegistry keys: alphabetically sorted element pairs ("earth+fire", etc.)
- Fusion eligibility: both Superior (upgrade_to==null), different elements
- fuse_towers() flow: validate -> charge cost -> remove tower_b -> swap tower_a data in-place
- All 15 fusion specials: freeze_burn, freeze_chain, wet_chain, cone_slow, stun_pulse, pushback, pull_burn, lava_pool, slow_zone, slow_aura, wide_slow, thorn, etc.

## Enemies
- Enemy.push_back(cells): decrements _path_index, teleports to path point
- Enemy.pull_toward(pos, px): moves toward pos, snaps to nearest path point
- GroundEffect uses custom _draw() for visuals, fades in last 0.5s, ticks every 0.5s

## Historical Fixes
- (FIXED) GameManager victory: changed > to >= for final wave
- (FIXED) Projectile class_name missing from .godot cache -- delete .godot/ to rebuild
- (FIXED) Tower AttackCooldown one_shot must be true
- (FIXED) Wave income was calculated for wrong wave number
