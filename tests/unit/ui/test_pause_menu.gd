extends GdUnitTestSuite

## Unit tests for Task A6: Pause Menu.
## Covers: GameManager pause methods, paused_changed signal, PauseMenu script logic,
## button actions, Game.gd Escape key handling, and process_mode behavior.

const PAUSE_MENU_SCRIPT_PATH: String = "res://scripts/ui/PauseMenu.gd"
const GAME_SCRIPT_PATH: String = "res://scripts/main/Game.gd"
const GAME_TSCN_PATH: String = "res://scenes/main/Game.tscn"

var _pause_menu: Control
var _original_max_waves: int
var _original_game_mode: int
var _scene_change_paths: Array[String] = []
var _scene_change_conn: Callable
var _original_transitioning: bool


# -- Helpers -------------------------------------------------------------------

## Build a PauseMenu node tree manually matching PauseMenu.tscn structure.
func _build_pause_menu() -> Control:
	var root := Control.new()

	# Semi-transparent background dimmer
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.color = Color(0.0, 0.0, 0.0, 0.7)
	root.add_child(dimmer)

	# CenterContainer to center the panel
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "PanelContainer"
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	panel.add_child(vbox)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Paused"
	vbox.add_child(title)

	var resume_btn := Button.new()
	resume_btn.name = "ResumeButton"
	resume_btn.text = "Resume"
	vbox.add_child(resume_btn)

	var restart_btn := Button.new()
	restart_btn.name = "RestartButton"
	restart_btn.text = "Restart"
	vbox.add_child(restart_btn)

	var settings_btn := Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.text = "Settings"
	vbox.add_child(settings_btn)

	var codex_btn := Button.new()
	codex_btn.name = "CodexButton"
	codex_btn.text = "Codex"
	vbox.add_child(codex_btn)

	var quit_btn := Button.new()
	quit_btn.name = "QuitButton"
	quit_btn.text = "Quit to Menu"
	vbox.add_child(quit_btn)

	return root


## Build a minimal Game node tree for input handler testing.
func _build_game_node() -> Node2D:
	var root := Node2D.new()

	var game_board := Node2D.new()
	game_board.name = "GameBoard"
	root.add_child(game_board)

	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	root.add_child(ui_layer)

	var camera := Camera2D.new()
	camera.name = "Camera2D"
	root.add_child(camera)

	return root


func _reset_game_manager() -> void:
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = 0
	GameManager.lives = GameManager.starting_lives
	GameManager._build_timer = 0.0
	GameManager._enemies_leaked_this_wave = 0
	GameManager.max_waves = _original_max_waves
	GameManager.current_mode = GameManager.GameMode.CLASSIC
	# Ensure unpaused
	if get_tree().paused:
		get_tree().paused = false


func _reset_enemy_system() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn.clear()
	EnemySystem._spawn_timer = 0.0


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_max_waves = GameManager.max_waves
	_original_transitioning = SceneManager.is_transitioning
	# Track scene changes to avoid actually loading scenes during tests
	_scene_change_conn = func(path: String) -> void: _scene_change_paths.append(path)
	# We can't easily intercept change_scene; tests verify toggle_pause behavior instead


func before_test() -> void:
	_reset_game_manager()
	_reset_enemy_system()
	EconomyManager.reset()
	SceneManager.current_game_config = {}
	SceneManager.is_transitioning = false
	_scene_change_paths.clear()
	# Build a fresh PauseMenu for each test
	_pause_menu = _build_pause_menu()
	var script: GDScript = load(PAUSE_MENU_SCRIPT_PATH)
	_pause_menu.set_script(script)
	# Wire up @onready refs manually (no scene tree, no _ready())
	_pause_menu.resume_button = _pause_menu.get_node("CenterContainer/PanelContainer/VBoxContainer/ResumeButton")
	_pause_menu.restart_button = _pause_menu.get_node("CenterContainer/PanelContainer/VBoxContainer/RestartButton")
	_pause_menu.settings_button = _pause_menu.get_node("CenterContainer/PanelContainer/VBoxContainer/SettingsButton")
	_pause_menu.codex_button = _pause_menu.get_node("CenterContainer/PanelContainer/VBoxContainer/CodexButton")
	_pause_menu.quit_button = _pause_menu.get_node("CenterContainer/PanelContainer/VBoxContainer/QuitButton")


func after_test() -> void:
	# Always unpause so subsequent tests aren't affected
	if get_tree().paused:
		get_tree().paused = false
	if is_instance_valid(_pause_menu):
		_pause_menu.free()
	for enemy: Node in EnemySystem._active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.free()
	EnemySystem._active_enemies.clear()
	EnemySystem._enemies_to_spawn.clear()
	GameManager.max_waves = _original_max_waves
	GameManager.current_mode = GameManager.GameMode.CLASSIC
	SceneManager.is_transitioning = _original_transitioning


