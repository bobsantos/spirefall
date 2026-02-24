class_name SaveSystemClass
extends Node

## Persistent save/load system using JSON at user://save_data.json.
## Stores settings, progression, and stats. Auto-loads on _ready().

signal save_completed()

const MAX_RUN_HISTORY: int = 100

var _save_path: String = "user://save_data.json"
var _data: Dictionary = {}


func _ready() -> void:
	_data = _default_data()
	load_save()


## Returns the default save data structure.
func _default_data() -> Dictionary:
	return {
		"version": 1,
		"settings": {
			"master_volume": 1.0,
			"sfx_volume": 1.0,
			"music_volume": 0.8,
			"screen_shake": true,
			"show_damage_numbers": true,
		},
		"progression": {
			"total_xp": 0,
			"unlocked_maps": ["forest_clearing"],
			"unlocked_modes": ["classic"],
			"run_history": [],
		},
		"stats": {
			"total_runs": 0,
			"total_kills": 0,
			"total_waves": 0,
			"best_wave_classic": 0,
		},
	}


## Serialize data to JSON and write to user://.
func save() -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveSystem: Failed to open save file for writing: %s" % _save_path)
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()
	save_completed.emit()


## Read from user://, parse JSON, populate data. Falls back to defaults on error.
func load_save() -> void:
	if not FileAccess.file_exists(_save_path):
		_data = _default_data()
		return

	var file := FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		push_warning("SaveSystem: Failed to open save file for reading.")
		_data = _default_data()
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_warning("SaveSystem: Corrupt save file detected. Resetting to defaults.")
		_data = _default_data()
		return

	# Merge with defaults to fill any missing keys
	_data = _merge_with_defaults(parsed as Dictionary)
	_normalize_int_fields()


## Returns true if a save file exists on disk.
func has_save() -> bool:
	return FileAccess.file_exists(_save_path)


## Reset save data to defaults and remove the file from disk.
func reset_save() -> void:
	_data = _default_data()
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)


## Returns the settings sub-dictionary.
func get_settings() -> Dictionary:
	return _data.get("settings", _default_data()["settings"])


## Returns the progression sub-dictionary.
func get_progression() -> Dictionary:
	return _data.get("progression", _default_data()["progression"])


## Returns the stats sub-dictionary.
func get_stats() -> Dictionary:
	return _data.get("stats", _default_data()["stats"])


## Update a single setting key and auto-save.
func update_settings(key: String, value: Variant) -> void:
	_data["settings"][key] = value
	save()


## Record a completed run: append to history, update aggregate stats, auto-save.
func record_run(run_data: Dictionary) -> void:
	# Append to run history
	_data["progression"]["run_history"].append(run_data)

	# Trim history to max size (remove oldest)
	while _data["progression"]["run_history"].size() > MAX_RUN_HISTORY:
		_data["progression"]["run_history"].pop_front()

	# Update aggregate stats
	var stats: Dictionary = _data["stats"]
	stats["total_runs"] += 1
	stats["total_kills"] += run_data.get("enemies_killed", 0)
	stats["total_waves"] += run_data.get("waves_survived", 0)

	# Update best wave for classic mode
	if run_data.get("mode", "") == "classic":
		var waves: int = run_data.get("waves_survived", 0)
		if waves > stats["best_wave_classic"]:
			stats["best_wave_classic"] = waves

	save()


## JSON parses all numbers as float. Normalize known integer fields back to int.
func _normalize_int_fields() -> void:
	var int_stats: Array[String] = ["total_runs", "total_kills", "total_waves", "best_wave_classic"]
	for key: String in int_stats:
		if _data["stats"].has(key):
			_data["stats"][key] = int(_data["stats"][key])
	var int_prog: Array[String] = ["total_xp"]
	for key: String in int_prog:
		if _data["progression"].has(key):
			_data["progression"][key] = int(_data["progression"][key])
	_data["version"] = int(_data.get("version", 1))


## Deep-merge loaded data with defaults so missing keys get filled.
func _merge_with_defaults(loaded: Dictionary) -> Dictionary:
	var defaults: Dictionary = _default_data()
	var result: Dictionary = defaults.duplicate(true)

	# Top-level keys
	for key: String in defaults:
		if not loaded.has(key):
			continue
		if defaults[key] is Dictionary and loaded[key] is Dictionary:
			# Merge sub-dictionary
			for sub_key: String in (defaults[key] as Dictionary):
				if loaded[key].has(sub_key):
					result[key][sub_key] = loaded[key][sub_key]
			# Also preserve extra keys from loaded data
			for sub_key: String in (loaded[key] as Dictionary):
				if not defaults[key].has(sub_key):
					result[key][sub_key] = loaded[key][sub_key]
		else:
			result[key] = loaded[key]

	return result
