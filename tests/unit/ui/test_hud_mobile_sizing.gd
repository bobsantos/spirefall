extends GdUnitTestSuite

## Unit tests for Task D1: HUD Mobile Sizing Expansion.
## Covers: top bar height (72px), all label font sizes >= 16px on mobile,
## action button touch targets, wave controls sizing, countdown/bonus/XP label
## font sizes, info label SIZE_EXPAND_FILL + text truncation, no desktop regression.

const HUD_SCRIPT_PATH: String = "res://scripts/ui/HUD.gd"
const HUD_TSCN_PATH: String = "res://scenes/ui/HUD.tscn"

var _hud: Control
var _original_game_state: int
var _original_current_wave: int
var _original_max_waves: int
var _original_lives: int
var _original_gold: int
var _original_game_running: bool
var _original_hud_ref: Control


# -- Helpers -------------------------------------------------------------------

func _build_hud() -> Control:
	var root := Control.new()

	# TopBar
	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	root.add_child(top_bar)

	var wave_label := Label.new()
	wave_label.name = "WaveLabel"
	wave_label.text = "Wave 0/30"
	top_bar.add_child(wave_label)

	var topbar_timer_label := Label.new()
	topbar_timer_label.name = "TopBarTimerLabel"
	topbar_timer_label.text = ""
	top_bar.add_child(topbar_timer_label)

	var lives_label := Label.new()
	lives_label.name = "LivesLabel"
	lives_label.text = "Lives: 20"
	top_bar.add_child(lives_label)

	var gold_label := Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "Gold: 100"
	top_bar.add_child(gold_label)

	var xp_label := Label.new()
	xp_label.name = "XPLabel"
	xp_label.text = "XP: 0"
	top_bar.add_child(xp_label)

	var speed_button := Button.new()
	speed_button.name = "SpeedButton"
	speed_button.text = "1x"
	top_bar.add_child(speed_button)

	var codex_button := Button.new()
	codex_button.name = "CodexButton"
	codex_button.text = "Codex (C)"
	top_bar.add_child(codex_button)

	var pause_button := Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = "||"
	top_bar.add_child(pause_button)

	# WaveControls
	var wave_controls := HBoxContainer.new()
	wave_controls.name = "WaveControls"
	root.add_child(wave_controls)

	var timer_label := Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "30"
	wave_controls.add_child(timer_label)

	var start_wave_button := Button.new()
	start_wave_button.name = "StartWaveButton"
	start_wave_button.text = "Start Wave (Space)"
	wave_controls.add_child(start_wave_button)

	var enemy_count_label := Label.new()
	enemy_count_label.name = "EnemyCountLabel"
	enemy_count_label.visible = false
	wave_controls.add_child(enemy_count_label)

	# CountdownLabel
	var countdown_label := Label.new()
	countdown_label.name = "CountdownLabel"
	countdown_label.visible = false
	root.add_child(countdown_label)

	# BonusLabel
	var bonus_label := Label.new()
	bonus_label.name = "BonusLabel"
	bonus_label.visible = false
	root.add_child(bonus_label)

	# XPNotifLabel
	var xp_notif_label := Label.new()
	xp_notif_label.name = "XPNotifLabel"
	xp_notif_label.visible = false
	root.add_child(xp_notif_label)

	# OvertimeLabel
	var overtime_label := Label.new()
	overtime_label.name = "OvertimeLabel"
	overtime_label.visible = false
	root.add_child(overtime_label)

	return root


