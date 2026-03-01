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

var _radius: float = 0.0
var _color: Color = Color.TRANSPARENT


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
	show_range(pos, radius, color)


func hide_range() -> void:
	visible = false
	_radius = 0.0
	_color = Color.TRANSPARENT
	queue_redraw()


func _draw() -> void:
	if _radius > 0.0:
		draw_arc(Vector2.ZERO, _radius, ARC_START_ANGLE, ARC_END_ANGLE, ARC_POINT_COUNT, _color, RING_WIDTH)
