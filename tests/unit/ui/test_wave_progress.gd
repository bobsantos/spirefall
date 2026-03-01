extends GdUnitTestSuite

## Unit tests for Task I4: Wave Progress Indicator.
## Covers: wave progress bar, enemy count label, build phase timer format,
## phase-based visibility toggling between timer and enemy count.

const HUD_SCRIPT_PATH: String = "res://scripts/ui/HUD.gd"
const HUD_TSCN_PATH: String = "res://scenes/ui/HUD.tscn"

var _hud: Control
var _original_game_state: int
var _original_current_wave: int
var _original_max_waves: int
var _original_lives: int
var _original_gold: int
var _original_game_running: bool
var _original_build_timer: float
var _original_combat_timer: float
var _original_hud_ref: Control


# -- Helpers -------------------------------------------------------------------

## Build a minimal HUD node tree matching the expected .tscn structure.
## Only includes nodes referenced by @onready vars that we exercise.
func _build_hud() -> Control:
	var root := Control.new()

	# TopBar
	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	root.add_child(top_bar)

	var wave_label := Label.new()
	wave_label.name = "WaveLabel"
	top_bar.add_child(wave_label)

	var lives_label := Label.new()
	lives_label.name = "LivesLabel"
	top_bar.add_child(lives_label)

	var gold_label := Label.new()
	gold_label.name = "GoldLabel"
	top_bar.add_child(gold_label)

	var xp_label := Label.new()
	xp_label.name = "XPLabel"
	top_bar.add_child(xp_label)

	var speed_button := Button.new()
	speed_button.name = "SpeedButton"
	top_bar.add_child(speed_button)

	var codex_button := Button.new()
	codex_button.name = "CodexButton"
	top_bar.add_child(codex_button)

	# WaveProgressBar -- new node for Task I4
	var wave_progress_bar := ProgressBar.new()
	wave_progress_bar.name = "WaveProgressBar"
	wave_progress_bar.show_percentage = false
	wave_progress_bar.min_value = 0.0
	root.add_child(wave_progress_bar)

	# WaveControls
	var wave_controls := HBoxContainer.new()
	wave_controls.name = "WaveControls"
	root.add_child(wave_controls)

	var timer_label := Label.new()
	timer_label.name = "TimerLabel"
	wave_controls.add_child(timer_label)

	var start_wave_button := Button.new()
	start_wave_button.name = "StartWaveButton"
	wave_controls.add_child(start_wave_button)

	var enemy_count_label := Label.new()
	enemy_count_label.name = "EnemyCountLabel"
	wave_controls.add_child(enemy_count_label)

	# CountdownLabel
	var countdown_label := Label.new()
	countdown_label.name = "CountdownLabel"
	root.add_child(countdown_label)

	# BonusLabel
	var bonus_label := Label.new()
	bonus_label.name = "BonusLabel"
	root.add_child(bonus_label)

	# XPNotifLabel
	var xp_notif_label := Label.new()
	xp_notif_label.name = "XPNotifLabel"
	root.add_child(xp_notif_label)

	# BossHPBar (stub -- PanelContainer with expected children)
	var boss_hp_bar := PanelContainer.new()
	boss_hp_bar.name = "BossHPBar"
	boss_hp_bar.visible = false
	root.add_child(boss_hp_bar)

	var boss_hbox := HBoxContainer.new()
	boss_hbox.name = "HBoxContainer"
	boss_hp_bar.add_child(boss_hbox)

	var boss_name_label := Label.new()
	boss_name_label.name = "BossNameLabel"
	boss_hbox.add_child(boss_name_label)

	var hp_bar := ProgressBar.new()
	hp_bar.name = "HPBar"
	boss_hbox.add_child(hp_bar)

	var hp_text := Label.new()
	hp_text.name = "HPText"
	boss_hbox.add_child(hp_text)

	# BossAnnouncement (stub)
	var boss_announcement := Control.new()
	boss_announcement.name = "BossAnnouncement"
	boss_announcement.visible = false
	root.add_child(boss_announcement)

	# Sub-nodes for BossAnnouncement that its script expects
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	boss_announcement.add_child(overlay)

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	boss_announcement.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	center.add_child(vbox)

	var ann_name := Label.new()
	ann_name.name = "BossNameLabel"
	vbox.add_child(ann_name)

	var ann_sub := Label.new()
	ann_sub.name = "SubtitleLabel"
	vbox.add_child(ann_sub)

	return root


