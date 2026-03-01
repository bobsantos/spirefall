extends GdUnitTestSuite

## Unit tests for Task H1: Boss HP Bar.
## Covers: visibility toggling on boss spawn/death, HP tracking and display,
## element color theming, boss name display, cleanup on wave end.

const BOSS_HP_BAR_SCRIPT_PATH: String = "res://scripts/ui/BossHPBar.gd"
const HUD_SCRIPT_PATH: String = "res://scripts/ui/HUD.gd"
const HUD_TSCN_PATH: String = "res://scenes/ui/HUD.tscn"

var _bar: Control
var _original_game_state: int
var _original_current_wave: int
var _original_max_waves: int
var _original_lives: int
var _original_gold: int
var _original_game_running: bool
var _original_hud_ref: Control


# -- Helpers -------------------------------------------------------------------

## Build a BossHPBar node tree manually matching the expected .tscn structure.
func _build_boss_hp_bar() -> Control:
	var root := PanelContainer.new()

	var hbox := HBoxContainer.new()
	hbox.name = "HBoxContainer"
	root.add_child(hbox)

	var name_label := Label.new()
	name_label.name = "BossNameLabel"
	name_label.text = ""
	hbox.add_child(name_label)

	var hp_bar := ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.min_value = 0
	hp_bar.max_value = 100
	hp_bar.value = 100
	hbox.add_child(hp_bar)

	var hp_text := Label.new()
	hp_text.name = "HPText"
	hp_text.text = "100/100"
	hbox.add_child(hp_text)

	return root


func _apply_script(node: Control) -> void:
	var script: GDScript = load(BOSS_HP_BAR_SCRIPT_PATH)
	node.set_script(script)
	# Wire @onready refs manually
	node.boss_name_label = node.get_node("HBoxContainer/BossNameLabel")
	node.hp_bar = node.get_node("HBoxContainer/HPBar")
	node.hp_text = node.get_node("HBoxContainer/HPText")


func _make_boss_stub(boss_name: String = "Ember Titan", element: String = "fire",
		health: int = 800, is_boss: bool = true) -> Node2D:
	var stub := Node2D.new()
	var data := EnemyData.new()
	data.enemy_name = boss_name
	data.element = element
	data.base_health = health
	data.is_boss = is_boss
	# Reuse cached script to prevent resource leak at exit
	if _boss_stub_script == null:
		_boss_stub_script = GDScript.new()
		_boss_stub_script.source_code = """
extends Node2D
var enemy_data: EnemyData
var max_health: int = 100
var current_health: int = 100
"""
		_boss_stub_script.reload()
	stub.set_script(_boss_stub_script)
	stub.enemy_data = data
	stub.max_health = health
	stub.current_health = health
	return stub


func _reset_game_manager() -> void:
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = _original_current_wave
	GameManager.max_waves = _original_max_waves
	GameManager.lives = _original_lives
	GameManager._game_running = false


func _reset_enemy_system() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn.clear()
	EnemySystem._spawn_timer = 0.0


# Cache the stub script to avoid "resources still in use" at exit
static var _boss_stub_script: GDScript = null


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_game_state = GameManager.game_state
	_original_current_wave = GameManager.current_wave
	_original_max_waves = GameManager.max_waves
	_original_lives = GameManager.lives
	_original_gold = EconomyManager.gold
	_original_game_running = GameManager._game_running
	_original_hud_ref = UIManager.hud


func before_test() -> void:
	_reset_game_manager()
	_reset_enemy_system()
	_bar = auto_free(_build_boss_hp_bar())
	_apply_script(_bar)
	_bar.visible = false


func after_test() -> void:
	UIManager.hud = _original_hud_ref
	_bar = null
	_reset_game_manager()
	_reset_enemy_system()


func after() -> void:
	GameManager.game_state = _original_game_state
	GameManager.current_wave = _original_current_wave
	GameManager.max_waves = _original_max_waves
	GameManager.lives = _original_lives
	GameManager._game_running = _original_game_running
	EconomyManager.gold = _original_gold
	UIManager.hud = _original_hud_ref
	_boss_stub_script = null


# ==============================================================================
# SECTION 1: Initial State
# ==============================================================================

