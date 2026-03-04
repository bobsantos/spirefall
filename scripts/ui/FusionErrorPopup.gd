class_name FusionErrorPopup
extends RefCounted

## Floating error label that appears near a tower when fusion fails.
## Use spawn() to create the label, add it to the scene tree, then call animate().


static func spawn(reason: String, pos: Vector2) -> Label:
	var label := Label.new()
	label.text = reason
	label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3, 1.0))
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = pos - Vector2(40, 20)
	label.z_index = 50
	return label


static func animate(label: Label) -> void:
	var tween: Tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40.0, 1.5)
	tween.tween_property(label, "modulate:a", 0.0, 1.5).set_delay(0.5)
	tween.chain().tween_callback(label.queue_free)
