# Game Designer Agent Memory

## Key Balance Insights

### ALL THREE BOSSES UNKILLABLE (CRITICAL)
- Full analysis completed. All bosses have base HP values that produce unkillable scaled HP.
- Root cause: quadratic HP scaling on high base HP values. See `boss-balance-analysis.md`.
- Recommended base HP: Ember Titan 800, Glacial Wyrm 1300, Chaos Elemental 1650.

### Boss Scaled HP vs Player DPS Summary
| Boss | Wave | Current Base HP | Scaled HP | Player DPS | Kill % | Fix Base HP | Fix Scaled HP |
|------|------|----------------|-----------|------------|--------|-------------|---------------|
| Ember Titan | 10 | 5000 | 31,250 | 89-136 | 12-19% | 800 | 5,000 |
| Glacial Wyrm | 20 | 12000 | 192,000 | 350-500 | 8-12% | 1300 | 20,800 |
| Chaos Elemental | 30 | 25000 | 756,250 | 700-1100 | 5-8% | 1650 | 49,913 |

### Scaling Formula Notes
- HP: `base_health * (1 + 0.15 * wave)^2`. W10=6.25x, W20=16x, W30=30.25x.
- Gold: `1 + 0.08 * wave`. Speed: `min(1 + 0.02 * wave, 2.0)`.

### T1 Tower DPS Reference (single target, neutral element)
- Flame Spire: 20 DPS (15+5burn) | 30g | Tidal Obelisk: 9.6 DPS+slow | 30g
- Gale Tower: 16 DPS (multi-2) | 25g | Thunder Pylon: 12.6 DPS+chain | 30g
- Stone Bastion: 12 DPS (AoE) | 35g | Frost Sentinel: 7 DPS+freeze | 35g

### T2 Fusion DPS Reference (top performers)
- Thermal Shock: 36.5 DPS | 120g | Inferno Vortex: 36 DPS | 110g
- Tempest Spire: 36 DPS (x5 tgt) | 110g | Steam Engine: 34 DPS | 120g
- Storm Beacon: 28 DPS+chain | 130g | Cryo-Volt: 28 DPS+freeze | 130g
- Plasma Cannon: 24 DPS (single) | 140g -- surprisingly low DPS/gold

### Economy Baseline
- Starting gold: 100g. Wave clear bonus: `int((10 + wave*3) * 1.25)` (no-leak).
- Approx gold by wave: W10 ~850-1000g, W20 ~2800-3500g, W30 ~6500-8500g.
- Interest: 5% per 100g banked, cap 25%. Applied at waves 5, 10, 15, 20, 25, 30.

### Boss-Specific Mechanic Notes
- Ember Titan: fire trail (1s interval -- too aggressive, recommend 3-4s), fire immune
- Glacial Wyrm: tower freeze (8s interval), spawns 2 ice minions every 15s (960 HP each at W20), ice immune
- Chaos Elemental: element cycle (10s), soft enrage (undefined -- needs implementation), no immunity
- Chaos Elemental W30 gold reward (1700g) is pointless on final wave -- consider score/XP instead

### Endless Mode Design (Task J1)
- CRITICAL: Do NOT apply a second HP multiplier on top of _create_scaled_enemy. The existing quadratic formula already handles all scaling. Just pass the actual wave number.
- HP scaling goes quadratic: W50=72.25x, W80=169x, W100=256x. Recommend hybrid formula past W50 to avoid HP wall.
- Speed cap hits 2.0x at W50 -- difficulty needs a 3rd axis past W50 (e.g. new enemy trait).
- base_count should be 20 individual enemies; cap count growth at 80 past wave 60.
- heal_per_second (10 HP/s) is intentionally NOT scaled in _create_scaled_enemy -- document this, do not "fix" it.
- Boss cycling: every 10th wave past 30. Add +50% HP per full cycle (3 bosses = 30 waves) on top of wave scaling.
- Enemy weight shift algorithm: use lerp across 9 types from early-profile to late-profile over waves 31-80. See full algorithm in response.
- Gold scales linearly vs HP quadratic -- ensure sell value is 75-80% in endless to prevent economy lock.

## Key File Paths
- Wave config: `resources/waves/wave_config.json`
- Enemy scaling: `scripts/autoload/EnemySystem.gd` (_create_scaled_enemy, line 261)
- Economy: `scripts/autoload/EconomyManager.gd`
- Element matrix: `scripts/systems/ElementMatrix.gd`
- Tower data: `scripts/towers/TowerData.gd` | Enemy data: `scripts/enemies/EnemyData.gd`
- Boss resources: `resources/enemies/boss_ember_titan.tres`, `boss_glacial_wyrm.tres`, `boss_chaos_elemental.tres`
- Ice minion: `resources/enemies/ice_minion.tres`
- All 18 base towers: `resources/towers/` | All 15 fusions: `resources/towers/fusions/`
