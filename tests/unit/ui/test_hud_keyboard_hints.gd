extends GdUnitTestSuite

## Unit tests for Task B4: Strip Keyboard Hints on Mobile.
## Covers: codex button "(C)" hint removal, start wave button "(Space)" hint removal,
## desktop text unchanged, no parenthesized key names on any button after mobile sizing.

const HUD_SCRIPT_PATH: String = "res://scripts/ui/HUD.gd"

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
# SECTION 1: Mobile -- keyboard hints stripped from buttons
# ==============================================================================

# -- 1-2. CodexButton is always hidden (accessible via PauseMenu → Codex) ------
# No keyboard hint tests needed — button is hidden on all platforms.


# -- 3. StartWaveButton text does not contain "(Space)" after mobile sizing ----

func test_mobile_start_wave_button_no_keyboard_hint() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.start_wave_button.text.contains("(Space)"))\
		.override_failure_message("StartWaveButton should NOT contain '(Space)' on mobile, got: '%s'" % _hud.start_wave_button.text)\
		.is_false()


# -- 4. StartWaveButton text is exactly "Start Wave" after mobile sizing -------

func test_mobile_start_wave_button_text_is_start_wave() -> void:
	_hud._apply_mobile_sizing()
	assert_str(_hud.start_wave_button.text).is_equal("Start Wave")


# -- 5. No button text contains parenthesized key names on mobile -------------

func test_mobile_no_button_has_parenthesized_key_hint() -> void:
	_hud._apply_mobile_sizing()
	var buttons: Array[Button] = [
		_hud.speed_button,
		_hud.pause_button,
		_hud.start_wave_button,
	]
	var key_pattern := RegEx.new()
	key_pattern.compile("\\([A-Za-z]+\\)")
	for btn: Button in buttons:
		var result := key_pattern.search(btn.text)
		assert_object(result)\
			.override_failure_message("Button '%s' contains parenthesized key hint: '%s'" % [btn.name, btn.text])\
			.is_null()


# ==============================================================================
# SECTION 2: Desktop -- keyboard hints preserved (no mobile sizing applied)
# ==============================================================================

# -- 6. CodexButton always hidden (accessible via PauseMenu → Codex) ----------
# No desktop keyboard hint test needed — button is hidden on all platforms.


# -- 7. StartWaveButton text still has "(Space)" on desktop --------------------

func test_desktop_start_wave_button_has_keyboard_hint() -> void:
	# Do NOT call _apply_mobile_sizing
	assert_str(_hud.start_wave_button.text).is_equal("Start Wave (Space)")
