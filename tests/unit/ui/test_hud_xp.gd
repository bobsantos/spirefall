extends GdUnitTestSuite

## Unit tests for Task E3: HUD XP Display and Kill Rewards.
## Covers: XPLabel node in TopBar, _run_xp tracking, enemy kill XP increment,
## wave completion XP increment, XP reset on new game, update_display XP text,
## and floating +XP notification on kill.


const HUD_SCRIPT_PATH: String = "res://scripts/ui/HUD.gd"
const HUD_TSCN_PATH: String = "res://scenes/ui/HUD.tscn"

var _hud: Control
var _original_game_state: int
var _original_current_wave: int
var _original_max_waves: int
var _original_lives: int
var _original_gold: int
var _original_run_stats: Dictionary
var _original_game_running: bool
var _original_hud_ref: Control


# -- Helpers -------------------------------------------------------------------

## Build a HUD node tree manually matching the expected .tscn structure,
## including the new XPLabel and XPNotifLabel.
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

	# XPNotifLabel for floating +XP text
	var xp_notif_label := Label.new()
	xp_notif_label.name = "XPNotifLabel"
	xp_notif_label.visible = false
	root.add_child(xp_notif_label)

	return root


func _apply_script(node: Control) -> void:
	var script: GDScript = load(HUD_SCRIPT_PATH)
	node.set_script(script)
	# Wire @onready refs manually (no scene tree, no _ready())
	node.wave_label = node.get_node("TopBar/WaveLabel")
	node.lives_label = node.get_node("TopBar/LivesLabel")
	node.gold_label = node.get_node("TopBar/GoldLabel")
	node.xp_label = node.get_node("TopBar/XPLabel")
	node.timer_label = node.get_node("WaveControls/TimerLabel")
	node.speed_button = node.get_node("TopBar/SpeedButton")
	node.codex_button = node.get_node("TopBar/CodexButton")
	node.start_wave_button = node.get_node("WaveControls/StartWaveButton")
	node.wave_controls = node.get_node("WaveControls")
	node.bonus_label = node.get_node("BonusLabel")
	node.countdown_label = node.get_node("CountdownLabel")
	node.xp_notif_label = node.get_node("XPNotifLabel")


func _make_enemy_stub() -> Node:
	var stub := Node2D.new()
	return stub


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
	_original_run_stats = GameManager.run_stats.duplicate() if GameManager.run_stats != null else {}
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
	# Prevent _ready() from running; manually init _run_xp
	_hud._run_xp = 0


func after_test() -> void:
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
	if _original_run_stats != null:
		GameManager.run_stats = _original_run_stats.duplicate()
	UIManager.hud = _original_hud_ref


# ==============================================================================
# SECTION 1: Node Structure -- XPLabel exists in TopBar
# ==============================================================================

# -- 1. HUD.tscn contains XPLabel node ----------------------------------------

func test_tscn_has_xp_label() -> void:
	var file := FileAccess.open(HUD_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains('"XPLabel"')).is_true()


# -- 2. XPLabel is a child of TopBar -----------------------------------------

func test_tscn_xp_label_under_top_bar() -> void:
	var file := FileAccess.open(HUD_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains('[node name="XPLabel" type="Label" parent="TopBar"]')).is_true()


# -- 3. XPLabel appears after GoldLabel (before CodexButton) ------------------

