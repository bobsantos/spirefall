# Boss Balance Analysis (Full)

## Summary
All three bosses are mathematically unkillable. The quadratic HP scaling formula
applied to inflated base HP values produces scaled HP 5-19x beyond what player
DPS can deliver within the boss traversal window.

## Recommended Base HP Changes
- Ember Titan (W10): 5000 -> 800 (scaled: 5,000 HP, ~8x normal)
- Glacial Wyrm (W20): 12000 -> 1300 (scaled: 20,800 HP, ~13x normal)
- Chaos Elemental (W30): 25000 -> 1650 (scaled: 49,913 HP, ~16.5x normal)

## Design Target
A well-built board kills the boss with 10-15% HP remaining (close call).
A poorly-built board fails, losing 1-3 lives.

## Boss-to-Normal HP Ratio Guideline
- W10 boss: 7-9x normal enemy HP
- W20 boss: 11-15x normal enemy HP
- W30 boss: 15-18x normal enemy HP

## Additional Mechanic Issues
1. Ember Titan fire_trail at 1s interval is too aggressive for W10. Recommend 3-4s.
2. Glacial Wyrm tower_freeze duration is undefined. Recommend 1.5-2.0s.
3. Chaos Elemental soft_enrage is undefined. Recommend: after 30s, +50% speed every 10s.
4. Chaos Elemental gold reward (1700g at W30) is meaningless. Consider score/XP.
5. Plasma Cannon (140g, 24 DPS) is a trap choice -- worst DPS/gold of all fusions.

## Key Playtesting Scenarios
1. Fire-heavy player vs Ember Titan (should lose 2-3 lives, not game over)
2. Water counter player vs Ember Titan (should barely kill it)
3. Tower freeze impact during Glacial Wyrm fight (count freeze activations)
4. Ice minion leak risk from Glacial Wyrm (fast minions near exit)
5. Diverse vs mono-element board vs Chaos Elemental (diverse should win by 20-30%)
6. Soft enrage timing on Chaos Elemental (final third of path should feel urgent)
