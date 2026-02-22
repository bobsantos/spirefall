extends GdUnitTestSuite

## Unit tests for Task A5: Parameterized Game Launch.
## Covers: GameManager.GameMode enum, start_game(mode), Game._ready() config reading,
## dynamic map loading, fallback defaults, endless mode behavior.

const GAME_SCRIPT_PATH: String = "res://scripts/main/Game.gd"
const FOREST_MAP: String = "res://scenes/maps/ForestClearing.tscn"
const MOUNTAIN_MAP: String = "res://scenes/maps/MountainPass.tscn"


# -- Helpers -------------------------------------------------------------------

## Save original GameManager state for restoration.
var _original_max_waves: int
var _original_game_mode: int  # GameMode enum value


func _reset_game_manager() -> void:
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = 0
	GameManager.lives = GameManager.starting_lives
	GameManager._build_timer = 0.0
	GameManager._enemies_leaked_this_wave = 0
	GameManager.max_waves = _original_max_waves
	GameManager.current_mode = GameManager.GameMode.CLASSIC


func _reset_enemy_system() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn.clear()
	EnemySystem._spawn_timer = 0.0


## Simulate a wave being fully cleared by the EnemySystem.
func _simulate_wave_cleared() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = true
	EnemySystem._enemies_to_spawn.clear()


## Build a minimal Game node tree manually (mirrors Game.tscn structure)
## so tests don't depend on the .tscn and its packed UI scenes loading in headless.
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


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_max_waves = GameManager.max_waves


func before_test() -> void:
	_reset_game_manager()
	_reset_enemy_system()
	EconomyManager.reset()
	SceneManager.current_game_config = {}


func after_test() -> void:
	# Free any enemy nodes that EnemySystem._process() may have spawned
	for enemy: Node in EnemySystem._active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.free()
	EnemySystem._active_enemies.clear()
	EnemySystem._enemies_to_spawn.clear()
	# Restore GameManager state
	GameManager.max_waves = _original_max_waves
	GameManager.current_mode = GameManager.GameMode.CLASSIC


# ==============================================================================
# SECTION 1: GameManager.GameMode Enum
# ==============================================================================

# -- 1. GameMode enum exists with expected values ------------------------------

func test_game_mode_enum_has_classic() -> void:
	assert_int(GameManager.GameMode.CLASSIC).is_equal(0)


func test_game_mode_enum_has_draft() -> void:
	assert_int(GameManager.GameMode.DRAFT).is_equal(1)


func test_game_mode_enum_has_endless() -> void:
	assert_int(GameManager.GameMode.ENDLESS).is_equal(2)


# -- 2. current_mode defaults to CLASSIC ---------------------------------------

func test_current_mode_defaults_to_classic() -> void:
	assert_int(GameManager.current_mode).is_equal(GameManager.GameMode.CLASSIC)


# ==============================================================================
# SECTION 2: GameManager.start_game(mode) with mode parameter
# ==============================================================================

# -- 3. start_game with no args defaults to CLASSIC ----------------------------

func test_start_game_default_mode_classic() -> void:
	GameManager.start_game()
	assert_int(GameManager.current_mode).is_equal(GameManager.GameMode.CLASSIC)
	assert_int(GameManager.max_waves).is_equal(30)


# -- 4. start_game with "classic" sets CLASSIC mode ----------------------------

func test_start_game_classic_mode() -> void:
	GameManager.start_game("classic")
	assert_int(GameManager.current_mode).is_equal(GameManager.GameMode.CLASSIC)
	assert_int(GameManager.max_waves).is_equal(30)


# -- 5. start_game with "draft" sets DRAFT mode -------------------------------

func test_start_game_draft_mode() -> void:
	GameManager.start_game("draft")
	assert_int(GameManager.current_mode).is_equal(GameManager.GameMode.DRAFT)
	assert_int(GameManager.max_waves).is_equal(30)


# -- 6. start_game with "endless" sets ENDLESS mode and max_waves = 999 -------

func test_start_game_endless_mode() -> void:
	GameManager.start_game("endless")
	assert_int(GameManager.current_mode).is_equal(GameManager.GameMode.ENDLESS)
	assert_int(GameManager.max_waves).is_equal(999)


# -- 7. start_game still transitions to BUILD_PHASE ---------------------------

