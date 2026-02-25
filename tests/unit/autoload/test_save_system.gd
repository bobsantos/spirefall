extends GdUnitTestSuite

## Unit tests for Task D1: SaveSystem Autoload.
## Covers: default data structure, save/load, has_save, reset_save, get/update
## settings, get_progression, record_run, corrupt file handling, version field.

const TEST_SAVE_PATH: String = "user://test_save_data.json"


# -- Helpers -------------------------------------------------------------------

## Store the original save path and swap in the test path.
var _original_save_path: String


func _reset_save_system() -> void:
	SaveSystem._save_path = TEST_SAVE_PATH
	SaveSystem._data = SaveSystem._default_data()
	# Delete the test file if it exists
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_save_path = SaveSystem._save_path


func before_test() -> void:
	_reset_save_system()


func after_test() -> void:
	_reset_save_system()


func after() -> void:
	SaveSystem._save_path = _original_save_path
	# Reload original save data
	SaveSystem.load_save()


# -- 1. Default data structure -------------------------------------------------

func test_default_data_has_version() -> void:
	var data: Dictionary = SaveSystem._default_data()
	assert_int(data["version"]).is_equal(1)


func test_default_data_has_settings() -> void:
	var data: Dictionary = SaveSystem._default_data()
	assert_bool(data.has("settings")).is_true()
	assert_float(data["settings"]["master_volume"]).is_equal(1.0)
	assert_float(data["settings"]["sfx_volume"]).is_equal(1.0)
	assert_float(data["settings"]["music_volume"]).is_equal(0.8)


func test_default_data_has_progression() -> void:
	var data: Dictionary = SaveSystem._default_data()
	assert_bool(data.has("progression")).is_true()
	assert_int(data["progression"]["total_xp"]).is_equal(0)
	var maps: Array = data["progression"]["unlocked_maps"]
	assert_int(maps.size()).is_equal(1)
	assert_str(maps[0]).is_equal("forest_clearing")
	var modes: Array = data["progression"]["unlocked_modes"]
	assert_int(modes.size()).is_equal(1)
	assert_str(modes[0]).is_equal("classic")
	var history: Array = data["progression"]["run_history"]
	assert_int(history.size()).is_equal(0)


func test_default_data_has_stats() -> void:
	var data: Dictionary = SaveSystem._default_data()
	assert_bool(data.has("stats")).is_true()
	assert_int(data["stats"]["total_runs"]).is_equal(0)
	assert_int(data["stats"]["total_kills"]).is_equal(0)
	assert_int(data["stats"]["total_waves"]).is_equal(0)
	assert_int(data["stats"]["best_wave_classic"]).is_equal(0)


func test_default_settings_has_screen_shake() -> void:
	var data: Dictionary = SaveSystem._default_data()
	assert_bool(data["settings"]["screen_shake"]).is_true()


func test_default_settings_has_show_damage_numbers() -> void:
	var data: Dictionary = SaveSystem._default_data()
	assert_bool(data["settings"]["show_damage_numbers"]).is_true()


# -- 2. has_save ---------------------------------------------------------------

func test_has_save_false_when_no_file() -> void:
	assert_bool(SaveSystem.has_save()).is_false()


func test_has_save_true_after_save() -> void:
	SaveSystem.save()
	assert_bool(SaveSystem.has_save()).is_true()


# -- 3. save and load_save -----------------------------------------------------

func test_save_creates_file() -> void:
	SaveSystem.save()
	assert_bool(FileAccess.file_exists(TEST_SAVE_PATH)).is_true()


func test_load_save_restores_data() -> void:
	# Modify data, save, reset in memory, then load
	SaveSystem._data["settings"]["master_volume"] = 0.5
	SaveSystem.save()
	SaveSystem._data = SaveSystem._default_data()
	assert_float(SaveSystem._data["settings"]["master_volume"]).is_equal(1.0)
	SaveSystem.load_save()
	assert_float(SaveSystem._data["settings"]["master_volume"]).is_equal(0.5)


