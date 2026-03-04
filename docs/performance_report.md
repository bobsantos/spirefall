# Spirefall Performance Report

## Overview

Performance benchmarks validated via automated GdUnit4 tests in `tests/unit/systems/test_performance.gd`. All measurements taken on the game's 20x15 grid (64px cells, 1280x960 playfield).

## Pathfinding Performance

| Benchmark | Target | Method |
|---|---|---|
| Recalculate (clear grid) | < 16ms | AStarGrid2D.update() on 20x15 grid |
| Recalculate (maze) | < 16ms | 8 zigzag tower columns, worst-case winding |
| Recalculate + path query | < 16ms | Full recalc + get_world_path spawn-to-exit |
| 10x recalc (spike check) | < 32ms per call | Toggling cells between recalcs |
| 20x path queries | < 16ms total | Cached AStar, no recalc needed |
| 10x is_path_valid | < 32ms per call | Includes recalculate() inside |

**Architecture notes:**
- AStarGrid2D operates on integer grid coordinates (not world pixels), keeping the search space at 300 cells
- `recalculate()` iterates all 300 cells to sync solid state, then calls `_astar.update()`
- Diagonal mode is NEVER (cardinal-only), reducing branching factor from 8 to 4
- Path results are cached by AStarGrid2D internally; only `recalculate()` invalidates

## Enemy System Performance

| Benchmark | Target | Method |
|---|---|---|
| 50 EnemyData creation | < 16ms | `_create_scaled_enemy()` with HP/speed/gold formulas |
| 100 EnemyData creation | < 32ms | Same formula at wave 50 scaling |
| 1000 scaling calculations | < 16ms | Pure math: `(1 + 0.15*wave)^2` etc. |
| 50 enemy array add/remove | < 1ms | `_active_enemies.append()` / `.erase()` |
| Endless wave queue (wave 50) | < 32ms | Weighted pool selection + template loading |
| 100 weighted pool builds | < 16ms | Tier-based weight calculation |

**Architecture notes:**
- Enemy data is Resources (lightweight), not scene instances -- creation is pure allocation + math
- EnemyData scaling uses simple power/linear formulas with no allocations beyond the new Resource
- `_active_enemies` is a flat Array -- O(n) erase, acceptable for expected max ~50-100 enemies
- Weighted pool is rebuilt per wave (not cached), but construction is trivial

## Economy Performance

| Benchmark | Target | Method |
|---|---|---|
| 1000 interest calculations | < 1ms | `calculate_interest()` tiered formula |
| 1000 wave bonus calculations | < 1ms | `calculate_wave_bonus()` linear formula |

## Grid Operations

| Benchmark | Target | Method |
|---|---|---|
| Full grid fill + clear | < 16ms | 300 cells toggled BUILDABLE <-> TOWER |
| 3000 cell accesses | < 16ms | `get_cell()` with bounds check |
| 300 coordinate conversions | < 16ms | `grid_to_world()` + `world_to_grid()` round-trip |

## Memory Budget

| Component | Estimated Size | Budget |
|---|---|---|
| 50 EnemyData Resources | ~25 KB | Part of 200MB web budget |
| 20 TowerData Resources | ~10 KB | Part of 200MB web budget |
| AStarGrid2D (20x15) | ~12 KB | Fixed allocation |
| Grid array (20x15 ints) | ~1.2 KB | Fixed allocation |
| Active enemy nodes (50) | ~100 KB | Node2D + children |
| Active tower nodes (20) | ~80 KB | Area2D + children |
| **Estimated total (gameplay)** | **~230 KB** | **Well within 200MB web** |

**Notes:**
- Textures and audio are the primary memory consumers, not gameplay data
- Object pooling for projectiles prevents allocation spikes during combat
- EnemyData Resources are created per-spawn (not pooled) but are lightweight (~500 bytes each)

## Cleanup Validation

- All created enemy/tower nodes are properly freed with `free()` (not `queue_free()` for test nodes)
- `_active_enemies` and `_active_towers` arrays are cleared on cleanup
- `is_instance_valid()` confirms no dangling references after cleanup
- GdUnit4 orphan detection validates no leaked nodes

## Platform-Specific Notes

### HTML5 (WebAssembly)
- `gl_compatibility` renderer avoids WebGL2 shader compilation stalls
- Thread support disabled for broader browser compatibility
- Canvas resize policy = adaptive (2) for responsive scaling
- ETC2/ASTC VRAM compression enabled for smaller download

### Android
- arm64-v8a only (drops armeabi-v7a for performance)
- Min SDK 24 (Android 7.0) -- covers 97%+ of active devices
- Target SDK 34 for Play Store compliance
- Landscape orientation enforced
- Immersive mode enabled (hides system bars)

## Recommendations

1. **Pathfinding is well within budget** -- AStarGrid2D on a 300-cell grid is extremely fast. No optimization needed.
2. **Enemy spawning is CPU-cheap** -- The bottleneck is scene instantiation (not tested here), not data creation.
3. **Array operations are negligible** -- Even with 100 enemies, flat array operations are sub-millisecond.
4. **Future concern: Draw calls** -- With 50 enemies + 20 towers + projectiles, sprite batching becomes important. Monitor draw call count in Godot profiler during real gameplay.
5. **Future concern: Projectile pooling** -- Object pool for projectiles should be validated under 20-tower simultaneous fire.
