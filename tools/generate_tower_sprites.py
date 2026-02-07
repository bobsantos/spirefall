#!/usr/bin/env python3
"""
Generate 6 unique tower placeholder sprites (32x32) for Spirefall.
Each tower has a distinct silhouette so players can tell them apart at a glance.
Top-down isometric perspective with transparent backgrounds.
"""

from PIL import Image, ImageDraw
import math
import os

OUTPUT_DIR = "/Users/bobsantos/spirefall/dev/spirefall/assets/sprites/towers"

def darker(hex_color, factor=0.6):
    """Return a darker version of a hex color for outlines/details."""
    r = int(hex_color[1:3], 16)
    g = int(hex_color[3:5], 16)
    b = int(hex_color[5:7], 16)
    return (int(r * factor), int(g * factor), int(b * factor), 255)

def hex_to_rgba(hex_color):
    r = int(hex_color[1:3], 16)
    g = int(hex_color[3:5], 16)
    b = int(hex_color[5:7], 16)
    return (r, g, b, 255)

def lighter(hex_color, factor=0.3):
    """Return a lighter/highlight version of a hex color."""
    r = int(hex_color[1:3], 16)
    g = int(hex_color[3:5], 16)
    b = int(hex_color[5:7], 16)
    r = min(255, int(r + (255 - r) * factor))
    g = min(255, int(g + (255 - g) * factor))
    b = min(255, int(b + (255 - b) * factor))
    return (r, g, b, 255)

TRANSPARENT = (0, 0, 0, 0)


def generate_flame_spire():
    """
    Flame Spire (Fire) - Pointed spire/obelisk.
    Top-down: tall narrow diamond with a pointed flame tip at center,
    tapering base. Looks like a narrow elongated shape with flame-like edges.
    """
    img = Image.new("RGBA", (32, 32), TRANSPARENT)
    draw = ImageDraw.Draw(img)

    color = "#E03030"
    fill = hex_to_rgba(color)
    outline = darker(color, 0.55)
    highlight = lighter(color, 0.35)
    accent = (255, 160, 40, 255)  # orange-yellow flame tip

    # Base platform - small isometric diamond at bottom
    base_cx, base_cy = 16, 22
    base_pts = [
        (base_cx, base_cy - 4),
        (base_cx + 7, base_cy),
        (base_cx, base_cy + 4),
        (base_cx - 7, base_cy),
    ]
    draw.polygon(base_pts, fill=outline)
    # Slightly smaller inner base
    inner_base = [
        (base_cx, base_cy - 3),
        (base_cx + 5, base_cy),
        (base_cx, base_cy + 3),
        (base_cx - 5, base_cy),
    ]
    draw.polygon(inner_base, fill=fill)

    # Spire body - narrow tall triangle pointing up
    spire_pts = [
        (16, 3),      # tip top
        (20, 20),     # bottom right
        (12, 20),     # bottom left
    ]
    draw.polygon(spire_pts, fill=fill)
    # Outline the spire
    draw.line([(16, 3), (20, 20)], fill=outline, width=1)
    draw.line([(16, 3), (12, 20)], fill=outline, width=1)
    draw.line([(12, 20), (20, 20)], fill=outline, width=1)

    # Flame tip - small flame shape at the very top
    flame_pts = [
        (16, 1),     # flame tip
        (18, 5),
        (17, 4),
        (16, 6),
        (15, 4),
        (14, 5),
    ]
    draw.polygon(flame_pts, fill=accent)

    # Highlight stripe on left side of spire
    draw.line([(14, 8), (13, 18)], fill=highlight, width=1)

    # Small window/detail
    draw.rectangle([(15, 12), (17, 14)], fill=outline)
    draw.point((16, 13), fill=accent)

    return img


