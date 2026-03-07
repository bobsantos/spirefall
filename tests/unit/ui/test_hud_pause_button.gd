extends GdUnitTestSuite

## Unit tests for Task B2: HUD Pause Button.
## Covers: PauseButton node existence in TopBar, positioning after CodexButton,
## signal wiring to GameManager.toggle_pause(), mobile sizing, and text.

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

## Build a HUD node tree manually matching the expected .tscn structure,
## including the new PauseButton.
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
	# Wire @onready refs manually (no scene tree, no _ready())
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
	# Always unpause to prevent freezing the test runner
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
# SECTION 1: Node Structure -- PauseButton exists in TopBar
# ==============================================================================

# -- 1. HUD.tscn contains PauseButton node ------------------------------------

func test_tscn_has_pause_button() -> void:
	var file := FileAccess.open(HUD_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains('"PauseButton"')).is_true()


# -- 2. PauseButton is a child of TopBar --------------------------------------

func test_tscn_pause_button_under_top_bar() -> void:
	var file := FileAccess.open(HUD_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains('[node name="PauseButton" type="Button" parent="TopBar"]'))\
		.override_failure_message("PauseButton should be a Button child of TopBar in .tscn")\
		.is_true()


# -- 3. PauseButton appears after CodexButton in .tscn ------------------------

func test_tscn_pause_button_after_codex_button() -> void:
	var file := FileAccess.open(HUD_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	var codex_pos: int = content.find('"CodexButton"')
	var pause_pos: int = content.find('"PauseButton"')
	assert_bool(codex_pos < pause_pos)\
		.override_failure_message("PauseButton should appear after CodexButton in .tscn")\
		.is_true()


# -- 4. PauseButton is the last child of TopBar in .tscn ----------------------

func test_tscn_pause_button_is_last_top_bar_child() -> void:
	var file := FileAccess.open(HUD_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	# PauseButton should be the last node with parent="TopBar"
	# Find the end of the PauseButton node line, then search for any further TopBar children
	var pause_line_pos: int = content.find('[node name="PauseButton"')
	var pause_line_end: int = content.find("\n", pause_line_pos)
	var next_top_bar: int = content.find('parent="TopBar"', pause_line_end)
	assert_bool(next_top_bar == -1)\
		.override_failure_message("PauseButton should be the last child of TopBar")\
		.is_true()


# ==============================================================================
# SECTION 2: Script -- pause_button @onready var
# ==============================================================================

# -- 5. HUD script has pause_button var ----------------------------------------

func test_script_has_pause_button_var() -> void:
	assert_object(_hud.get("pause_button")).is_not_null()
	assert_bool(_hud.pause_button is Button).is_true()


# -- 6. HUD.gd source declares @onready var pause_button ----------------------

func test_script_source_declares_pause_button_onready() -> void:
	var file := FileAccess.open(HUD_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("@onready var pause_button"))\
		.override_failure_message("HUD.gd should declare @onready var pause_button")\
		.is_true()


# ==============================================================================
# SECTION 3: Button Text
# ==============================================================================

# -- 7. PauseButton text is "||" -----------------------------------------------

func test_pause_button_text() -> void:
	assert_str(_hud.pause_button.text).is_equal("||")


# -- 8. PauseButton text in .tscn is "||" -------------------------------------

func test_tscn_pause_button_text() -> void:
	var file := FileAccess.open(HUD_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	# Find the PauseButton node block and check its text property
	var pause_pos: int = content.find('"PauseButton"')
	assert_bool(pause_pos != -1).is_true()
	# The text property should be in the PauseButton node block
	var block_end: int = content.find("\n[node", pause_pos + 1)
	if block_end == -1:
		block_end = content.length()
	var block: String = content.substr(pause_pos, block_end - pause_pos)
	assert_bool(block.contains('text = "||"'))\
		.override_failure_message("PauseButton text should be '||' in .tscn")\
		.is_true()


# ==============================================================================
# SECTION 4: Signal Wiring -- press calls GameManager.toggle_pause()
# ==============================================================================

# -- 9. HUD.gd connects pause_button.pressed in _ready() ----------------------

func test_script_connects_pause_button_pressed() -> void:
	var file := FileAccess.open(HUD_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("pause_button.pressed.connect"))\
		.override_failure_message("HUD._ready() should connect pause_button.pressed")\
		.is_true()


# -- 10. HUD.gd has _on_pause_pressed method ----------------------------------

func test_script_has_on_pause_pressed_method() -> void:
	assert_bool(_hud.has_method("_on_pause_pressed")).is_true()


# -- 11. _on_pause_pressed calls GameManager.toggle_pause() -------------------

func test_on_pause_pressed_calls_toggle_pause() -> void:
	var file := FileAccess.open(HUD_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("GameManager.toggle_pause()"))\
		.override_failure_message("_on_pause_pressed should call GameManager.toggle_pause()")\
		.is_true()


# -- 12. Pressing pause button emits paused_changed signal --------------------

func test_pause_button_press_emits_paused_changed() -> void:
	# Track paused_changed signal
	var paused_values: Array[bool] = []
	var _conn: Callable = func(is_paused: bool) -> void: paused_values.append(is_paused)
	GameManager.paused_changed.connect(_conn)
	# Call the handler directly (simulates button press)
	_hud._on_pause_pressed()
	# Immediately unpause to prevent the test runner from freezing
	GameManager.get_tree().paused = false
	GameManager.paused_changed.disconnect(_conn)
	assert_bool(paused_values.size() > 0)\
		.override_failure_message("paused_changed signal should have been emitted")\
		.is_true()


# ==============================================================================
# SECTION 5: Button Properties -- focus_mode, minimum size
# ==============================================================================

# -- 13. PauseButton has focus_mode = 0 (FOCUS_NONE) in .tscn -----------------

func test_tscn_pause_button_focus_mode() -> void:
	var file := FileAccess.open(HUD_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	var pause_pos: int = content.find('"PauseButton"')
	var block_end: int = content.find("\n[node", pause_pos + 1)
	if block_end == -1:
		block_end = content.length()
	var block: String = content.substr(pause_pos, block_end - pause_pos)
	assert_bool(block.contains("focus_mode = 0"))\
		.override_failure_message("PauseButton should have focus_mode = 0 (FOCUS_NONE)")\
		.is_true()


# -- 14. PauseButton has custom_minimum_size in .tscn -------------------------

func test_tscn_pause_button_has_minimum_size() -> void:
	var file := FileAccess.open(HUD_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	var pause_pos: int = content.find('"PauseButton"')
	var block_end: int = content.find("\n[node", pause_pos + 1)
	if block_end == -1:
		block_end = content.length()
	var block: String = content.substr(pause_pos, block_end - pause_pos)
	assert_bool(block.contains("custom_minimum_size"))\
		.override_failure_message("PauseButton should have custom_minimum_size set in .tscn")\
		.is_true()


# ==============================================================================
# SECTION 6: Mobile Sizing
# ==============================================================================

# -- 15. _apply_mobile_sizing hides pause_button on mobile (moved to overflow) -

func test_apply_mobile_sizing_sets_pause_button_size() -> void:
	_hud._apply_mobile_sizing()
	assert_bool(_hud.pause_button.visible)\
		.override_failure_message("PauseButton should be hidden on mobile (moved to overflow menu)")\
		.is_false()


# -- 16. _apply_mobile_sizing source mentions pause_button ---------------------

func test_apply_mobile_sizing_source_mentions_pause_button() -> void:
	var file := FileAccess.open(HUD_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("pause_button.visible"))\
		.override_failure_message("_apply_mobile_sizing should hide pause_button on mobile")\
		.is_true()
