class_name RangeIndicator
extends Node2D

## Draws a ring outline showing a tower's attack range.
## Used during tower placement (ghost preview) and when a tower is selected.
## Ring is drawn with draw_arc() at 20% alpha in the tower's element color.

# Element colors matching TowerInfoPanel and BuildMenu for visual consistency
const ELEMENT_COLORS: Dictionary = {
	"fire": Color(0.9, 0.25, 0.15),
	"water": Color(0.2, 0.5, 0.95),
	"earth": Color(0.6, 0.4, 0.2),
	"wind": Color(0.3, 0.8, 0.35),
	"lightning": Color(0.95, 0.85, 0.15),
	"ice": Color(0.3, 0.85, 0.9),
}

const RING_WIDTH: float = 2.0
const RING_ALPHA: float = 0.2
const ARC_POINT_COUNT: int = 64
const ARC_START_ANGLE: float = 0.0
const ARC_END_ANGLE: float = TAU

# Selection highlight pulse
const HIGHLIGHT_RADIUS: float = 28.0  # Inner highlight ring around tower sprite
const HIGHLIGHT_PULSE_SPEED: float = 3.0  # Cycles per second
const HIGHLIGHT_MIN_ALPHA: float = 0.3
const HIGHLIGHT_MAX_ALPHA: float = 0.8

var _radius: float = 0.0
var _color: Color = Color.TRANSPARENT
var _highlight_color: Color = Color.TRANSPARENT
var _show_highlight: bool = false
var _pulse_time: float = 0.0


func _ready() -> void:
	visible = false
	z_index = 50


func show_range(pos: Vector2, radius: float, color: Color) -> void:
	position = pos
	_radius = radius
	_color = Color(color.r, color.g, color.b, RING_ALPHA)
	visible = true
	queue_redraw()


func show_range_for_tower(pos: Vector2, tower_data: TowerData) -> void:
	## Convenience method that calculates radius and color from tower data.
	var radius: float = tower_data.range_cells * GridManager.CELL_SIZE
	var color: Color = ELEMENT_COLORS.get(tower_data.element, Color.WHITE)
	_highlight_color = color
	_show_highlight = true
	_pulse_time = 0.0
	show_range(pos, radius, color)


func hide_range() -> void:
	visible = false
	_radius = 0.0
	_color = Color.TRANSPARENT
	_show_highlight = false
	_highlight_color = Color.TRANSPARENT
	queue_redraw()


func _process(delta: float) -> void:
	if _show_highlight:
		_pulse_time += delta
		queue_redraw()


func _draw() -> void:
	if _radius > 0.0:
		draw_arc(Vector2.ZERO, _radius, ARC_START_ANGLE, ARC_END_ANGLE, ARC_POINT_COUNT, _color, RING_WIDTH)
	if _show_highlight:
		# Pulsing selection ring around the tower sprite
		var pulse: float = (sin(_pulse_time * HIGHLIGHT_PULSE_SPEED * TAU) + 1.0) * 0.5
		var alpha: float = lerpf(HIGHLIGHT_MIN_ALPHA, HIGHLIGHT_MAX_ALPHA, pulse)
		var highlight: Color = Color(_highlight_color.r, _highlight_color.g, _highlight_color.b, alpha)
		draw_arc(Vector2.ZERO, HIGHLIGHT_RADIUS, ARC_START_ANGLE, ARC_END_ANGLE, ARC_POINT_COUNT, highlight, 3.0)