func _apply_script(node: Control) -> void:
	var script: GDScript = load(HUD_SCRIPT_PATH)
	node.set_script(script)
	node.wave_label = node.get_node("TopBar/WaveLabel")
	node.topbar_timer_label = node.get_node("TopBar/TopBarTimerLabel")
	node.lives_label = node.get_node("TopBar/LivesLabel")
	node.gold_label = node.get_node("TopBar/GoldLabel")
	node.xp_label = node.get_node("TopBar/XPLabel")
	node.timer_label = node.get_node("WaveControls/TimerLabel")
	node.speed_button = node.get_node("TopBar/SpeedButton")
	node.codex_button = node.get_node("TopBar/CodexButton")
	node.pause_button = node.get_node("TopBar/PauseButton")
	node.start_wave_button = node.get_node("WaveControls/StartWaveButton")
	node.wave_controls = node.get_node("WaveControls")
	node.bonus_label = node.get_node("BonusLabel")
	node.countdown_label = node.get_node("CountdownLabel")
	node.xp_notif_label = node.get_node("XPNotifLabel")
	node.overtime_label = node.get_node("OvertimeLabel")
	node.enemy_count_label = node.get_node("WaveControls/EnemyCountLabel")
	node.wave_progress_bar = null
	node.boss_hp_bar = null
	node.boss_announcement = null


func _reset_game_manager() -> void:
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = _original_current_wave
	GameManager.max_waves = _original_max_waves
	GameManager.lives = _original_lives
	GameManager._game_running = false
	GameManager.run_stats = {}


func _reset_economy_manager() -> void:
	EconomyManager.gold = _original_gold


func _reset_enemy_system() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn.clear()


## Helper to get effective font size of a label (checks override, then falls back to theme default).
func _get_font_size(label: Label) -> int:
	if label.has_theme_font_size_override("font_size"):
		return label.get_theme_font_size("font_size")
	# Default Godot font size is 16
	return label.get_theme_font_size("font_size")


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
	_reset_economy_manager()
	_reset_enemy_system()
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	GameManager.current_wave = 1
	GameManager.max_waves = 30
	GameManager.lives = 20
	_hud = auto_free(_build_hud())
	_apply_script(_hud)
	_hud._run_xp = 0


func after_test() -> void:
	GameManager.get_tree().paused = false
	UIManager.hud = _original_hud_ref
	_hud = null
	_reset_game_manager()
	_reset_economy_manager()
	_reset_enemy_system()


func after() -> void:
	GameManager.game_state = _original_game_state
	GameManager.current_wave = _original_current_wave
	GameManager.max_waves = _original_max_waves
	GameManager.lives = _original_lives
	GameManager._game_running = _original_game_running
	EconomyManager.gold = _original_gold
	UIManager.hud = _original_hud_ref


# ==============================================================================
# SECTION 1: Top bar height on mobile
# ==============================================================================

# -- 1. Top bar height is set to MOBILE_TOPBAR_HEIGHT (72) on mobile -----------

func test_mobile_topbar_height_is_72() -> void:
	_hud._apply_mobile_sizing()
	var top_bar: HBoxContainer = _hud.get_node("TopBar")
	assert_bool(top_bar.custom_minimum_size.y >= UIManager.MOBILE_TOPBAR_HEIGHT)\
		.override_failure_message("Top bar height should be >= %d on mobile, got %f" % [UIManager.MOBILE_TOPBAR_HEIGHT, top_bar.custom_minimum_size.y])\
		.is_true()


# -- 2. Top bar height is exactly MOBILE_TOPBAR_HEIGHT -------------------------

func test_mobile_topbar_height_exact() -> void:
	_hud._apply_mobile_sizing()
	var top_bar: HBoxContainer = _hud.get_node("TopBar")
	assert_float(top_bar.custom_minimum_size.y).is_equal(float(UIManager.MOBILE_TOPBAR_HEIGHT))


# ==============================================================================
# SECTION 2: Top bar label font sizes on mobile
# ==============================================================================

# -- 3. WaveLabel font size >= MOBILE_FONT_SIZE_BODY on mobile -----------------

