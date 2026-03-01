extends GdUnitTestSuite

## Unit tests for Enemy HP bar visual polish (Task I2).
## Covers: background track styling, color thresholds (green/yellow/red),
## sizing (48x5), boss HP bar hiding, and full-HP visibility.

# -- Constants matching implementation -------------------------------------------

const COLOR_GREEN := Color(0.2, 0.85, 0.2)
const COLOR_YELLOW := Color(0.95, 0.8, 0.1)
const COLOR_RED := Color(0.9, 0.2, 0.15)
const BG_COLOR := Color(0.1, 0.1, 0.1, 0.7)

const BAR_WIDTH := 48.0
const BAR_HEIGHT := 5.0


# -- Helpers -------------------------------------------------------------------

static var _enemy_script: GDScript = null

func _make_enemy_data(
	p_health: int = 100,
	p_is_boss: bool = false
) -> EnemyData:
	var data := EnemyData.new()
	data.enemy_name = "TestEnemy"
	data.base_health = p_health
	data.speed_multiplier = 1.0
	data.gold_reward = 3
	data.element = "none"
	data.is_boss = p_is_boss
	return data


func _create_enemy(data: EnemyData) -> Node2D:
	if _enemy_script == null:
		_enemy_script = load("res://scripts/enemies/Enemy.gd") as GDScript

	var enemy := Node2D.new()

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	enemy.add_child(sprite)

	var health_bar := ProgressBar.new()
	health_bar.name = "HealthBar"
	enemy.add_child(health_bar)

	enemy.set_script(_enemy_script)

	enemy.sprite = sprite
	enemy.health_bar = health_bar

	enemy.enemy_data = null
	enemy.max_health = data.base_health
	enemy.current_health = data.base_health
	enemy.speed = 64.0 * data.speed_multiplier
	enemy._base_speed = 64.0
	enemy.enemy_data = data

	return enemy


func _get_fill_stylebox(bar: ProgressBar) -> StyleBoxFlat:
	return bar.get_theme_stylebox("fill") as StyleBoxFlat


func _get_bg_stylebox(bar: ProgressBar) -> StyleBoxFlat:
	return bar.get_theme_stylebox("background") as StyleBoxFlat


# -- Setup / Teardown ----------------------------------------------------------

func after() -> void:
	_enemy_script = null


func before_test() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn.clear()
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = 0


# ==============================================================================
# BACKGROUND TRACK STYLING (3 tests)
# ==============================================================================

func test_health_bar_has_background_stylebox_override() -> void:
	## The health bar should have a StyleBoxFlat background override.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy._update_health_bar()

	assert_bool(enemy.health_bar.has_theme_stylebox_override("background")).is_true()


func test_health_bar_background_color() -> void:
	## Background track should be dark semi-transparent.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy._update_health_bar()

	var bg: StyleBoxFlat = _get_bg_stylebox(enemy.health_bar)
	assert_object(bg).is_not_null()
	assert_bool(bg.bg_color.is_equal_approx(BG_COLOR)).is_true()


func test_health_bar_background_has_no_border() -> void:
	## Background StyleBoxFlat should have zero corner radius for a clean look.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy._update_health_bar()

	var bg: StyleBoxFlat = _get_bg_stylebox(enemy.health_bar)
	assert_object(bg).is_not_null()
	assert_int(bg.corner_radius_top_left).is_equal(0)
	assert_int(bg.corner_radius_top_right).is_equal(0)
	assert_int(bg.corner_radius_bottom_left).is_equal(0)
	assert_int(bg.corner_radius_bottom_right).is_equal(0)


# ==============================================================================
# COLOR THRESHOLDS (6 tests)
# ==============================================================================

func test_fill_color_green_above_50_percent() -> void:
	## HP > 50% should show green fill.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy.current_health = 60  # 60%
	enemy._update_health_bar()

	var fill: StyleBoxFlat = _get_fill_stylebox(enemy.health_bar)
	assert_object(fill).is_not_null()
	assert_bool(fill.bg_color.is_equal_approx(COLOR_GREEN)).is_true()