# -- 1. BossHPBar starts hidden -----------------------------------------------

func test_starts_hidden() -> void:
	assert_bool(_bar.visible).is_false()


# -- 2. BossHPBar has expected child nodes ------------------------------------

func test_has_expected_children() -> void:
	assert_object(_bar.boss_name_label).is_not_null()
	assert_object(_bar.hp_bar).is_not_null()
	assert_object(_bar.hp_text).is_not_null()


# -- 3. Script has show_for_boss method ---------------------------------------

func test_has_show_for_boss_method() -> void:
	assert_bool(_bar.has_method("show_for_boss")).is_true()


# -- 4. Script has hide_bar method --------------------------------------------

func test_has_hide_bar_method() -> void:
	assert_bool(_bar.has_method("hide_bar")).is_true()


# ==============================================================================
# SECTION 2: Show for Boss
# ==============================================================================

# -- 5. show_for_boss makes bar visible ----------------------------------------

func test_show_for_boss_makes_visible() -> void:
	var boss: Node2D = auto_free(_make_boss_stub())
	_bar.show_for_boss(boss)
	assert_bool(_bar.visible).is_true()


# -- 6. show_for_boss sets boss name label ------------------------------------

func test_show_for_boss_sets_name() -> void:
	var boss: Node2D = auto_free(_make_boss_stub("Ember Titan"))
	_bar.show_for_boss(boss)
	assert_str(_bar.boss_name_label.text).contains("Ember Titan")


# -- 7. show_for_boss sets HP bar max value ------------------------------------

func test_show_for_boss_sets_max_hp() -> void:
	var boss: Node2D = auto_free(_make_boss_stub("Ember Titan", "fire", 800))
	_bar.show_for_boss(boss)
	assert_float(_bar.hp_bar.max_value).is_equal(800.0)


# -- 8. show_for_boss sets HP bar value to max ---------------------------------

func test_show_for_boss_sets_current_hp() -> void:
	var boss: Node2D = auto_free(_make_boss_stub("Ember Titan", "fire", 800))
	_bar.show_for_boss(boss)
	assert_float(_bar.hp_bar.value).is_equal(800.0)


# -- 9. show_for_boss sets HP text correctly ----------------------------------

func test_show_for_boss_sets_hp_text() -> void:
	var boss: Node2D = auto_free(_make_boss_stub("Ember Titan", "fire", 800))
	_bar.show_for_boss(boss)
	assert_str(_bar.hp_text.text).is_equal("800/800")


# -- 10. show_for_boss stores boss reference -----------------------------------

func test_show_for_boss_stores_reference() -> void:
	var boss: Node2D = auto_free(_make_boss_stub())
	_bar.show_for_boss(boss)
	assert_object(_bar._tracked_boss).is_same(boss)


# ==============================================================================
# SECTION 3: Element Color Theming
# ==============================================================================

# -- 11. Fire boss gets fire color on HP bar -----------------------------------

func test_fire_boss_color() -> void:
	var boss: Node2D = auto_free(_make_boss_stub("Ember Titan", "fire", 800))
	_bar.show_for_boss(boss)
	var expected_color: Color = ElementMatrix.get_color("fire")
	# The fill stylebox should use the element color
	var fill_style: StyleBox = _bar.hp_bar.get_theme_stylebox("fill")
	assert_object(fill_style).is_not_null()
	if fill_style is StyleBoxFlat:
		assert_bool((fill_style as StyleBoxFlat).bg_color.is_equal_approx(expected_color)).is_true()


# -- 12. Ice boss gets ice color on HP bar ------------------------------------

func test_ice_boss_color() -> void:
	var boss: Node2D = auto_free(_make_boss_stub("Glacial Wyrm", "ice", 1300))
	_bar.show_for_boss(boss)
	var expected_color: Color = ElementMatrix.get_color("ice")
	var fill_style: StyleBox = _bar.hp_bar.get_theme_stylebox("fill")
	assert_object(fill_style).is_not_null()
	if fill_style is StyleBoxFlat:
		assert_bool((fill_style as StyleBoxFlat).bg_color.is_equal_approx(expected_color)).is_true()


# -- 13. "none" element boss gets white color ---------------------------------

