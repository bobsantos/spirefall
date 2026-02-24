extends GdUnitTestSuite

## Unit tests for Task D2: SettingsManager Autoload.
## Covers: initial state from SaveSystem, set_volume, apply_all, settings_changed
## signal, persistence via SaveSystem, screen_shake and show_damage_numbers toggles.

const TEST_SAVE_PATH: String = "user://test_save_data_settings.json"

var _original_save_path: String


# -- Helpers -------------------------------------------------------------------

func _reset_settings_manager() -> void:
	SettingsManager.master_volume = 1.0
	SettingsManager.sfx_volume = 1.0
	SettingsManager.music_volume = 0.8
	SettingsManager.screen_shake = true
	SettingsManager.show_damage_numbers = true


func _reset_save_system() -> void:
	SaveSystem._save_path = TEST_SAVE_PATH
	SaveSystem._data = SaveSystem._default_data()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_save_path = SaveSystem._save_path


func before_test() -> void:
	_reset_save_system()
	_reset_settings_manager()


func after_test() -> void:
	_reset_settings_manager()
	_reset_save_system()


func after() -> void:
	SaveSystem._save_path = _original_save_path
	SaveSystem.load_save()


# -- 1. Initial state ----------------------------------------------------------

func test_default_master_volume() -> void:
	assert_float(SettingsManager.master_volume).is_equal(1.0)


func test_default_sfx_volume() -> void:
	assert_float(SettingsManager.sfx_volume).is_equal(1.0)


func test_default_music_volume() -> void:
	assert_float(SettingsManager.music_volume).is_equal(0.8)


func test_default_screen_shake() -> void:
	assert_bool(SettingsManager.screen_shake).is_true()


func test_default_show_damage_numbers() -> void:
	assert_bool(SettingsManager.show_damage_numbers).is_true()


# -- 2. load_from_save ---------------------------------------------------------

func test_load_from_save_reads_settings() -> void:
	SaveSystem._data["settings"]["master_volume"] = 0.5
	SaveSystem._data["settings"]["sfx_volume"] = 0.6
	SaveSystem._data["settings"]["music_volume"] = 0.3
	SaveSystem._data["settings"]["screen_shake"] = false
	SaveSystem._data["settings"]["show_damage_numbers"] = false
	SettingsManager.load_from_save()
	assert_float(SettingsManager.master_volume).is_equal(0.5)
	assert_float(SettingsManager.sfx_volume).is_equal(0.6)
	assert_float(SettingsManager.music_volume).is_equal(0.3)
	assert_bool(SettingsManager.screen_shake).is_false()
	assert_bool(SettingsManager.show_damage_numbers).is_false()


# -- 3. set_volume -------------------------------------------------------------

func test_set_volume_master_updates_property() -> void:
	SettingsManager.set_volume("Master", 0.5)
	assert_float(SettingsManager.master_volume).is_equal(0.5)


func test_set_volume_sfx_updates_property() -> void:
	SettingsManager.set_volume("SFX", 0.7)
	assert_float(SettingsManager.sfx_volume).is_equal(0.7)


func test_set_volume_music_updates_property() -> void:
	SettingsManager.set_volume("Music", 0.4)
	assert_float(SettingsManager.music_volume).is_equal(0.4)


func test_set_volume_applies_to_audio_bus() -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	SettingsManager.set_volume("Master", 0.5)
	# linear_to_db(0.5) should give approximately -6.02 dB
	var expected_db: float = linear_to_db(0.5)
	var actual_db: float = AudioServer.get_bus_volume_db(bus_idx)
	assert_float(actual_db).is_equal_approx(expected_db, 0.01)


func test_set_volume_zero_mutes_bus() -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	SettingsManager.set_volume("Master", 0.0)
	assert_bool(AudioServer.is_bus_mute(bus_idx)).is_true()


func test_set_volume_nonzero_unmutes_bus() -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	SettingsManager.set_volume("Master", 0.0)
	assert_bool(AudioServer.is_bus_mute(bus_idx)).is_true()
	SettingsManager.set_volume("Master", 0.8)
	assert_bool(AudioServer.is_bus_mute(bus_idx)).is_false()


func test_set_volume_clamps_to_0_1() -> void:
	SettingsManager.set_volume("Master", 1.5)
	assert_float(SettingsManager.master_volume).is_equal(1.0)
	SettingsManager.set_volume("Master", -0.5)
	assert_float(SettingsManager.master_volume).is_equal(0.0)


func test_set_volume_emits_settings_changed() -> void:
	var emitted: Array[int] = [0]
	var conn: Callable = func() -> void: emitted[0] += 1
	SettingsManager.settings_changed.connect(conn)
	SettingsManager.set_volume("Master", 0.5)
	SettingsManager.settings_changed.disconnect(conn)
	assert_int(emitted[0]).is_equal(1)


func test_set_volume_saves_to_save_system() -> void:
	SettingsManager.set_volume("Music", 0.3)
	assert_float(SaveSystem._data["settings"]["music_volume"]).is_equal(0.3)


# -- 4. set_screen_shake / set_show_damage_numbers -----------------------------

func test_set_screen_shake_updates_property() -> void:
	SettingsManager.set_screen_shake(false)
	assert_bool(SettingsManager.screen_shake).is_false()


