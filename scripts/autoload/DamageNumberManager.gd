class_name DamageNumberManagerClass
extends Node

## Object-pooled floating damage number manager.
## Spawns damage labels at enemy positions, categorized by effectiveness.

enum Category { IMMUNE, SUPER_EFFECTIVE, EFFECTIVE, RESISTED, NEUTRAL }

const POOL_SIZE: int = 64
const LIFETIME: float = 0.7
const THROTTLE_MS: int = 150
const FLOAT_DISTANCE: float = 30.0
const CLEANUP_INTERVAL: float = 5.0

const CATEGORY_CONFIG: Dictionary = {
	Category.IMMUNE: {"text": "IMMUNE", "color": Color(0.5, 0.5, 0.5, 0.8), "size": 12, "scale_punch": false},
	Category.SUPER_EFFECTIVE: {"text": "", "color": Color(1.0, 0.9, 0.2), "size": 20, "scale_punch": true},
	Category.EFFECTIVE: {"text": "", "color": Color(0.4, 1.0, 0.4), "size": 16, "scale_punch": false},
	Category.RESISTED: {"text": "", "color": Color(0.7, 0.7, 0.7, 0.9), "size": 12, "scale_punch": false},
	Category.NEUTRAL: {"text": "", "color": Color(1.0, 1.0, 1.0), "size": 14, "scale_punch": false},
}

var _pool: Array[Label] = []
var _canvas_layer: CanvasLayer
var _last_spawn_time: Dictionary = {}
var _cleanup_timer: float = 0.0


func _ready() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 5
	add_child(_canvas_layer)
	_preallocate_pool()


func _process(delta: float) -> void:
	_cleanup_timer += delta
	if _cleanup_timer >= CLEANUP_INTERVAL:
		_cleanup_timer = 0.0
		_last_spawn_time.clear()


func _preallocate_pool() -> void:
	for i: int in range(POOL_SIZE):
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.visible = false
		# Add to canvas layer so they're in the tree and properly freed on exit
		_canvas_layer.add_child(label)
		_pool.append(label)


func spawn(world_pos: Vector2, amount: int, element: String, multiplier: float) -> void:
	if _pool.is_empty():
		return

	# Per-position throttle
	var key: Vector2 = world_pos.snapped(Vector2(1, 1))
	var now: int = Time.get_ticks_msec()
	if _last_spawn_time.has(key) and (now - _last_spawn_time[key]) < THROTTLE_MS:
		return
	_last_spawn_time[key] = now

	var label: Label = _pool.pop_back()
	var category: Category = _classify(amount, multiplier)
	_configure(label, world_pos, amount, element, category)
	label.visible = true
	_animate(label, category)


func _classify(amount: int, multiplier: float) -> Category:
	if amount == 0:
		return Category.IMMUNE
	if multiplier >= 1.5:
		return Category.SUPER_EFFECTIVE
	if multiplier >= 1.2:
		return Category.EFFECTIVE
	if multiplier <= 0.75:
		return Category.RESISTED
	return Category.NEUTRAL


func _configure(label: Label, world_pos: Vector2, amount: int, element: String, category: Category) -> void:
	var config: Dictionary = CATEGORY_CONFIG[category]

	# Set text
	if config["text"] != "":
		label.text = config["text"]
	else:
		label.text = str(amount)

	# Base color with element tint
	var base_color: Color = config["color"]
	if category != Category.IMMUNE and element != "":
		var elem_color: Color = _get_element_color(element)
		base_color = base_color.lerp(elem_color, 0.25)
	label.modulate = Color.WHITE
	label.self_modulate = Color.WHITE

	# Apply label settings
	var settings := LabelSettings.new()
	settings.font_size = config["size"]
	settings.font_color = base_color
	settings.outline_size = 1
	settings.outline_color = Color.BLACK
	label.label_settings = settings

	# Position: convert world position to canvas position
	var canvas_transform: Transform2D = label.get_viewport().get_canvas_transform() if label.get_viewport() else Transform2D.IDENTITY
	var screen_pos: Vector2 = canvas_transform * world_pos
	screen_pos.x += randf_range(-8.0, 8.0)
	label.position = screen_pos
	label.scale = Vector2.ONE
	label.pivot_offset = label.size / 2.0


func _animate(label: Label, category: Category) -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)

	# Float upward
	tween.tween_property(label, "position:y", label.position.y - FLOAT_DISTANCE, LIFETIME)

	# Fade out (delay 0.3s, then fade over 0.4s)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.3)

	# Scale punch for super effective hits
	if category == Category.SUPER_EFFECTIVE:
		label.scale = Vector2(1.3, 1.3)
		tween.tween_property(label, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)

	tween.chain().tween_callback(_return_to_pool.bind(label))


func _return_to_pool(label: Label) -> void:
	label.visible = false
	_pool.append(label)


func _get_element_color(element: String) -> Color:
	const COLORS: Dictionary = {
		"fire": Color(1.0, 0.4, 0.2),
		"water": Color(0.3, 0.5, 1.0),
		"earth": Color(0.6, 0.4, 0.2),
		"wind": Color(0.6, 1.0, 0.6),
		"lightning": Color(1.0, 1.0, 0.3),
		"ice": Color(0.7, 0.9, 1.0),
	}
	return COLORS.get(element, Color.WHITE)
