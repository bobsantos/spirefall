extends GdUnitTestSuite

## Unit tests for Task B1: Minimal Status Bar with Overflow Menu.
## Covers: XP/timer label hiding, codex/pause moved to overflow menu,
## overflow button creation, menu toggle, dimmer, wave counter merging,
## desktop regression.

const HUD_SCRIPT_PATH: String = "res://scripts/ui/HUD.gd"

var _hud: Control
var _original_game_state: int
var _original_current_wave: int
var _original_max_waves: int
var _original_lives: int
var _original_gold: int
var _original_game_running: bool
var _original_hud_ref: Control
var _original_build_timer: float
var _original_combat_timer: float
var _original_overtime_active: bool
var _original_overtime_elapsed: float


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
	GameManager._build_timer = _original_build_timer
	GameManager._combat_timer = _original_combat_timer
	GameManager._overtime_active = _original_overtime_active
	GameManager._overtime_elapsed = _original_overtime_elapsed


func _reset_economy_manager() -> void:
	EconomyManager.gold = _original_gold


func _reset_enemy_system() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn.clear()


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_game_state = GameManager.game_state
	_original_current_wave = GameManager.current_wave
	_original_max_waves = GameManager.max_waves
	_original_lives = GameManager.lives
	_original_gold = EconomyManager.gold
	_original_game_running = GameManager._game_running
	_original_hud_ref = UIManager.hud
	_original_build_timer = GameManager._build_timer
	_original_combat_timer = GameManager._combat_timer
	_original_overtime_active = GameManager._overtime_active
	_original_overtime_elapsed = GameManager._overtime_elapsed


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
	GameManager._build_timer = _original_build_timer
	GameManager._combat_timer = _original_combat_timer
	GameManager._overtime_active = _original_overtime_active
	GameManager._overtime_elapsed = _original_overtime_elapsed


# ==============================================================================
# SECTION 1: Labels hidden on mobile
# ==============================================================================

# -- 1. XP label hidden on mobile after _apply_mobile_sizing -------------------

func test_mobile_xp_label_hidden() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.xp_label.visible)\
		.override_failure_message("XP label should be hidden on mobile")\
		.is_false()


# -- 2. TopBarTimerLabel hidden on mobile after _apply_mobile_sizing -----------

func test_mobile_topbar_timer_label_hidden() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.topbar_timer_label.visible)\
		.override_failure_message("TopBarTimerLabel should be hidden on mobile")\
		.is_false()


# -- 3. CodexButton hidden on mobile (moved to overflow) ----------------------

func test_mobile_codex_button_hidden() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.codex_button.visible)\
		.override_failure_message("CodexButton should be hidden on mobile (moved to overflow)")\
		.is_false()


# -- 4. PauseButton hidden on mobile (moved to overflow) ----------------------

func test_mobile_pause_button_hidden() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.pause_button.visible)\
		.override_failure_message("PauseButton should be hidden on mobile (moved to overflow)")\
		.is_false()


# ==============================================================================
# SECTION 2: Overflow button creation
# ==============================================================================

# -- 5. Overflow button exists after mobile sizing -----------------------------

func test_mobile_overflow_button_exists() -> void:
	_hud._apply_mobile_sizing()
	assert_object(_hud._overflow_button)\
		.override_failure_message("Overflow button should exist after mobile sizing")\
		.is_not_null()


# -- 6. Overflow button is child of TopBar -------------------------------------

func test_mobile_overflow_button_in_topbar() -> void:
	_hud._apply_mobile_sizing()
	var top_bar: HBoxContainer = _hud.get_node("TopBar")
	assert_bool(_hud._overflow_button.get_parent() == top_bar)\
		.override_failure_message("Overflow button should be a child of TopBar")\
		.is_true()


# -- 7. Overflow button has hamburger text -------------------------------------

func test_mobile_overflow_button_text() -> void:
	_hud._apply_mobile_sizing()
	assert_str(_hud._overflow_button.text).is_equal("\u2261")


