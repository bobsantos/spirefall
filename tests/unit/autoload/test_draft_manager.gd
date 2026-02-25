extends GdUnitTestSuite

## Unit tests for DraftManager autoload.
## Covers: initial state, start_draft, get_draft_choices, pick_element,
## is_tower_available (base/fusion/legendary), reset, wave triggers, round system,
## multi-pick rounds, and edge cases.


# -- Helpers -------------------------------------------------------------------

func _reset_draft_manager() -> void:
	DraftManager.drafted_elements.clear()
	DraftManager.is_draft_active = false
	DraftManager.picks_remaining = 0
	DraftManager._current_round = 0
	DraftManager._picks_this_round = 0
	DraftManager._picks_needed_this_round = 0


func _reset_game_manager() -> void:
	GameManager.game_state = GameManager.GameState.MENU
	GameManager.current_wave = 0
	GameManager.lives = GameManager.starting_lives
	GameManager._build_timer = 0.0
	GameManager._combat_timer = 0.0
	GameManager._combat_timer_max = 0.0
	GameManager._enemies_leaked_this_wave = 0


func _reset_enemy_system() -> void:
	EnemySystem._active_enemies.clear()
	EnemySystem._wave_finished_spawning = false
	EnemySystem._enemies_to_spawn.clear()
	EnemySystem._spawn_timer = 0.0


func _make_tower_data(element: String, tier: int = 1, fusion_elements: Array[String] = []) -> TowerData:
	var td: TowerData = TowerData.new()
	td.element = element
	td.tier = tier
	td.fusion_elements = fusion_elements
	return td


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_reset_draft_manager()
	_reset_game_manager()
	_reset_enemy_system()


func after_test() -> void:
	_reset_draft_manager()
	# Unpause if any test triggered game over
	if get_tree().paused:
		get_tree().paused = false
	# Free any enemy nodes spawned by EnemySystem._process()
	for enemy: Node in EnemySystem._active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.free()
	EnemySystem._active_enemies.clear()
	EnemySystem._enemies_to_spawn.clear()


# -- 1. Initial State ----------------------------------------------------------

func test_initial_state_is_inactive() -> void:
	assert_bool(DraftManager.is_draft_active).is_false()


func test_initial_drafted_elements_empty() -> void:
	assert_int(DraftManager.drafted_elements.size()).is_equal(0)


func test_initial_picks_remaining_zero() -> void:
	assert_int(DraftManager.picks_remaining).is_equal(0)


# -- 2. Constants --------------------------------------------------------------

func test_draft_rounds_constant() -> void:
	assert_int(DraftManager.DRAFT_ROUNDS.size()).is_equal(3)
	# Round 0: wave 0, pick 1
	assert_int(DraftManager.DRAFT_ROUNDS[0][0]).is_equal(0)
	assert_int(DraftManager.DRAFT_ROUNDS[0][1]).is_equal(1)
	# Round 1: wave 5, pick 1
	assert_int(DraftManager.DRAFT_ROUNDS[1][0]).is_equal(5)
	assert_int(DraftManager.DRAFT_ROUNDS[1][1]).is_equal(1)
	# Round 2: wave 10, pick 2
	assert_int(DraftManager.DRAFT_ROUNDS[2][0]).is_equal(10)
	assert_int(DraftManager.DRAFT_ROUNDS[2][1]).is_equal(2)


func test_choices_per_pick_constant() -> void:
	assert_int(DraftManager.CHOICES_PER_PICK).is_equal(3)


# -- 3. start_draft() ---------------------------------------------------------

func test_start_draft_activates() -> void:
	DraftManager.start_draft()
	assert_bool(DraftManager.is_draft_active).is_true()


func test_start_draft_no_pre_assigned_element() -> void:
	DraftManager.start_draft()
	assert_int(DraftManager.drafted_elements.size()).is_equal(0)


func test_start_draft_sets_picks_remaining_to_four() -> void:
	DraftManager.start_draft()
	assert_int(DraftManager.picks_remaining).is_equal(4)


func test_start_draft_emits_started_with_empty_string() -> void:
	var emitted_elements: Array[String] = []
	var conn: Callable = func(el: String) -> void: emitted_elements.append(el)
	DraftManager.draft_started.connect(conn)
	DraftManager.start_draft()
	DraftManager.draft_started.disconnect(conn)
	assert_int(emitted_elements.size()).is_equal(1)
	assert_str(emitted_elements[0]).is_equal("")


