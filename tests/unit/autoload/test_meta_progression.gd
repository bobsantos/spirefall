extends GdUnitTestSuite

## Unit tests for Task E1: MetaProgression Autoload.
## Covers: XP calculation, award_xp, unlock thresholds, get_new_unlocks,
## signal emission, SaveSystem integration, and reset functionality.

const TEST_SAVE_PATH: String = "user://test_save_data_meta.json"

var _original_save_path: String


# -- Helpers -------------------------------------------------------------------

func _reset_save_system() -> void:
	SaveSystem._save_path = TEST_SAVE_PATH
	SaveSystem._data = SaveSystem._default_data()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


func _reset_meta_progression() -> void:
	MetaProgression.reset()


func _make_run_stats(
	waves: int = 0,
	kills: int = 0,
	gold: int = 0,
	victory: bool = false,
) -> Dictionary:
	return {
		"waves_survived": waves,
		"enemies_killed": kills,
		"total_gold_earned": gold,
		"victory": victory,
	}


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_save_path = SaveSystem._save_path


func before_test() -> void:
	_reset_save_system()
	_reset_meta_progression()


func after_test() -> void:
	_reset_meta_progression()
	_reset_save_system()


func after() -> void:
	SaveSystem._save_path = _original_save_path
	SaveSystem.load_save()


# -- 1. XP calculation --------------------------------------------------------

func test_calculate_run_xp_zero_stats() -> void:
	var xp: int = MetaProgression.calculate_run_xp(_make_run_stats())
	assert_int(xp).is_equal(0)


func test_calculate_run_xp_waves_only() -> void:
	var xp: int = MetaProgression.calculate_run_xp(_make_run_stats(10, 0, 0, false))
	# base_xp = 10 * 10 = 100
	assert_int(xp).is_equal(100)


func test_calculate_run_xp_kills_only() -> void:
	var xp: int = MetaProgression.calculate_run_xp(_make_run_stats(0, 50, 0, false))
	# kill_bonus = 50 * 1 = 50
	assert_int(xp).is_equal(50)


func test_calculate_run_xp_gold_only() -> void:
	var xp: int = MetaProgression.calculate_run_xp(_make_run_stats(0, 0, 350, false))
	# gold_bonus = floor(350 / 100) * 5 = 3 * 5 = 15
	assert_int(xp).is_equal(15)


func test_calculate_run_xp_gold_rounds_down() -> void:
	var xp: int = MetaProgression.calculate_run_xp(_make_run_stats(0, 0, 99, false))
	# floor(99 / 100) = 0, gold_bonus = 0
	assert_int(xp).is_equal(0)


func test_calculate_run_xp_victory_bonus() -> void:
	var xp: int = MetaProgression.calculate_run_xp(_make_run_stats(0, 0, 0, true))
	# victory_bonus = 200
	assert_int(xp).is_equal(200)


func test_calculate_run_xp_no_victory_bonus_on_defeat() -> void:
	var xp: int = MetaProgression.calculate_run_xp(_make_run_stats(0, 0, 0, false))
	assert_int(xp).is_equal(0)


func test_calculate_run_xp_full_formula() -> void:
	# 20 waves, 150 kills, 800 gold, victory
	var xp: int = MetaProgression.calculate_run_xp(_make_run_stats(20, 150, 800, true))
	# base_xp = 20 * 10 = 200
	# kill_bonus = 150 * 1 = 150
	# gold_bonus = floor(800 / 100) * 5 = 8 * 5 = 40
	# victory_bonus = 200
	# total = 200 + 150 + 40 + 200 = 590
	assert_int(xp).is_equal(590)


func test_calculate_run_xp_large_values() -> void:
	var xp: int = MetaProgression.calculate_run_xp(_make_run_stats(30, 500, 5000, true))
	# base_xp = 30 * 10 = 300
	# kill_bonus = 500 * 1 = 500
	# gold_bonus = floor(5000 / 100) * 5 = 50 * 5 = 250
	# victory_bonus = 200
	# total = 300 + 500 + 250 + 200 = 1250
	assert_int(xp).is_equal(1250)


