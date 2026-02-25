class_name SettingsPanel
extends PanelContainer

## Reusable settings panel with audio sliders and display toggles.
## Used in both MainMenu (as an overlay) and PauseMenu.

signal close_requested()

@onready var master_slider: HSlider = $VBoxContainer/MasterRow/MasterSlider
@onready var master_value_label: Label = $VBoxContainer/MasterRow/MasterValue
@onready var sfx_slider: HSlider = $VBoxContainer/SFXRow/SFXSlider
@onready var sfx_value_label: Label = $VBoxContainer/SFXRow/SFXValue
@onready var music_slider: HSlider = $VBoxContainer/MusicRow/MusicSlider
@onready var music_value_label: Label = $VBoxContainer/MusicRow/MusicValue
@onready var shake_toggle: CheckButton = $VBoxContainer/ShakeRow/ShakeToggle
@onready var damage_toggle: CheckButton = $VBoxContainer/DamageRow/DamageToggle
@onready var reset_button: Button = $VBoxContainer/ResetButton
@onready var close_button: Button = $VBoxContainer/CloseButton


func _ready() -> void:
	setup()


## Configure sliders, load current values, and connect signals.
## Called from _ready() and also manually in tests.
func setup() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Configure slider ranges
	_configure_slider(master_slider)
	_configure_slider(sfx_slider)
	_configure_slider(music_slider)

	# Load current values from SettingsManager
	master_slider.value = SettingsManager.master_volume * 100.0
	sfx_slider.value = SettingsManager.sfx_volume * 100.0
	music_slider.value = SettingsManager.music_volume * 100.0
	shake_toggle.button_pressed = SettingsManager.screen_shake
	damage_toggle.button_pressed = SettingsManager.show_damage_numbers

	# Update value labels
	master_value_label.text = str(int(master_slider.value))
	sfx_value_label.text = str(int(sfx_slider.value))
	music_value_label.text = str(int(music_slider.value))

	# Connect signals (idempotent)
	if not master_slider.value_changed.is_connected(_on_master_slider_changed):
		master_slider.value_changed.connect(_on_master_slider_changed)
	if not sfx_slider.value_changed.is_connected(_on_sfx_slider_changed):
		sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	if not music_slider.value_changed.is_connected(_on_music_slider_changed):
		music_slider.value_changed.connect(_on_music_slider_changed)
	if not shake_toggle.toggled.is_connected(_on_shake_toggled):
		shake_toggle.toggled.connect(_on_shake_toggled)
	if not damage_toggle.toggled.is_connected(_on_damage_toggled):
		damage_toggle.toggled.connect(_on_damage_toggled)
	if not reset_button.pressed.is_connected(_on_reset_pressed):
		reset_button.pressed.connect(_on_reset_pressed)
	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)


func _configure_slider(slider: HSlider) -> void:
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 5.0


func _on_master_slider_changed(value: float) -> void:
	master_value_label.text = str(int(value))
	SettingsManager.set_volume("Master", value / 100.0)


func _on_sfx_slider_changed(value: float) -> void:
	sfx_value_label.text = str(int(value))
	SettingsManager.set_volume("SFX", value / 100.0)


func _on_music_slider_changed(value: float) -> void:
	music_value_label.text = str(int(value))
	SettingsManager.set_volume("Music", value / 100.0)


func _on_shake_toggled(pressed: bool) -> void:
	SettingsManager.set_screen_shake(pressed)


func _on_damage_toggled(pressed: bool) -> void:
	SettingsManager.set_show_damage_numbers(pressed)


func _on_reset_pressed() -> void:
	SettingsManager.reset_to_defaults()
	master_slider.value = SettingsManager.master_volume * 100.0
	sfx_slider.value = SettingsManager.sfx_volume * 100.0
	music_slider.value = SettingsManager.music_volume * 100.0
	shake_toggle.button_pressed = SettingsManager.screen_shake
	damage_toggle.button_pressed = SettingsManager.show_damage_numbers
	master_value_label.text = str(int(master_slider.value))
	sfx_value_label.text = str(int(sfx_slider.value))
	music_value_label.text = str(int(music_slider.value))


func _on_close_pressed() -> void:
	close_requested.emit()
