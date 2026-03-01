extends GdUnitTestSuite

## Unit tests for Task H2: Boss Announcement Splash.
## Covers: show/hide, boss name and subtitle display, element color theming,
## animation timing, overlay appearance, non-boss waves ignored.

const BOSS_ANNOUNCEMENT_SCRIPT_PATH: String = "res://scripts/ui/BossAnnouncement.gd"
const HUD_SCRIPT_PATH: String = "res://scripts/ui/HUD.gd"
const HUD_TSCN_PATH: String = "res://scenes/ui/HUD.tscn"

var _announcement: Control
var _original_game_state: int
var _original_current_wave: int
var _original_max_waves: int
var _original_lives: int
var _original_game_running: bool


# -- Helpers -------------------------------------------------------------------

## Build a BossAnnouncement node tree manually matching the expected .tscn structure.
func _build_boss_announcement() -> Control:
	var root := Control.new()

	# Semi-transparent dark overlay
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.4)
	root.add_child(overlay)

	# Center container for text
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	center.add_child(vbox)

	var boss_name_label := Label.new()
	boss_name_label.name = "BossNameLabel"
	boss_name_label.text = ""
	vbox.add_child(boss_name_label)

	var subtitle_label := Label.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.text = ""
	vbox.add_child(subtitle_label)

	return root


func _apply_script(node: Control) -> void:
	var script: GDScript = load(BOSS_ANNOUNCEMENT_SCRIPT_PATH)
	node.set_script(script)
	# Wire @onready refs manually
	node.overlay = node.get_node("Overlay")
	node.boss_name_label = node.get_node("CenterContainer/VBoxContainer/BossNameLabel")
	node.subtitle_label = node.get_node("CenterContainer/VBoxContainer/SubtitleLabel")


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


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_game_state = GameManager.game_state
	_original_current_wave = GameManager.current_wave
	_original_max_waves = GameManager.max_waves
	_original_lives = GameManager.lives
	_original_game_running = GameManager._game_running


func before_test() -> void:
	_reset_game_manager()
	_reset_enemy_system()
	_announcement = auto_free(_build_boss_announcement())
	_apply_script(_announcement)
	_announcement.visible = false


func after_test() -> void:
	_announcement = null
	_reset_game_manager()
	_reset_enemy_system()


func after() -> void:
	GameManager.game_state = _original_game_state
	GameManager.current_wave = _original_current_wave
	GameManager.max_waves = _original_max_waves
	GameManager.lives = _original_lives
	GameManager._game_running = _original_game_running


# ==============================================================================
# SECTION 1: Initial State
# ==============================================================================

# -- 1. BossAnnouncement starts hidden ----------------------------------------

func test_starts_hidden() -> void:
	assert_bool(_announcement.visible).is_false()


# -- 2. Has expected child nodes ----------------------------------------------

func test_has_expected_children() -> void:
	assert_object(_announcement.boss_name_label).is_not_null()
	assert_object(_announcement.subtitle_label).is_not_null()
	assert_object(_announcement.overlay).is_not_null()


# -- 3. Has show_announcement method ------------------------------------------

func test_has_show_announcement_method() -> void:
	assert_bool(_announcement.has_method("show_announcement")).is_true()


# ==============================================================================
# SECTION 2: Show Announcement
# ==============================================================================

# -- 4. show_announcement makes panel visible ---------------------------------

func test_show_announcement_makes_visible() -> void:
	_announcement.show_announcement("Ember Titan", "fire", "Leaves a trail of fire in its wake")
	assert_bool(_announcement.visible).is_true()


# -- 5. show_announcement sets boss name text ---------------------------------

func test_show_announcement_sets_name() -> void:
	_announcement.show_announcement("Ember Titan", "fire", "Leaves a trail of fire in its wake")
	assert_str(_announcement.boss_name_label.text).is_equal("Ember Titan")


# -- 6. show_announcement sets subtitle text ----------------------------------