def generate_tidal_obelisk():
    """
    Tidal Obelisk (Water) - Rounded dome / teardrop.
    Top-down: circular dome with a slight point, like a water droplet viewed from above.
    Concentric rings suggest a dome or water surface.
    """
    img = Image.new("RGBA", (32, 32), TRANSPARENT)
    draw = ImageDraw.Draw(img)

    color = "#3070E0"
    fill = hex_to_rgba(color)
    outline = darker(color, 0.5)
    highlight = lighter(color, 0.4)
    wave_color = (100, 160, 255, 255)  # lighter blue for wave detail

    # Base - isometric oval shadow/platform
    draw.ellipse([(6, 18), (26, 28)], fill=outline)
    draw.ellipse([(7, 19), (25, 27)], fill=darker(color, 0.75))

    # Main dome body - large circle
    cx, cy = 16, 14
    r = 9
    draw.ellipse([(cx - r, cy - r), (cx + r, cy + r)], fill=fill)
    draw.ellipse([(cx - r, cy - r), (cx + r, cy + r)], outline=outline)

    # Inner dome ring (concentric circle for dome effect)
    r2 = 6
    draw.ellipse([(cx - r2, cy - r2), (cx + r2, cy + r2)], outline=wave_color)

    # Highlight arc on upper-left of dome
    r3 = 4
    draw.arc([(cx - r3 - 2, cy - r3 - 2), (cx + r3 - 2, cy + r3 - 2)],
             200, 320, fill=highlight, width=1)

    # Center point - the obelisk tip seen from above
    draw.ellipse([(cx - 2, cy - 2), (cx + 2, cy + 2)], fill=outline)
    draw.point((cx - 1, cy - 1), fill=highlight)

    # Small wave/ripple details around base
    draw.arc([(4, 20), (14, 28)], 180, 360, fill=wave_color, width=1)
    draw.arc([(18, 20), (28, 28)], 180, 360, fill=wave_color, width=1)

    return img


def generate_stone_bastion():
    """
    Stone Bastion (Earth) - Wide square fortress.
    Top-down: a chunky square/rectangular fort with corner turrets.
    Reads as solid, heavy, defensive.
    """
    img = Image.new("RGBA", (32, 32), TRANSPARENT)
    draw = ImageDraw.Draw(img)

    color = "#A07030"
    fill = hex_to_rgba(color)
    outline = darker(color, 0.5)
    highlight = lighter(color, 0.3)
    stone_dark = darker(color, 0.7)

    # Main fortress body - large isometric square (rotated 45deg diamond but chunky)
    # Use a wide squat shape for the "fortress" feel
    body = [(5, 8), (27, 8), (27, 24), (5, 24)]
    draw.rectangle([(5, 8), (27, 24)], fill=fill, outline=outline)

    # Crenellations (battlements) along top edge
    for x in range(5, 28, 4):
        draw.rectangle([(x, 5), (x + 2, 8)], fill=fill, outline=outline)

    # Crenellations along bottom edge
    for x in range(5, 28, 4):
        draw.rectangle([(x, 24), (x + 2, 27)], fill=fill, outline=outline)

    # Crenellations along left edge
    for y in range(8, 25, 4):
        draw.rectangle([(2, y), (5, y + 2)], fill=fill, outline=outline)

    # Crenellations along right edge
    for y in range(8, 25, 4):
        draw.rectangle([(27, y), (30, y + 2)], fill=fill, outline=outline)

    # Corner turrets (slightly raised squares at corners)
    turret_size = 4
    corners = [(3, 4), (25, 4), (3, 22), (25, 22)]
    for cx, cy in corners:
        draw.rectangle([(cx, cy), (cx + turret_size, cy + turret_size)],
                       fill=highlight, outline=outline)

    # Inner courtyard
    draw.rectangle([(11, 12), (21, 20)], fill=stone_dark, outline=outline)

    # Center structure inside courtyard
    draw.rectangle([(14, 14), (18, 18)], fill=highlight, outline=outline)

    return img