func test_start_draft_emits_pick_available_with_three_choices() -> void:
	var emitted_choices: Array = []
	var emitted_pick_counts: Array[int] = []
	var conn: Callable = func(choices: Array[String], pick_count: int) -> void:
		emitted_choices.append(choices)
		emitted_pick_counts.append(pick_count)
	DraftManager.draft_pick_available.connect(conn)
	DraftManager.start_draft()
	DraftManager.draft_pick_available.disconnect(conn)
	assert_int(emitted_choices.size()).is_equal(1)
	assert_int(emitted_choices[0].size()).is_equal(3)
	assert_int(emitted_pick_counts[0]).is_equal(1)


func test_start_draft_initializes_round_zero() -> void:
	DraftManager.start_draft()
	assert_int(DraftManager._current_round).is_equal(0)
	assert_int(DraftManager._picks_this_round).is_equal(0)
	assert_int(DraftManager._picks_needed_this_round).is_equal(1)


# -- 4. get_draft_choices() ----------------------------------------------------

func test_get_draft_choices_returns_correct_count() -> void:
	DraftManager.start_draft()
	var choices: Array[String] = DraftManager.get_draft_choices()
	assert_int(choices.size()).is_equal(DraftManager.CHOICES_PER_PICK)


func test_get_draft_choices_excludes_drafted() -> void:
	DraftManager.start_draft()
	DraftManager.pick_element("fire")
	var choices: Array[String] = DraftManager.get_draft_choices()
	assert_bool("fire" in choices).is_false()


func test_get_draft_choices_all_valid_elements() -> void:
	DraftManager.start_draft()
	var choices: Array[String] = DraftManager.get_draft_choices()
	for choice: String in choices:
		assert_bool(choice in ElementMatrix.ELEMENTS).is_true()


func test_get_draft_choices_no_duplicates() -> void:
	DraftManager.start_draft()
	var choices: Array[String] = DraftManager.get_draft_choices()
	var unique: Dictionary = {}
	for c: String in choices:
		unique[c] = true
	assert_int(unique.size()).is_equal(choices.size())


# -- 5. pick_element() --------------------------------------------------------

func test_pick_element_adds_to_drafted() -> void:
	DraftManager.start_draft()
	var choices: Array[String] = DraftManager.get_draft_choices()
	var pick: String = choices[0]
	DraftManager.pick_element(pick)
	assert_bool(pick in DraftManager.drafted_elements).is_true()


func test_pick_element_decrements_picks_remaining() -> void:
	DraftManager.start_draft()
	assert_int(DraftManager.picks_remaining).is_equal(4)
	var choices: Array[String] = DraftManager.get_draft_choices()
	DraftManager.pick_element(choices[0])
	assert_int(DraftManager.picks_remaining).is_equal(3)


func test_pick_element_increments_picks_this_round() -> void:
	DraftManager.start_draft()
	assert_int(DraftManager._picks_this_round).is_equal(0)
	var choices: Array[String] = DraftManager.get_draft_choices()
	DraftManager.pick_element(choices[0])
	assert_int(DraftManager._picks_this_round).is_equal(1)


func test_pick_element_emits_signal() -> void:
	DraftManager.start_draft()
	var choices: Array[String] = DraftManager.get_draft_choices()
	var pick: String = choices[0]
	var emitted: Array[String] = []
	var conn: Callable = func(el: String) -> void: emitted.append(el)
	DraftManager.element_drafted.connect(conn)
	DraftManager.pick_element(pick)
	DraftManager.element_drafted.disconnect(conn)
	assert_int(emitted.size()).is_equal(1)
	assert_str(emitted[0]).is_equal(pick)


func test_pick_element_ignored_when_no_picks() -> void:
	DraftManager.start_draft()
	# Exhaust picks
	DraftManager.picks_remaining = 0
	var size_before: int = DraftManager.drafted_elements.size()
	DraftManager.pick_element("water")
	assert_int(DraftManager.drafted_elements.size()).is_equal(size_before)


func test_pick_element_ignored_for_already_drafted() -> void:
	DraftManager.start_draft()
	# Pick fire first, then try to pick it again
	DraftManager.pick_element("fire")
	var picks_before: int = DraftManager.picks_remaining
	DraftManager.pick_element("fire")
	# Should not add duplicate or decrement picks
	assert_int(DraftManager.picks_remaining).is_equal(picks_before)
	# Count occurrences
	var count: int = 0
	for el: String in DraftManager.drafted_elements:
		if el == "fire":
			count += 1
	assert_int(count).is_equal(1)


# -- 6. is_tower_available() for base towers -----------------------------------