func test_calculate_run_xp_missing_keys_treated_as_zero() -> void:
	var xp: int = MetaProgression.calculate_run_xp({})
	assert_int(xp).is_equal(0)


# -- 2. award_xp --------------------------------------------------------------

func test_award_xp_adds_to_total() -> void:
	MetaProgression.award_xp(100)
	assert_int(MetaProgression.get_total_xp()).is_equal(100)


func test_award_xp_accumulates() -> void:
	MetaProgression.award_xp(100)
	MetaProgression.award_xp(250)
	assert_int(MetaProgression.get_total_xp()).is_equal(350)


func test_award_xp_zero_does_not_change_total() -> void:
	MetaProgression.award_xp(100)
	MetaProgression.award_xp(0)
	assert_int(MetaProgression.get_total_xp()).is_equal(100)


func test_award_xp_persists_to_save_system() -> void:
	MetaProgression.award_xp(750)
	var prog: Dictionary = SaveSystem.get_progression()
	assert_int(int(prog["total_xp"])).is_equal(750)


func test_award_xp_saves_to_disk() -> void:
	MetaProgression.award_xp(300)
	# Verify data persists on disk by reloading
	SaveSystem._data = SaveSystem._default_data()
	SaveSystem.load_save()
	assert_int(int(SaveSystem._data["progression"]["total_xp"])).is_equal(300)


# -- 3. Unlock thresholds -----------------------------------------------------

func test_is_unlocked_default_nothing_unlocked() -> void:
	assert_bool(MetaProgression.is_unlocked("mode_draft")).is_false()
	assert_bool(MetaProgression.is_unlocked("map_mountain_pass")).is_false()
	assert_bool(MetaProgression.is_unlocked("mode_endless")).is_false()
	assert_bool(MetaProgression.is_unlocked("map_river_delta")).is_false()
	assert_bool(MetaProgression.is_unlocked("map_volcanic_caldera")).is_false()


func test_is_unlocked_unknown_id_returns_false() -> void:
	assert_bool(MetaProgression.is_unlocked("nonexistent_thing")).is_false()


func test_unlock_draft_at_exactly_500() -> void:
	MetaProgression.award_xp(500)
	assert_bool(MetaProgression.is_unlocked("mode_draft")).is_true()


func test_no_unlock_draft_at_499() -> void:
	MetaProgression.award_xp(499)
	assert_bool(MetaProgression.is_unlocked("mode_draft")).is_false()


func test_unlock_mountain_pass_at_1000() -> void:
	MetaProgression.award_xp(1000)
	assert_bool(MetaProgression.is_unlocked("map_mountain_pass")).is_true()


func test_unlock_endless_at_2000() -> void:
	MetaProgression.award_xp(2000)
	assert_bool(MetaProgression.is_unlocked("mode_endless")).is_true()


func test_unlock_river_delta_at_3000() -> void:
	MetaProgression.award_xp(3000)
	assert_bool(MetaProgression.is_unlocked("map_river_delta")).is_true()


func test_unlock_volcanic_caldera_at_6000() -> void:
	MetaProgression.award_xp(6000)
	assert_bool(MetaProgression.is_unlocked("map_volcanic_caldera")).is_true()


func test_all_unlocked_above_6000() -> void:
	MetaProgression.award_xp(10000)
	assert_bool(MetaProgression.is_unlocked("mode_draft")).is_true()
	assert_bool(MetaProgression.is_unlocked("map_mountain_pass")).is_true()
	assert_bool(MetaProgression.is_unlocked("mode_endless")).is_true()
	assert_bool(MetaProgression.is_unlocked("map_river_delta")).is_true()
	assert_bool(MetaProgression.is_unlocked("map_volcanic_caldera")).is_true()


func test_unlock_persists_to_save_system_maps() -> void:
	MetaProgression.award_xp(1000)
	var prog: Dictionary = SaveSystem.get_progression()
	var maps: Array = prog["unlocked_maps"]
	assert_bool(maps.has("map_mountain_pass")).is_true()