func _apply_hud_script(node: Control) -> void:
	var script: GDScript = load(HUD_SCRIPT_PATH)
	node.set_script(script)
	# Manually wire @onready references
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
	node.boss_hp_bar = node.get_node("BossHPBar")
	node.boss_announcement = node.get_node("BossAnnouncement")
	node.wave_progress_bar = node.get_node("WaveProgressBar")
	node.enemy_count_label = node.get_node("WaveControls/EnemyCountLabel")


func _reset_game_manager() -> void:
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = 0
	GameManager.max_waves = 30
	GameManager.lives = 20
	GameManager._build_timer = 0.0
	GameManager._combat_timer = 0.0
	GameManager._game_running = false
	GameManager._enemies_leaked_this_wave = 0


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
	_original_gold = EconomyManager.gold
	_original_game_running = GameManager._game_running
	_original_build_timer = GameManager._build_timer
	_original_combat_timer = GameManager._combat_timer
	_original_hud_ref = UIManager.hud


func before_test() -> void:
	_reset_game_manager()
	_reset_enemy_system()
	_hud = auto_free(_build_hud())
	_apply_hud_script(_hud)
	# Prevent HUD._ready() side effects by not adding to tree
	# Manually init state that _ready() would set
	_hud.countdown_label.visible = false
	_hud.xp_notif_label.visible = false


func after_test() -> void:
	UIManager.hud = _original_hud_ref
	_hud = null
	_reset_game_manager()
	_reset_enemy_system()


func after() -> void:
	GameManager.game_state = _original_game_state
	GameManager.current_wave = _original_current_wave
	GameManager.max_waves = _original_max_waves
	GameManager.lives = _original_lives
	GameManager._game_running = _original_game_running
	GameManager._build_timer = _original_build_timer
	GameManager._combat_timer = _original_combat_timer
	EconomyManager.gold = _original_gold
	UIManager.hud = _original_hud_ref


# ==============================================================================
# SECTION 1: WaveProgressBar Exists in Scene
# ==============================================================================

# -- 1. HUD.tscn contains WaveProgressBar node --------------------------------

func test_hud_tscn_has_wave_progress_bar() -> void:
	var file := FileAccess.open(HUD_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("WaveProgressBar"))\
		.override_failure_message("HUD.tscn should contain a WaveProgressBar node")\
		.is_true()


# -- 2. HUD.gd has wave_progress_bar reference --------------------------------

func test_hud_script_has_wave_progress_bar_ref() -> void:
	var file := FileAccess.open(HUD_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("wave_progress_bar"))\
		.override_failure_message("HUD.gd should reference wave_progress_bar")\
		.is_true()


# -- 3. WaveProgressBar is a ProgressBar --------------------------------------

func test_wave_progress_bar_is_progress_bar() -> void:
	assert_bool(_hud.wave_progress_bar is ProgressBar).is_true()


# ==============================================================================
# SECTION 2: WaveProgressBar Initial State
# ==============================================================================

# -- 4. Wave progress bar value starts at 0 -----------------------------------

func test_wave_progress_bar_initial_value() -> void:
	_hud.update_display()
	assert_float(_hud.wave_progress_bar.value).is_equal(0.0)


# -- 5. Wave progress bar max is max_waves for classic (30) -------------------

func test_wave_progress_bar_max_classic() -> void:
	GameManager.max_waves = 30
	_hud.update_display()
	assert_float(_hud.wave_progress_bar.max_value).is_equal(30.0)


# -- 6. Wave progress bar max is 999 for endless ------------------------------

func test_wave_progress_bar_max_endless() -> void:
	GameManager.max_waves = 999
	_hud.update_display()
	assert_float(_hud.wave_progress_bar.max_value).is_equal(999.0)