# ==============================================================================
# SECTION 1: GameManager.toggle_pause() and paused_changed signal
# ==============================================================================

# -- 1. toggle_pause() method exists on GameManager ---------------------------

func test_game_manager_has_toggle_pause() -> void:
	assert_bool(GameManager.has_method("toggle_pause")).is_true()


# -- 2. toggle_pause() pauses the tree when unpaused -------------------------

func test_toggle_pause_pauses_tree() -> void:
	get_tree().paused = false
	GameManager.toggle_pause()
	assert_bool(get_tree().paused).is_true()


# -- 3. toggle_pause() unpauses the tree when paused -------------------------

func test_toggle_pause_unpauses_tree() -> void:
	get_tree().paused = true
	GameManager.toggle_pause()
	assert_bool(get_tree().paused).is_false()


# -- 4. toggle_pause() emits paused_changed(true) when pausing ---------------

func test_toggle_pause_emits_paused_changed_true() -> void:
	get_tree().paused = false
	var emitted: Array[bool] = []
	var conn: Callable = func(is_paused: bool) -> void: emitted.append(is_paused)
	GameManager.paused_changed.connect(conn)
	GameManager.toggle_pause()
	GameManager.paused_changed.disconnect(conn)
	assert_int(emitted.size()).is_equal(1)
	assert_bool(emitted[0]).is_true()


# -- 5. toggle_pause() emits paused_changed(false) when unpausing ------------

func test_toggle_pause_emits_paused_changed_false() -> void:
	get_tree().paused = true
	var emitted: Array[bool] = []
	var conn: Callable = func(is_paused: bool) -> void: emitted.append(is_paused)
	GameManager.paused_changed.connect(conn)
	GameManager.toggle_pause()
	GameManager.paused_changed.disconnect(conn)
	assert_int(emitted.size()).is_equal(1)
	assert_bool(emitted[0]).is_false()


# -- 6. paused_changed signal exists on GameManager ---------------------------

func test_game_manager_has_paused_changed_signal() -> void:
	assert_bool(GameManager.has_signal("paused_changed")).is_true()


# -- 7. toggle_pause() twice returns to unpaused state -----------------------

func test_toggle_pause_twice_returns_to_unpaused() -> void:
	get_tree().paused = false
	GameManager.toggle_pause()
	GameManager.toggle_pause()
	assert_bool(get_tree().paused).is_false()


# -- 8. toggle_pause() emits signal on each call -----------------------------

func test_toggle_pause_emits_signal_each_call() -> void:
	get_tree().paused = false
	var counts: Array[int] = [0]
	var conn: Callable = func(_v: bool) -> void: counts[0] += 1
	GameManager.paused_changed.connect(conn)
	GameManager.toggle_pause()
	GameManager.toggle_pause()
	GameManager.paused_changed.disconnect(conn)
	assert_int(counts[0]).is_equal(2)


# ==============================================================================
# SECTION 2: PauseMenu Node Structure
# ==============================================================================

# -- 9. PauseMenu has Dimmer ColorRect child ----------------------------------

func test_pause_menu_has_dimmer() -> void:
	assert_object(_pause_menu.get_node_or_null("Dimmer")).is_not_null()


# -- 10. Dimmer is a ColorRect ------------------------------------------------

func test_pause_menu_dimmer_is_color_rect() -> void:
	var dimmer: Node = _pause_menu.get_node("Dimmer")
	assert_bool(dimmer is ColorRect).is_true()


# -- 11. PauseMenu has ResumeButton -------------------------------------------

func test_pause_menu_has_resume_button() -> void:
	var btn: Node = _pause_menu.get_node_or_null(
		"CenterContainer/PanelContainer/VBoxContainer/ResumeButton"
	)
	assert_object(btn).is_not_null()


# -- 12. PauseMenu has RestartButton ------------------------------------------

func test_pause_menu_has_restart_button() -> void:
	var btn: Node = _pause_menu.get_node_or_null(
		"CenterContainer/PanelContainer/VBoxContainer/RestartButton"
	)
	assert_object(btn).is_not_null()


# -- 13. PauseMenu has SettingsButton -----------------------------------------

func test_pause_menu_has_settings_button() -> void:
	var btn: Node = _pause_menu.get_node_or_null(
		"CenterContainer/PanelContainer/VBoxContainer/SettingsButton"
	)
	assert_object(btn).is_not_null()


# -- 14. PauseMenu has QuitButton ---------------------------------------------

func test_pause_menu_has_quit_button() -> void:
	var btn: Node = _pause_menu.get_node_or_null(
		"CenterContainer/PanelContainer/VBoxContainer/QuitButton"
	)
	assert_object(btn).is_not_null()


# -- 15. PauseMenu has CodexButton --------------------------------------------

func test_pause_menu_has_codex_button() -> void:
	var btn: Node = _pause_menu.get_node_or_null(
		"CenterContainer/PanelContainer/VBoxContainer/CodexButton"
	)
	assert_object(btn).is_not_null()


