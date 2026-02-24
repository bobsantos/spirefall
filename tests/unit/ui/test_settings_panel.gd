extends GdUnitTestSuite

## Unit tests for Task D3: SettingsPanel UI.
## Covers: node structure, slider ranges, slider-to-SettingsManager integration,
## toggle buttons, close signal, load from SettingsManager state.

const SETTINGS_PANEL_SCRIPT_PATH: String = "res://scripts/ui/SettingsPanel.gd"
const TEST_SAVE_PATH: String = "user://test_save_data_panel.json"

var _panel: Control
var _original_save_path: String


# -- Helpers -------------------------------------------------------------------

## Build a SettingsPanel node tree manually matching the .tscn structure.
func _build_settings_panel() -> Control:
	var root := PanelContainer.new()

	var main_vbox := VBoxContainer.new()
	main_vbox.name = "VBoxContainer"
	root.add_child(main_vbox)

	# Title
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Settings"
	main_vbox.add_child(title)

	# Audio section
	var audio_label := Label.new()
	audio_label.name = "AudioLabel"
	audio_label.text = "Audio"
	main_vbox.add_child(audio_label)

	# Master volume row
	var master_row := HBoxContainer.new()
	master_row.name = "MasterRow"
	main_vbox.add_child(master_row)
	var master_label := Label.new()
	master_label.name = "MasterLabel"
	master_label.text = "Master"
	master_row.add_child(master_label)
	var master_slider := HSlider.new()
	master_slider.name = "MasterSlider"
	master_row.add_child(master_slider)
	var master_value := Label.new()
	master_value.name = "MasterValue"
	master_row.add_child(master_value)

	# SFX volume row
	var sfx_row := HBoxContainer.new()
	sfx_row.name = "SFXRow"
	main_vbox.add_child(sfx_row)
	var sfx_label := Label.new()
	sfx_label.name = "SFXLabel"
	sfx_label.text = "SFX"
	sfx_row.add_child(sfx_label)
	var sfx_slider := HSlider.new()
	sfx_slider.name = "SFXSlider"
	sfx_row.add_child(sfx_slider)
	var sfx_value := Label.new()
	sfx_value.name = "SFXValue"
	sfx_row.add_child(sfx_value)

	# Music volume row
	var music_row := HBoxContainer.new()
	music_row.name = "MusicRow"
	main_vbox.add_child(music_row)
	var music_label := Label.new()
	music_label.name = "MusicLabel"
	music_label.text = "Music"
	music_row.add_child(music_label)
	var music_slider := HSlider.new()
	music_slider.name = "MusicSlider"
	music_row.add_child(music_slider)
	var music_value := Label.new()
	music_value.name = "MusicValue"
	music_row.add_child(music_value)

	# Display section
	var display_label := Label.new()
	display_label.name = "DisplayLabel"
	display_label.text = "Display"
	main_vbox.add_child(display_label)

	# Screen shake row
	var shake_row := HBoxContainer.new()
	shake_row.name = "ShakeRow"
	main_vbox.add_child(shake_row)
	var shake_label := Label.new()
	shake_label.name = "ShakeLabel"
	shake_label.text = "Screen Shake"
	shake_row.add_child(shake_label)
	var shake_toggle := CheckButton.new()
	shake_toggle.name = "ShakeToggle"
	shake_row.add_child(shake_toggle)

	# Damage numbers row
	var dmg_row := HBoxContainer.new()
	dmg_row.name = "DamageRow"
	main_vbox.add_child(dmg_row)
	var dmg_label := Label.new()
	dmg_label.name = "DamageLabel"
	dmg_label.text = "Damage Numbers"
	dmg_row.add_child(dmg_label)
	var dmg_toggle := CheckButton.new()
	dmg_toggle.name = "DamageToggle"
	dmg_row.add_child(dmg_toggle)

	# Reset to Defaults button
	var reset_btn := Button.new()
	reset_btn.name = "ResetButton"
	reset_btn.text = "Reset to Defaults"
	main_vbox.add_child(reset_btn)

	# Close button
	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "Close"
	main_vbox.add_child(close_btn)

	return root