func test_is_tower_available_base_tower_drafted() -> void:
	DraftManager.drafted_elements = ["fire"] as Array[String]
	DraftManager.is_draft_active = true
	var td: TowerData = _make_tower_data("fire", 1)
	assert_bool(DraftManager.is_tower_available(td)).is_true()


func test_is_tower_available_base_tower_not_drafted() -> void:
	DraftManager.drafted_elements = ["fire"] as Array[String]
	DraftManager.is_draft_active = true
	var td: TowerData = _make_tower_data("water", 1)
	assert_bool(DraftManager.is_tower_available(td)).is_false()


func test_is_tower_available_when_draft_inactive() -> void:
	# When draft mode is not active, all towers are available
	DraftManager.is_draft_active = false
	var td: TowerData = _make_tower_data("water", 1)
	assert_bool(DraftManager.is_tower_available(td)).is_true()


# -- 7. is_tower_available() for fusion towers ---------------------------------

func test_is_tower_available_fusion_both_elements_drafted() -> void:
	DraftManager.drafted_elements = ["fire", "earth"] as Array[String]
	DraftManager.is_draft_active = true
	var fe: Array[String] = ["fire", "earth"]
	var td: TowerData = _make_tower_data("fire", 2, fe)
	assert_bool(DraftManager.is_tower_available(td)).is_true()


func test_is_tower_available_fusion_missing_element() -> void:
	DraftManager.drafted_elements = ["fire"] as Array[String]
	DraftManager.is_draft_active = true
	var fe: Array[String] = ["fire", "earth"]
	var td: TowerData = _make_tower_data("fire", 2, fe)
	assert_bool(DraftManager.is_tower_available(td)).is_false()


func test_is_tower_available_fusion_no_elements_drafted() -> void:
	DraftManager.drafted_elements = ["wind"] as Array[String]
	DraftManager.is_draft_active = true
	var fe: Array[String] = ["fire", "earth"]
	var td: TowerData = _make_tower_data("fire", 2, fe)
	assert_bool(DraftManager.is_tower_available(td)).is_false()


# -- 8. is_tower_available() for legendary towers ------------------------------

func test_is_tower_available_legendary_all_elements_drafted() -> void:
	DraftManager.drafted_elements = ["fire", "earth", "water"] as Array[String]
	DraftManager.is_draft_active = true
	var fe: Array[String] = ["fire", "earth", "water"]
	var td: TowerData = _make_tower_data("fire", 3, fe)
	assert_bool(DraftManager.is_tower_available(td)).is_true()


func test_is_tower_available_legendary_missing_one() -> void:
	DraftManager.drafted_elements = ["fire", "earth"] as Array[String]
	DraftManager.is_draft_active = true
	var fe: Array[String] = ["fire", "earth", "water"]
	var td: TowerData = _make_tower_data("fire", 3, fe)
	assert_bool(DraftManager.is_tower_available(td)).is_false()


# -- 9. reset() ---------------------------------------------------------------

func test_reset_clears_drafted_elements() -> void:
	DraftManager.start_draft()
	DraftManager.pick_element("fire")
	assert_int(DraftManager.drafted_elements.size()).is_greater(0)
	DraftManager.reset()
	assert_int(DraftManager.drafted_elements.size()).is_equal(0)


func test_reset_deactivates_draft() -> void:
	DraftManager.start_draft()
	assert_bool(DraftManager.is_draft_active).is_true()
	DraftManager.reset()
	assert_bool(DraftManager.is_draft_active).is_false()


func test_reset_zeroes_picks_remaining() -> void:
	DraftManager.start_draft()
	DraftManager.reset()
	assert_int(DraftManager.picks_remaining).is_equal(0)


func test_reset_clears_round_state() -> void:
	DraftManager.start_draft()
	DraftManager.pick_element("fire")
	DraftManager.reset()
	assert_int(DraftManager._current_round).is_equal(0)
	assert_int(DraftManager._picks_this_round).is_equal(0)
	assert_int(DraftManager._picks_needed_this_round).is_equal(0)


# -- 10. Wave completion triggers draft_pick_available -------------------------

func test_wave_5_triggers_draft_pick_available() -> void:
	DraftManager.start_draft()
	# Pick the first element so round 0 is complete
	DraftManager.pick_element("fire")
	assert_int(DraftManager.picks_remaining).is_greater(0)
	var emitted_choices: Array = []
	var emitted_pick_counts: Array[int] = []
	var conn: Callable = func(choices: Array[String], pick_count: int) -> void:
		emitted_choices.append(choices)
		emitted_pick_counts.append(pick_count)
	DraftManager.draft_pick_available.connect(conn)
	# Simulate wave 5 completed
	GameManager.wave_completed.emit(5)
	DraftManager.draft_pick_available.disconnect(conn)
	assert_int(emitted_choices.size()).is_equal(1)
	# The emitted choices should have CHOICES_PER_PICK elements
	assert_int(emitted_choices[0].size()).is_equal(DraftManager.CHOICES_PER_PICK)
	# Round 1 needs 1 pick
	assert_int(emitted_pick_counts[0]).is_equal(1)