func test_unlock_persists_to_save_system_modes() -> void:
	MetaProgression.award_xp(500)
	var prog: Dictionary = SaveSystem.get_progression()
	var modes: Array = prog["unlocked_modes"]
	assert_bool(modes.has("mode_draft")).is_true()


func test_incremental_awards_trigger_unlock() -> void:
	MetaProgression.award_xp(200)
	assert_bool(MetaProgression.is_unlocked("mode_draft")).is_false()
	MetaProgression.award_xp(300)
	assert_bool(MetaProgression.is_unlocked("mode_draft")).is_true()


# -- 4. get_new_unlocks --------------------------------------------------------

func test_get_new_unlocks_crossing_500() -> void:
	var unlocks: Array[String] = MetaProgression.get_new_unlocks(400, 500)
	assert_int(unlocks.size()).is_equal(1)
	assert_str(unlocks[0]).is_equal("mode_draft")


func test_get_new_unlocks_crossing_multiple_thresholds() -> void:
	var unlocks: Array[String] = MetaProgression.get_new_unlocks(0, 2500)
	# Should unlock: mode_draft (500), map_mountain_pass (1000), mode_endless (2000)
	assert_int(unlocks.size()).is_equal(3)
	assert_bool(unlocks.has("mode_draft")).is_true()
	assert_bool(unlocks.has("map_mountain_pass")).is_true()
	assert_bool(unlocks.has("mode_endless")).is_true()


func test_get_new_unlocks_no_threshold_crossed() -> void:
	var unlocks: Array[String] = MetaProgression.get_new_unlocks(100, 200)
	assert_int(unlocks.size()).is_equal(0)


func test_get_new_unlocks_same_values() -> void:
	var unlocks: Array[String] = MetaProgression.get_new_unlocks(500, 500)
	assert_int(unlocks.size()).is_equal(0)


func test_get_new_unlocks_all_thresholds() -> void:
	var unlocks: Array[String] = MetaProgression.get_new_unlocks(0, 6000)
	assert_int(unlocks.size()).is_equal(5)


func test_get_new_unlocks_already_past_threshold() -> void:
	# Both values above 500 -- mode_draft should NOT appear
	var unlocks: Array[String] = MetaProgression.get_new_unlocks(600, 900)
	assert_int(unlocks.size()).is_equal(0)


# -- 5. Signal emission --------------------------------------------------------

func test_xp_awarded_signal_emitted() -> void:
	var emitted: Array[int] = [0]
	var received_amount: Array[int] = [0]
	var received_total: Array[int] = [0]
	var conn: Callable = func(amount: int, total: int) -> void:
		emitted[0] += 1
		received_amount[0] = amount
		received_total[0] = total
	MetaProgression.xp_awarded.connect(conn)
	MetaProgression.award_xp(250)
	MetaProgression.xp_awarded.disconnect(conn)
	assert_int(emitted[0]).is_equal(1)
	assert_int(received_amount[0]).is_equal(250)
	assert_int(received_total[0]).is_equal(250)


func test_xp_awarded_signal_cumulative_total() -> void:
	MetaProgression.award_xp(100)
	var received_total: Array[int] = [0]
	var conn: Callable = func(_amount: int, total: int) -> void:
		received_total[0] = total
	MetaProgression.xp_awarded.connect(conn)
	MetaProgression.award_xp(200)
	MetaProgression.xp_awarded.disconnect(conn)
	assert_int(received_total[0]).is_equal(300)


func test_unlocked_signal_emitted() -> void:
	var unlock_ids: Array[String] = []
	var conn: Callable = func(unlock_id: String) -> void:
		unlock_ids.append(unlock_id)
	MetaProgression.unlocked.connect(conn)
	MetaProgression.award_xp(500)
	MetaProgression.unlocked.disconnect(conn)
	assert_int(unlock_ids.size()).is_equal(1)
	assert_str(unlock_ids[0]).is_equal("mode_draft")