# ==============================================================================
# SECTION 3: WaveProgressBar Updates with Waves
# ==============================================================================

# -- 7. Progress bar value matches current wave --------------------------------

func test_wave_progress_bar_matches_current_wave() -> void:
	GameManager.current_wave = 10
	GameManager.max_waves = 30
	_hud.update_display()
	assert_float(_hud.wave_progress_bar.value).is_equal(10.0)


# -- 8. Progress bar updates when wave changes ---------------------------------

func test_wave_progress_bar_updates_on_wave_change() -> void:
	GameManager.current_wave = 5
	_hud.update_display()
	assert_float(_hud.wave_progress_bar.value).is_equal(5.0)
	GameManager.current_wave = 15
	_hud.update_display()
	assert_float(_hud.wave_progress_bar.value).is_equal(15.0)


# -- 9. Progress bar at max wave shows full ------------------------------------

func test_wave_progress_bar_full_at_max() -> void:
	GameManager.current_wave = 30
	GameManager.max_waves = 30
	_hud.update_display()
	assert_float(_hud.wave_progress_bar.value).is_equal(30.0)


# ==============================================================================
# SECTION 4: EnemyCountLabel Exists
# ==============================================================================

# -- 10. HUD.tscn contains EnemyCountLabel node -------------------------------

func test_hud_tscn_has_enemy_count_label() -> void:
	var file := FileAccess.open(HUD_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("EnemyCountLabel"))\
		.override_failure_message("HUD.tscn should contain an EnemyCountLabel node")\
		.is_true()


# -- 11. HUD.gd has enemy_count_label reference --------------------------------

func test_hud_script_has_enemy_count_label_ref() -> void:
	var file := FileAccess.open(HUD_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("enemy_count_label"))\
		.override_failure_message("HUD.gd should reference enemy_count_label")\
		.is_true()


# -- 12. EnemyCountLabel is a Label -------------------------------------------

func test_enemy_count_label_is_label() -> void:
	assert_bool(_hud.enemy_count_label is Label).is_true()


# ==============================================================================
# SECTION 5: EnemySystem Queued Count Getter
# ==============================================================================

# -- 13. EnemySystem has get_queued_enemy_count method -------------------------

func test_enemy_system_has_queued_count_getter() -> void:
	assert_bool(EnemySystem.has_method("get_queued_enemy_count")).is_true()


# -- 14. get_queued_enemy_count returns 0 when queue is empty ------------------

func test_queued_enemy_count_empty() -> void:
	EnemySystem._enemies_to_spawn.clear()
	assert_int(EnemySystem.get_queued_enemy_count()).is_equal(0)


# -- 15. get_queued_enemy_count returns correct count --------------------------

func test_queued_enemy_count_with_entries() -> void:
	EnemySystem._enemies_to_spawn.clear()
	# Add some dummy entries to the queue
	EnemySystem._enemies_to_spawn.append(EnemyData.new())
	EnemySystem._enemies_to_spawn.append(EnemyData.new())
	EnemySystem._enemies_to_spawn.append(EnemyData.new())
	assert_int(EnemySystem.get_queued_enemy_count()).is_equal(3)


# ==============================================================================
# SECTION 6: Enemy Count During Combat Phase
# ==============================================================================

# -- 16. Enemy count label shows "X remaining" during combat -------------------

func test_enemy_count_shows_remaining_during_combat() -> void:
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager._combat_timer = 30.0
	# 3 active enemies + 2 queued = 5 remaining
	var e1: Node2D = auto_free(Node2D.new())
	var e2: Node2D = auto_free(Node2D.new())
	var e3: Node2D = auto_free(Node2D.new())
	var typed_enemies: Array[Node] = [e1, e2, e3]
	EnemySystem._active_enemies = typed_enemies
	EnemySystem._enemies_to_spawn = [EnemyData.new(), EnemyData.new()]
	_hud._process(0.016)
	assert_str(_hud.enemy_count_label.text).is_equal("5 remaining")
	EnemySystem._active_enemies.clear()
	EnemySystem._enemies_to_spawn.clear()


# -- 17. Enemy count label visible during combat phase -------------------------