# -- 8. Overflow button has correct minimum size ------------------------------

func test_mobile_overflow_button_size() -> void:
	_hud._apply_mobile_sizing()
	assert_vector(_hud._overflow_button.custom_minimum_size)\
		.is_equal(Vector2(48, 44))


# ==============================================================================
# SECTION 3: Overflow menu creation and behavior
# ==============================================================================

# -- 9. Overflow menu exists after mobile sizing -------------------------------

func test_mobile_overflow_menu_exists() -> void:
	_hud._apply_mobile_sizing()
	assert_object(_hud._overflow_menu)\
		.override_failure_message("Overflow menu should exist after mobile sizing")\
		.is_not_null()


# -- 10. Overflow menu starts hidden -------------------------------------------

func test_mobile_overflow_menu_starts_hidden() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud._overflow_menu.visible)\
		.override_failure_message("Overflow menu should start hidden")\
		.is_false()


# -- 11. Toggling overflow shows the menu --------------------------------------

func test_mobile_toggle_overflow_shows_menu() -> void:
	_hud._apply_mobile_sizing()
	_hud._toggle_overflow_menu()
	assert_bool(_hud._overflow_menu.visible)\
		.override_failure_message("Overflow menu should be visible after toggle")\
		.is_true()


# -- 12. Toggling overflow again hides the menu --------------------------------

func test_mobile_toggle_overflow_hides_menu() -> void:
	_hud._apply_mobile_sizing()
	_hud._toggle_overflow_menu()
	_hud._toggle_overflow_menu()
	assert_bool(_hud._overflow_menu.visible)\
		.override_failure_message("Overflow menu should be hidden after second toggle")\
		.is_false()


# -- 13. Overflow menu has Codex button inside ---------------------------------

func test_mobile_overflow_has_codex_button() -> void:
	_hud._apply_mobile_sizing()
	var vbox: VBoxContainer = _hud._overflow_menu.get_child(0)
	var found := false
	for child: Node in vbox.get_children():
		if child is Button and child.text == "Codex":
			found = true
			break
	assert_bool(found)\
		.override_failure_message("Overflow menu should contain a Codex button")\
		.is_true()


# -- 14. Overflow menu has Pause button inside ---------------------------------

func test_mobile_overflow_has_pause_button() -> void:
	_hud._apply_mobile_sizing()
	var vbox: VBoxContainer = _hud._overflow_menu.get_child(0)
	var found := false
	for child: Node in vbox.get_children():
		if child is Button and child.text == "Pause":
			found = true
			break
	assert_bool(found)\
		.override_failure_message("Overflow menu should contain a Pause button")\
		.is_true()


# -- 15. Overflow menu process_mode is WHEN_PAUSED -----------------------------

func test_mobile_overflow_menu_process_mode() -> void:
	_hud._apply_mobile_sizing()
	assert_int(_hud._overflow_menu.process_mode)\
		.is_equal(Node.PROCESS_MODE_WHEN_PAUSED)


# -- 16. Dimmer exists and starts hidden ---------------------------------------

func test_mobile_dimmer_exists_and_hidden() -> void:
	_hud._apply_mobile_sizing()
	assert_object(_hud._overflow_dimmer)\
		.override_failure_message("Overflow dimmer should exist after mobile sizing")\
		.is_not_null()
	assert_bool(_hud._overflow_dimmer.visible)\
		.override_failure_message("Overflow dimmer should start hidden")\
		.is_false()


# -- 17. Dimmer process_mode is WHEN_PAUSED ------------------------------------

func test_mobile_dimmer_process_mode() -> void:
	_hud._apply_mobile_sizing()
	assert_int(_hud._overflow_dimmer.process_mode)\
		.is_equal(Node.PROCESS_MODE_WHEN_PAUSED)


# ==============================================================================
# SECTION 4: Speed button stays in TopBar
# ==============================================================================

# -- 18. Speed button still in TopBar on mobile --------------------------------