func test_fill_color_green_at_exactly_51_percent() -> void:
	## HP at 51% (just above threshold) should be green.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy.current_health = 51
	enemy._update_health_bar()

	var fill: StyleBoxFlat = _get_fill_stylebox(enemy.health_bar)
	assert_bool(fill.bg_color.is_equal_approx(COLOR_GREEN)).is_true()


func test_fill_color_yellow_at_50_percent() -> void:
	## HP at exactly 50% should show yellow (<=50%).
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy.current_health = 50
	enemy._update_health_bar()

	var fill: StyleBoxFlat = _get_fill_stylebox(enemy.health_bar)
	assert_bool(fill.bg_color.is_equal_approx(COLOR_YELLOW)).is_true()


func test_fill_color_yellow_at_30_percent() -> void:
	## HP at 30% (between 25% and 50%) should show yellow.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy.current_health = 30
	enemy._update_health_bar()

	var fill: StyleBoxFlat = _get_fill_stylebox(enemy.health_bar)
	assert_bool(fill.bg_color.is_equal_approx(COLOR_YELLOW)).is_true()


func test_fill_color_red_below_25_percent() -> void:
	## HP < 25% should show red.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy.current_health = 20  # 20%
	enemy._update_health_bar()

	var fill: StyleBoxFlat = _get_fill_stylebox(enemy.health_bar)
	assert_bool(fill.bg_color.is_equal_approx(COLOR_RED)).is_true()


func test_fill_color_red_at_exactly_25_percent() -> void:
	## HP at exactly 25% should still be yellow (>=25%).
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy.current_health = 25
	enemy._update_health_bar()

	var fill: StyleBoxFlat = _get_fill_stylebox(enemy.health_bar)
	assert_bool(fill.bg_color.is_equal_approx(COLOR_YELLOW)).is_true()


# ==============================================================================
# COLOR TRANSITIONS THROUGH DAMAGE (3 tests)
# ==============================================================================

func test_color_transitions_green_to_yellow_on_damage() -> void:
	## Taking damage that drops HP from green to yellow range updates color.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy.current_health = 60
	enemy._update_health_bar()
	var fill: StyleBoxFlat = _get_fill_stylebox(enemy.health_bar)
	assert_bool(fill.bg_color.is_equal_approx(COLOR_GREEN)).is_true()

	# Take damage to drop to 40%
	enemy.current_health = 40
	enemy._update_health_bar()
	fill = _get_fill_stylebox(enemy.health_bar)
	assert_bool(fill.bg_color.is_equal_approx(COLOR_YELLOW)).is_true()


func test_color_transitions_yellow_to_red_on_damage() -> void:
	## Taking damage that drops HP from yellow to red range updates color.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy.current_health = 40
	enemy._update_health_bar()

	enemy.current_health = 10
	enemy._update_health_bar()
	var fill: StyleBoxFlat = _get_fill_stylebox(enemy.health_bar)
	assert_bool(fill.bg_color.is_equal_approx(COLOR_RED)).is_true()


func test_color_transitions_red_back_to_green_on_heal() -> void:
	## Healing back above 50% should restore green fill.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy.current_health = 10
	enemy._update_health_bar()

	enemy.current_health = 80
	enemy._update_health_bar()
	var fill: StyleBoxFlat = _get_fill_stylebox(enemy.health_bar)
	assert_bool(fill.bg_color.is_equal_approx(COLOR_GREEN)).is_true()


# ==============================================================================
# VISIBILITY (3 tests)
# ==============================================================================

func test_health_bar_hidden_at_full_hp() -> void:
	## HP bar should be invisible when enemy is at full health.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy._update_health_bar()

	assert_bool(enemy.health_bar.visible).is_false()