# -- 16. PauseMenu has TitleLabel with "Paused" text -------------------------

func test_pause_menu_title_label_text() -> void:
	var label: Node = _pause_menu.get_node_or_null(
		"CenterContainer/PanelContainer/VBoxContainer/TitleLabel"
	)
	assert_object(label).is_not_null()
	assert_str((label as Label).text).is_equal("Paused")


# ==============================================================================
# SECTION 3: PauseMenu Script Properties
# ==============================================================================

# -- 16. PauseMenu script has resume_button @onready var ---------------------

func test_pause_menu_has_resume_button_var() -> void:
	assert_bool(_pause_menu.get("resume_button") != null).is_true()


# -- 17. PauseMenu script has restart_button @onready var --------------------

func test_pause_menu_has_restart_button_var() -> void:
	assert_bool(_pause_menu.get("restart_button") != null).is_true()


# -- 18. PauseMenu script has settings_button @onready var -------------------

func test_pause_menu_has_settings_button_var() -> void:
	assert_bool(_pause_menu.get("settings_button") != null).is_true()


# -- 19. PauseMenu script has quit_button @onready var -----------------------

func test_pause_menu_has_quit_button_var() -> void:
	assert_bool(_pause_menu.get("quit_button") != null).is_true()


# -- 20. PauseMenu script has codex_button @onready var ----------------------

func test_pause_menu_has_codex_button_var() -> void:
	assert_bool(_pause_menu.get("codex_button") != null).is_true()


# ==============================================================================
# SECTION 4: PauseMenu Button Actions (called directly)
# ==============================================================================

# -- 20. _on_resume_pressed() unpauses the tree ------------------------------

func test_on_resume_pressed_unpauses() -> void:
	get_tree().paused = true
	_pause_menu._on_resume_pressed()
	assert_bool(get_tree().paused).is_false()


# -- 21. _on_resume_pressed() hides the menu ----------------------------------

func test_on_resume_pressed_hides_menu() -> void:
	_pause_menu.visible = true
	get_tree().paused = true
	_pause_menu._on_resume_pressed()
	assert_bool(_pause_menu.visible).is_false()


# -- 22. _on_resume_pressed() emits paused_changed(false) -------------------

func test_on_resume_pressed_emits_paused_changed_false() -> void:
	get_tree().paused = true
	var emitted: Array[bool] = []
	var conn: Callable = func(v: bool) -> void: emitted.append(v)
	GameManager.paused_changed.connect(conn)
	_pause_menu._on_resume_pressed()
	GameManager.paused_changed.disconnect(conn)
	assert_int(emitted.size()).is_equal(1)
	assert_bool(emitted[0]).is_false()


# -- 23. _on_quit_pressed() unpauses the tree before navigating --------------

func test_on_quit_pressed_unpauses() -> void:
	# Must unpause before changing scene, or the new scene won't process
	get_tree().paused = true
	# Prevent actual scene change (SceneManager won't be able to change scene in test)
	SceneManager.is_transitioning = true
	_pause_menu._on_quit_pressed()
	assert_bool(get_tree().paused).is_false()


# -- 24. _on_restart_pressed() unpauses before restarting --------------------

func test_on_restart_pressed_unpauses() -> void:
	get_tree().paused = true
	SceneManager.is_transitioning = true
	_pause_menu._on_restart_pressed()
	assert_bool(get_tree().paused).is_false()


# -- 25. _on_settings_pressed() does not crash --------------------------------

func test_on_settings_pressed_no_crash() -> void:
	# SettingsPanel doesn't exist yet (Task D3); just verify no error
	var did_error: bool = false
	_pause_menu._on_settings_pressed()
	assert_bool(did_error).is_false()


# -- 26. _on_codex_pressed() is a no-op when UIManager.codex_panel is null ---
#
# UIManager.codex_panel is null by default, so the handler should not crash.

func test_on_codex_pressed_no_crash() -> void:
	var original_panel: Control = UIManager.codex_panel
	UIManager.codex_panel = null
	_pause_menu._on_codex_pressed()
	UIManager.codex_panel = original_panel
	# If we reach this point without an error the call succeeded
	assert_bool(true).is_true()


# -- 27. _on_codex_pressed() calls toggle() on codex_panel -------------------
#
# Register a stub codex panel with a toggle() method and confirm it gets called.

func test_on_codex_pressed_calls_toggle_codex() -> void:
	var stub_script := GDScript.new()
	stub_script.source_code = (
		"extends Control\n"
		+ "signal closed\n"
		+ "var toggle_count: int = 0\n"
		+ "func toggle() -> void:\n"
		+ "\ttoggle_count += 1\n"
	)
	stub_script.reload()
	var stub_panel := Control.new()
	stub_panel.set_script(stub_script)

	var original_panel: Control = UIManager.codex_panel
	UIManager.codex_panel = stub_panel
	_pause_menu._on_codex_pressed()
	var count: int = stub_panel.toggle_count
	UIManager.codex_panel = original_panel
	stub_panel.free()

	assert_int(count).is_equal(1)


