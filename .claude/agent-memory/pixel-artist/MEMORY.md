# Pixel Artist Agent Memory

## Tower Sprite Conventions (T1 Base Towers)
- All tower sprites: 32x32 px, RGBA PNG, transparent background
- Generated programmatically via `/tools/generate_tower_sprites.py` using Pillow
- Each tower has: primary fill color, darker outline (60% brightness), lighter highlight (30% blend to white)
- Godot auto-generates `.import` files alongside each PNG -- do not delete those

## Element Color Palette (Established)
| Tower            | Element   | Primary Hex | Outline Factor | Shape Archetype      |
|------------------|-----------|-------------|----------------|----------------------|
| Flame Spire      | Fire      | #E03030     | 0.55           | Narrow pointed spire |
| Tidal Obelisk    | Water     | #3070E0     | 0.50           | Round dome + rings   |
| Stone Bastion    | Earth     | #A07030     | 0.50           | Square fortress      |
| Gale Tower       | Wind      | #80E080     | 0.45           | 4-blade pinwheel     |
| Thunder Pylon    | Lightning | #E0D030     | 0.50           | 4-point star cross   |
| Frost Sentinel   | Ice       | #90C0F0     | 0.50           | 6-point snowflake    |

## Silhouette Differentiation Strategy
- Fire: VERTICAL (tall, narrow) -- tallest and thinnest
- Water: CIRCULAR (dome, rounded) -- the only round shape
- Earth: SQUARE (fortress, blocky) -- widest and chunkiest
- Wind: ROTATIONAL (pinwheel blades) -- implies movement/spin
- Lightning: RADIAL STAR (cross, 4-point) -- sharp angular star
- Ice: HEXAGONAL (snowflake, 6-point) -- most complex/geometric

## Helper Functions (in generate_tower_sprites.py)
- `darker(hex, factor)` -- returns RGBA tuple, multiply RGB by factor
- `lighter(hex, factor)` -- returns RGBA tuple, blend toward white
- `hex_to_rgba(hex)` -- simple hex string to RGBA tuple

## Key Lessons
- PIL polygon outline renders at 1px -- good for 32x32 detail work
- At 32x32, keep shapes to 3-5 major geometric elements max for readability
- Concentric detail (rings, inner shapes) adds depth without cluttering silhouette
- Use math module for regular polygon generation (hexagons, star points)