func test_set_screen_shake_emits_signal() -> void:
	var emitted: Array[int] = [0]
	var conn: Callable = func() -> void: emitted[0] += 1
	SettingsManager.settings_changed.connect(conn)
	SettingsManager.set_screen_shake(false)
	SettingsManager.settings_changed.disconnect(conn)
	assert_int(emitted[0]).is_equal(1)


func test_set_screen_shake_saves() -> void:
	SettingsManager.set_screen_shake(false)
	assert_bool(SaveSystem._data["settings"]["screen_shake"]).is_false()


func test_set_show_damage_numbers_updates_property() -> void:
	SettingsManager.set_show_damage_numbers(false)
	assert_bool(SettingsManager.show_damage_numbers).is_false()


func test_set_show_damage_numbers_emits_signal() -> void:
	var emitted: Array[int] = [0]
	var conn: Callable = func() -> void: emitted[0] += 1
	SettingsManager.settings_changed.connect(conn)
	SettingsManager.set_show_damage_numbers(false)
	SettingsManager.settings_changed.disconnect(conn)
	assert_int(emitted[0]).is_equal(1)


func test_set_show_damage_numbers_saves() -> void:
	SettingsManager.set_show_damage_numbers(false)
	assert_bool(SaveSystem._data["settings"]["show_damage_numbers"]).is_false()


# -- 5. apply_all --------------------------------------------------------------

# -- 7. reset_to_defaults -------------------------------------------------------

func test_reset_to_defaults_restores_master_volume() -> void:
	SettingsManager.master_volume = 0.3
	SettingsManager.reset_to_defaults()
	assert_float(SettingsManager.master_volume).is_equal(1.0)


func test_reset_to_defaults_restores_sfx_volume() -> void:
	SettingsManager.sfx_volume = 0.4
	SettingsManager.reset_to_defaults()
	assert_float(SettingsManager.sfx_volume).is_equal(1.0)


func test_reset_to_defaults_restores_music_volume() -> void:
	SettingsManager.music_volume = 0.2
	SettingsManager.reset_to_defaults()
	assert_float(SettingsManager.music_volume).is_equal(0.8)


func test_reset_to_defaults_restores_screen_shake() -> void:
	SettingsManager.screen_shake = false
	SettingsManager.reset_to_defaults()
	assert_bool(SettingsManager.screen_shake).is_true()


func test_reset_to_defaults_restores_damage_numbers() -> void:
	SettingsManager.show_damage_numbers = false
	SettingsManager.reset_to_defaults()
	assert_bool(SettingsManager.show_damage_numbers).is_true()


func test_reset_to_defaults_emits_settings_changed() -> void:
	var emitted: Array[int] = [0]
	var conn: Callable = func() -> void: emitted[0] += 1
	SettingsManager.settings_changed.connect(conn)
	SettingsManager.reset_to_defaults()
	SettingsManager.settings_changed.disconnect(conn)
	assert_int(emitted[0]).is_equal(1)


func test_reset_to_defaults_applies_audio_buses() -> void:
	SettingsManager.master_volume = 0.3
	SettingsManager.sfx_volume = 0.4
	SettingsManager.music_volume = 0.2
	SettingsManager.reset_to_defaults()
	var master_idx: int = AudioServer.get_bus_index("Master")
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	var music_idx: int = AudioServer.get_bus_index("Music")
	assert_float(AudioServer.get_bus_volume_db(master_idx)).is_equal_approx(linear_to_db(1.0), 0.01)
	assert_float(AudioServer.get_bus_volume_db(sfx_idx)).is_equal_approx(linear_to_db(1.0), 0.01)
	assert_float(AudioServer.get_bus_volume_db(music_idx)).is_equal_approx(linear_to_db(0.8), 0.01)


# -- 5. apply_all --------------------------------------------------------------

func test_apply_all_sets_all_bus_volumes() -> void:
	SettingsManager.master_volume = 0.5
	SettingsManager.sfx_volume = 0.6
	SettingsManager.music_volume = 0.4
	SettingsManager.apply_all()
	var master_idx: int = AudioServer.get_bus_index("Master")
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	var music_idx: int = AudioServer.get_bus_index("Music")
	assert_float(AudioServer.get_bus_volume_db(master_idx)).is_equal_approx(linear_to_db(0.5), 0.01)
	assert_float(AudioServer.get_bus_volume_db(sfx_idx)).is_equal_approx(linear_to_db(0.6), 0.01)
	assert_float(AudioServer.get_bus_volume_db(music_idx)).is_equal_approx(linear_to_db(0.4), 0.01)


# -- 6. Persistence round-trip -------------------------------------------------

func test_settings_persist_through_save_load_cycle() -> void:
	SettingsManager.set_volume("Master", 0.3)
	SettingsManager.set_volume("SFX", 0.4)
	SettingsManager.set_volume("Music", 0.5)
	SettingsManager.set_screen_shake(false)
	SettingsManager.set_show_damage_numbers(false)
	# Reset in-memory and reload from disk
	_reset_settings_manager()
	SaveSystem.load_save()
	SettingsManager.load_from_save()
	assert_float(SettingsManager.master_volume).is_equal(0.3)
	assert_float(SettingsManager.sfx_volume).is_equal(0.4)
	assert_float(SettingsManager.music_volume).is_equal(0.5)
	assert_bool(SettingsManager.screen_shake).is_false()
	assert_bool(SettingsManager.show_damage_numbers).is_false()