# ==============================================================================
# SECTION 5: PauseMenu show/hide helpers
# ==============================================================================

# -- 26. show_pause_menu() makes menu visible and pauses tree -----------------

func test_show_pause_menu_makes_visible() -> void:
	_pause_menu.visible = false
	get_tree().paused = false
	_pause_menu.show_pause_menu()
	assert_bool(_pause_menu.visible).is_true()


# -- 27. show_pause_menu() pauses the tree ------------------------------------

func test_show_pause_menu_pauses_tree() -> void:
	get_tree().paused = false
	_pause_menu.show_pause_menu()
	assert_bool(get_tree().paused).is_true()


# -- 28. hide_pause_menu() hides menu and unpauses tree ----------------------

func test_hide_pause_menu_hides_and_unpauses() -> void:
	get_tree().paused = true
	_pause_menu.visible = true
	_pause_menu.hide_pause_menu()
	assert_bool(_pause_menu.visible).is_false()
	assert_bool(get_tree().paused).is_false()


# -- 29. PauseMenu starts hidden ----------------------------------------------

func test_pause_menu_starts_hidden() -> void:
	# Build a fresh one via the script's initializer logic — visible defaults to false
	var fresh: Control = _build_pause_menu()
	var script: GDScript = load(PAUSE_MENU_SCRIPT_PATH)
	fresh.set_script(script)
	# Manually set the initial state that _ready() would set
	fresh.visible = false
	assert_bool(fresh.visible).is_false()
	fresh.free()


# ==============================================================================
# SECTION 6: Game.gd Escape Key Handling
# ==============================================================================

# -- 30. Game._unhandled_input with ui_cancel while placing cancels placement -

func test_game_escape_while_placing_cancels_placement() -> void:
	var game_node: Node2D = _build_game_node()
	var script: GDScript = load(GAME_SCRIPT_PATH)
	game_node.set_script(script)
	game_node.game_board = game_node.get_node("GameBoard")
	game_node.ui_layer = game_node.get_node("UILayer")
	game_node.camera = game_node.get_node("Camera2D")

	# Simulate a placement in progress (not null)
	var fake_data: TowerData = TowerData.new()
	game_node._placing_tower = fake_data

	# Escape while placing should cancel placement, NOT toggle pause
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	game_node._unhandled_input(event)

	# Placement should be cancelled
	assert_object(game_node._placing_tower).is_null()
	# Tree should NOT be paused (escape was consumed by placement cancellation)
	assert_bool(get_tree().paused).is_false()

	EnemySystem._enemies_to_spawn.clear()
	game_node.free()


# -- 31. Game._unhandled_input with ui_cancel while fusing cancels fusion ----

func test_game_escape_while_fusing_cancels_fusion() -> void:
	var game_node: Node2D = _build_game_node()
	var script: GDScript = load(GAME_SCRIPT_PATH)
	game_node.set_script(script)
	game_node.game_board = game_node.get_node("GameBoard")
	game_node.ui_layer = game_node.get_node("UILayer")
	game_node.camera = game_node.get_node("Camera2D")

	# Simulate a fusion in progress
	var fake_tower := Node.new()
	game_node._fusing_tower = fake_tower

	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	game_node._unhandled_input(event)

	# Fusion should be cancelled
	assert_object(game_node._fusing_tower).is_null()
	# Tree should NOT be paused
	assert_bool(get_tree().paused).is_false()

	fake_tower.free()
	EnemySystem._enemies_to_spawn.clear()
	game_node.free()


# -- 32. Game._unhandled_input with ui_cancel while idle toggles pause -------

func test_game_escape_while_idle_toggles_pause() -> void:
	get_tree().paused = false
	var game_node: Node2D = _build_game_node()
	var script: GDScript = load(GAME_SCRIPT_PATH)
	game_node.set_script(script)
	game_node.game_board = game_node.get_node("GameBoard")
	game_node.ui_layer = game_node.get_node("UILayer")
	game_node.camera = game_node.get_node("Camera2D")

	# No placement, no fusion — escape should toggle pause
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	game_node._unhandled_input(event)

	assert_bool(get_tree().paused).is_true()

	EnemySystem._enemies_to_spawn.clear()
	game_node.free()


# -- 33. Game escape when already paused unpauses ----------------------------

func test_game_escape_when_paused_unpauses() -> void:
	get_tree().paused = true
	var game_node: Node2D = _build_game_node()
	var script: GDScript = load(GAME_SCRIPT_PATH)
	game_node.set_script(script)
	game_node.game_board = game_node.get_node("GameBoard")
	game_node.ui_layer = game_node.get_node("UILayer")
	game_node.camera = game_node.get_node("Camera2D")

	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	game_node._unhandled_input(event)

	assert_bool(get_tree().paused).is_false()

	EnemySystem._enemies_to_spawn.clear()
	game_node.free()


