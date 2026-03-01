#!/usr/bin/env python3
"""Generate distinct 64x64 enemy sprites for Spirefall.

Each enemy type has a unique silhouette identifiable by shape alone.
Sprites use transparency for the background and solid colors for the shapes.
"""

import math
from PIL import Image, ImageDraw

SIZE = 64
OUT_DIR = "assets/sprites/enemies"


def make_image():
    """Create a new 64x64 RGBA image with transparent background."""
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def hex_to_rgba(hex_color, alpha=255):
    """Convert hex color string to RGBA tuple."""
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return (r, g, b, alpha)


# -- Normal: Rounded square, neutral gray (#888888) ---------------------------

def gen_normal():
    img = make_image()
    draw = ImageDraw.Draw(img)
    color = hex_to_rgba("#888888")
    # Rounded rectangle centered in 64x64
    draw.rounded_rectangle([12, 12, 51, 51], radius=8, fill=color)
    return img


# -- Fast: Narrow wedge/arrow pointing right, light green (#66CC44) -----------

def gen_fast():
    img = make_image()
    draw = ImageDraw.Draw(img)
    color = hex_to_rgba("#66CC44")
    # Arrow/wedge pointing right
    points = [
        (8, 16),   # top-left of arrow body
        (40, 16),  # top-right before tip
        (56, 32),  # tip (right center)
        (40, 48),  # bottom-right before tip
        (8, 48),   # bottom-left of arrow body
        (20, 32),  # indentation on left (arrow notch)
    ]
    draw.polygon(points, fill=color)
    return img


# -- Armored: Thick square with inner border, metallic gray/steel blue --------

def gen_armored():
    img = make_image()
    draw = ImageDraw.Draw(img)
    outer = hex_to_rgba("#7788AA")
    inner = hex_to_rgba("#556688")
    # Outer thick square
    draw.rectangle([8, 8, 55, 55], fill=outer)
    # Inner border (darker inset)
    draw.rectangle([14, 14, 49, 49], fill=inner)
    # Inner fill (lighter core)
    core = hex_to_rgba("#8899BB")
    draw.rectangle([18, 18, 45, 45], fill=core)
    return img


# -- Flying: Diamond shape with wing-like extensions, light blue (#88BBFF) ----

def gen_flying():
    img = make_image()
    draw = ImageDraw.Draw(img)
    color = hex_to_rgba("#88BBFF")
    # Central diamond
    diamond = [(32, 8), (52, 32), (32, 56), (12, 32)]
    draw.polygon(diamond, fill=color)
    # Left wing extension
    left_wing = [(12, 32), (2, 24), (8, 32), (2, 40)]
    draw.polygon(left_wing, fill=color)
    # Right wing extension
    right_wing = [(52, 32), (62, 24), (56, 32), (62, 40)]
    draw.polygon(right_wing, fill=color)
    return img


# -- Swarm: Small circle (50% scale of normal), yellow-green (#AACC44) --------

def gen_swarm():
    img = make_image()
    draw = ImageDraw.Draw(img)
    color = hex_to_rgba("#AACC44")
    # Small circle centered in 64x64 (about 20px diameter)
    cx, cy = 32, 32
    r = 10
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    return img


# -- Healer: Circle with a cross/plus overlay, bright green (#44DD44) ---------

def gen_healer():
    img = make_image()
    draw = ImageDraw.Draw(img)
    color = hex_to_rgba("#44DD44")
    cross_color = hex_to_rgba("#FFFFFF")
    # Circle
    draw.ellipse([10, 10, 53, 53], fill=color)
    # White cross/plus
    draw.rectangle([28, 16, 35, 47], fill=cross_color)  # Vertical bar
    draw.rectangle([16, 28, 47, 35], fill=cross_color)  # Horizontal bar
    return img


# -- Split: Figure-8 / two-lobed shape, dark cyan (#44AAAA) ------------------