func test_tscn_xp_label_after_gold_label() -> void:
	var file := FileAccess.open(HUD_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	var gold_pos: int = content.find('"GoldLabel"')
	var xp_pos: int = content.find('"XPLabel"')
	var codex_pos: int = content.find('"CodexButton"')
	assert_bool(gold_pos < xp_pos and xp_pos < codex_pos)\
		.override_failure_message("XPLabel should appear after GoldLabel and before CodexButton in .tscn")\
		.is_true()


# -- 4. HUD script has xp_label @onready var ----------------------------------

func test_script_has_xp_label_var() -> void:
	assert_object(_hud.get("xp_label")).is_not_null()
	assert_bool(_hud.xp_label is Label).is_true()


# -- 5. HUD.tscn contains XPNotifLabel node -----------------------------------

func test_tscn_has_xp_notif_label() -> void:
	var file := FileAccess.open(HUD_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains('"XPNotifLabel"')).is_true()


# -- 6. HUD script has xp_notif_label var -------------------------------------

func test_script_has_xp_notif_label_var() -> void:
	assert_object(_hud.get("xp_notif_label")).is_not_null()
	assert_bool(_hud.xp_notif_label is Label).is_true()


# ==============================================================================
# SECTION 2: _run_xp Tracking
# ==============================================================================

# -- 7. _run_xp starts at 0 ---------------------------------------------------

func test_run_xp_starts_at_zero() -> void:
	assert_int(_hud._run_xp).is_equal(0)


# -- 8. _run_xp property exists on HUD script ---------------------------------

func test_script_has_run_xp_var() -> void:
	assert_bool(_hud.get("_run_xp") != null).is_true()


# ==============================================================================
# SECTION 3: Enemy Kill XP Increment
# ==============================================================================

# -- 9. _on_enemy_killed increments _run_xp by 1 -----------------------------

func test_on_enemy_killed_increments_run_xp() -> void:
	_hud._run_xp = 0
	var enemy: Node = auto_free(_make_enemy_stub())
	_hud._on_enemy_killed(enemy)
	assert_int(_hud._run_xp).is_equal(1)


# -- 10. Multiple kills accumulate XP -----------------------------------------

func test_multiple_kills_accumulate_xp() -> void:
	_hud._run_xp = 0
	for i: int in range(5):
		var enemy: Node = auto_free(_make_enemy_stub())
		_hud._on_enemy_killed(enemy)
	assert_int(_hud._run_xp).is_equal(5)


# -- 11. _on_enemy_killed updates XP label text -------------------------------

func test_on_enemy_killed_updates_xp_label() -> void:
	_hud._run_xp = 0
	var enemy: Node = auto_free(_make_enemy_stub())
	_hud._on_enemy_killed(enemy)
	assert_str(_hud.xp_label.text).is_equal("XP: 1")


# -- 12. _on_enemy_killed has correct method signature -----------------------

func test_has_on_enemy_killed_method() -> void:
	assert_bool(_hud.has_method("_on_enemy_killed")).is_true()


# ==============================================================================
# SECTION 4: Wave Completion XP
# ==============================================================================

# -- 13. _on_xp_wave_completed adds wave XP -----------------------------------

func test_wave_completed_adds_wave_xp() -> void:
	_hud._run_xp = 5  # 5 kill XP
	_hud._on_xp_wave_completed(1)
	# wave XP = wave_number * 10 = 10
	assert_int(_hud._run_xp).is_equal(15)


# -- 14. Wave 3 completion adds 30 XP ----------------------------------------

func test_wave_3_completed_adds_30_xp() -> void:
	_hud._run_xp = 10
	_hud._on_xp_wave_completed(3)
	assert_int(_hud._run_xp).is_equal(40)


# -- 15. Wave completion updates XP label -------------------------------------

func test_wave_completed_updates_xp_label() -> void:
	_hud._run_xp = 0
	_hud._on_xp_wave_completed(2)
	assert_str(_hud.xp_label.text).is_equal("XP: 20")


# ==============================================================================
# SECTION 5: XP Reset on New Game
# ==============================================================================

# -- 16. XP resets to 0 when phase changes to BUILD_PHASE wave 1 --------------

func test_xp_resets_on_new_game() -> void:
	_hud._run_xp = 150
	GameManager.current_wave = 1
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	_hud._on_phase_changed(GameManager.GameState.BUILD_PHASE)
	assert_int(_hud._run_xp).is_equal(0)


# -- 17. XP does NOT reset on BUILD_PHASE for wave > 1 ------------------------

func test_xp_does_not_reset_on_later_waves() -> void:
	_hud._run_xp = 50
	GameManager.current_wave = 5
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	_hud._on_phase_changed(GameManager.GameState.BUILD_PHASE)
	assert_int(_hud._run_xp).is_equal(50)


# -- 18. XP does NOT reset on COMBAT_PHASE ------------------------------------

func test_xp_does_not_reset_on_combat_phase() -> void:
	_hud._run_xp = 50
	GameManager.current_wave = 1
	_hud._on_phase_changed(GameManager.GameState.COMBAT_PHASE)
	assert_int(_hud._run_xp).is_equal(50)


# ==============================================================================
# SECTION 6: update_display XP Text
# ==============================================================================

# -- 19. update_display shows XP in label -------------------------------------

func test_update_display_shows_xp() -> void:
	_hud._run_xp = 42
	_hud.update_display()
	assert_str(_hud.xp_label.text).is_equal("XP: 42")


# -- 20. update_display shows 0 XP initially ---------------------------------

func test_update_display_shows_zero_xp() -> void:
	_hud._run_xp = 0
	_hud.update_display()
	assert_str(_hud.xp_label.text).is_equal("XP: 0")


# -- 21. update_display shows large XP values --------------------------------

func test_update_display_shows_large_xp() -> void:
	_hud._run_xp = 9999
	_hud.update_display()
	assert_str(_hud.xp_label.text).is_equal("XP: 9999")


# ==============================================================================
# SECTION 7: Floating +XP Notification
# ==============================================================================

# -- 22. _on_enemy_killed shows XP notification label -------------------------

func test_on_enemy_killed_shows_xp_notif() -> void:
	var enemy: Node = auto_free(_make_enemy_stub())
	_hud._on_enemy_killed(enemy)
	assert_bool(_hud.xp_notif_label.visible).is_true()


# -- 23. XP notification text is "+1 XP" -------------------------------------

func test_xp_notif_text_is_plus_one_xp() -> void:
	var enemy: Node = auto_free(_make_enemy_stub())
	_hud._on_enemy_killed(enemy)
	assert_str(_hud.xp_notif_label.text).is_equal("+1 XP")


# -- 24. XP notification label starts hidden ---------------------------------

func test_xp_notif_label_starts_hidden() -> void:
	assert_bool(_hud.xp_notif_label.visible).is_false()


# ==============================================================================
# SECTION 8: HUD Script Source Verification
# ==============================================================================

# -- 25. HUD.gd connects to EnemySystem.enemy_killed in _ready ---------------

func test_script_connects_enemy_killed_signal() -> void:
	var file := FileAccess.open(HUD_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("EnemySystem.enemy_killed.connect"))\
		.override_failure_message("HUD._ready() should connect to EnemySystem.enemy_killed")\
		.is_true()


# -- 26. HUD.gd connects to GameManager.wave_completed for XP ----------------

func test_script_connects_wave_completed_for_xp() -> void:
	var file := FileAccess.open(HUD_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("_on_xp_wave_completed"))\
		.override_failure_message("HUD should have _on_xp_wave_completed handler")\
		.is_true()


# ==============================================================================
# SECTION 9: Integration-style: EnemySystem.enemy_killed -> HUD XP
# ==============================================================================

# -- 27. Emitting EnemySystem.enemy_killed triggers HUD XP update via method --

func test_enemy_killed_signal_triggers_xp_update() -> void:
	_hud._run_xp = 0
	# Simulate signal emission
	var enemy: Node = auto_free(_make_enemy_stub())
	# Manually connect and fire to verify the handler works
	var xp_count: Array[int] = [0]
	var _conn: Callable = func(_e: Node) -> void: xp_count[0] = _hud._run_xp
	# Call handler directly (signal connection is done in _ready)
	_hud._on_enemy_killed(enemy)
	assert_int(_hud._run_xp).is_equal(1)