func _apply_script(node: Control) -> void:
	var script: GDScript = load(SETTINGS_PANEL_SCRIPT_PATH) as GDScript
	node.set_script(script)
	# Manually assign @onready vars since _ready() won't fire outside scene tree
	node.master_slider = node.get_node("VBoxContainer/MasterRow/MasterSlider")
	node.master_value_label = node.get_node("VBoxContainer/MasterRow/MasterValue")
	node.sfx_slider = node.get_node("VBoxContainer/SFXRow/SFXSlider")
	node.sfx_value_label = node.get_node("VBoxContainer/SFXRow/SFXValue")
	node.music_slider = node.get_node("VBoxContainer/MusicRow/MusicSlider")
	node.music_value_label = node.get_node("VBoxContainer/MusicRow/MusicValue")
	node.shake_toggle = node.get_node("VBoxContainer/ShakeRow/ShakeToggle")
	node.damage_toggle = node.get_node("VBoxContainer/DamageRow/DamageToggle")
	node.reset_button = node.get_node("VBoxContainer/ResetButton")
	node.close_button = node.get_node("VBoxContainer/CloseButton")
	# Call setup manually
	node.setup()


func _reset_save_system() -> void:
	SaveSystem._save_path = TEST_SAVE_PATH
	SaveSystem._data = SaveSystem._default_data()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


func _reset_settings_manager() -> void:
	SettingsManager.master_volume = 1.0
	SettingsManager.sfx_volume = 1.0
	SettingsManager.music_volume = 0.8
	SettingsManager.screen_shake = true
	SettingsManager.show_damage_numbers = true


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_original_save_path = SaveSystem._save_path


func before_test() -> void:
	_reset_save_system()
	_reset_settings_manager()
	var panel: Control = _build_settings_panel()
	_panel = auto_free(panel)
	_apply_script(_panel)


func after_test() -> void:
	_panel = null
	_reset_settings_manager()
	_reset_save_system()


func after() -> void:
	SaveSystem._save_path = _original_save_path
	SaveSystem.load_save()


# -- 1. Node structure ---------------------------------------------------------

func test_panel_has_master_slider() -> void:
	assert_bool(_panel.master_slider != null).is_true()
	assert_bool(_panel.master_slider is HSlider).is_true()


func test_panel_has_sfx_slider() -> void:
	assert_bool(_panel.sfx_slider != null).is_true()
	assert_bool(_panel.sfx_slider is HSlider).is_true()


func test_panel_has_music_slider() -> void:
	assert_bool(_panel.music_slider != null).is_true()
	assert_bool(_panel.music_slider is HSlider).is_true()


func test_panel_has_shake_toggle() -> void:
	assert_bool(_panel.shake_toggle != null).is_true()
	assert_bool(_panel.shake_toggle is CheckButton).is_true()


func test_panel_has_damage_toggle() -> void:
	assert_bool(_panel.damage_toggle != null).is_true()
	assert_bool(_panel.damage_toggle is CheckButton).is_true()


func test_panel_has_close_button() -> void:
	assert_bool(_panel.close_button != null).is_true()
	assert_bool(_panel.close_button is Button).is_true()


# -- 2. Slider configuration --------------------------------------------------

func test_master_slider_range() -> void:
	assert_float(_panel.master_slider.min_value).is_equal(0.0)
	assert_float(_panel.master_slider.max_value).is_equal(100.0)
	assert_float(_panel.master_slider.step).is_equal(5.0)


func test_sfx_slider_range() -> void:
	assert_float(_panel.sfx_slider.min_value).is_equal(0.0)
	assert_float(_panel.sfx_slider.max_value).is_equal(100.0)
	assert_float(_panel.sfx_slider.step).is_equal(5.0)


func test_music_slider_range() -> void:
	assert_float(_panel.music_slider.min_value).is_equal(0.0)
	assert_float(_panel.music_slider.max_value).is_equal(100.0)
	assert_float(_panel.music_slider.step).is_equal(5.0)


# -- 3. Initial slider values from SettingsManager ----------------------------

func test_master_slider_initial_value() -> void:
	# Default master_volume is 1.0 -> slider should be 100
	assert_float(_panel.master_slider.value).is_equal(100.0)


func test_sfx_slider_initial_value() -> void:
	# Default sfx_volume is 1.0 -> slider should be 100
	assert_float(_panel.sfx_slider.value).is_equal(100.0)


func test_music_slider_initial_value() -> void:
	# Default music_volume is 0.8 -> slider should be 80
	assert_float(_panel.music_slider.value).is_equal(80.0)


func test_shake_toggle_initial_value() -> void:
	assert_bool(_panel.shake_toggle.button_pressed).is_true()


func test_damage_toggle_initial_value() -> void:
	assert_bool(_panel.damage_toggle.button_pressed).is_true()