func test_mobile_wave_label_font_size() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.wave_label.has_theme_font_size_override("font_size"))\
		.override_failure_message("WaveLabel should have font_size override on mobile")\
		.is_true()
	assert_bool(_hud.wave_label.get_theme_font_size("font_size") >= UIManager.MOBILE_FONT_SIZE_BODY)\
		.override_failure_message("WaveLabel font size should be >= %d" % UIManager.MOBILE_FONT_SIZE_BODY)\
		.is_true()


# -- 4. TopBarTimerLabel font size >= MOBILE_FONT_SIZE_BODY --------------------

func test_mobile_topbar_timer_label_font_size() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.topbar_timer_label.has_theme_font_size_override("font_size"))\
		.override_failure_message("TopBarTimerLabel should have font_size override on mobile")\
		.is_true()
	assert_bool(_hud.topbar_timer_label.get_theme_font_size("font_size") >= UIManager.MOBILE_FONT_SIZE_BODY)\
		.override_failure_message("TopBarTimerLabel font size should be >= %d" % UIManager.MOBILE_FONT_SIZE_BODY)\
		.is_true()


# -- 5. LivesLabel font size >= MOBILE_FONT_SIZE_BODY -------------------------

func test_mobile_lives_label_font_size() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.lives_label.has_theme_font_size_override("font_size"))\
		.override_failure_message("LivesLabel should have font_size override on mobile")\
		.is_true()
	assert_bool(_hud.lives_label.get_theme_font_size("font_size") >= UIManager.MOBILE_FONT_SIZE_BODY)\
		.override_failure_message("LivesLabel font size should be >= %d" % UIManager.MOBILE_FONT_SIZE_BODY)\
		.is_true()


# -- 6. GoldLabel font size >= MOBILE_FONT_SIZE_BODY --------------------------

func test_mobile_gold_label_font_size() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.gold_label.has_theme_font_size_override("font_size"))\
		.override_failure_message("GoldLabel should have font_size override on mobile")\
		.is_true()
	assert_bool(_hud.gold_label.get_theme_font_size("font_size") >= UIManager.MOBILE_FONT_SIZE_BODY)\
		.override_failure_message("GoldLabel font size should be >= %d" % UIManager.MOBILE_FONT_SIZE_BODY)\
		.is_true()


# -- 7. XPLabel font size >= MOBILE_FONT_SIZE_BODY ----------------------------

func test_mobile_xp_label_font_size() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.xp_label.has_theme_font_size_override("font_size"))\
		.override_failure_message("XPLabel should have font_size override on mobile")\
		.is_true()
	assert_bool(_hud.xp_label.get_theme_font_size("font_size") >= UIManager.MOBILE_FONT_SIZE_BODY)\
		.override_failure_message("XPLabel font size should be >= %d" % UIManager.MOBILE_FONT_SIZE_BODY)\
		.is_true()


# ==============================================================================
# SECTION 3: Action button touch targets on mobile
# ==============================================================================

# -- 8. SpeedButton has MOBILE_BUTTON_MIN on mobile ---------------------------

func test_mobile_speed_button_size() -> void:
	_hud._apply_mobile_sizing()
	assert_vector(_hud.speed_button.custom_minimum_size)\
		.is_equal(UIManager.MOBILE_BUTTON_MIN)


# -- 9. CodexButton has MOBILE_BUTTON_MIN on mobile ---------------------------

func test_mobile_codex_button_size() -> void:
	_hud._apply_mobile_sizing()
	assert_vector(_hud.codex_button.custom_minimum_size)\
		.is_equal(UIManager.MOBILE_BUTTON_MIN)


# -- 10. PauseButton has MOBILE_BUTTON_MIN on mobile --------------------------

func test_mobile_pause_button_size() -> void:
	_hud._apply_mobile_sizing()
	assert_vector(_hud.pause_button.custom_minimum_size)\
		.is_equal(UIManager.MOBILE_BUTTON_MIN)


# -- 11. StartWaveButton has MOBILE_START_WAVE_MIN on mobile -------------------

