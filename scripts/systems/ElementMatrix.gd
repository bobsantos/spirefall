class_name ElementMatrix

## Single source of truth for the elemental damage system.
## Contains the 6x6 damage multiplier matrix, element counter relationships,
## element colors (for gameplay tinting), and the canonical element list.
## Used by Tower.gd, Projectile.gd, and Enemy.gd -- no autoload needed.

# Canonical element list (order matters for iteration, not priority)
const ELEMENTS: Array[String] = ["fire", "water", "earth", "wind", "lightning", "ice"]

# 6x6 damage multiplier matrix: MATRIX[attacker][defender] -> float
# Strong = 1.5, Weak = 0.5, Slightly strong = 1.25, Slightly weak = 0.75, Neutral = 1.0
const MATRIX: Dictionary = {
	"fire":      {"fire": 1.0, "water": 0.5, "earth": 1.5, "wind": 1.0, "lightning": 1.0, "ice": 1.5},
	"water":     {"fire": 1.5, "water": 1.0, "earth": 0.5, "wind": 1.0, "lightning": 0.75, "ice": 1.0},
	"earth":     {"fire": 0.5, "water": 1.5, "earth": 1.0, "wind": 0.75, "lightning": 1.5, "ice": 1.0},
	"wind":      {"fire": 1.0, "water": 1.0, "earth": 1.25, "wind": 1.0, "lightning": 0.5, "ice": 1.5},
	"lightning": {"fire": 1.0, "water": 1.25, "earth": 0.5, "wind": 1.5, "lightning": 1.0, "ice": 1.0},
	"ice":       {"fire": 0.5, "water": 1.0, "earth": 1.0, "wind": 0.5, "lightning": 1.0, "ice": 1.0},
}

# Element counter relationships: element -> the element that deals 1.5x to it
# Also used by Elemental enemies (immune -> weak mapping)
const COUNTERS: Dictionary = {
	"fire": "water",
	"water": "earth",
	"earth": "wind",
	"wind": "lightning",
	"lightning": "fire",
	"ice": "fire",
}

# Element colors for gameplay tinting (enemy elemental sprites, status indicators)
# UI scripts may use their own palettes for buttons/borders.
const COLORS: Dictionary = {
	"fire": Color(1.0, 0.4, 0.2),
	"water": Color(0.3, 0.5, 1.0),
	"earth": Color(0.6, 0.4, 0.2),
	"wind": Color(0.6, 1.0, 0.6),
	"lightning": Color(1.0, 1.0, 0.3),
	"ice": Color(0.7, 0.9, 1.0),
}


static func get_multiplier(attacker_element: String, target_element: String) -> float:
	## Returns the damage multiplier for attacker vs target element.
	## "none" and "chaos" targets return 1.0 (neutral).
	if attacker_element in MATRIX and target_element in MATRIX[attacker_element]:
		return MATRIX[attacker_element][target_element]
	return 1.0


static func get_elements() -> Array[String]:
	## Returns the canonical list of 6 elements.
	return ELEMENTS.duplicate()


static func get_counter(element: String) -> String:
	## Returns the element that deals 1.5x damage to the given element.
	## Returns "" if no counter defined (e.g. for "none" or "chaos").
	if element in COUNTERS:
		return COUNTERS[element]
	return ""


static func get_color(element: String) -> Color:
	## Returns the gameplay tint color for the given element.
	## Returns WHITE for unknown elements.
	if element in COLORS:
		return COLORS[element]
	return Color.WHITE