def gen_split():
    img = make_image()
    draw = ImageDraw.Draw(img)
    color = hex_to_rgba("#44AAAA")
    # Top lobe
    draw.ellipse([16, 6, 47, 34], fill=color)
    # Bottom lobe
    draw.ellipse([16, 30, 47, 58], fill=color)
    return img


# -- Stealth: Ghost/diamond shape, pale purple (#BB88DD). Fully opaque. -------

def gen_stealth():
    img = make_image()
    draw = ImageDraw.Draw(img)
    color = hex_to_rgba("#BB88DD")  # Fully opaque, alpha=255
    # Ghost body (rounded top, wavy bottom)
    # Upper body: ellipse for head
    draw.ellipse([14, 6, 49, 38], fill=color)
    # Lower body: rectangle
    draw.rectangle([14, 22, 49, 48], fill=color)
    # Wavy bottom: three small bumps
    draw.ellipse([14, 42, 26, 56], fill=color)
    draw.ellipse([25, 42, 38, 56], fill=color)
    draw.ellipse([37, 42, 49, 56], fill=color)
    # Eyes (darker spots)
    eye_color = hex_to_rgba("#6644AA")
    draw.ellipse([20, 18, 28, 26], fill=eye_color)
    draw.ellipse([35, 18, 43, 26], fill=eye_color)
    return img


# -- Elemental: Ring/donut shape, white/neutral (#FFFFFF) ---------------------

def gen_elemental():
    img = make_image()
    draw = ImageDraw.Draw(img)
    color = hex_to_rgba("#FFFFFF")
    # Outer circle
    draw.ellipse([8, 8, 55, 55], fill=color)
    # Inner hole (transparent)
    draw.ellipse([20, 20, 43, 43], fill=(0, 0, 0, 0))
    return img


# -- Boss Ember Titan: Large flame shape, red-orange (#FF5522) ----------------

def gen_ember_titan():
    img = make_image()
    draw = ImageDraw.Draw(img)
    color = hex_to_rgba("#FF5522")
    highlight = hex_to_rgba("#FFAA44")
    # Flame silhouette: wider at bottom, pointed tips at top
    flame = [
        (32, 2),   # Top tip
        (22, 12),
        (26, 18),
        (18, 8),   # Left tongue
        (14, 20),
        (10, 16),  # Far left tongue
        (8, 28),
        (6, 40),
        (10, 52),
        (16, 58),
        (24, 60),
        (32, 62),  # Bottom center
        (40, 60),
        (48, 58),
        (54, 52),
        (58, 40),
        (56, 28),
        (54, 16),  # Far right tongue
        (50, 20),
        (46, 8),   # Right tongue
        (38, 18),
        (42, 12),
    ]
    draw.polygon(flame, fill=color)
    # Inner highlight
    inner_flame = [
        (32, 14),
        (24, 26),
        (20, 40),
        (24, 52),
        (32, 54),
        (40, 52),
        (44, 40),
        (40, 26),
    ]
    draw.polygon(inner_flame, fill=highlight)
    return img


# -- Boss Glacial Wyrm: Large serpentine shape, icy blue-white (#AADDFF) ------

def gen_glacial_wyrm():
    img = make_image()
    draw = ImageDraw.Draw(img)
    body_color = hex_to_rgba("#AADDFF")
    accent = hex_to_rgba("#77BBEE")
    # Serpentine S-curve body using overlapping ellipses
    # Head (top-right)
    draw.ellipse([36, 2, 56, 22], fill=body_color)
    # Upper body curve (arcing left)
    draw.ellipse([16, 10, 46, 32], fill=body_color)
    # Middle body (center-left)
    draw.ellipse([10, 22, 40, 44], fill=body_color)
    # Lower body curve (arcing right)
    draw.ellipse([20, 34, 50, 56], fill=body_color)
    # Tail (bottom-right)
    draw.ellipse([38, 46, 58, 62], fill=body_color)
    # Eye
    draw.ellipse([42, 8, 50, 16], fill=accent)
    # Spine ridge accents
    draw.line([(38, 12), (28, 24), (22, 36), (32, 48), (44, 54)], fill=accent, width=2)
    return img