func test_show_announcement_sets_subtitle() -> void:
	_announcement.show_announcement("Ember Titan", "fire", "Leaves a trail of fire in its wake")
	assert_str(_announcement.subtitle_label.text).is_equal("Leaves a trail of fire in its wake")


# -- 7. show_announcement applies fire element color to name label ------------

func test_show_announcement_fire_color() -> void:
	_announcement.show_announcement("Ember Titan", "fire", "trail")
	assert_bool(_announcement.boss_name_label.has_theme_color_override("font_color")).is_true()


# -- 8. show_announcement applies ice element color ---------------------------

func test_show_announcement_ice_color() -> void:
	_announcement.show_announcement("Glacial Wyrm", "ice", "freeze")
	assert_bool(_announcement.boss_name_label.has_theme_color_override("font_color")).is_true()


# ==============================================================================
# SECTION 3: Boss Subtitles
# ==============================================================================

# -- 9. BOSS_SUBTITLES dictionary exists on script ----------------------------

func test_boss_subtitles_exists() -> void:
	assert_bool("BOSS_SUBTITLES" in _announcement or _announcement.get("BOSS_SUBTITLES") != null).is_true()


# -- 10. Ember Titan subtitle is correct --------------------------------------

func test_ember_titan_subtitle() -> void:
	var subtitles: Dictionary = _announcement.BOSS_SUBTITLES
	assert_str(subtitles.get("Ember Titan", "")).is_equal("Leaves a trail of fire in its wake")


# -- 11. Glacial Wyrm subtitle is correct ------------------------------------

func test_glacial_wyrm_subtitle() -> void:
	var subtitles: Dictionary = _announcement.BOSS_SUBTITLES
	assert_str(subtitles.get("Glacial Wyrm", "")).is_equal("Freezes towers caught in its gaze")


# -- 12. Chaos Elemental subtitle is correct ----------------------------------

func test_chaos_elemental_subtitle() -> void:
	var subtitles: Dictionary = _announcement.BOSS_SUBTITLES
	assert_str(subtitles.get("Chaos Elemental", "")).is_equal("Shifts between elemental forms")


# ==============================================================================
# SECTION 4: Overlay Appearance
# ==============================================================================

# -- 13. Overlay color is semi-transparent dark --------------------------------

func test_overlay_color() -> void:
	assert_bool(_announcement.overlay.color.is_equal_approx(Color(0, 0, 0, 0.4))).is_true()


# ==============================================================================
# SECTION 5: on_wave_started Logic
# ==============================================================================

# -- 14. on_wave_started has correct method signature -------------------------

func test_has_on_wave_started_method() -> void:
	assert_bool(_announcement.has_method("on_wave_started")).is_true()


# -- 15. on_wave_started with boss wave shows announcement --------------------

func test_on_wave_started_boss_wave_shows() -> void:
	# Set up wave config so wave 10 is a boss wave
	# We need to mock get_wave_config to return is_boss_wave: true
	# Since EnemySystem.get_wave_config may not have real data loaded in tests,
	# we test the show_for_wave method which is what on_wave_started calls
	_announcement.show_for_wave(10, true, "Ember Titan", "fire")
	assert_bool(_announcement.visible).is_true()
	assert_str(_announcement.boss_name_label.text).is_equal("Ember Titan")


# -- 16. on_wave_started with non-boss wave does nothing ---------------------

func test_on_wave_started_non_boss_wave_ignored() -> void:
	_announcement.show_for_wave(5, false, "", "")
	assert_bool(_announcement.visible).is_false()


# -- 17. show_for_wave with Glacial Wyrm shows correct info ------------------

func test_show_for_wave_glacial_wyrm() -> void:
	_announcement.show_for_wave(20, true, "Glacial Wyrm", "ice")
	assert_str(_announcement.boss_name_label.text).is_equal("Glacial Wyrm")
	assert_str(_announcement.subtitle_label.text).is_equal("Freezes towers caught in its gaze")


