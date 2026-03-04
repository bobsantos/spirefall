#!/usr/bin/env python3
"""Generate 64x64 placeholder tower sprites for Spirefall.

Generates 33 sprites:
- 6 enhanced (base shape + 2px glow border)
- 6 superior (base shape + 4-point star accent, brighter)
- 15 fusion (diamond shape blending both element colors)
- 6 legendary (circle with 3-color gradient ring)

Run from project root: python3 scripts/tools/generate_tower_sprites.py
"""

import math
from pathlib import Path
from PIL import Image, ImageDraw

# Project root is two levels up from this script
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
TOWERS_DIR = PROJECT_ROOT / "assets" / "sprites" / "towers"
FUSIONS_DIR = TOWERS_DIR / "fusions"
LEGENDARIES_DIR = TOWERS_DIR / "legendaries"

# Element colors
ELEMENT_COLORS = {
    "fire": (0xFF, 0x66, 0x33),
    "water": (0x33, 0x99, 0xFF),
    "earth": (0x88, 0xAA, 0x44),
    "wind": (0xAA, 0xDD, 0xFF),
    "lightning": (0xFF, 0xDD, 0x33),
    "ice": (0x99, 0xEE, 0xFF),
}

# Base tower -> element mapping
BASE_TOWERS = {
    "flame_spire": "fire",
    "frost_sentinel": "ice",
    "gale_tower": "wind",
    "stone_bastion": "earth",
    "thunder_pylon": "lightning",
    "tidal_obelisk": "water",
}

# Fusion tower -> [element1, element2]
FUSION_TOWERS = {
    "blizzard_tower": ["ice", "wind"],
    "cryo-volt_array": ["ice", "lightning"],
    "glacier_keep": ["ice", "water"],
    "inferno_vortex": ["fire", "wind"],
    "magma_forge": ["earth", "fire"],
    "mud_pit": ["earth", "water"],
    "permafrost_pillar": ["earth", "ice"],
    "plasma_cannon": ["fire", "lightning"],
    "sandstorm_citadel": ["earth", "wind"],
    "seismic_coil": ["earth", "lightning"],
    "steam_engine": ["fire", "water"],
    "storm_beacon": ["lightning", "water"],
    "tempest_spire": ["lightning", "wind"],
    "thermal_shock": ["fire", "ice"],
    "tsunami_shrine": ["water", "wind"],
}

# Legendary tower -> [element1, element2, element3]
LEGENDARY_TOWERS = {
    "arctic_maelstrom": ["ice", "water", "wind"],
    "crystalline_monolith": ["earth", "ice", "lightning"],
    "primordial_nexus": ["earth", "fire", "water"],
    "supercell_obelisk": ["fire", "lightning", "wind"],
    "tectonic_dynamo": ["earth", "lightning", "water"],
    "volcanic_tempest": ["earth", "fire", "wind"],
}

SIZE = 64


def lighten(color, factor=0.4):
    """Lighten a color by blending toward white."""
    return tuple(min(255, int(c + (255 - c) * factor)) for c in color)


def brighten(color, factor=0.3):
    """Increase saturation/brightness of a color."""
    return tuple(min(255, int(c * (1.0 + factor))) for c in color)


def blend_colors(c1, c2, t=0.5):
    """Linearly blend two colors."""
    return tuple(int(c1[i] * (1 - t) + c2[i] * t) for i in range(3))


def draw_base_shape(draw, color, cx, cy, radius):
    """Draw a filled rounded square (base tower shape)."""
    r = radius
    margin = cx - r
    draw.rounded_rectangle(
        [margin, margin, cx + r, cy + r],
        radius=6,
        fill=color,
        outline=None,
    )


def generate_enhanced(name, element):
    """Enhanced: base shape with 2px glow border in lighter shade."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    color = ELEMENT_COLORS[element]
    glow = lighten(color, 0.5)
    cx, cy = SIZE // 2, SIZE // 2

    # Glow border (larger shape behind)
    r_outer = 22
    draw.rounded_rectangle(
        [cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer],
        radius=8,
        fill=glow,
    )
    # Inner shape
    r_inner = 19
    draw.rounded_rectangle(
        [cx - r_inner, cy - r_inner, cx + r_inner, cy + r_inner],
        radius=6,
        fill=color,
    )

    path = TOWERS_DIR / f"{name}_enhanced.png"
    img.save(path)
    return path


def generate_superior(name, element):
    """Superior: base shape with 4-point star accent, brighter saturation."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    color = brighten(ELEMENT_COLORS[element], 0.4)
    accent = lighten(ELEMENT_COLORS[element], 0.7)
    cx, cy = SIZE // 2, SIZE // 2

    # 4-point star accent behind the main shape
    star_size = 28
    star_points = [
        (cx, cy - star_size),       # top
        (cx + 6, cy - 6),
        (cx + star_size, cy),       # right
        (cx + 6, cy + 6),
        (cx, cy + star_size),       # bottom
        (cx - 6, cy + 6),
        (cx - star_size, cy),       # left
        (cx - 6, cy - 6),
    ]
    draw.polygon(star_points, fill=accent)

    # Inner shape (brighter)
    r = 17
    draw.rounded_rectangle(
        [cx - r, cy - r, cx + r, cy + r],
        radius=6,
        fill=color,
    )

    path = TOWERS_DIR / f"{name}_superior.png"
    img.save(path)
    return path


