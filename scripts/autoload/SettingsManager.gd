class_name SettingsManagerClass
extends Node

## Manages game settings (audio volumes, display prefs).
## Reads initial values from SaveSystem and persists changes back to it.

signal settings_changed()

var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 0.8
var screen_shake: bool = true
var show_damage_numbers: bool = true


func _ready() -> void:
	load_from_save()
	apply_all()


## Read settings from SaveSystem and apply them to local properties.
func load_from_save() -> void:
	var settings: Dictionary = SaveSystem.get_settings()
	master_volume = settings.get("master_volume", 1.0)
	sfx_volume = settings.get("sfx_volume", 1.0)
	music_volume = settings.get("music_volume", 0.8)
	screen_shake = settings.get("screen_shake", true)
	show_damage_numbers = settings.get("show_damage_numbers", true)


## Reset all settings to their default values, apply to audio buses, and save.
func reset_to_defaults() -> void:
	master_volume = 1.0
	sfx_volume = 1.0
	music_volume = 0.8
	screen_shake = true
	show_damage_numbers = true
	apply_all()
	SaveSystem.update_settings("master_volume", master_volume)
	SaveSystem.update_settings("sfx_volume", sfx_volume)
	SaveSystem.update_settings("music_volume", music_volume)
	SaveSystem.update_settings("screen_shake", screen_shake)
	SaveSystem.update_settings("show_damage_numbers", show_damage_numbers)
	settings_changed.emit()


## Set volume for a named audio bus. Converts linear [0,1] to dB.
## Mutes the bus when value is 0.
func set_volume(bus_name: String, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)

	# Update the local property
	match bus_name:
		"Master":
			master_volume = linear
		"SFX":
			sfx_volume = linear
		"Music":
			music_volume = linear

	# Apply to AudioServer
	_apply_bus_volume(bus_name, linear)

	# Save the setting key (lowercase with underscore)
	var key: String = _bus_name_to_setting_key(bus_name)
	SaveSystem.update_settings(key, linear)

	settings_changed.emit()


## Set screen shake preference.
func set_screen_shake(enabled: bool) -> void:
	screen_shake = enabled
	SaveSystem.update_settings("screen_shake", enabled)
	settings_changed.emit()


## Set damage numbers display preference.
func set_show_damage_numbers(enabled: bool) -> void:
	show_damage_numbers = enabled
	SaveSystem.update_settings("show_damage_numbers", enabled)
	settings_changed.emit()


## Apply all volume settings to AudioServer buses. Called on startup.
func apply_all() -> void:
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume("SFX", sfx_volume)
	_apply_bus_volume("Music", music_volume)


## Apply a single bus volume. Mutes if linear is 0.
func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return
	if linear <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear))


## Convert bus name ("Master", "SFX", "Music") to save key ("master_volume", etc.).
func _bus_name_to_setting_key(bus_name: String) -> String:
	match bus_name:
		"Master":
			return "master_volume"
		"SFX":
			return "sfx_volume"
		"Music":
			return "music_volume"
	return bus_name.to_lower() + "_volume"