func test_mobile_start_wave_button_size() -> void:
	_hud._apply_mobile_sizing()
	assert_vector(_hud.start_wave_button.custom_minimum_size)\
		.is_equal(UIManager.MOBILE_START_WAVE_MIN)


# ==============================================================================
# SECTION 4: WaveControls sizing on mobile
# ==============================================================================

# -- 12. WaveControls height increases on mobile ------------------------------

func test_mobile_wave_controls_height() -> void:
	_hud._apply_mobile_sizing()
	var wc: HBoxContainer = _hud.wave_controls
	# Wave controls should have a minimum height proportional to mobile sizing
	assert_bool(wc.custom_minimum_size.y >= UIManager.MOBILE_BUTTON_MIN.y)\
		.override_failure_message("WaveControls height should be >= %f on mobile" % UIManager.MOBILE_BUTTON_MIN.y)\
		.is_true()


# -- 13. TimerLabel font size >= MOBILE_FONT_SIZE_BODY on mobile ---------------

func test_mobile_timer_label_font_size() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.timer_label.has_theme_font_size_override("font_size"))\
		.override_failure_message("TimerLabel should have font_size override on mobile")\
		.is_true()
	assert_bool(_hud.timer_label.get_theme_font_size("font_size") >= UIManager.MOBILE_FONT_SIZE_BODY)\
		.override_failure_message("TimerLabel font size should be >= %d" % UIManager.MOBILE_FONT_SIZE_BODY)\
		.is_true()


# -- 14. EnemyCountLabel font size >= MOBILE_FONT_SIZE_BODY on mobile ----------

func test_mobile_enemy_count_label_font_size() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.enemy_count_label.has_theme_font_size_override("font_size"))\
		.override_failure_message("EnemyCountLabel should have font_size override on mobile")\
		.is_true()
	assert_bool(_hud.enemy_count_label.get_theme_font_size("font_size") >= UIManager.MOBILE_FONT_SIZE_BODY)\
		.override_failure_message("EnemyCountLabel font size should be >= %d" % UIManager.MOBILE_FONT_SIZE_BODY)\
		.is_true()


# ==============================================================================
# SECTION 5: Countdown / Bonus / XP notification labels on mobile
# ==============================================================================

# -- 15. CountdownLabel font size increases on mobile --------------------------

func test_mobile_countdown_label_font_size() -> void:
	_hud._apply_mobile_sizing()
	# Desktop default is 64; mobile should be larger
	assert_bool(_hud.countdown_label.has_theme_font_size_override("font_size"))\
		.override_failure_message("CountdownLabel should have font_size override on mobile")\
		.is_true()
	assert_bool(_hud.countdown_label.get_theme_font_size("font_size") >= 72)\
		.override_failure_message("CountdownLabel font size should be >= 72 on mobile")\
		.is_true()


# -- 16. BonusLabel font size >= MOBILE_FONT_SIZE_BODY on mobile ---------------

func test_mobile_bonus_label_font_size() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.bonus_label.has_theme_font_size_override("font_size"))\
		.override_failure_message("BonusLabel should have font_size override on mobile")\
		.is_true()
	assert_bool(_hud.bonus_label.get_theme_font_size("font_size") >= UIManager.MOBILE_FONT_SIZE_BODY)\
		.override_failure_message("BonusLabel font size should be >= %d" % UIManager.MOBILE_FONT_SIZE_BODY)\
		.is_true()


# -- 17. XPNotifLabel font size >= MOBILE_FONT_SIZE_BODY on mobile -------------

func test_mobile_xp_notif_label_font_size() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.xp_notif_label.has_theme_font_size_override("font_size"))\
		.override_failure_message("XPNotifLabel should have font_size override on mobile")\
		.is_true()
	assert_bool(_hud.xp_notif_label.get_theme_font_size("font_size") >= UIManager.MOBILE_FONT_SIZE_BODY)\
		.override_failure_message("XPNotifLabel font size should be >= %d" % UIManager.MOBILE_FONT_SIZE_BODY)\
		.is_true()