def generate_gale_tower():
    """
    Gale Tower (Wind) - Spiral/pinwheel fan shape.
    Top-down: a central hub with 3-4 curved fan blades radiating outward,
    suggesting spinning wind turbine/fan.
    """
    img = Image.new("RGBA", (32, 32), TRANSPARENT)
    draw = ImageDraw.Draw(img)

    color = "#80E080"
    fill = hex_to_rgba(color)
    outline = darker(color, 0.45)
    highlight = lighter(color, 0.35)
    blade_color = hex_to_rgba(color)

    cx, cy = 16, 16

    # Draw 4 fan blades as curved triangular shapes
    # Each blade extends from center outward in a pinwheel pattern

    # Blade 1 - pointing up-right (curved)
    blade1 = [
        (cx, cy),
        (cx + 2, cy - 10),
        (cx + 8, cy - 8),
        (cx + 4, cy - 2),
    ]
    draw.polygon(blade1, fill=blade_color)
    draw.polygon(blade1, outline=outline)

    # Blade 2 - pointing down-right
    blade2 = [
        (cx, cy),
        (cx + 10, cy + 2),
        (cx + 8, cy + 8),
        (cx + 2, cy + 4),
    ]
    draw.polygon(blade2, fill=blade_color)
    draw.polygon(blade2, outline=outline)

    # Blade 3 - pointing down-left
    blade3 = [
        (cx, cy),
        (cx - 2, cy + 10),
        (cx - 8, cy + 8),
        (cx - 4, cy + 2),
    ]
    draw.polygon(blade3, fill=blade_color)
    draw.polygon(blade3, outline=outline)

    # Blade 4 - pointing up-left
    blade4 = [
        (cx, cy),
        (cx - 10, cy - 2),
        (cx - 8, cy - 8),
        (cx - 2, cy - 4),
    ]
    draw.polygon(blade4, fill=blade_color)
    draw.polygon(blade4, outline=outline)

    # Highlight on leading edge of each blade
    draw.line([(cx, cy), (cx + 2, cy - 10)], fill=highlight, width=1)
    draw.line([(cx, cy), (cx + 10, cy + 2)], fill=highlight, width=1)
    draw.line([(cx, cy), (cx - 2, cy + 10)], fill=highlight, width=1)
    draw.line([(cx, cy), (cx - 10, cy - 2)], fill=highlight, width=1)

    # Central hub circle
    hub_r = 4
    draw.ellipse([(cx - hub_r, cy - hub_r), (cx + hub_r, cy + hub_r)],
                 fill=outline)
    draw.ellipse([(cx - hub_r + 1, cy - hub_r + 1), (cx + hub_r - 1, cy + hub_r - 1)],
                 fill=highlight)
    # Center dot
    draw.ellipse([(cx - 1, cy - 1), (cx + 1, cy + 1)], fill=outline)

    return img


def generate_thunder_pylon():
    """
    Thunder Pylon (Lightning) - Angular zigzag / tall pylon with pointed top.
    Top-down: a narrow angular shape like a lightning bolt or a tall thin
    pylon with radiating energy prongs. Star/cross shape with sharp points.
    """
    img = Image.new("RGBA", (32, 32), TRANSPARENT)
    draw = ImageDraw.Draw(img)

    color = "#E0D030"
    fill = hex_to_rgba(color)
    outline = darker(color, 0.5)
    highlight = lighter(color, 0.3)
    spark_color = (255, 255, 200, 255)

    cx, cy = 16, 16

    # Main shape: 4-pointed star / cross with sharp angular points
    # This gives it that "electrical/pylon" silhouette - very different from others

    # Vertical beam (tall, narrow)
    draw.polygon([
        (cx, 1),       # top point
        (cx + 3, cy - 3),
        (cx + 3, cy + 3),
        (cx, 31),      # bottom point
        (cx - 3, cy + 3),
        (cx - 3, cy - 3),
    ], fill=fill)

    # Horizontal beam (wide, narrow)
    draw.polygon([
        (1, cy),       # left point
        (cx - 3, cy - 3),
        (cx + 3, cy - 3),
        (31, cy),      # right point
        (cx + 3, cy + 3),
        (cx - 3, cy + 3),
    ], fill=fill)

    # Outline the star shape
    star_outline = [
        (cx, 1),
        (cx + 3, cy - 3),
        (31, cy),
        (cx + 3, cy + 3),
        (cx, 31),
        (cx - 3, cy + 3),
        (1, cy),
        (cx - 3, cy - 3),
    ]
    draw.polygon(star_outline, outline=outline)

    # Diagonal energy prongs (small zigzag lines)
    # Upper-right prong
    draw.line([(cx + 3, cy - 3), (cx + 7, cy - 7), (cx + 5, cy - 5), (cx + 9, cy - 9)],
              fill=fill, width=1)
    # Lower-left prong
    draw.line([(cx - 3, cy + 3), (cx - 7, cy + 7), (cx - 5, cy + 5), (cx - 9, cy + 9)],
              fill=fill, width=1)
    # Upper-left prong
    draw.line([(cx - 3, cy - 3), (cx - 7, cy - 7), (cx - 5, cy - 5), (cx - 9, cy - 9)],
              fill=fill, width=1)
    # Lower-right prong
    draw.line([(cx + 3, cy + 3), (cx + 7, cy + 7), (cx + 5, cy + 5), (cx + 9, cy + 9)],
              fill=fill, width=1)

    # Center energy core
    draw.ellipse([(cx - 4, cy - 4), (cx + 4, cy + 4)], fill=outline)
    draw.ellipse([(cx - 3, cy - 3), (cx + 3, cy + 3)], fill=spark_color)
    draw.ellipse([(cx - 1, cy - 1), (cx + 1, cy + 1)], fill=fill)

    # Spark highlights at tips
    for px, py in [(cx, 2), (cx, 30), (2, cy), (30, cy)]:
        draw.point((px, py), fill=spark_color)

    return img