func test_wave_10_triggers_draft_pick_available_with_pick_count_2() -> void:
	DraftManager.start_draft()
	# Pick two elements (round 0 at start, round 1 at wave 5)
	DraftManager.pick_element("fire")
	GameManager.wave_completed.emit(5)
	DraftManager.pick_element("water")
	assert_int(DraftManager.picks_remaining).is_greater(0)
	var emitted_choices: Array = []
	var emitted_pick_counts: Array[int] = []
	var conn: Callable = func(c: Array[String], pc: int) -> void:
		emitted_choices.append(c)
		emitted_pick_counts.append(pc)
	DraftManager.draft_pick_available.connect(conn)
	GameManager.wave_completed.emit(10)
	DraftManager.draft_pick_available.disconnect(conn)
	assert_int(emitted_choices.size()).is_equal(1)
	# Round 2 needs 2 picks
	assert_int(emitted_pick_counts[0]).is_equal(2)


func test_non_draft_wave_does_not_trigger() -> void:
	DraftManager.start_draft()
	var emitted_count: Array[int] = [0]
	var conn: Callable = func(_c: Array[String], _pc: int) -> void: emitted_count[0] += 1
	DraftManager.draft_pick_available.connect(conn)
	GameManager.wave_completed.emit(3)
	DraftManager.draft_pick_available.disconnect(conn)
	assert_int(emitted_count[0]).is_equal(0)


func test_draft_wave_no_picks_remaining_does_not_trigger() -> void:
	DraftManager.start_draft()
	DraftManager.picks_remaining = 0
	var emitted_count: Array[int] = [0]
	var conn: Callable = func(_c: Array[String], _pc: int) -> void: emitted_count[0] += 1
	DraftManager.draft_pick_available.connect(conn)
	GameManager.wave_completed.emit(5)
	DraftManager.draft_pick_available.disconnect(conn)
	assert_int(emitted_count[0]).is_equal(0)


func test_draft_inactive_wave_does_not_trigger() -> void:
	# Draft not started -- wave_completed should not trigger anything
	var emitted_count: Array[int] = [0]
	var conn: Callable = func(_c: Array[String], _pc: int) -> void: emitted_count[0] += 1
	DraftManager.draft_pick_available.connect(conn)
	GameManager.wave_completed.emit(5)
	DraftManager.draft_pick_available.disconnect(conn)
	assert_int(emitted_count[0]).is_equal(0)


# -- 11. Round system ----------------------------------------------------------

func test_round_0_needs_1_pick() -> void:
	DraftManager.start_draft()
	assert_int(DraftManager._picks_needed_this_round).is_equal(1)


func test_round_0_complete_after_1_pick() -> void:
	DraftManager.start_draft()
	DraftManager.pick_element("fire")
	assert_bool(DraftManager.is_round_complete()).is_true()


func test_wave_5_advances_to_round_1() -> void:
	DraftManager.start_draft()
	DraftManager.pick_element("fire")
	GameManager.wave_completed.emit(5)
	assert_int(DraftManager._current_round).is_equal(1)
	assert_int(DraftManager._picks_needed_this_round).is_equal(1)
	assert_int(DraftManager._picks_this_round).is_equal(0)


func test_wave_10_advances_to_round_2() -> void:
	DraftManager.start_draft()
	DraftManager.pick_element("fire")
	GameManager.wave_completed.emit(5)
	DraftManager.pick_element("water")
	GameManager.wave_completed.emit(10)
	assert_int(DraftManager._current_round).is_equal(2)
	assert_int(DraftManager._picks_needed_this_round).is_equal(2)
	assert_int(DraftManager._picks_this_round).is_equal(0)


func test_round_2_needs_2_picks_to_complete() -> void:
	DraftManager.start_draft()
	DraftManager.pick_element("fire")
	GameManager.wave_completed.emit(5)
	DraftManager.pick_element("water")
	GameManager.wave_completed.emit(10)
	# First pick of round 2
	DraftManager.pick_element("earth")
	assert_bool(DraftManager.is_round_complete()).is_false()
	# Second pick of round 2
	DraftManager.pick_element("wind")
	assert_bool(DraftManager.is_round_complete()).is_true()