def generate_ascended(name, element):
    """Ascended: superior shape with golden outer glow ring and brighter colors."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    color = brighten(ELEMENT_COLORS[element], 0.6)
    accent = lighten(ELEMENT_COLORS[element], 0.8)
    gold = (255, 215, 60)
    gold_light = (255, 240, 150)
    cx, cy = SIZE // 2, SIZE // 2

    # Golden outer glow ring
    glow_r = 30
    draw.ellipse(
        [cx - glow_r, cy - glow_r, cx + glow_r, cy + glow_r],
        fill=None,
        outline=gold_light,
        width=2,
    )

    # 4-point star accent (same as superior, slightly larger)
    star_size = 28
    star_points = [
        (cx, cy - star_size),       # top
        (cx + 6, cy - 6),
        (cx + star_size, cy),       # right
        (cx + 6, cy + 6),
        (cx, cy + star_size),       # bottom
        (cx - 6, cy + 6),
        (cx - star_size, cy),       # left
        (cx - 6, cy - 6),
    ]
    draw.polygon(star_points, fill=accent)

    # Inner shape (brighter than superior)
    r = 17
    draw.rounded_rectangle(
        [cx - r, cy - r, cx + r, cy + r],
        radius=6,
        fill=color,
        outline=gold,
        width=2,
    )

    # Golden corner ornaments (small dots at star tips)
    for px, py in [(cx, cy - star_size), (cx + star_size, cy),
                   (cx, cy + star_size), (cx - star_size, cy)]:
        draw.ellipse([px - 3, py - 3, px + 3, py + 3], fill=gold)

    path = TOWERS_DIR / f"{name}_ascended.png"
    img.save(path)
    return path


def generate_fusion(name, elements):
    """Fusion: diamond shape blending both element colors."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    c1 = ELEMENT_COLORS[elements[0]]
    c2 = ELEMENT_COLORS[elements[1]]
    cx, cy = SIZE // 2, SIZE // 2

    # Outer diamond in blended color
    blend = blend_colors(c1, c2, 0.5)
    diamond_size = 26
    outer_points = [
        (cx, cy - diamond_size),
        (cx + diamond_size, cy),
        (cx, cy + diamond_size),
        (cx - diamond_size, cy),
    ]
    draw.polygon(outer_points, fill=blend)

    # Top-left half tinted toward element 1, bottom-right toward element 2
    # Draw two small inner triangles for visual split
    inner = 16
    draw.polygon([
        (cx, cy - inner),
        (cx - inner, cy),
        (cx, cy),
    ], fill=c1)
    draw.polygon([
        (cx, cy + inner),
        (cx + inner, cy),
        (cx, cy),
    ], fill=c2)

    # Center dot
    draw.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(255, 255, 255, 200))

    path = FUSIONS_DIR / f"{name}.png"
    img.save(path)
    return path


def generate_legendary(name, elements):
    """Legendary: circle with 3-color gradient ring."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    c1 = ELEMENT_COLORS[elements[0]]
    c2 = ELEMENT_COLORS[elements[1]]
    c3 = ELEMENT_COLORS[elements[2]]
    cx, cy = SIZE // 2, SIZE // 2

    # Outer ring: draw 3 arc segments in each element color
    # Each arc covers 120 degrees
    ring_r = 26
    ring_w = 6
    bbox = [cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r]
    draw.arc(bbox, start=0, end=120, fill=c1, width=ring_w)
    draw.arc(bbox, start=120, end=240, fill=c2, width=ring_w)
    draw.arc(bbox, start=240, end=360, fill=c3, width=ring_w)

    # Inner filled circle with blended color
    inner_r = 18
    inner_color = blend_colors(blend_colors(c1, c2, 0.5), c3, 0.33)
    draw.ellipse(
        [cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r],
        fill=inner_color,
    )

    # Center bright dot
    draw.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=(255, 255, 255, 230))

    # Small ornamental dots at each ring segment transition
    for angle_deg in [0, 120, 240]:
        angle_rad = math.radians(angle_deg)
        dx = int(ring_r * math.cos(angle_rad))
        dy = int(ring_r * math.sin(angle_rad))
        draw.ellipse([cx + dx - 3, cy + dy - 3, cx + dx + 3, cy + dy + 3],
                      fill=(255, 255, 255, 180))

    path = LEGENDARIES_DIR / f"{name}.png"
    img.save(path)
    return path


def main():
    FUSIONS_DIR.mkdir(parents=True, exist_ok=True)
    LEGENDARIES_DIR.mkdir(parents=True, exist_ok=True)

    generated = []

    # Enhanced (6)
    for name, element in BASE_TOWERS.items():
        p = generate_enhanced(name, element)
        generated.append(p)

    # Superior (6)
    for name, element in BASE_TOWERS.items():
        p = generate_superior(name, element)
        generated.append(p)

    # Ascended (6)
    for name, element in BASE_TOWERS.items():
        p = generate_ascended(name, element)
        generated.append(p)

    # Fusions (15)
    for name, elements in FUSION_TOWERS.items():
        p = generate_fusion(name, elements)
        generated.append(p)

    # Legendaries (6)
    for name, elements in LEGENDARY_TOWERS.items():
        p = generate_legendary(name, elements)
        generated.append(p)

    print(f"Generated {len(generated)} tower sprites:")
    for p in generated:
        print(f"  {p.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