def generate_frost_sentinel():
    """
    Frost Sentinel (Ice) - Hexagonal crystal / snowflake.
    Top-down: a hexagonal shape with 6 crystalline spokes radiating out,
    like a stylized snowflake or ice crystal. Very geometric.
    """
    img = Image.new("RGBA", (32, 32), TRANSPARENT)
    draw = ImageDraw.Draw(img)

    color = "#90C0F0"
    fill = hex_to_rgba(color)
    outline = darker(color, 0.5)
    highlight = lighter(color, 0.35)
    crystal_bright = (220, 240, 255, 255)

    cx, cy = 16, 16

    # Central hexagon
    hex_r = 6
    hex_pts = []
    for i in range(6):
        angle = math.radians(60 * i - 30)  # flat-top hexagon
        px = cx + hex_r * math.cos(angle)
        py = cy + hex_r * math.sin(angle)
        hex_pts.append((px, py))
    draw.polygon(hex_pts, fill=fill, outline=outline)

    # Inner hexagon highlight
    hex_r2 = 3
    hex_pts2 = []
    for i in range(6):
        angle = math.radians(60 * i - 30)
        px = cx + hex_r2 * math.cos(angle)
        py = cy + hex_r2 * math.sin(angle)
        hex_pts2.append((px, py))
    draw.polygon(hex_pts2, fill=highlight, outline=outline)

    # 6 crystal spokes radiating from hexagon vertices
    spoke_len = 13
    for i in range(6):
        angle = math.radians(60 * i - 30)
        # Spoke from hex edge to outer tip
        tip_x = cx + spoke_len * math.cos(angle)
        tip_y = cy + spoke_len * math.sin(angle)

        # Draw spoke as a thin diamond/crystal shard
        perp_angle = angle + math.pi / 2
        half_w = 2
        base_x = cx + (hex_r - 1) * math.cos(angle)
        base_y = cy + (hex_r - 1) * math.sin(angle)

        spoke_pts = [
            (tip_x, tip_y),  # tip
            (base_x + half_w * math.cos(perp_angle), base_y + half_w * math.sin(perp_angle)),
            (base_x - half_w * math.cos(perp_angle), base_y - half_w * math.sin(perp_angle)),
        ]
        draw.polygon(spoke_pts, fill=fill, outline=outline)

        # Small branch barbs on each spoke (at the midpoint)
        mid_x = (base_x + tip_x) / 2
        mid_y = (base_y + tip_y) / 2
        barb_len = 3
        for sign in [1, -1]:
            barb_angle = angle + sign * math.pi / 3
            bx = mid_x + barb_len * math.cos(barb_angle)
            by = mid_y + barb_len * math.sin(barb_angle)
            draw.line([(int(mid_x), int(mid_y)), (int(bx), int(by))],
                      fill=fill, width=1)

    # Center jewel
    draw.ellipse([(cx - 2, cy - 2), (cx + 2, cy + 2)], fill=crystal_bright, outline=outline)

    return img


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    towers = {
        "flame_spire": generate_flame_spire,
        "tidal_obelisk": generate_tidal_obelisk,
        "stone_bastion": generate_stone_bastion,
        "gale_tower": generate_gale_tower,
        "thunder_pylon": generate_thunder_pylon,
        "frost_sentinel": generate_frost_sentinel,
    }

    for name, generator in towers.items():
        img = generator()
        path = os.path.join(OUTPUT_DIR, f"{name}.png")
        img.save(path)
        print(f"Generated: {path} ({img.size[0]}x{img.size[1]})")


if __name__ == "__main__":
    main()