func test_enemy_count_visible_during_combat() -> void:
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager._combat_timer = 30.0
	_hud._process(0.016)
	assert_bool(_hud.enemy_count_label.visible).is_true()


# -- 18. Enemy count label hidden during build phase ---------------------------

func test_enemy_count_hidden_during_build() -> void:
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	GameManager.current_wave = 2
	GameManager._build_timer = 15.0
	_hud._process(0.016)
	assert_bool(_hud.enemy_count_label.visible).is_false()


# -- 19. Timer label visible during build phase --------------------------------

func test_timer_label_visible_during_build() -> void:
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	GameManager.current_wave = 2
	GameManager._build_timer = 15.0
	_hud._process(0.016)
	assert_bool(_hud.timer_label.visible).is_true()


# -- 20. Timer label hidden during combat phase --------------------------------

func test_timer_label_hidden_during_combat() -> void:
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager._combat_timer = 30.0
	_hud._process(0.016)
	assert_bool(_hud.timer_label.visible).is_false()


# -- 21. Enemy count with only active enemies (no queued) ----------------------

func test_enemy_count_active_only() -> void:
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager._combat_timer = 30.0
	var e1: Node2D = auto_free(Node2D.new())
	var e2: Node2D = auto_free(Node2D.new())
	var typed_enemies: Array[Node] = [e1, e2]
	EnemySystem._active_enemies = typed_enemies
	EnemySystem._enemies_to_spawn.clear()
	_hud._process(0.016)
	assert_str(_hud.enemy_count_label.text).is_equal("2 remaining")
	EnemySystem._active_enemies.clear()


# -- 22. Enemy count with only queued enemies (no active) ----------------------

func test_enemy_count_queued_only() -> void:
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager._combat_timer = 30.0
	EnemySystem._active_enemies.clear()
	EnemySystem._enemies_to_spawn = [EnemyData.new(), EnemyData.new(), EnemyData.new(), EnemyData.new()]
	_hud._process(0.016)
	assert_str(_hud.enemy_count_label.text).is_equal("4 remaining")
	EnemySystem._enemies_to_spawn.clear()


# -- 23. Enemy count shows 0 remaining when all cleared -----------------------

func test_enemy_count_zero_remaining() -> void:
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager._combat_timer = 30.0
	EnemySystem._active_enemies.clear()
	EnemySystem._enemies_to_spawn.clear()
	_hud._process(0.016)
	assert_str(_hud.enemy_count_label.text).is_equal("0 remaining")


# ==============================================================================
# SECTION 7: Build Phase Timer Format
# ==============================================================================

# -- 24. Wave 1 build phase shows "Place towers!" (unchanged) ------------------

func test_wave_1_shows_place_towers() -> void:
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	GameManager.current_wave = 1
	_hud._process(0.016)
	assert_str(_hud.timer_label.text).is_equal("Place towers!")


# -- 25. Wave 2+ build phase shows "Next wave in: Xs" format ------------------

func test_wave_2_shows_next_wave_in_format() -> void:
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	GameManager.current_wave = 2
	GameManager._build_timer = 15.0
	_hud._process(0.016)
	assert_str(_hud.timer_label.text).is_equal("Next wave in: 15s")


# -- 26. Build timer format at different timer values --------------------------

func test_wave_3_build_timer_25s() -> void:
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	GameManager.current_wave = 3
	GameManager._build_timer = 25.7
	_hud._process(0.016)
	assert_str(_hud.timer_label.text).is_equal("Next wave in: 26s")


# -- 27. Build timer format at 1 second remaining -----------------------------

func test_build_timer_1s_remaining() -> void:
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	GameManager.current_wave = 5
	GameManager._build_timer = 1.0
	_hud._process(0.016)
	assert_str(_hud.timer_label.text).is_equal("Next wave in: 1s")


# -- 28. Build timer format at 0 seconds does not go negative -----------------

func test_build_timer_at_zero() -> void:
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	GameManager.current_wave = 2
	GameManager._build_timer = 0.0
	_hud._process(0.016)
	# Timer at 0 should show "Next wave in: 0s" (transition happens next frame)
	assert_str(_hud.timer_label.text).is_equal("Next wave in: 0s")