func test_load_save_uses_defaults_when_no_file() -> void:
	SaveSystem.load_save()
	assert_int(SaveSystem._data["version"]).is_equal(1)
	assert_float(SaveSystem._data["settings"]["master_volume"]).is_equal(1.0)


func test_save_writes_valid_json() -> void:
	SaveSystem.save()
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	assert_bool(parsed != null).is_true()
	assert_bool(parsed is Dictionary).is_true()


# -- 4. get_settings / get_progression -----------------------------------------

func test_get_settings_returns_settings_dict() -> void:
	var settings: Dictionary = SaveSystem.get_settings()
	assert_bool(settings.has("master_volume")).is_true()
	assert_bool(settings.has("sfx_volume")).is_true()
	assert_bool(settings.has("music_volume")).is_true()


func test_get_progression_returns_progression_dict() -> void:
	var prog: Dictionary = SaveSystem.get_progression()
	assert_bool(prog.has("total_xp")).is_true()
	assert_bool(prog.has("unlocked_maps")).is_true()
	assert_bool(prog.has("unlocked_modes")).is_true()
	assert_bool(prog.has("run_history")).is_true()


func test_get_stats_returns_stats_dict() -> void:
	var stats: Dictionary = SaveSystem.get_stats()
	assert_bool(stats.has("total_runs")).is_true()
	assert_bool(stats.has("total_kills")).is_true()
	assert_bool(stats.has("total_waves")).is_true()
	assert_bool(stats.has("best_wave_classic")).is_true()


# -- 5. update_settings -------------------------------------------------------

func test_update_settings_changes_value() -> void:
	SaveSystem.update_settings("master_volume", 0.3)
	assert_float(SaveSystem._data["settings"]["master_volume"]).is_equal(0.3)


func test_update_settings_auto_saves() -> void:
	SaveSystem.update_settings("sfx_volume", 0.7)
	# Verify it persists on disk by reloading
	SaveSystem._data = SaveSystem._default_data()
	SaveSystem.load_save()
	assert_float(SaveSystem._data["settings"]["sfx_volume"]).is_equal(0.7)


func test_update_settings_emits_signal() -> void:
	var emitted: Array[int] = [0]
	var conn: Callable = func() -> void: emitted[0] += 1
	SaveSystem.save_completed.connect(conn)
	SaveSystem.update_settings("music_volume", 0.5)
	SaveSystem.save_completed.disconnect(conn)
	assert_int(emitted[0]).is_equal(1)


# -- 6. reset_save -------------------------------------------------------------

func test_reset_save_restores_defaults() -> void:
	SaveSystem._data["settings"]["master_volume"] = 0.1
	SaveSystem._data["stats"]["total_runs"] = 99
	SaveSystem.save()
	SaveSystem.reset_save()
	assert_float(SaveSystem._data["settings"]["master_volume"]).is_equal(1.0)
	assert_int(SaveSystem._data["stats"]["total_runs"]).is_equal(0)


func test_reset_save_removes_file() -> void:
	SaveSystem.save()
	assert_bool(FileAccess.file_exists(TEST_SAVE_PATH)).is_true()
	SaveSystem.reset_save()
	assert_bool(FileAccess.file_exists(TEST_SAVE_PATH)).is_false()


# -- 7. record_run -------------------------------------------------------------

func test_record_run_appends_to_history() -> void:
	var run_data: Dictionary = {
		"waves_survived": 15,
		"enemies_killed": 200,
		"victory": false,
		"mode": "classic",
	}
	SaveSystem.record_run(run_data)
	var history: Array = SaveSystem._data["progression"]["run_history"]
	assert_int(history.size()).is_equal(1)
	assert_int(history[0]["waves_survived"]).is_equal(15)