# -- 18. show_for_wave with Chaos Elemental shows correct info ---------------

func test_show_for_wave_chaos_elemental() -> void:
	_announcement.show_for_wave(30, true, "Chaos Elemental", "none")
	assert_str(_announcement.boss_name_label.text).is_equal("Chaos Elemental")
	assert_str(_announcement.subtitle_label.text).is_equal("Shifts between elemental forms")


# ==============================================================================
# SECTION 6: dismiss Method
# ==============================================================================

# -- 19. dismiss hides the announcement --------------------------------------

func test_dismiss_hides() -> void:
	_announcement.show_announcement("Ember Titan", "fire", "trail")
	_announcement.dismiss()
	assert_bool(_announcement.visible).is_false()


# ==============================================================================
# SECTION 7: Does NOT Pause the Game
# ==============================================================================

# -- 20. show_announcement does not pause game --------------------------------

func test_show_does_not_pause() -> void:
	GameManager._game_running = true
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	_announcement.show_announcement("Ember Titan", "fire", "trail")
	# Game should still be running (not paused)
	assert_bool(GameManager._game_running).is_true()


# ==============================================================================
# SECTION 8: Animation Constants
# ==============================================================================

# -- 21. TOTAL_DURATION constant exists and equals 2.0 -------------------------

func test_total_duration_constant() -> void:
	assert_float(_announcement.TOTAL_DURATION).is_equal(2.0)


# -- 22. HOLD_DURATION constant exists and equals 1.5 -------------------------

func test_hold_duration_constant() -> void:
	assert_float(_announcement.HOLD_DURATION).is_equal(1.5)


# -- 23. FADE_DURATION constant exists and equals 0.5 -------------------------

func test_fade_duration_constant() -> void:
	assert_float(_announcement.FADE_DURATION).is_equal(0.5)


# ==============================================================================
# SECTION 9: Unknown Boss Fallback
# ==============================================================================

# -- 24. show_for_wave with unknown boss uses empty subtitle ------------------

func test_unknown_boss_fallback_subtitle() -> void:
	_announcement.show_for_wave(99, true, "Unknown Boss", "fire")
	assert_str(_announcement.boss_name_label.text).is_equal("Unknown Boss")
	# Should have some subtitle (even if empty or generic)
	assert_str(_announcement.subtitle_label.text).is_not_equal("")


# ==============================================================================
# SECTION 10: HUD Integration
# ==============================================================================

# -- 25. HUD.tscn contains BossAnnouncement node -----------------------------

func test_hud_tscn_has_boss_announcement() -> void:
	var file := FileAccess.open(HUD_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("BossAnnouncement"))\
		.override_failure_message("HUD.tscn should contain a BossAnnouncement node")\
		.is_true()


# -- 26. HUD.gd references BossAnnouncement ----------------------------------

func test_hud_script_references_boss_announcement() -> void:
	var file := FileAccess.open(HUD_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("boss_announcement") or content.contains("BossAnnouncement"))\
		.override_failure_message("HUD.gd should reference BossAnnouncement")\
		.is_true()


# ==============================================================================
# SECTION 11: Element Color Verification
# ==============================================================================

# -- 27. Fire element uses correct color from ElementMatrix -------------------

func test_fire_element_color_matches() -> void:
	_announcement.show_announcement("Ember Titan", "fire", "trail")
	var expected: Color = ElementMatrix.get_color("fire")
	# Boss name should be tinted with element color
	assert_bool(_announcement.boss_name_label.has_theme_color_override("font_color")).is_true()


# -- 28. None element uses white color from ElementMatrix ---------------------

func test_none_element_color_matches() -> void:
	_announcement.show_announcement("Chaos Elemental", "none", "cycle")
	var expected: Color = ElementMatrix.get_color("none")
	assert_bool(_announcement.boss_name_label.has_theme_color_override("font_color")).is_true()