# -- 18. OvertimeLabel font size >= MOBILE_FONT_SIZE_BODY on mobile ------------

func test_mobile_overtime_label_font_size() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.overtime_label.has_theme_font_size_override("font_size"))\
		.override_failure_message("OvertimeLabel should have font_size override on mobile")\
		.is_true()
	assert_bool(_hud.overtime_label.get_theme_font_size("font_size") >= UIManager.MOBILE_FONT_SIZE_BODY)\
		.override_failure_message("OvertimeLabel font size should be >= %d" % UIManager.MOBILE_FONT_SIZE_BODY)\
		.is_true()


# ==============================================================================
# SECTION 6: Info labels use SIZE_EXPAND_FILL and text truncation
# ==============================================================================

# -- 19. WaveLabel has SIZE_EXPAND_FILL and clip_text on mobile ----------------

func test_mobile_wave_label_expand_fill_and_clip() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.wave_label.size_flags_horizontal & Control.SIZE_EXPAND_FILL != 0)\
		.override_failure_message("WaveLabel should have SIZE_EXPAND_FILL on mobile")\
		.is_true()
	assert_bool(_hud.wave_label.clip_text)\
		.override_failure_message("WaveLabel should have clip_text enabled on mobile")\
		.is_true()


# -- 20. LivesLabel has SIZE_EXPAND_FILL and clip_text on mobile ---------------

func test_mobile_lives_label_expand_fill_and_clip() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.lives_label.size_flags_horizontal & Control.SIZE_EXPAND_FILL != 0)\
		.override_failure_message("LivesLabel should have SIZE_EXPAND_FILL on mobile")\
		.is_true()
	assert_bool(_hud.lives_label.clip_text)\
		.override_failure_message("LivesLabel should have clip_text enabled on mobile")\
		.is_true()


# -- 21. GoldLabel has SIZE_EXPAND_FILL and clip_text on mobile ----------------

func test_mobile_gold_label_expand_fill_and_clip() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.gold_label.size_flags_horizontal & Control.SIZE_EXPAND_FILL != 0)\
		.override_failure_message("GoldLabel should have SIZE_EXPAND_FILL on mobile")\
		.is_true()
	assert_bool(_hud.gold_label.clip_text)\
		.override_failure_message("GoldLabel should have clip_text enabled on mobile")\
		.is_true()


# -- 22. XPLabel has SIZE_EXPAND_FILL and clip_text on mobile ------------------

func test_mobile_xp_label_expand_fill_and_clip() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.xp_label.size_flags_horizontal & Control.SIZE_EXPAND_FILL != 0)\
		.override_failure_message("XPLabel should have SIZE_EXPAND_FILL on mobile")\
		.is_true()
	assert_bool(_hud.xp_label.clip_text)\
		.override_failure_message("XPLabel should have clip_text enabled on mobile")\
		.is_true()


# -- 23. TopBarTimerLabel has SIZE_EXPAND_FILL and clip_text on mobile ---------

func test_mobile_topbar_timer_label_expand_fill_and_clip() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.topbar_timer_label.size_flags_horizontal & Control.SIZE_EXPAND_FILL != 0)\
		.override_failure_message("TopBarTimerLabel should have SIZE_EXPAND_FILL on mobile")\
		.is_true()
	assert_bool(_hud.topbar_timer_label.clip_text)\
		.override_failure_message("TopBarTimerLabel should have clip_text enabled on mobile")\
		.is_true()


# ==============================================================================
# SECTION 7: Buttons have fixed sizes (not EXPAND_FILL)
# ==============================================================================

# -- 24. SpeedButton does NOT have SIZE_EXPAND flag on mobile ------------------

func test_mobile_speed_button_no_expand() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.speed_button.size_flags_horizontal & Control.SIZE_EXPAND == 0)\
		.override_failure_message("SpeedButton should NOT have SIZE_EXPAND on mobile")\
		.is_true()