func test_unlocked_signal_multiple_unlocks() -> void:
	var unlock_ids: Array[String] = []
	var conn: Callable = func(unlock_id: String) -> void:
		unlock_ids.append(unlock_id)
	MetaProgression.unlocked.connect(conn)
	MetaProgression.award_xp(6000)
	MetaProgression.unlocked.disconnect(conn)
	assert_int(unlock_ids.size()).is_equal(5)


func test_unlocked_signal_not_emitted_below_threshold() -> void:
	var emitted: Array[int] = [0]
	var conn: Callable = func(_id: String) -> void:
		emitted[0] += 1
	MetaProgression.unlocked.connect(conn)
	MetaProgression.award_xp(100)
	MetaProgression.unlocked.disconnect(conn)
	assert_int(emitted[0]).is_equal(0)


func test_unlocked_signal_not_re_emitted_for_existing_unlock() -> void:
	MetaProgression.award_xp(600)
	# mode_draft already unlocked at 500
	var emitted: Array[int] = [0]
	var conn: Callable = func(_id: String) -> void:
		emitted[0] += 1
	MetaProgression.unlocked.connect(conn)
	MetaProgression.award_xp(100)
	MetaProgression.unlocked.disconnect(conn)
	assert_int(emitted[0]).is_equal(0)


# -- 6. SaveSystem integration ------------------------------------------------

func test_state_persists_across_reset_and_reload() -> void:
	MetaProgression.award_xp(1500)
	# Simulate restart: reset in-memory state and reload from disk
	SaveSystem._data = SaveSystem._default_data()
	SaveSystem.load_save()
	MetaProgression.reset()
	# Re-initialize from SaveSystem (as _ready() would do)
	MetaProgression._load_from_save()
	assert_int(MetaProgression.get_total_xp()).is_equal(1500)
	assert_bool(MetaProgression.is_unlocked("mode_draft")).is_true()
	assert_bool(MetaProgression.is_unlocked("map_mountain_pass")).is_true()


func test_unlock_maps_persisted_in_save_data() -> void:
	MetaProgression.award_xp(3000)
	var prog: Dictionary = SaveSystem.get_progression()
	var maps: Array = prog["unlocked_maps"]
	assert_bool(maps.has("map_mountain_pass")).is_true()
	assert_bool(maps.has("map_river_delta")).is_true()


func test_unlock_modes_persisted_in_save_data() -> void:
	MetaProgression.award_xp(2000)
	var prog: Dictionary = SaveSystem.get_progression()
	var modes: Array = prog["unlocked_modes"]
	assert_bool(modes.has("mode_draft")).is_true()
	assert_bool(modes.has("mode_endless")).is_true()


func test_no_duplicate_unlocks_in_save_data() -> void:
	MetaProgression.award_xp(300)
	MetaProgression.award_xp(300)
	# mode_draft crossed on second award (total 600)
	var prog: Dictionary = SaveSystem.get_progression()
	var modes: Array = prog["unlocked_modes"]
	var count: int = 0
	for m: String in modes:
		if m == "mode_draft":
			count += 1
	assert_int(count).is_equal(1)


# -- 7. Reset functionality ---------------------------------------------------

func test_reset_clears_total_xp() -> void:
	MetaProgression.award_xp(1000)
	MetaProgression.reset()
	assert_int(MetaProgression.get_total_xp()).is_equal(0)


func test_reset_clears_unlocks() -> void:
	MetaProgression.award_xp(6000)
	MetaProgression.reset()
	assert_bool(MetaProgression.is_unlocked("mode_draft")).is_false()
	assert_bool(MetaProgression.is_unlocked("map_mountain_pass")).is_false()
	assert_bool(MetaProgression.is_unlocked("mode_endless")).is_false()
	assert_bool(MetaProgression.is_unlocked("map_river_delta")).is_false()
	assert_bool(MetaProgression.is_unlocked("map_volcanic_caldera")).is_false()


func test_get_total_xp_default_zero() -> void:
	assert_int(MetaProgression.get_total_xp()).is_equal(0)