func test_start_game_with_mode_transitions_to_build() -> void:
	GameManager.start_game("classic")
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.BUILD_PHASE)
	assert_int(GameManager.current_wave).is_equal(1)


# -- 8. start_game with mode resets lives -------------------------------------

func test_start_game_with_mode_resets_lives() -> void:
	GameManager.lives = 5
	GameManager.start_game("endless")
	assert_int(GameManager.lives).is_equal(GameManager.starting_lives)


# -- 9. start_game unknown mode falls back to CLASSIC -------------------------

func test_start_game_unknown_mode_falls_back_to_classic() -> void:
	GameManager.start_game("unknown_mode")
	assert_int(GameManager.current_mode).is_equal(GameManager.GameMode.CLASSIC)
	assert_int(GameManager.max_waves).is_equal(30)


# ==============================================================================
# SECTION 3: Endless Mode Does Not End at Wave 30
# ==============================================================================

# -- 10. Endless mode: wave 30 cleared does not trigger GAME_OVER -------------

func test_endless_wave_30_does_not_end() -> void:
	GameManager.start_game("endless")
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 30
	_simulate_wave_cleared()
	GameManager._process(0.016)
	# Should NOT be game over -- should advance to next wave
	assert_int(GameManager.game_state).is_not_equal(GameManager.GameState.GAME_OVER)
	assert_int(GameManager.current_wave).is_equal(31)


# -- 11. Endless mode: wave 100 cleared continues playing ---------------------

func test_endless_wave_100_continues() -> void:
	GameManager.start_game("endless")
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 100
	_simulate_wave_cleared()
	GameManager._process(0.016)
	assert_int(GameManager.game_state).is_not_equal(GameManager.GameState.GAME_OVER)


# -- 12. Classic mode: wave 30 cleared triggers GAME_OVER ---------------------

func test_classic_wave_30_ends_game() -> void:
	GameManager.start_game("classic")
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 30
	_simulate_wave_cleared()
	GameManager._process(0.016)
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.GAME_OVER)


# -- 13. Endless mode: game_over victory check uses 999 max_waves -------------

func test_endless_game_over_victory_flag() -> void:
	GameManager.start_game("endless")
	# Simulate losing all lives
	var victory_values: Array[bool] = []
	var _conn: Callable = func(v: bool) -> void: victory_values.append(v)
	GameManager.game_over.connect(_conn)
	GameManager.lose_life(GameManager.lives)
	GameManager.game_over.disconnect(_conn)
	# Should be defeat (victory = false), since wave < 999
	assert_bool(victory_values[0]).is_false()


# ==============================================================================
# SECTION 4: Game._ready() Config Reading and Map Loading
# ==============================================================================

# -- 14. Game reads map from config and loads it into GameBoard ----------------

func test_game_loads_map_from_config() -> void:
	# Set config with a specific map path
	SceneManager.current_game_config = {"map": FOREST_MAP, "mode": "classic"}

	var game_node: Node2D = _build_game_node()
	var script: GDScript = load(GAME_SCRIPT_PATH)
	game_node.set_script(script)

	# Manually assign @onready vars
	game_node.game_board = game_node.get_node("GameBoard")
	game_node.ui_layer = game_node.get_node("UILayer")
	game_node.camera = game_node.get_node("Camera2D")

	# _load_map() is what we really want to test; call it directly
	# to avoid _ready() connecting signals to UIManager etc.
	game_node._load_map()

	# Clean up spawned enemies from start_game
	EnemySystem._enemies_to_spawn.clear()

	# GameBoard should have a child (the loaded map)
	assert_int(game_node.game_board.get_child_count()).is_greater(0)

	# Clean up
	game_node.game_board.get_child(0).free()
	game_node.free()


# -- 15. Game defaults to ForestClearing when config is empty ------------------

func test_game_defaults_to_forest_clearing_when_config_empty() -> void:
	SceneManager.current_game_config = {}

	var game_node: Node2D = _build_game_node()
	var script: GDScript = load(GAME_SCRIPT_PATH)
	game_node.set_script(script)

	game_node.game_board = game_node.get_node("GameBoard")
	game_node.ui_layer = game_node.get_node("UILayer")
	game_node.camera = game_node.get_node("Camera2D")

	game_node._load_map()

	EnemySystem._enemies_to_spawn.clear()

	# Should still have a child (ForestClearing as fallback)
	assert_int(game_node.game_board.get_child_count()).is_greater(0)

	game_node.game_board.get_child(0).free()
	game_node.free()