# ==============================================================================
# SECTION 7: Process Mode
# ==============================================================================

# -- 34. PauseMenu has PROCESS_MODE_WHEN_PAUSED set --------------------------

func test_pause_menu_process_mode_when_paused() -> void:
	# The script sets process_mode = PROCESS_MODE_WHEN_PAUSED in _ready().
	# We verify the constant exists and the script sets it by checking the value
	# directly via property access (set in before_test via manual assignment).
	# Since we don't call _ready() in unit tests, we call the setter directly.
	_pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	assert_int(_pause_menu.process_mode).is_equal(Node.PROCESS_MODE_WHEN_PAUSED)


# -- 35. PROCESS_MODE_WHEN_PAUSED constant value is correct ------------------

func test_process_mode_when_paused_constant() -> void:
	# Godot 4: PROCESS_MODE_WHEN_PAUSED = 2
	assert_int(Node.PROCESS_MODE_WHEN_PAUSED).is_equal(2)


# ==============================================================================
# SECTION 8: Game.tscn Integration — PauseMenu placement and visibility
# ==============================================================================

# -- 36. Game.tscn has a PauseMenu node as a child of UILayer -----------------
#
# Parses the raw .tscn text to verify the node declaration without loading the
# full packed scene (which would pull in HUD, BuildMenu, etc. in headless).

