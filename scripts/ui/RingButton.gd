class_name RingButton
extends Control

## A single circular button in the TowerActionRing.
## Draws its icon and cost text programmatically using _draw().

var action_type: String = ""  # "upgrade", "sell", "ascend", "fuse"
var border_color: Color = Color.WHITE
var cost_text: String = ""
var diameter: float = 48.0
var is_disabled: bool = false

const BG_COLOR := Color(0.1, 0.1, 0.12, 0.85)
const BG_COLOR_DISABLED := Color(0.08, 0.08, 0.1, 0.6)
const BORDER_WIDTH: float = 3.0
const ICON_COLOR := Color(0.95, 0.95, 0.95)
const ICON_COLOR_DISABLED := Color(0.5, 0.5, 0.5)
const COST_FONT_SIZE: int = 10
const ICON_LABEL_FONT_SIZE: int = 14


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = diameter / 2.0

	# Background circle
	var bg: Color = BG_COLOR_DISABLED if is_disabled else BG_COLOR
	draw_circle(center, radius, bg)

	# Border circle (drawn as a slightly larger circle behind, or as an arc)
	var border_col: Color = border_color
	if is_disabled:
		border_col = border_color.darkened(0.4)
	# Draw border as ring: outer circle minus inner
	draw_arc(center, radius - BORDER_WIDTH / 2.0, 0.0, TAU, 64, border_col, BORDER_WIDTH, true)

	# Icon
	var icon_col: Color = ICON_COLOR_DISABLED if is_disabled else ICON_COLOR
	var icon_area_center: Vector2 = Vector2(center.x, center.y - 4.0)
	match action_type:
		"upgrade":
			_draw_upgrade_icon(icon_area_center, icon_col)
		"sell":
			_draw_sell_icon(icon_area_center, icon_col)
		"ascend":
			_draw_star_icon(icon_area_center, icon_col)
		"fuse":
			_draw_fuse_icon(icon_area_center, icon_col)

	# Cost text below icon
	if cost_text != "":
		var font: Font = ThemeDB.fallback_font
		var font_size: int = COST_FONT_SIZE
		var text_size: Vector2 = font.get_string_size(cost_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos: Vector2 = Vector2(center.x - text_size.x / 2.0, center.y + radius * 0.5 + 2.0)
		draw_string(font, text_pos, cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, icon_col)


func _draw_upgrade_icon(center: Vector2, color: Color) -> void:
	## Draw an upward-pointing triangle.
	var s: float = diameter * 0.22
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(center.x, center.y - s),        # top
		Vector2(center.x - s * 0.9, center.y + s * 0.6),  # bottom-left
		Vector2(center.x + s * 0.9, center.y + s * 0.6),  # bottom-right
	])
	draw_polygon(points, PackedColorArray([color, color, color]))


func _draw_sell_icon(center: Vector2, color: Color) -> void:
	## Draw "$" as ASCII text.
	var font: Font = ThemeDB.fallback_font
	var font_size: int = ICON_LABEL_FONT_SIZE
	var text: String = "$"
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos: Vector2 = Vector2(center.x - text_size.x / 2.0, center.y + text_size.y * 0.35)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_star_icon(center: Vector2, color: Color) -> void:
	## Draw a 5-pointed star using draw_polygon.
	var outer_r: float = diameter * 0.22
	var inner_r: float = outer_r * 0.45
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(10):
		var angle: float = -PI / 2.0 + i * PI / 5.0
		var r: float = outer_r if i % 2 == 0 else inner_r
		points.append(Vector2(center.x + cos(angle) * r, center.y + sin(angle) * r))
	var colors: PackedColorArray = PackedColorArray()
	for i: int in range(10):
		colors.append(color)
	draw_polygon(points, colors)


func _draw_fuse_icon(center: Vector2, color: Color) -> void:
	## Draw "Fuse" as ASCII text.
	var font: Font = ThemeDB.fallback_font
	var font_size: int = int(ICON_LABEL_FONT_SIZE * 0.75)
	var text: String = "Fuse"
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos: Vector2 = Vector2(center.x - text_size.x / 2.0, center.y + text_size.y * 0.35)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
