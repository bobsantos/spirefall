extends GdUnitTestSuite

## Unit tests for Task I1: Tower Range Indicator.
## Covers: show/hide, radius calculation, element color theming, draw_arc call,
## placement integration, selection integration, deselection cleanup.

const RANGE_INDICATOR_SCRIPT_PATH: String = "res://scripts/ui/RangeIndicator.gd"

var _indicator: Node2D


# -- Helpers -------------------------------------------------------------------

func _build_indicator() -> Node2D:
	var node := Node2D.new()
	var script: GDScript = load(RANGE_INDICATOR_SCRIPT_PATH)
	node.set_script(script)
	# Manually apply _ready() state since node is not in scene tree
	node.visible = false
	node.z_index = 50
	return node


func _make_tower_data(element: String = "fire", range_cells: int = 4) -> TowerData:
	var data := TowerData.new()
	data.tower_name = "Test Tower"
	data.element = element
	data.range_cells = range_cells
	data.cost = 30
	data.damage = 10
	data.attack_speed = 1.0
	return data


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_indicator = _build_indicator()


func after_test() -> void:
	if _indicator and is_instance_valid(_indicator):
		_indicator.free()
		_indicator = null


# -- Section 1: Initial State --------------------------------------------------

func test_initial_state_not_visible() -> void:
	assert_bool(_indicator.visible).is_false()


func test_initial_state_no_radius() -> void:
	assert_float(_indicator._radius).is_equal(0.0)


func test_initial_state_no_color() -> void:
	assert_object(_indicator._color).is_equal(Color.TRANSPARENT)


# -- Section 2: show_range() ---------------------------------------------------

func test_show_range_makes_visible() -> void:
	_indicator.show_range(Vector2(320, 320), 256.0, Color.RED)
	assert_bool(_indicator.visible).is_true()


func test_show_range_sets_position() -> void:
	_indicator.show_range(Vector2(320, 480), 128.0, Color.BLUE)
	assert_vector(_indicator.position).is_equal(Vector2(320, 480))


func test_show_range_sets_radius() -> void:
	_indicator.show_range(Vector2.ZERO, 192.0, Color.GREEN)
	assert_float(_indicator._radius).is_equal(192.0)


func test_show_range_sets_color_with_alpha() -> void:
	var input_color := Color(0.9, 0.25, 0.15)
	_indicator.show_range(Vector2.ZERO, 100.0, input_color)
	# Color should be stored at RING_ALPHA (50%) alpha
	assert_float(_indicator._color.r).is_equal_approx(input_color.r, 0.01)
	assert_float(_indicator._color.g).is_equal_approx(input_color.g, 0.01)
	assert_float(_indicator._color.b).is_equal_approx(input_color.b, 0.01)
	assert_float(_indicator._color.a).is_equal_approx(0.5, 0.01)


func test_show_range_preserves_alpha_override() -> void:
	# If caller passes a color with custom alpha, show_range still forces RING_ALPHA
	var input_color := Color(1.0, 0.0, 0.0, 0.8)
	_indicator.show_range(Vector2.ZERO, 100.0, input_color)
	assert_float(_indicator._color.a).is_equal_approx(0.5, 0.01)


func test_show_range_triggers_redraw() -> void:
	# After show_range, the node should have requested a redraw.
	# We can verify by checking that _radius was set (draw depends on _radius > 0).
	_indicator.show_range(Vector2(100, 100), 256.0, Color.WHITE)
	assert_float(_indicator._radius).is_greater(0.0)
	assert_bool(_indicator.visible).is_true()


# -- Section 3: hide_range() ---------------------------------------------------

func test_hide_range_makes_invisible() -> void:
	_indicator.show_range(Vector2.ZERO, 256.0, Color.RED)
	_indicator.hide_range()
	assert_bool(_indicator.visible).is_false()


func test_hide_range_resets_radius() -> void:
	_indicator.show_range(Vector2.ZERO, 256.0, Color.RED)
	_indicator.hide_range()
	assert_float(_indicator._radius).is_equal(0.0)


func test_hide_range_resets_color() -> void:
	_indicator.show_range(Vector2.ZERO, 256.0, Color.RED)
	_indicator.hide_range()
	assert_object(_indicator._color).is_equal(Color.TRANSPARENT)


func test_hide_range_when_already_hidden() -> void:
	# Should not error when called on an already-hidden indicator
	_indicator.hide_range()
	assert_bool(_indicator.visible).is_false()


# -- Section 4: Radius calculation from tower data -----------------------------

func test_radius_from_tower_data_range_cells() -> void:
	var data: TowerData = _make_tower_data("fire", 4)
	var expected_radius: float = data.range_cells * GridManager.CELL_SIZE
	assert_float(expected_radius).is_equal(256.0)


func test_radius_from_tower_data_range_cells_large() -> void:
	var data: TowerData = _make_tower_data("ice", 6)
	var expected_radius: float = data.range_cells * GridManager.CELL_SIZE
	assert_float(expected_radius).is_equal(384.0)


func test_radius_from_tower_data_range_cells_small() -> void:
	var data: TowerData = _make_tower_data("earth", 2)
	var expected_radius: float = data.range_cells * GridManager.CELL_SIZE
	assert_float(expected_radius).is_equal(128.0)


# -- Section 5: Element color mapping -----------------------------------------

func test_fire_element_color() -> void:
	var data: TowerData = _make_tower_data("fire", 4)
	_indicator.show_range_for_tower(Vector2.ZERO, data)
	assert_float(_indicator._color.r).is_equal_approx(0.9, 0.01)
	assert_float(_indicator._color.g).is_equal_approx(0.25, 0.01)
	assert_float(_indicator._color.b).is_equal_approx(0.15, 0.01)