# -- Boss Chaos Elemental: Large star/chaos shape, rainbow gradient -----------

def gen_chaos_elemental():
    img = make_image()
    draw = ImageDraw.Draw(img)
    # Draw a large 8-pointed star with rainbow gradient fill
    cx, cy = 32, 32
    # First draw a filled background star in white, then overlay rainbow sectors
    points_outer = []
    points_inner = []
    num_points = 8
    outer_r = 30
    inner_r = 20
    for i in range(num_points * 2):
        angle = math.pi / num_points * i - math.pi / 2
        r = outer_r if i % 2 == 0 else inner_r
        px = cx + r * math.cos(angle)
        py = cy + r * math.sin(angle)
        points_outer.append((int(px), int(py)))

    # Rainbow colors for the star
    rainbow = [
        "#FF0000", "#FF8800", "#FFFF00", "#00FF00",
        "#0088FF", "#4400FF", "#8800FF", "#FF00FF",
    ]

    # Draw the star outline filled with a base color
    draw.polygon(points_outer, fill=hex_to_rgba("#DDDDFF"))

    # Overlay colored triangular sectors from center
    for i in range(num_points):
        idx = i * 2
        p1 = points_outer[idx]
        p2 = points_outer[(idx + 1) % len(points_outer)]
        p3 = points_outer[(idx + 2) % len(points_outer)]
        color = hex_to_rgba(rainbow[i])
        draw.polygon([(cx, cy), p1, p2], fill=color)
        # Slightly lighter for the inner wedge
        lighter = (min(color[0] + 40, 255), min(color[1] + 40, 255), min(color[2] + 40, 255), 255)
        draw.polygon([(cx, cy), p2, p3], fill=lighter)

    # Center orb
    draw.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=hex_to_rgba("#FFFFFF"))
    return img


# -- Split Child: Smaller version of split, dark cyan -------------------------

def gen_split_child():
    img = make_image()
    draw = ImageDraw.Draw(img)
    color = hex_to_rgba("#44AAAA")
    # Single small lobe (half of split)
    draw.ellipse([20, 18, 43, 46], fill=color)
    return img


# -- Ice Minion: Small icy shard, pale blue -----------------------------------

def gen_ice_minion():
    img = make_image()
    draw = ImageDraw.Draw(img)
    color = hex_to_rgba("#99CCEE")
    accent = hex_to_rgba("#CCDDFF")
    # Small crystalline shard shape
    shard = [
        (32, 12),  # Top point
        (44, 28),  # Right
        (38, 52),  # Bottom right
        (26, 52),  # Bottom left
        (20, 28),  # Left
    ]
    draw.polygon(shard, fill=color)
    # Inner highlight
    inner = [
        (32, 18),
        (38, 28),
        (34, 44),
        (30, 44),
        (26, 28),
    ]
    draw.polygon(inner, fill=accent)
    return img


# -- Generate all sprites -----------------------------------------------------

SPRITES = {
    "normal": gen_normal,
    "fast": gen_fast,
    "armored": gen_armored,
    "flying": gen_flying,
    "swarm": gen_swarm,
    "healer": gen_healer,
    "split": gen_split,
    "stealth": gen_stealth,
    "elemental": gen_elemental,
    "ember_titan": gen_ember_titan,
    "glacial_wyrm": gen_glacial_wyrm,
    "chaos_elemental": gen_chaos_elemental,
    "split_child": gen_split_child,
    "ice_minion": gen_ice_minion,
}


def main():
    import os
    os.makedirs(OUT_DIR, exist_ok=True)

    for name, gen_func in SPRITES.items():
        path = os.path.join(OUT_DIR, f"{name}.png")
        img = gen_func()
        assert img.size == (SIZE, SIZE), f"{name} is {img.size}, expected ({SIZE}, {SIZE})"
        img.save(path)
        print(f"  Generated {path}")

    print(f"\nGenerated {len(SPRITES)} enemy sprites in {OUT_DIR}/")


if __name__ == "__main__":
    main()