func test_mobile_speed_button_in_topbar() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.speed_button.visible)\
		.override_failure_message("Speed button should remain visible on mobile")\
		.is_true()
	var top_bar: HBoxContainer = _hud.get_node("TopBar")
	assert_bool(_hud.speed_button.get_parent() == top_bar)\
		.override_failure_message("Speed button should remain a child of TopBar")\
		.is_true()


# -- 19. Speed button sized for 48px bar on mobile ----------------------------

func test_mobile_speed_button_size() -> void:
	_hud._apply_mobile_sizing()
	assert_vector(_hud.speed_button.custom_minimum_size)\
		.is_equal(Vector2(80, 44))


# ==============================================================================
# SECTION 5: Desktop regression -- no overflow, all labels visible
# ==============================================================================

# -- 20. Desktop: XP label visible (no mobile sizing applied) ------------------

func test_desktop_xp_label_visible() -> void:
	# Do NOT call _apply_mobile_sizing
	assert_bool(_hud.xp_label.visible)\
		.override_failure_message("XP label should be visible on desktop")\
		.is_true()


# -- 21. Desktop: codex button visible ----------------------------------------

func test_desktop_codex_visible() -> void:
	assert_bool(_hud.codex_button.visible)\
		.override_failure_message("Codex button should be visible on desktop")\
		.is_true()


# -- 22. Desktop: pause button visible ----------------------------------------

func test_desktop_pause_visible() -> void:
	assert_bool(_hud.pause_button.visible)\
		.override_failure_message("Pause button should be visible on desktop")\
		.is_true()


# -- 23. Desktop: no overflow button exists ------------------------------------

func test_desktop_no_overflow_button() -> void:
	assert_object(_hud._overflow_button)\
		.override_failure_message("Overflow button should not exist on desktop")\
		.is_null()


# -- 24. Desktop: topbar timer label visible -----------------------------------

func test_desktop_topbar_timer_visible() -> void:
	assert_bool(_hud.topbar_timer_label.visible)\
		.override_failure_message("TopBarTimerLabel should be visible on desktop (initially)")\
		.is_true()


# ==============================================================================
# SECTION 6: Dismiss behavior
# ==============================================================================

# -- 25. Dismiss hides both menu and dimmer ------------------------------------

func test_mobile_dismiss_hides_menu_and_dimmer() -> void:
	_hud._apply_mobile_sizing()
	_hud._toggle_overflow_menu()
	assert_bool(_hud._overflow_menu.visible).is_true()
	_hud._dismiss_overflow_menu()
	assert_bool(_hud._overflow_menu.visible)\
		.override_failure_message("Menu should be hidden after dismiss")\
		.is_false()
	assert_bool(_hud._overflow_dimmer.visible)\
		.override_failure_message("Dimmer should be hidden after dismiss")\
		.is_false()


# -- 26. Toggle shows dimmer alongside menu ------------------------------------

func test_mobile_toggle_shows_dimmer() -> void:
	_hud._apply_mobile_sizing()
	_hud._toggle_overflow_menu()
	assert_bool(_hud._overflow_dimmer.visible)\
		.override_failure_message("Dimmer should be visible when menu is open")\
		.is_true()


# -- 27. Overflow menu is child of HUD root (not TopBar) ----------------------

func test_mobile_overflow_menu_parent_is_hud() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud._overflow_menu.get_parent() == _hud)\
		.override_failure_message("Overflow menu should be a child of HUD root, not TopBar")\
		.is_true()


# -- 28. Overflow menu buttons have correct minimum size ----------------------

func test_mobile_overflow_menu_button_sizes() -> void:
	_hud._apply_mobile_sizing()
	var vbox: VBoxContainer = _hud._overflow_menu.get_child(0)
	for child: Node in vbox.get_children():
		if child is Button:
			assert_vector(child.custom_minimum_size)\
				.override_failure_message("Overflow menu button '%s' should be 200x48" % child.text)\
				.is_equal(Vector2(200, 48))