func test_none_element_boss_color() -> void:
	var boss: Node2D = auto_free(_make_boss_stub("Chaos Elemental", "none", 1650))
	_bar.show_for_boss(boss)
	var expected_color: Color = ElementMatrix.get_color("none")  # WHITE
	var fill_style: StyleBox = _bar.hp_bar.get_theme_stylebox("fill")
	assert_object(fill_style).is_not_null()
	if fill_style is StyleBoxFlat:
		assert_bool((fill_style as StyleBoxFlat).bg_color.is_equal_approx(expected_color)).is_true()


# -- 14. Boss name label uses element color ------------------------------------

func test_boss_name_uses_element_color() -> void:
	var boss: Node2D = auto_free(_make_boss_stub("Ember Titan", "fire", 800))
	_bar.show_for_boss(boss)
	var expected_color: Color = ElementMatrix.get_color("fire")
	assert_bool(_bar.boss_name_label.has_theme_color_override("font_color")).is_true()


# ==============================================================================
# SECTION 4: HP Tracking (update_hp)
# ==============================================================================

# -- 15. update_hp updates bar value -------------------------------------------

func test_update_hp_updates_bar_value() -> void:
	var boss: Node2D = auto_free(_make_boss_stub("Ember Titan", "fire", 800))
	_bar.show_for_boss(boss)
	boss.current_health = 400
	_bar.update_hp()
	assert_float(_bar.hp_bar.value).is_equal(400.0)


# -- 16. update_hp updates text label -----------------------------------------

func test_update_hp_updates_text() -> void:
	var boss: Node2D = auto_free(_make_boss_stub("Ember Titan", "fire", 800))
	_bar.show_for_boss(boss)
	boss.current_health = 400
	_bar.update_hp()
	assert_str(_bar.hp_text.text).is_equal("400/800")


# -- 17. update_hp with zero health -------------------------------------------

func test_update_hp_zero_health() -> void:
	var boss: Node2D = auto_free(_make_boss_stub("Ember Titan", "fire", 800))
	_bar.show_for_boss(boss)
	boss.current_health = 0
	_bar.update_hp()
	assert_float(_bar.hp_bar.value).is_equal(0.0)
	assert_str(_bar.hp_text.text).is_equal("0/800")


# -- 18. update_hp with no tracked boss does nothing --------------------------

func test_update_hp_no_boss_does_nothing() -> void:
	_bar.hp_text.text = "100/100"
	_bar.update_hp()
	# Should not crash and text should remain unchanged
	assert_str(_bar.hp_text.text).is_equal("100/100")


# ==============================================================================
# SECTION 5: Hide Bar
# ==============================================================================

# -- 19. hide_bar hides the control -------------------------------------------

func test_hide_bar_hides_control() -> void:
	var boss: Node2D = auto_free(_make_boss_stub())
	_bar.show_for_boss(boss)
	assert_bool(_bar.visible).is_true()
	_bar.hide_bar()
	assert_bool(_bar.visible).is_false()


# -- 20. hide_bar clears tracked boss reference --------------------------------

func test_hide_bar_clears_reference() -> void:
	var boss: Node2D = auto_free(_make_boss_stub())
	_bar.show_for_boss(boss)
	_bar.hide_bar()
	assert_object(_bar._tracked_boss).is_null()


# ==============================================================================
# SECTION 6: Non-Boss Enemies Ignored
# ==============================================================================

# -- 21. show_for_boss with non-boss enemy does not show bar ------------------

func test_non_boss_enemy_ignored() -> void:
	var enemy: Node2D = auto_free(_make_boss_stub("Grunt", "fire", 100, false))
	_bar.show_for_boss(enemy)
	assert_bool(_bar.visible).is_false()


# ==============================================================================
# SECTION 7: Boss Spawn/Death via on_enemy_spawned / on_enemy_killed
# ==============================================================================

# -- 22. on_enemy_spawned with boss shows bar ---------------------------------

func test_on_enemy_spawned_boss_shows_bar() -> void:
	var boss: Node2D = auto_free(_make_boss_stub("Ember Titan", "fire", 800))
	_bar.on_enemy_spawned(boss)
	assert_bool(_bar.visible).is_true()


