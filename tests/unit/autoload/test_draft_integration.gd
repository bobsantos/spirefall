extends GdUnitTestSuite

## Integration tests for Draft mode wiring.
## Verifies GameManager.start_game() properly initializes/resets DraftManager
## and that Game.tscn includes DraftPickPanel in the UILayer.


# -- Helpers -------------------------------------------------------------------

func _reset_game_manager() -> void:
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = 0
	GameManager.lives = GameManager.starting_lives
	GameManager._build_timer = 0.0
	GameManager._combat_timer = 0.0
	GameManager._combat_timer_max = 0.0
	GameManager._enemies_leaked_this_wave = 0
	GameManager._game_running = false
	GameManager.run_stats = {}


func _reset_enemy_system() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn.clear()
	EnemySystem._spawn_timer = 0.0


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	DraftManager.reset()
	_reset_game_manager()
	_reset_enemy_system()
	EconomyManager.reset()


func after_test() -> void:
	DraftManager.reset()
	_reset_game_manager()
	_reset_enemy_system()
	if get_tree().paused:
		get_tree().paused = false
	# Free any enemy nodes spawned by EnemySystem._process()
	for enemy: Node in EnemySystem._active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.free()
	EnemySystem._active_enemies.clear()
	EnemySystem._enemies_to_spawn.clear()


# -- 1. Draft mode start_game initializes DraftManager -------------------------

func test_start_game_draft_activates_draft_manager() -> void:
	GameManager.start_game("draft")
	assert_bool(DraftManager.is_draft_active).is_true()


func test_start_game_draft_no_pre_assigned_element() -> void:
	GameManager.start_game("draft")
	assert_int(DraftManager.drafted_elements.size()).is_equal(0)


func test_start_game_draft_sets_picks_remaining_to_four() -> void:
	GameManager.start_game("draft")
	assert_int(DraftManager.picks_remaining).is_equal(4)


# -- 2. Non-draft modes reset DraftManager ------------------------------------

func test_start_game_classic_deactivates_draft() -> void:
	GameManager.start_game("classic")
	assert_bool(DraftManager.is_draft_active).is_false()


func test_start_game_classic_clears_drafted_elements() -> void:
	GameManager.start_game("classic")
	assert_int(DraftManager.drafted_elements.size()).is_equal(0)


func test_start_game_endless_deactivates_draft() -> void:
	GameManager.start_game("endless")
	assert_bool(DraftManager.is_draft_active).is_false()


func test_start_game_endless_clears_drafted_elements() -> void:
	GameManager.start_game("endless")
	assert_int(DraftManager.drafted_elements.size()).is_equal(0)


# -- 3. Classic after draft resets DraftManager --------------------------------

func test_classic_after_draft_resets_draft_active() -> void:
	GameManager.start_game("draft")
	assert_bool(DraftManager.is_draft_active).is_true()
	# Reset GameManager state so start_game can be called again cleanly
	_reset_game_manager()
	_reset_enemy_system()
	GameManager.start_game("classic")
	assert_bool(DraftManager.is_draft_active).is_false()


func test_classic_after_draft_clears_elements() -> void:
	GameManager.start_game("draft")
	# Simulate a pick so there's something to clear
	DraftManager.pick_element("fire")
	assert_int(DraftManager.drafted_elements.size()).is_greater(0)
	_reset_game_manager()
	_reset_enemy_system()
	GameManager.start_game("classic")
	assert_int(DraftManager.drafted_elements.size()).is_equal(0)


func test_classic_after_draft_clears_picks_remaining() -> void:
	GameManager.start_game("draft")
	assert_int(DraftManager.picks_remaining).is_greater(0)
	_reset_game_manager()
	_reset_enemy_system()
	GameManager.start_game("classic")
	assert_int(DraftManager.picks_remaining).is_equal(0)


# -- 4. Game.tscn scene structure ----------------------------------------------

func test_game_tscn_has_draft_pick_panel() -> void:
	var game_scene: PackedScene = load("res://scenes/main/Game.tscn")
	var game: Node = auto_free(game_scene.instantiate())
	var panel: Node = game.find_child("DraftPickPanel", true, false)
	assert_bool(panel != null).is_true()


func test_game_tscn_draft_pick_panel_under_ui_layer() -> void:
	var game_scene: PackedScene = load("res://scenes/main/Game.tscn")
	var game: Node = auto_free(game_scene.instantiate())
	var ui_layer: Node = game.find_child("UILayer", true, false)
	assert_bool(ui_layer != null).is_true()
	var panel: Node = ui_layer.find_child("DraftPickPanel", false, false)
	assert_bool(panel != null).is_true()