# ==============================================================================
# SECTION 8: Phase Visibility Toggling
# ==============================================================================

# -- 29. Build phase: timer visible, enemy count hidden ------------------------

func test_build_phase_visibility_toggle() -> void:
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	GameManager.current_wave = 3
	GameManager._build_timer = 10.0
	_hud._process(0.016)
	assert_bool(_hud.timer_label.visible)\
		.override_failure_message("timer_label should be visible during build phase")\
		.is_true()
	assert_bool(_hud.enemy_count_label.visible)\
		.override_failure_message("enemy_count_label should be hidden during build phase")\
		.is_false()


# -- 30. Combat phase: enemy count visible, timer hidden -----------------------

func test_combat_phase_visibility_toggle() -> void:
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager._combat_timer = 30.0
	_hud._process(0.016)
	assert_bool(_hud.enemy_count_label.visible)\
		.override_failure_message("enemy_count_label should be visible during combat phase")\
		.is_true()
	assert_bool(_hud.timer_label.visible)\
		.override_failure_message("timer_label should be hidden during combat phase")\
		.is_false()


# -- 31. Non-build/combat hides both labels -----------------------------------

func test_menu_state_hides_both() -> void:
	GameManager.game_state = GameManager.GameState.MENU
	_hud._process(0.016)
	assert_bool(_hud.timer_label.visible).is_false()
	assert_bool(_hud.enemy_count_label.visible).is_false()


# -- 32. Game over state hides both labels ------------------------------------

func test_game_over_hides_both() -> void:
	GameManager.game_state = GameManager.GameState.GAME_OVER
	_hud._process(0.016)
	assert_bool(_hud.timer_label.visible).is_false()
	assert_bool(_hud.enemy_count_label.visible).is_false()


# ==============================================================================
# SECTION 9: WaveProgressBar Layout
# ==============================================================================

# -- 33. WaveProgressBar show_percentage is false (clean look) -----------------

func test_wave_progress_bar_no_percentage_text() -> void:
	# The progress bar should not show percentage text overlay
	assert_bool(_hud.wave_progress_bar.show_percentage).is_false()


# -- 34. WaveProgressBar min_value is 0 ---------------------------------------

func test_wave_progress_bar_min_value() -> void:
	assert_float(_hud.wave_progress_bar.min_value).is_equal(0.0)


# ==============================================================================
# SECTION 10: Wave 1 Build Phase Special Handling
# ==============================================================================

# -- 35. Wave 1 build phase hides enemy count label ----------------------------

func test_wave_1_build_hides_enemy_count() -> void:
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	GameManager.current_wave = 1
	_hud._process(0.016)
	assert_bool(_hud.enemy_count_label.visible).is_false()


# -- 36. Wave 1 build phase shows timer label with "Place towers!" ------------

func test_wave_1_build_shows_timer() -> void:
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	GameManager.current_wave = 1
	_hud._process(0.016)
	assert_bool(_hud.timer_label.visible).is_true()
	assert_str(_hud.timer_label.text).is_equal("Place towers!")


# ==============================================================================
# SECTION 11: update_display Updates Progress Bar
# ==============================================================================

# -- 37. update_display sets progress bar value and max from GameManager -------

func test_update_display_syncs_progress_bar() -> void:
	GameManager.current_wave = 12
	GameManager.max_waves = 30
	_hud.update_display()
	assert_float(_hud.wave_progress_bar.value).is_equal(12.0)
	assert_float(_hud.wave_progress_bar.max_value).is_equal(30.0)


# -- 38. wave_controls visible during build phase via update_display -----------

func test_update_display_wave_controls_visible_build() -> void:
	GameManager.game_state = GameManager.GameState.BUILD_PHASE
	_hud.update_display()
	assert_bool(_hud.wave_controls.visible).is_true()


# -- 39. wave_controls hidden during combat phase via update_display -----------

func test_update_display_wave_controls_hidden_combat() -> void:
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	_hud.update_display()
	assert_bool(_hud.wave_controls.visible).is_false()