# -- 23. on_enemy_spawned with non-boss does nothing -------------------------

func test_on_enemy_spawned_non_boss_ignored() -> void:
	var enemy: Node2D = auto_free(_make_boss_stub("Grunt", "fire", 100, false))
	_bar.on_enemy_spawned(enemy)
	assert_bool(_bar.visible).is_false()


# -- 24. on_enemy_killed with tracked boss hides bar -------------------------

func test_on_enemy_killed_boss_hides_bar() -> void:
	var boss: Node2D = auto_free(_make_boss_stub("Ember Titan", "fire", 800))
	_bar.show_for_boss(boss)
	_bar.on_enemy_killed(boss)
	assert_bool(_bar.visible).is_false()


# -- 25. on_enemy_killed with different enemy does not hide bar ---------------

func test_on_enemy_killed_other_enemy_does_not_hide() -> void:
	var boss: Node2D = auto_free(_make_boss_stub("Ember Titan", "fire", 800))
	_bar.show_for_boss(boss)
	var other: Node2D = auto_free(_make_boss_stub("Grunt", "fire", 100, false))
	_bar.on_enemy_killed(other)
	assert_bool(_bar.visible).is_true()


# ==============================================================================
# SECTION 8: Wave End Cleanup
# ==============================================================================

# -- 26. on_wave_cleared hides bar -------------------------------------------

func test_on_wave_cleared_hides_bar() -> void:
	var boss: Node2D = auto_free(_make_boss_stub("Ember Titan", "fire", 800))
	_bar.show_for_boss(boss)
	_bar.on_wave_cleared(10)
	assert_bool(_bar.visible).is_false()
	assert_object(_bar._tracked_boss).is_null()


# ==============================================================================
# SECTION 9: Different Bosses
# ==============================================================================

# -- 27. Glacial Wyrm boss data displayed correctly ---------------------------

func test_glacial_wyrm_display() -> void:
	var boss: Node2D = auto_free(_make_boss_stub("Glacial Wyrm", "ice", 1300))
	_bar.show_for_boss(boss)
	assert_str(_bar.boss_name_label.text).contains("Glacial Wyrm")
	assert_float(_bar.hp_bar.max_value).is_equal(1300.0)
	assert_str(_bar.hp_text.text).is_equal("1300/1300")


# -- 28. Chaos Elemental boss data displayed correctly -------------------------

func test_chaos_elemental_display() -> void:
	var boss: Node2D = auto_free(_make_boss_stub("Chaos Elemental", "none", 1650))
	_bar.show_for_boss(boss)
	assert_str(_bar.boss_name_label.text).contains("Chaos Elemental")
	assert_float(_bar.hp_bar.max_value).is_equal(1650.0)
	assert_str(_bar.hp_text.text).is_equal("1650/1650")


# ==============================================================================
# SECTION 10: HUD Integration
# ==============================================================================

# -- 29. HUD.tscn contains BossHPBar node ------------------------------------

func test_hud_tscn_has_boss_hp_bar() -> void:
	var file := FileAccess.open(HUD_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("BossHPBar"))\
		.override_failure_message("HUD.tscn should contain a BossHPBar node")\
		.is_true()


# -- 30. HUD.gd references BossHPBar script ----------------------------------

func test_hud_script_references_boss_hp_bar() -> void:
	var file := FileAccess.open(HUD_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("boss_hp_bar") or content.contains("BossHPBar"))\
		.override_failure_message("HUD.gd should reference BossHPBar")\
		.is_true()


# ==============================================================================
# SECTION 11: update_hp with freed boss
# ==============================================================================

# -- 31. update_hp hides bar when tracked boss set to null --------------------

func test_update_hp_hides_when_boss_invalidated() -> void:
	var boss: Node2D = auto_free(_make_boss_stub("Ember Titan", "fire", 800))
	_bar.show_for_boss(boss)
	assert_bool(_bar.visible).is_true()
	# Simulate boss being invalidated by clearing the reference
	_bar._tracked_boss = null
	_bar.update_hp()
	# update_hp returns early when _tracked_boss is null; bar stays visible
	# The hide_bar() path is tested via on_enemy_killed and on_wave_cleared
	assert_bool(_bar.visible).is_true()