func test_slider_reflects_custom_settings() -> void:
	SettingsManager.master_volume = 0.5
	SettingsManager.sfx_volume = 0.6
	SettingsManager.music_volume = 0.3
	SettingsManager.screen_shake = false
	SettingsManager.show_damage_numbers = false
	# Rebuild panel to pick up new values
	# Old panel is auto_free'd by GdUnit4; build a new one
	var new_panel: Control = auto_free(_build_settings_panel())
	_panel = new_panel
	_apply_script(_panel)
	assert_float(_panel.master_slider.value).is_equal(50.0)
	assert_float(_panel.sfx_slider.value).is_equal(60.0)
	assert_float(_panel.music_slider.value).is_equal(30.0)
	assert_bool(_panel.shake_toggle.button_pressed).is_false()
	assert_bool(_panel.damage_toggle.button_pressed).is_false()


# -- 4. Slider changes call SettingsManager -----------------------------------

func test_master_slider_change_updates_settings_manager() -> void:
	_panel.master_slider.value = 50.0
	# Emit value_changed manually since we're not in tree
	_panel._on_master_slider_changed(50.0)
	assert_float(SettingsManager.master_volume).is_equal(0.5)


func test_sfx_slider_change_updates_settings_manager() -> void:
	_panel.sfx_slider.value = 70.0
	_panel._on_sfx_slider_changed(70.0)
	assert_float(SettingsManager.sfx_volume).is_equal(0.7)


func test_music_slider_change_updates_settings_manager() -> void:
	_panel.music_slider.value = 40.0
	_panel._on_music_slider_changed(40.0)
	assert_float(SettingsManager.music_volume).is_equal(0.4)


func test_slider_change_updates_value_label() -> void:
	_panel._on_master_slider_changed(75.0)
	assert_str(_panel.master_value_label.text).is_equal("75")


# -- 5. Toggle changes call SettingsManager -----------------------------------

func test_shake_toggle_off_updates_settings() -> void:
	_panel._on_shake_toggled(false)
	assert_bool(SettingsManager.screen_shake).is_false()


func test_shake_toggle_on_updates_settings() -> void:
	SettingsManager.screen_shake = false
	_panel._on_shake_toggled(true)
	assert_bool(SettingsManager.screen_shake).is_true()


func test_damage_toggle_off_updates_settings() -> void:
	_panel._on_damage_toggled(false)
	assert_bool(SettingsManager.show_damage_numbers).is_false()


func test_damage_toggle_on_updates_settings() -> void:
	SettingsManager.show_damage_numbers = false
	_panel._on_damage_toggled(true)
	assert_bool(SettingsManager.show_damage_numbers).is_true()


# -- 6. Close button emits close_requested signal -----------------------------

func test_close_button_emits_signal() -> void:
	var emitted: Array[int] = [0]
	var conn: Callable = func() -> void: emitted[0] += 1
	_panel.close_requested.connect(conn)
	_panel._on_close_pressed()
	_panel.close_requested.disconnect(conn)
	assert_int(emitted[0]).is_equal(1)


# -- 7. Value labels show correct text ----------------------------------------

func test_initial_master_value_label() -> void:
	assert_str(_panel.master_value_label.text).is_equal("100")


func test_initial_sfx_value_label() -> void:
	assert_str(_panel.sfx_value_label.text).is_equal("100")


func test_initial_music_value_label() -> void:
	assert_str(_panel.music_value_label.text).is_equal("80")


# -- 8. process_mode is ALWAYS (works in both paused and unpaused contexts) ----

func test_process_mode_is_always() -> void:
	assert_int(_panel.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


# -- 9. Reset to Defaults button -----------------------------------------------

func test_reset_button_exists() -> void:
	assert_bool(_panel.reset_button != null).is_true()
	assert_bool(_panel.reset_button is Button).is_true()


func test_reset_button_updates_sliders() -> void:
	# Change settings away from defaults
	SettingsManager.master_volume = 0.3
	SettingsManager.sfx_volume = 0.4
	SettingsManager.music_volume = 0.2
	# Manually set sliders to match changed values
	_panel.master_slider.value = 30.0
	_panel.sfx_slider.value = 40.0
	_panel.music_slider.value = 20.0
	# Press reset
	_panel._on_reset_pressed()
	# Sliders should reflect default values
	assert_float(_panel.master_slider.value).is_equal(100.0)
	assert_float(_panel.sfx_slider.value).is_equal(100.0)
	assert_float(_panel.music_slider.value).is_equal(80.0)


func test_reset_button_updates_toggles() -> void:
	# Change settings away from defaults
	SettingsManager.screen_shake = false
	SettingsManager.show_damage_numbers = false
	_panel.shake_toggle.button_pressed = false
	_panel.damage_toggle.button_pressed = false
	# Press reset
	_panel._on_reset_pressed()
	# Toggles should reflect default values
	assert_bool(_panel.shake_toggle.button_pressed).is_true()
	assert_bool(_panel.damage_toggle.button_pressed).is_true()