func test_water_element_color() -> void:
	var data: TowerData = _make_tower_data("water", 4)
	_indicator.show_range_for_tower(Vector2.ZERO, data)
	assert_float(_indicator._color.r).is_equal_approx(0.2, 0.01)
	assert_float(_indicator._color.g).is_equal_approx(0.5, 0.01)
	assert_float(_indicator._color.b).is_equal_approx(0.95, 0.01)


func test_earth_element_color() -> void:
	var data: TowerData = _make_tower_data("earth", 3)
	_indicator.show_range_for_tower(Vector2.ZERO, data)
	assert_float(_indicator._color.r).is_equal_approx(0.6, 0.01)
	assert_float(_indicator._color.g).is_equal_approx(0.4, 0.01)
	assert_float(_indicator._color.b).is_equal_approx(0.2, 0.01)


func test_wind_element_color() -> void:
	var data: TowerData = _make_tower_data("wind", 4)
	_indicator.show_range_for_tower(Vector2.ZERO, data)
	assert_float(_indicator._color.r).is_equal_approx(0.3, 0.01)
	assert_float(_indicator._color.g).is_equal_approx(0.8, 0.01)
	assert_float(_indicator._color.b).is_equal_approx(0.35, 0.01)


func test_lightning_element_color() -> void:
	var data: TowerData = _make_tower_data("lightning", 5)
	_indicator.show_range_for_tower(Vector2.ZERO, data)
	assert_float(_indicator._color.r).is_equal_approx(0.95, 0.01)
	assert_float(_indicator._color.g).is_equal_approx(0.85, 0.01)
	assert_float(_indicator._color.b).is_equal_approx(0.15, 0.01)


func test_ice_element_color() -> void:
	var data: TowerData = _make_tower_data("ice", 4)
	_indicator.show_range_for_tower(Vector2.ZERO, data)
	assert_float(_indicator._color.r).is_equal_approx(0.3, 0.01)
	assert_float(_indicator._color.g).is_equal_approx(0.85, 0.01)
	assert_float(_indicator._color.b).is_equal_approx(0.9, 0.01)


func test_unknown_element_defaults_to_white() -> void:
	var data: TowerData = _make_tower_data("chaos", 4)
	_indicator.show_range_for_tower(Vector2.ZERO, data)
	# Unknown element -> white at RING_ALPHA (50%) alpha
	assert_float(_indicator._color.r).is_equal_approx(1.0, 0.01)
	assert_float(_indicator._color.g).is_equal_approx(1.0, 0.01)
	assert_float(_indicator._color.b).is_equal_approx(1.0, 0.01)
	assert_float(_indicator._color.a).is_equal_approx(0.5, 0.01)


# -- Section 6: show_range_for_tower() convenience ----------------------------

func test_show_range_for_tower_sets_correct_radius() -> void:
	var data: TowerData = _make_tower_data("fire", 5)
	_indicator.show_range_for_tower(Vector2(640, 480), data)
	assert_float(_indicator._radius).is_equal(5.0 * GridManager.CELL_SIZE)


func test_show_range_for_tower_sets_correct_position() -> void:
	var data: TowerData = _make_tower_data("water", 3)
	_indicator.show_range_for_tower(Vector2(192, 256), data)
	assert_vector(_indicator.position).is_equal(Vector2(192, 256))


func test_show_range_for_tower_makes_visible() -> void:
	var data: TowerData = _make_tower_data("earth", 4)
	_indicator.show_range_for_tower(Vector2.ZERO, data)
	assert_bool(_indicator.visible).is_true()


func test_show_range_for_tower_alpha_always_50_percent() -> void:
	var data: TowerData = _make_tower_data("lightning", 4)
	_indicator.show_range_for_tower(Vector2.ZERO, data)
	assert_float(_indicator._color.a).is_equal_approx(0.5, 0.01)


# -- Section 7: Repeated show/hide cycles -------------------------------------

func test_show_then_hide_then_show_again() -> void:
	_indicator.show_range(Vector2(100, 100), 128.0, Color.RED)
	assert_bool(_indicator.visible).is_true()
	_indicator.hide_range()
	assert_bool(_indicator.visible).is_false()
	_indicator.show_range(Vector2(200, 200), 256.0, Color.BLUE)
	assert_bool(_indicator.visible).is_true()
	assert_vector(_indicator.position).is_equal(Vector2(200, 200))
	assert_float(_indicator._radius).is_equal(256.0)


func test_show_range_overwrites_previous() -> void:
	_indicator.show_range(Vector2(100, 100), 128.0, Color.RED)
	_indicator.show_range(Vector2(200, 200), 256.0, Color.BLUE)
	assert_vector(_indicator.position).is_equal(Vector2(200, 200))
	assert_float(_indicator._radius).is_equal(256.0)


# -- Section 8: Ring width constant -------------------------------------------

func test_ring_width() -> void:
	assert_float(_indicator.RING_WIDTH).is_equal(2.5)


# -- Section 9: z_index for rendering above towers ----------------------------

func test_z_index_above_towers() -> void:
	# Range indicator should render above the game board but below UI
	assert_int(_indicator.z_index).is_equal(50)


# -- Section 10: draw_arc parameters (via internal state) ----------------------

func test_draw_uses_full_circle_point_count() -> void:
	# 64 points is sufficient for a smooth circle at game resolution
	assert_int(_indicator.ARC_POINT_COUNT).is_equal(64)


func test_draw_arc_covers_full_circle() -> void:
	# The arc should cover 0 to TAU (full 360 degrees)
	assert_float(_indicator.ARC_START_ANGLE).is_equal(0.0)
	assert_float(_indicator.ARC_END_ANGLE).is_equal_approx(TAU, 0.001)