func test_health_bar_visible_when_damaged() -> void:
	## HP bar should become visible when enemy takes damage.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy.current_health = 80
	enemy._update_health_bar()

	assert_bool(enemy.health_bar.visible).is_true()


func test_health_bar_hidden_after_heal_to_full() -> void:
	## HP bar should hide again if enemy is healed back to full.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy.current_health = 80
	enemy._update_health_bar()
	assert_bool(enemy.health_bar.visible).is_true()

	enemy.current_health = 100
	enemy._update_health_bar()
	assert_bool(enemy.health_bar.visible).is_false()


# ==============================================================================
# BOSS HP BAR HIDING (3 tests)
# ==============================================================================

func test_boss_health_bar_always_hidden() -> void:
	## Boss enemies should never show the individual HP bar (they use BossHPBar HUD).
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(1000, true)))
	enemy.current_health = 500  # 50% HP
	enemy._update_health_bar()

	assert_bool(enemy.health_bar.visible).is_false()


func test_boss_health_bar_hidden_even_at_low_hp() -> void:
	## Boss HP bar stays hidden even at very low HP.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(1000, true)))
	enemy.current_health = 50  # 5% HP
	enemy._update_health_bar()

	assert_bool(enemy.health_bar.visible).is_false()


func test_non_boss_health_bar_visible_when_damaged() -> void:
	## Non-boss enemies still show HP bar when damaged (sanity check).
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100, false)))
	enemy.current_health = 50
	enemy._update_health_bar()

	assert_bool(enemy.health_bar.visible).is_true()


# ==============================================================================
# SIZING (2 tests)
# ==============================================================================

func test_health_bar_width() -> void:
	## HP bar should be 48px wide.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy._update_health_bar()

	var bar: ProgressBar = enemy.health_bar
	var width: float = bar.offset_right - bar.offset_left
	assert_float(width).is_equal_approx(BAR_WIDTH, 0.1)


func test_health_bar_height() -> void:
	## HP bar should be 5px tall.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy._update_health_bar()

	var bar: ProgressBar = enemy.health_bar
	var height: float = bar.offset_bottom - bar.offset_top
	assert_float(height).is_equal_approx(BAR_HEIGHT, 0.1)


# ==============================================================================
# FILL STYLEBOX EXISTS (2 tests)
# ==============================================================================

func test_fill_stylebox_is_styleboxflat() -> void:
	## The fill override should be a StyleBoxFlat so we can set bg_color.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy.current_health = 50
	enemy._update_health_bar()

	assert_bool(enemy.health_bar.has_theme_stylebox_override("fill")).is_true()
	var fill: StyleBoxFlat = _get_fill_stylebox(enemy.health_bar)
	assert_object(fill).is_not_null()


func test_fill_stylebox_has_no_border() -> void:
	## Fill StyleBoxFlat should have zero corner radius.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy.current_health = 50
	enemy._update_health_bar()

	var fill: StyleBoxFlat = _get_fill_stylebox(enemy.health_bar)
	assert_int(fill.corner_radius_top_left).is_equal(0)


# ==============================================================================
# EDGE CASES (2 tests)
# ==============================================================================

func test_color_at_1_hp() -> void:
	## At 1 HP out of 100, should be red.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(100)))
	enemy.current_health = 1
	enemy._update_health_bar()

	var fill: StyleBoxFlat = _get_fill_stylebox(enemy.health_bar)
	assert_bool(fill.bg_color.is_equal_approx(COLOR_RED)).is_true()


func test_color_with_small_max_health() -> void:
	## With max_health=4, at 2 HP (50%) should be yellow.
	var enemy: Node2D = auto_free(_create_enemy(_make_enemy_data(4)))
	enemy.current_health = 2
	enemy._update_health_bar()

	var fill: StyleBoxFlat = _get_fill_stylebox(enemy.health_bar)
	assert_bool(fill.bg_color.is_equal_approx(COLOR_YELLOW)).is_true()