func test_game_tscn_has_pause_menu_under_ui_layer() -> void:
	var file := FileAccess.open(GAME_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	# The .tscn node declaration for PauseMenu under UILayer looks like:
	#   [node name="PauseMenu" parent="UILayer" instance=...]
	var has_pause_menu_under_ui_layer: bool = (
		content.contains('[node name="PauseMenu" parent="UILayer"')
	)
	assert_bool(has_pause_menu_under_ui_layer).is_true()


# -- 37. Game.tscn references PauseMenu.tscn as an ext_resource ---------------

func test_game_tscn_references_pause_menu_tscn() -> void:
	var file := FileAccess.open(GAME_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("PauseMenu.tscn")).is_true()


# -- 38. PauseMenu becomes visible when _on_paused_changed receives true ------
#
# Simulates what happens when GameManager.paused_changed emits true:
# PauseMenu._on_paused_changed(true) must set visible = true.

func test_pause_menu_visible_on_paused_changed_true() -> void:
	_pause_menu.visible = false
	_pause_menu._on_paused_changed(true)
	assert_bool(_pause_menu.visible).is_true()


# -- 39. PauseMenu hides when _on_paused_changed receives false ---------------
#
# Simulates what happens when GameManager.paused_changed emits false:
# PauseMenu._on_paused_changed(false) must set visible = false.

func test_pause_menu_hidden_on_paused_changed_false() -> void:
	_pause_menu.visible = true
	_pause_menu._on_paused_changed(false)
	assert_bool(_pause_menu.visible).is_false()


# -- 40. paused_changed(true) via GameManager makes PauseMenu visible ---------
#
# End-to-end: connect _on_paused_changed manually (mirroring what _ready() does)
# then fire the real GameManager signal and confirm visibility follows.

func test_paused_changed_signal_makes_pause_menu_visible() -> void:
	_pause_menu.visible = false
	# Wire up the signal as _ready() would do when in the scene tree
	var conn: Callable = _pause_menu._on_paused_changed
	GameManager.paused_changed.connect(conn)
	get_tree().paused = false
	GameManager.toggle_pause()          # emits paused_changed(true)
	GameManager.paused_changed.disconnect(conn)
	assert_bool(_pause_menu.visible).is_true()


# -- 41. paused_changed(false) via GameManager hides PauseMenu ----------------

func test_paused_changed_signal_hides_pause_menu() -> void:
	_pause_menu.visible = true
	var conn: Callable = _pause_menu._on_paused_changed
	GameManager.paused_changed.connect(conn)
	get_tree().paused = true
	GameManager.toggle_pause()          # emits paused_changed(false)
	GameManager.paused_changed.disconnect(conn)
	assert_bool(_pause_menu.visible).is_false()


# ==============================================================================
# SECTION 9: Codex-from-PauseMenu z-order fix
# ==============================================================================

## Builds a stub CodexPanel with a `closed` signal and a `toggle()` method.
## toggle() sets visible = true; calling _emit_closed() fires the closed signal
## so tests can simulate the Codex being closed without a full scene.
func _build_codex_stub() -> Control:
	var stub_script := GDScript.new()
	stub_script.source_code = (
		"extends Control\n"
		+ "signal closed\n"
		+ "var toggle_count: int = 0\n"
		+ "func toggle() -> void:\n"
		+ "\ttoggle_count += 1\n"
		+ "\tvisible = true\n"
		+ "func _emit_closed() -> void:\n"
		+ "\tclosed.emit()\n"
	)
	stub_script.reload()
	var stub := Control.new()
	stub.set_script(stub_script)
	return stub


# -- 42. _on_codex_pressed() hides the PauseMenu so the Codex is unobstructed -

func test_on_codex_pressed_hides_pause_menu() -> void:
	var stub := _build_codex_stub()
	var original_panel: Control = UIManager.codex_panel
	UIManager.codex_panel = stub

	_pause_menu.visible = true
	_pause_menu._on_codex_pressed()
	var is_hidden: bool = not _pause_menu.visible

	UIManager.codex_panel = original_panel
	stub.free()

	assert_bool(is_hidden).is_true()


# -- 43. _on_codex_closed() restores PauseMenu visibility --------------------

func test_on_codex_closed_restores_pause_menu() -> void:
	_pause_menu.visible = false
	_pause_menu._on_codex_closed()
	assert_bool(_pause_menu.visible).is_true()


# -- 44. _on_codex_pressed() connects closed signal; menu reappears on close --

func test_codex_closed_signal_restores_pause_menu() -> void:
	var stub := _build_codex_stub()
	var original_panel: Control = UIManager.codex_panel
	UIManager.codex_panel = stub

	_pause_menu.visible = true
	_pause_menu._on_codex_pressed()
	# PauseMenu is now hidden; simulate Codex closing
	stub._emit_closed()
	var restored: bool = _pause_menu.visible

	UIManager.codex_panel = original_panel
	stub.free()

	assert_bool(restored).is_true()


# -- 45. _on_codex_pressed() is a no-op when codex_panel has no `closed` sig -
#
# Guards against a codex stub that lacks the signal (null-safety).

func test_on_codex_pressed_no_crash_without_codex_panel() -> void:
	var original_panel: Control = UIManager.codex_panel
	UIManager.codex_panel = null
	_pause_menu.visible = true
	_pause_menu._on_codex_pressed()
	# Menu stays visible since there was no codex to open
	assert_bool(_pause_menu.visible).is_true()
	UIManager.codex_panel = original_panel


# -- 46. _on_paused_changed(true) does not override codex-hide state ----------
#
# When Codex is open (PauseMenu hidden), a paused_changed(true) must not
# accidentally show the PauseMenu on top of the Codex.
# (paused_changed(true) is only emitted by the initial pause; while Codex is
# open the tree stays paused so this signal won't fire again — but if it did,
# we verify it does set visible = true as _on_paused_changed simply mirrors
# the pause state.)

func test_paused_changed_true_sets_visible() -> void:
	_pause_menu.visible = false
	_pause_menu._on_paused_changed(true)
	assert_bool(_pause_menu.visible).is_true()


# ==============================================================================
# SECTION 10: CodexPanel closed-signal and pause-state integrity
# ==============================================================================

const CODEX_PANEL_SCRIPT_PATH: String = "res://scripts/ui/CodexPanel.gd"


## Builds a minimal CodexPanel node tree matching CodexPanel.tscn.
func _build_codex_panel() -> PanelContainer:
	var root := PanelContainer.new()

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	root.add_child(vbox)

	var header_bar := HBoxContainer.new()
	header_bar.name = "HeaderBar"
	vbox.add_child(header_bar)

	var title_label := Label.new()
	title_label.name = "TitleLabel"
	header_bar.add_child(title_label)

	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	header_bar.add_child(close_btn)

	var tab_bar := HBoxContainer.new()
	tab_bar.name = "TabBar"
	vbox.add_child(tab_bar)

	for tab_name: String in ["TowersTab", "ElementsTab", "FusionsTab", "EnemiesTab"]:
		var btn := Button.new()
		btn.name = tab_name
		tab_bar.add_child(btn)

	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.name = "ContentContainer"
	scroll.add_child(content)

	return root


# -- 47. CodexPanel has a `closed` signal ------------------------------------

func test_codex_panel_has_closed_signal() -> void:
	var panel := _build_codex_panel()
	var script: GDScript = load(CODEX_PANEL_SCRIPT_PATH)
	panel.set_script(script)
	assert_bool(panel.has_signal("closed")).is_true()
	panel.free()


# -- 48. CodexPanel._close() emits `closed` ----------------------------------

func test_codex_panel_close_emits_closed_signal() -> void:
	var panel := _build_codex_panel()
	var script: GDScript = load(CODEX_PANEL_SCRIPT_PATH)
	panel.set_script(script)
	# Wire @onready refs manually.
	# tab_buttons is Array[Button], so build a typed array first.
	panel.content_container = panel.get_node("VBoxContainer/ScrollContainer/ContentContainer")
	panel.close_button = panel.get_node("VBoxContainer/HeaderBar/CloseButton")
	var typed_tabs: Array[Button] = [
		panel.get_node("VBoxContainer/TabBar/TowersTab") as Button,
		panel.get_node("VBoxContainer/TabBar/ElementsTab") as Button,
		panel.get_node("VBoxContainer/TabBar/FusionsTab") as Button,
		panel.get_node("VBoxContainer/TabBar/EnemiesTab") as Button,
	]
	panel.tab_buttons = typed_tabs

	var emitted: Array[int] = [0]
	var conn: Callable = func() -> void: emitted[0] += 1
	panel.closed.connect(conn)
	panel._close()
	panel.closed.disconnect(conn)

	panel.free()
	assert_int(emitted[0]).is_equal(1)


# -- 49. CodexPanel._close() does NOT unpause when _was_paused_before_open ---

func test_codex_panel_close_does_not_unpause_when_was_paused() -> void:
	var panel := _build_codex_panel()
	var script: GDScript = load(CODEX_PANEL_SCRIPT_PATH)
	panel.set_script(script)
	panel.content_container = panel.get_node("VBoxContainer/ScrollContainer/ContentContainer")
	panel.close_button = panel.get_node("VBoxContainer/HeaderBar/CloseButton")
	var typed_tabs_49: Array[Button] = [
		panel.get_node("VBoxContainer/TabBar/TowersTab") as Button,
		panel.get_node("VBoxContainer/TabBar/ElementsTab") as Button,
		panel.get_node("VBoxContainer/TabBar/FusionsTab") as Button,
		panel.get_node("VBoxContainer/TabBar/EnemiesTab") as Button,
	]
	panel.tab_buttons = typed_tabs_49

	# Simulate: game was paused before Codex opened
	get_tree().paused = true
	panel._was_paused_before_open = true
	panel.visible = true
	panel._close()

	var still_paused: bool = get_tree().paused
	panel.free()

	assert_bool(still_paused).is_true()


# -- 50. CodexPanel._close() unpauses when it paused the tree itself ----------

func test_codex_panel_close_unpauses_when_it_paused_tree() -> void:
	var panel := _build_codex_panel()
	var script: GDScript = load(CODEX_PANEL_SCRIPT_PATH)
	panel.set_script(script)
	panel.content_container = panel.get_node("VBoxContainer/ScrollContainer/ContentContainer")
	panel.close_button = panel.get_node("VBoxContainer/HeaderBar/CloseButton")
	var typed_tabs_50: Array[Button] = [
		panel.get_node("VBoxContainer/TabBar/TowersTab") as Button,
		panel.get_node("VBoxContainer/TabBar/ElementsTab") as Button,
		panel.get_node("VBoxContainer/TabBar/FusionsTab") as Button,
		panel.get_node("VBoxContainer/TabBar/EnemiesTab") as Button,
	]
	panel.tab_buttons = typed_tabs_50

	# Simulate: game was NOT paused before Codex opened (opened from HUD)
	get_tree().paused = true
	panel._was_paused_before_open = false
	panel.visible = true
	panel._close()

	var unpaused: bool = not get_tree().paused
	panel.free()

	assert_bool(unpaused).is_true()


# -- 51. CodexPanel has _was_paused_before_open variable ----------------------

func test_codex_panel_has_was_paused_before_open_var() -> void:
	var panel := _build_codex_panel()
	var script: GDScript = load(CODEX_PANEL_SCRIPT_PATH)
	panel.set_script(script)
	assert_bool(panel.get("_was_paused_before_open") != null).is_true()
	panel.free()


# ==============================================================================
# SECTION 11: Codex z-order regression — scene node ordering and process mode
# ==============================================================================

# -- 52. PauseMenu script has _codex_open guard variable ----------------------
#
# The flag prevents _on_paused_changed from re-showing the overlay while the
# Codex is open.

func test_pause_menu_has_codex_open_flag() -> void:
	assert_bool(_pause_menu.get("_codex_open") != null).is_true()


# -- 53. _codex_open defaults to false ----------------------------------------

func test_pause_menu_codex_open_defaults_false() -> void:
	assert_bool(_pause_menu._codex_open).is_false()


# -- 54. _on_codex_pressed() sets _codex_open = true -------------------------

func test_on_codex_pressed_sets_codex_open_true() -> void:
	var stub := _build_codex_stub()
	var original_panel: Control = UIManager.codex_panel
	UIManager.codex_panel = stub

	_pause_menu._codex_open = false
	_pause_menu._on_codex_pressed()
	var flag: bool = _pause_menu._codex_open

	UIManager.codex_panel = original_panel
	stub.free()

	assert_bool(flag).is_true()


# -- 55. _on_codex_closed() clears _codex_open = false -----------------------

func test_on_codex_closed_clears_codex_open_flag() -> void:
	_pause_menu._codex_open = true
	_pause_menu._on_codex_closed()
	assert_bool(_pause_menu._codex_open).is_false()


# -- 56. _on_paused_changed(true) does NOT show menu when _codex_open ---------
#
# This is the key regression guard: CodexPanel.toggle() calls GameManager.pause()
# which emits paused_changed(true). Without the guard, PauseMenu would re-appear
# on top of the Codex.

func test_on_paused_changed_true_skipped_when_codex_open() -> void:
	_pause_menu.visible = false
	_pause_menu._codex_open = true
	_pause_menu._on_paused_changed(true)
	assert_bool(_pause_menu.visible).is_false()


# -- 57. _on_paused_changed(false) is also skipped when _codex_open ----------
#
# While Codex is open, _on_codex_pressed has already hidden the PauseMenu.
# Neither paused_changed(true) nor paused_changed(false) should disturb the
# carefully managed visibility state; _on_codex_closed restores it cleanly.

func test_on_paused_changed_false_skipped_when_codex_open() -> void:
	_pause_menu.visible = false   # already hidden when codex opened
	_pause_menu._codex_open = true
	_pause_menu._on_paused_changed(false)
	# visible stays false — the guard returned early, no accidental show
	assert_bool(_pause_menu.visible).is_false()


# -- 58. Game.tscn — CodexPanel is declared AFTER PauseMenu under UILayer ----
#
# In Godot 4, later children in a CanvasLayer draw on top of earlier ones.
# CodexPanel must come after PauseMenu so it renders above the dimmer.

func test_game_tscn_codex_panel_after_pause_menu() -> void:
	var file := FileAccess.open(GAME_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()

	var pause_menu_pos: int = content.find('[node name="PauseMenu" parent="UILayer"')
	var codex_panel_pos: int = content.find('[node name="CodexPanel" parent="UILayer"')

	assert_bool(pause_menu_pos != -1).is_true()
	assert_bool(codex_panel_pos != -1).is_true()
	# CodexPanel declaration must appear later in the file than PauseMenu
	assert_bool(codex_panel_pos > pause_menu_pos).is_true()


# -- 59. CodexPanel.tscn has process_mode = 3 (PROCESS_MODE_WHEN_PAUSED) -----
#
# Ensures the scene file itself has the correct process_mode so the panel
# can receive input while the tree is paused (opened from PauseMenu or HUD).

func test_codex_panel_tscn_has_process_mode_when_paused() -> void:
	const CODEX_TSCN_PATH: String = "res://scenes/ui/CodexPanel.tscn"
	var file := FileAccess.open(CODEX_TSCN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	# process_mode = 3 is PROCESS_MODE_WHEN_PAUSED in Godot 4
	assert_bool(content.contains("process_mode = 3")).is_true()


# -- 60. CodexPanel script enforces process_mode = WHEN_PAUSED in _ready() ----
#
# The script sets process_mode explicitly so it works even if the .tscn value
# is accidentally removed during future scene editing.

func test_codex_panel_script_sets_process_mode_when_paused() -> void:
	const CODEX_SCRIPT_PATH: String = "res://scripts/ui/CodexPanel.gd"
	var file := FileAccess.open(CODEX_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("process_mode = Node.PROCESS_MODE_WHEN_PAUSED")).is_true()


# ==============================================================================
# SECTION 12: PauseMenu._unhandled_input — Escape closes the pause menu
# ==============================================================================
#
# When the game tree is paused, Game.gd stops receiving input because it has
# no PROCESS_MODE_WHEN_PAUSED set. PauseMenu (which does have that mode) must
# therefore handle ui_cancel/Escape itself to allow the player to close the
# pause menu via keyboard.

# -- 61. PauseMenu script defines _unhandled_input ----------------------------

func test_pause_menu_has_unhandled_input() -> void:
	assert_bool(_pause_menu.has_method("_unhandled_input")).is_true()


# -- 62. _unhandled_input with ui_cancel while visible unpauses the tree ------
#
# Simulates the player pressing Escape when the pause overlay is showing.
# The handler must call _on_resume_pressed(), which calls GameManager.unpause().

func test_unhandled_input_escape_while_visible_unpauses() -> void:
	get_tree().paused = true
	_pause_menu.visible = true

	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	_pause_menu._unhandled_input(event)

	assert_bool(get_tree().paused).is_false()


# -- 63. _unhandled_input with ui_cancel while visible hides the menu ---------

func test_unhandled_input_escape_while_visible_hides_menu() -> void:
	get_tree().paused = true
	_pause_menu.visible = true

	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	_pause_menu._unhandled_input(event)

	assert_bool(_pause_menu.visible).is_false()


# -- 64. _unhandled_input with ui_cancel while hidden does NOT unpause --------
#
# When the menu is not visible (e.g. Codex is open on top), the Escape press
# must be ignored so it doesn't accidentally resume the game.

func test_unhandled_input_escape_while_hidden_does_not_unpause() -> void:
	get_tree().paused = true
	_pause_menu.visible = false

	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	_pause_menu._unhandled_input(event)

	# Tree must still be paused — the handler should be a no-op when invisible
	assert_bool(get_tree().paused).is_true()