func test_wave_10_choices_exclude_already_drafted() -> void:
	DraftManager.start_draft()
	DraftManager.pick_element("fire")
	GameManager.wave_completed.emit(5)
	DraftManager.pick_element("water")
	var emitted_choices: Array = []
	var conn: Callable = func(c: Array[String], _pc: int) -> void: emitted_choices.append(c)
	DraftManager.draft_pick_available.connect(conn)
	GameManager.wave_completed.emit(10)
	DraftManager.draft_pick_available.disconnect(conn)
	# Choices should not include fire or water
	assert_bool("fire" not in emitted_choices[0]).is_true()
	assert_bool("water" not in emitted_choices[0]).is_true()


# -- 12. Edge cases ------------------------------------------------------------

func test_get_choices_with_five_elements_drafted() -> void:
	# With 5 of 6 elements drafted, only 1 remains -- choices should be size 1
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["fire", "water", "earth", "wind", "lightning"] as Array[String]
	DraftManager.picks_remaining = 1
	var choices: Array[String] = DraftManager.get_draft_choices()
	assert_int(choices.size()).is_equal(1)
	assert_str(choices[0]).is_equal("ice")


func test_get_choices_with_all_six_drafted() -> void:
	# All 6 drafted -- no choices available
	DraftManager.is_draft_active = true
	DraftManager.drafted_elements = ["fire", "water", "earth", "wind", "lightning", "ice"] as Array[String]
	DraftManager.picks_remaining = 1
	var choices: Array[String] = DraftManager.get_draft_choices()
	assert_int(choices.size()).is_equal(0)


func test_pick_invalid_element_ignored() -> void:
	DraftManager.start_draft()
	var picks_before: int = DraftManager.picks_remaining
	var size_before: int = DraftManager.drafted_elements.size()
	DraftManager.pick_element("invalid_element")
	assert_int(DraftManager.picks_remaining).is_equal(picks_before)
	assert_int(DraftManager.drafted_elements.size()).is_equal(size_before)


func test_is_tower_available_base_tower_uses_element_field() -> void:
	# Even for tier 1 with empty fusion_elements, element field is checked
	DraftManager.drafted_elements = ["wind", "ice"] as Array[String]
	DraftManager.is_draft_active = true
	var td: TowerData = _make_tower_data("wind", 1)
	assert_bool(DraftManager.is_tower_available(td)).is_true()
	td.element = "fire"
	assert_bool(DraftManager.is_tower_available(td)).is_false()


func test_full_draft_flow() -> void:
	# Simulate a complete draft: pick at start -> pick at wave 5 -> 2 picks at wave 10
	DraftManager.start_draft()
	assert_int(DraftManager.drafted_elements.size()).is_equal(0)
	assert_int(DraftManager.picks_remaining).is_equal(4)

	# Round 0: pick 1 element at game start
	DraftManager.pick_element("fire")
	assert_int(DraftManager.drafted_elements.size()).is_equal(1)
	assert_int(DraftManager.picks_remaining).is_equal(3)
	assert_bool(DraftManager.is_round_complete()).is_true()

	# Wave 5 round 1: pick 1 element
	GameManager.wave_completed.emit(5)
	assert_int(DraftManager._current_round).is_equal(1)
	var choices_1: Array[String] = DraftManager.get_draft_choices()
	assert_bool("fire" not in choices_1).is_true()
	DraftManager.pick_element(choices_1[0])
	assert_int(DraftManager.drafted_elements.size()).is_equal(2)
	assert_int(DraftManager.picks_remaining).is_equal(2)
	assert_bool(DraftManager.is_round_complete()).is_true()

	# Wave 10 round 2: pick 2 elements
	GameManager.wave_completed.emit(10)
	assert_int(DraftManager._current_round).is_equal(2)
	assert_int(DraftManager._picks_needed_this_round).is_equal(2)
	var choices_2: Array[String] = DraftManager.get_draft_choices()
	assert_bool("fire" not in choices_2).is_true()
	assert_bool(choices_1[0] not in choices_2).is_true()

	# First pick of round 2
	DraftManager.pick_element(choices_2[0])
	assert_int(DraftManager.drafted_elements.size()).is_equal(3)
	assert_int(DraftManager.picks_remaining).is_equal(1)
	assert_bool(DraftManager.is_round_complete()).is_false()

	# Second pick of round 2
	DraftManager.pick_element(choices_2[1])
	assert_int(DraftManager.drafted_elements.size()).is_equal(4)
	assert_int(DraftManager.picks_remaining).is_equal(0)
	assert_bool(DraftManager.is_round_complete()).is_true()
