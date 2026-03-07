extends Node2D

## Draws a highlighted border around a grid cell during tower placement.
## Color depends on placement validity (set via meta "is_valid").

const CELL_SIZE: int = 64
const BORDER_WIDTH: float = 3.0
const VALID_COLOR := Color("#00CC66")
const INVALID_COLOR := Color("#CC3333")

func _draw() -> void:
	var is_valid: bool = get_meta("is_valid", true)
	var color: Color
	if is_valid:
		color = VALID_COLOR
		color.a = 0.65
	else:
		color = INVALID_COLOR
		color.a = 0.6
	var half: float = CELL_SIZE / 2.0
	var rect := Rect2(-half, -half, CELL_SIZE, CELL_SIZE)
	draw_rect(rect, color, false, BORDER_WIDTH)