func test_game_tscn_draft_pick_panel_after_pause_menu() -> void:
	var game_scene: PackedScene = load("res://scenes/main/Game.tscn")
	var game: Node = auto_free(game_scene.instantiate())
	var ui_layer: Node = game.find_child("UILayer", true, false)
	var pause_idx: int = -1
	var draft_idx: int = -1
	for i: int in range(ui_layer.get_child_count()):
		var child: Node = ui_layer.get_child(i)
		if child.name == "PauseMenu":
			pause_idx = i
		elif child.name == "DraftPickPanel":
			draft_idx = i
	assert_bool(pause_idx >= 0).is_true()
	assert_bool(draft_idx >= 0).is_true()
	assert_bool(draft_idx > pause_idx).is_true()


func test_game_tscn_draft_pick_panel_starts_hidden_when_in_tree() -> void:
	# DraftPickPanel._ready() sets visible = false. Verify by adding to tree.
	var panel: DraftPickPanel = auto_free(DraftPickPanel.new())
	# Build the required child nodes so @onready resolves
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	var panel_container := PanelContainer.new()
	panel_container.name = "PanelContainer"
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	var title := Label.new()
	title.name = "TitleLabel"
	var cards := HBoxContainer.new()
	cards.name = "CardsContainer"
	vbox.add_child(title)
	vbox.add_child(cards)
	panel_container.add_child(vbox)
	center.add_child(panel_container)
	panel.add_child(center)
	add_child(panel)
	assert_bool(panel.visible).is_false()


# -- 5. DraftPickPanel signal connection ---------------------------------------

func test_draft_pick_panel_connects_to_draft_pick_available() -> void:
	# Build a DraftPickPanel with required children and add to tree so _ready() fires
	var panel: DraftPickPanel = auto_free(DraftPickPanel.new())
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	var panel_container := PanelContainer.new()
	panel_container.name = "PanelContainer"
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	var title := Label.new()
	title.name = "TitleLabel"
	var cards := HBoxContainer.new()
	cards.name = "CardsContainer"
	vbox.add_child(title)
	vbox.add_child(cards)
	panel_container.add_child(vbox)
	center.add_child(panel_container)
	panel.add_child(center)
	add_child(panel)
	# _ready() connects to DraftManager.draft_pick_available
	assert_bool(DraftManager.draft_pick_available.is_connected(panel._on_draft_pick_available)).is_true()


func test_draft_pick_panel_has_paused_process_mode() -> void:
	# process_mode = 2 (WHEN_PAUSED) is set in the .tscn and confirmed by _ready()
	var scene: PackedScene = load("res://scenes/ui/DraftPickPanel.tscn")
	var panel: Node = auto_free(scene.instantiate())
	# process_mode is set in .tscn (no need for tree entry)
	assert_int(panel.process_mode).is_equal(Node.PROCESS_MODE_WHEN_PAUSED)


# -- 6. Full draft flow integration -------------------------------------------

func test_full_draft_flow_four_elements() -> void:
	# Start draft mode
	GameManager.start_game("draft")
	assert_int(DraftManager.picks_remaining).is_equal(4)
	assert_int(DraftManager.drafted_elements.size()).is_equal(0)

	# Round 0: pick 1 element
	DraftManager.pick_element("fire")
	assert_int(DraftManager.drafted_elements.size()).is_equal(1)
	assert_int(DraftManager.picks_remaining).is_equal(3)

	# Wave 5: round 1, pick 1 element
	GameManager.wave_completed.emit(5)
	DraftManager.pick_element("water")
	assert_int(DraftManager.drafted_elements.size()).is_equal(2)
	assert_int(DraftManager.picks_remaining).is_equal(2)

	# Wave 10: round 2, pick 2 elements
	GameManager.wave_completed.emit(10)
	DraftManager.pick_element("earth")
	assert_int(DraftManager.drafted_elements.size()).is_equal(3)
	assert_int(DraftManager.picks_remaining).is_equal(1)
	DraftManager.pick_element("wind")
	assert_int(DraftManager.drafted_elements.size()).is_equal(4)
	assert_int(DraftManager.picks_remaining).is_equal(0)

	# 2 elements should be locked out
	var undrafted: int = 0
	for el: String in ElementMatrix.ELEMENTS:
		if el not in DraftManager.drafted_elements:
			undrafted += 1
	assert_int(undrafted).is_equal(2)
