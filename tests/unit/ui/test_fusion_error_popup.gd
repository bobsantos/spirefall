extends GdUnitTestSuite

## Unit tests for FusionErrorPopup floating error label.


# -- 1. spawn() creates a Label with the correct text --

func test_spawn_creates_label_with_correct_text() -> void:
	var label: Label = auto_free(FusionErrorPopup.spawn("Not enough gold", Vector2(100, 200)))
	assert_str(label.text).is_equal("Not enough gold")


# -- 2. spawn() creates a Label with red font color --

func test_spawn_creates_label_with_red_color() -> void:
	var label: Label = auto_free(FusionErrorPopup.spawn("Invalid fusion", Vector2(50, 50)))
	var color: Color = label.get_theme_color("font_color")
	assert_bool(color.is_equal_approx(Color(1.0, 0.4, 0.3, 1.0))).is_true()


# -- 3. spawn() positions the label offset from the given position --

func test_spawn_positions_label_offset_from_pos() -> void:
	var label: Label = auto_free(FusionErrorPopup.spawn("Error", Vector2(100, 200)))
	assert_vector(label.position).is_equal(Vector2(60, 180))


# -- 4. animate() sets up a tween (label must be in tree) --

func test_animate_sets_up_tween() -> void:
	var label: Label = auto_free(FusionErrorPopup.spawn("Tween test", Vector2(200, 300)))
	# Label must be in scene tree for create_tween() to work
	add_child(label)
	var initial_y: float = label.position.y
	FusionErrorPopup.animate(label)
	# Immediately after animate(), label should still be valid and visible
	assert_bool(is_instance_valid(label)).is_true()
	assert_float(label.modulate.a).is_equal(1.0)
	# z_index should be 50
	assert_int(label.z_index).is_equal(50)
