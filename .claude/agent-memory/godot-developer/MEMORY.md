# Spirefall Agent Memory

## Architecture Overview
- **Grid**: 20x15, 64px cells, managed by `GridManager` autoload (`scripts/autoload/GridManager.gd`)
- **CellType enum**: PATH, BUILDABLE, UNBUILDABLE, TOWER, SPAWN, EXIT
- **GridManager signals**: `tower_placed`, `tower_removed`, `grid_updated`
- **Maps** (e.g. `ForestClearing.gd`) own tile visuals as child Sprite2D nodes
- **Towers/Enemies** have `$Sprite2D` child nodes; textures loaded dynamically in setup methods

## Asset Conventions
- Tile sprites: `res://assets/sprites/tiles/{buildable,path,spawn,exit,unbuildable}.png` (64x64)
- Tower sprites: `res://assets/sprites/towers/{snake_case_name}.png` -- name derived from `TowerData.tower_name`
- Enemy sprites: `res://assets/sprites/enemies/{snake_case_name}.png` -- name derived from `EnemyData.enemy_name`
- Name conversion: `"Flame Spire".to_lower().replace(" ", "_")` -> `"flame_spire"`

## Data Resources
- `TowerData` (Resource): tower_name, element, tier, cost, damage, attack_speed, range_cells, etc.
- `EnemyData` (Resource): enemy_name, base_health, speed_multiplier, element, is_flying, is_boss, etc.

## Key Patterns
- Use `load()` (not `preload()`) for dynamically constructed texture paths
- TOWER cells display BUILDABLE tile texture visually (tower node handles its own sprite)
- Maps connect to `GridManager.grid_updated` to refresh tile visuals when grid changes
- `GridManager.grid_to_world()` returns cell center in world coords

## Lessons Learned
- Maps must explicitly create visual Sprite2D nodes for tiles -- GridManager only manages data
- Tower and Enemy scripts must assign textures to their Sprite2D children -- scene files have empty sprites