# -- 16. Game reads mode from config and passes to start_game -----------------

func test_game_reads_mode_from_config() -> void:
	SceneManager.current_game_config = {"mode": "endless"}

	var game_node: Node2D = _build_game_node()
	var script: GDScript = load(GAME_SCRIPT_PATH)
	game_node.set_script(script)

	game_node.game_board = game_node.get_node("GameBoard")
	game_node.ui_layer = game_node.get_node("UILayer")
	game_node.camera = game_node.get_node("Camera2D")

	# Call _start_game_from_config() which reads config and calls GameManager.start_game
	game_node._start_game_from_config()

	EnemySystem._enemies_to_spawn.clear()

	assert_int(GameManager.current_mode).is_equal(GameManager.GameMode.ENDLESS)
	assert_int(GameManager.max_waves).is_equal(999)

	game_node.free()


# -- 17. Game defaults to "classic" mode when config has no mode ---------------

func test_game_defaults_to_classic_when_no_mode_in_config() -> void:
	SceneManager.current_game_config = {"map": FOREST_MAP}

	var game_node: Node2D = _build_game_node()
	var script: GDScript = load(GAME_SCRIPT_PATH)
	game_node.set_script(script)

	game_node.game_board = game_node.get_node("GameBoard")
	game_node.ui_layer = game_node.get_node("UILayer")
	game_node.camera = game_node.get_node("Camera2D")

	game_node._start_game_from_config()

	EnemySystem._enemies_to_spawn.clear()

	assert_int(GameManager.current_mode).is_equal(GameManager.GameMode.CLASSIC)
	assert_int(GameManager.max_waves).is_equal(30)

	game_node.free()


# -- 18. Game _load_map uses config map path -----------------------------------

func test_game_load_map_uses_config_path() -> void:
	# Use a known map that exists
	SceneManager.current_game_config = {"map": FOREST_MAP}

	var game_node: Node2D = _build_game_node()
	var script: GDScript = load(GAME_SCRIPT_PATH)
	game_node.set_script(script)

	game_node.game_board = game_node.get_node("GameBoard")
	game_node.ui_layer = game_node.get_node("UILayer")
	game_node.camera = game_node.get_node("Camera2D")

	game_node._load_map()

	# The child should be a map instance
	var map_child: Node = game_node.game_board.get_child(0)
	assert_object(map_child).is_not_null()

	map_child.free()
	game_node.free()


# ==============================================================================
# SECTION 5: Draft Mode Sets Correct State
# ==============================================================================

# -- 19. start_game("draft") sets DRAFT mode with 30 waves --------------------

func test_draft_mode_has_30_waves() -> void:
	GameManager.start_game("draft")
	assert_int(GameManager.current_mode).is_equal(GameManager.GameMode.DRAFT)
	assert_int(GameManager.max_waves).is_equal(30)


# -- 20. Draft mode: wave 30 cleared triggers GAME_OVER -----------------------

func test_draft_wave_30_ends_game() -> void:
	GameManager.start_game("draft")
	GameManager.game_state = GameManager.GameState.COMBAT_PHASE
	GameManager.current_wave = 30
	_simulate_wave_cleared()
	GameManager._process(0.016)
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.GAME_OVER)


# ==============================================================================
# SECTION 6: Backward Compatibility
# ==============================================================================

# -- 21. Existing tests: start_game() with no args still works ----------------

func test_start_game_no_args_backward_compat() -> void:
	GameManager.start_game()
	assert_int(GameManager.game_state).is_equal(GameManager.GameState.BUILD_PHASE)
	assert_int(GameManager.current_wave).is_equal(1)
	assert_int(GameManager.lives).is_equal(20)
	assert_int(GameManager.current_mode).is_equal(GameManager.GameMode.CLASSIC)
	assert_int(GameManager.max_waves).is_equal(30)


# -- 22. start_game emits phase_changed signal with mode param ----------------

func test_start_game_with_mode_emits_phase_changed() -> void:
	var signal_count: Array[int] = [0]
	var _conn: Callable = func(_phase: int) -> void: signal_count[0] += 1
	GameManager.phase_changed.connect(_conn)
	GameManager.start_game("endless")
	GameManager.phase_changed.disconnect(_conn)
	assert_int(signal_count[0]).is_greater(0)