func test_record_run_updates_total_runs() -> void:
	var run_data: Dictionary = {"waves_survived": 10, "enemies_killed": 50, "victory": false, "mode": "classic"}
	SaveSystem.record_run(run_data)
	assert_int(SaveSystem._data["stats"]["total_runs"]).is_equal(1)
	SaveSystem.record_run(run_data)
	assert_int(SaveSystem._data["stats"]["total_runs"]).is_equal(2)


func test_record_run_updates_total_kills() -> void:
	var run_data: Dictionary = {"waves_survived": 10, "enemies_killed": 50, "victory": false, "mode": "classic"}
	SaveSystem.record_run(run_data)
	assert_int(SaveSystem._data["stats"]["total_kills"]).is_equal(50)
	run_data["enemies_killed"] = 30
	SaveSystem.record_run(run_data)
	assert_int(SaveSystem._data["stats"]["total_kills"]).is_equal(80)


func test_record_run_updates_total_waves() -> void:
	var run_data: Dictionary = {"waves_survived": 10, "enemies_killed": 0, "victory": false, "mode": "classic"}
	SaveSystem.record_run(run_data)
	assert_int(SaveSystem._data["stats"]["total_waves"]).is_equal(10)


func test_record_run_updates_best_wave_classic() -> void:
	var run_data: Dictionary = {"waves_survived": 15, "enemies_killed": 0, "victory": false, "mode": "classic"}
	SaveSystem.record_run(run_data)
	assert_int(SaveSystem._data["stats"]["best_wave_classic"]).is_equal(15)
	# Lower wave doesn't replace best
	run_data["waves_survived"] = 5
	SaveSystem.record_run(run_data)
	assert_int(SaveSystem._data["stats"]["best_wave_classic"]).is_equal(15)
	# Higher wave replaces best
	run_data["waves_survived"] = 25
	SaveSystem.record_run(run_data)
	assert_int(SaveSystem._data["stats"]["best_wave_classic"]).is_equal(25)


func test_record_run_auto_saves() -> void:
	var run_data: Dictionary = {"waves_survived": 5, "enemies_killed": 10, "victory": false, "mode": "classic"}
	SaveSystem.record_run(run_data)
	# Verify it persists on disk
	SaveSystem._data = SaveSystem._default_data()
	SaveSystem.load_save()
	assert_int(SaveSystem._data["stats"]["total_runs"]).is_equal(1)


func test_record_run_limits_history_size() -> void:
	for i: int in range(110):
		var run_data: Dictionary = {"waves_survived": i, "enemies_killed": 0, "victory": false, "mode": "classic"}
		SaveSystem.record_run(run_data)
	var history: Array = SaveSystem._data["progression"]["run_history"]
	assert_int(history.size()).is_equal(100)
	# Oldest entries removed, newest kept
	assert_int(history[history.size() - 1]["waves_survived"]).is_equal(109)


# -- 8. Corrupt save file handling ---------------------------------------------

func test_corrupt_file_resets_to_defaults() -> void:
	# Write garbage to the save file
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string("NOT VALID JSON {{{")
	file.close()
	SaveSystem.load_save()
	# Should reset to defaults
	assert_int(SaveSystem._data["version"]).is_equal(1)
	assert_float(SaveSystem._data["settings"]["master_volume"]).is_equal(1.0)


func test_partial_data_fills_missing_keys() -> void:
	# Write a file with missing keys
	var partial: Dictionary = {"version": 1, "settings": {"master_volume": 0.5}}
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(partial))
	file.close()
	SaveSystem.load_save()
	# Preserved key
	assert_float(SaveSystem._data["settings"]["master_volume"]).is_equal(0.5)
	# Filled missing key from defaults
	assert_float(SaveSystem._data["settings"]["sfx_volume"]).is_equal(1.0)
	assert_bool(SaveSystem._data.has("progression")).is_true()
	assert_bool(SaveSystem._data.has("stats")).is_true()


# -- 9. Version field ----------------------------------------------------------

func test_version_is_preserved_on_save_load() -> void:
	SaveSystem.save()
	SaveSystem.load_save()
	assert_int(SaveSystem._data["version"]).is_equal(1)