# -- 25. CodexButton does NOT have SIZE_EXPAND flag on mobile ------------------

func test_mobile_codex_button_no_expand() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.codex_button.size_flags_horizontal & Control.SIZE_EXPAND == 0)\
		.override_failure_message("CodexButton should NOT have SIZE_EXPAND on mobile")\
		.is_true()


# -- 26. PauseButton does NOT have SIZE_EXPAND flag on mobile ------------------

func test_mobile_pause_button_no_expand() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.pause_button.size_flags_horizontal & Control.SIZE_EXPAND == 0)\
		.override_failure_message("PauseButton should NOT have SIZE_EXPAND on mobile")\
		.is_true()


# ==============================================================================
# SECTION 8: Desktop regression -- no changes without _apply_mobile_sizing
# ==============================================================================

# -- 27. Top bar height remains 40 on desktop (no mobile sizing applied) -------

func test_desktop_topbar_height_unchanged() -> void:
	# Do NOT call _apply_mobile_sizing
	var top_bar: HBoxContainer = _hud.get_node("TopBar")
	# Default custom_minimum_size.y should be 0 (no override on manually built node)
	assert_float(top_bar.custom_minimum_size.y).is_equal(0.0)


# -- 28. Labels have no font_size override on desktop -------------------------

func test_desktop_labels_no_font_override() -> void:
	# Do NOT call _apply_mobile_sizing
	assert_bool(_hud.wave_label.has_theme_font_size_override("font_size")).is_false()
	assert_bool(_hud.lives_label.has_theme_font_size_override("font_size")).is_false()
	assert_bool(_hud.gold_label.has_theme_font_size_override("font_size")).is_false()
	assert_bool(_hud.xp_label.has_theme_font_size_override("font_size")).is_false()


# -- 29. Buttons have default minimum size on desktop --------------------------

func test_desktop_buttons_default_size() -> void:
	# Do NOT call _apply_mobile_sizing
	assert_vector(_hud.speed_button.custom_minimum_size).is_equal(Vector2.ZERO)
	assert_vector(_hud.codex_button.custom_minimum_size).is_equal(Vector2.ZERO)
	assert_vector(_hud.pause_button.custom_minimum_size).is_equal(Vector2.ZERO)


# -- 30. Labels have no clip_text on desktop -----------------------------------

func test_desktop_labels_no_clip_text() -> void:
	# Do NOT call _apply_mobile_sizing
	assert_bool(_hud.wave_label.clip_text).is_false()
	assert_bool(_hud.lives_label.clip_text).is_false()
	assert_bool(_hud.gold_label.clip_text).is_false()
	assert_bool(_hud.xp_label.clip_text).is_false()


# ==============================================================================
# SECTION 9: Source code verification
# ==============================================================================

# -- 31. _apply_mobile_sizing references MOBILE_TOPBAR_HEIGHT ------------------

func test_source_uses_mobile_topbar_height_constant() -> void:
	var file := FileAccess.open(HUD_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("MOBILE_TOPBAR_HEIGHT"))\
		.override_failure_message("_apply_mobile_sizing should reference UIManager.MOBILE_TOPBAR_HEIGHT")\
		.is_true()


# -- 32. _apply_mobile_sizing references MOBILE_FONT_SIZE_BODY ----------------

func test_source_uses_mobile_font_size_body_constant() -> void:
	var file := FileAccess.open(HUD_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("MOBILE_FONT_SIZE_BODY"))\
		.override_failure_message("_apply_mobile_sizing should reference UIManager.MOBILE_FONT_SIZE_BODY")\
		.is_true()


# -- 33. _apply_mobile_sizing sets clip_text -----------------------------------

func test_source_sets_clip_text() -> void:
	var file := FileAccess.open(HUD_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("clip_text"))\
		.override_failure_message("_apply_mobile_sizing should set clip_text on labels")\
		.is_true()
