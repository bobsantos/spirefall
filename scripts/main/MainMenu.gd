extends Control

## Main menu screen. Provides navigation to game modes, settings, and credits.

const MODE_SELECT_PATH: String = "res://scenes/main/ModeSelect.tscn"

@onready var play_button: Button = %PlayButton
@onready var settings_button: Button = %SettingsButton
@onready var credits_button: Button = %CreditsButton
@onready var collection_button: Button = %CollectionButton
@onready var leaderboards_button: Button = %LeaderboardsButton
@onready var settings_overlay: PanelContainer = %SettingsOverlay
@onready var credits_overlay: PanelContainer = %CreditsOverlay
@onready var settings_close_button: Button = %SettingsCloseButton
@onready var credits_close_button: Button = %CreditsCloseButton
@onready var title_label: Label = %TitleLabel


func _ready() -> void:
	connect_buttons()
	apply_button_styles()
	AudioManager.play_music("menu")


func connect_buttons() -> void:
	if not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)
	if not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if not credits_button.pressed.is_connected(_on_credits_pressed):
		credits_button.pressed.connect(_on_credits_pressed)
	if not settings_close_button.pressed.is_connected(_on_settings_close_pressed):
		settings_close_button.pressed.connect(_on_settings_close_pressed)
	if not credits_close_button.pressed.is_connected(_on_credits_close_pressed):
		credits_close_button.pressed.connect(_on_credits_close_pressed)


func apply_button_styles() -> void:
	var active_buttons: Array[Button] = [
		play_button, settings_button, credits_button
	]
	for btn: Button in active_buttons:
		_apply_style_to_button(btn)


func _apply_style_to_button(btn: Button) -> void:
	# Hover style: lighter background
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.3, 0.3, 0.4, 1.0)
	hover_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", hover_style)

	# Pressed style: darker, slightly inset look
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.15, 0.15, 0.25, 1.0)
	pressed_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("pressed", pressed_style)


func _on_play_pressed() -> void:
	SceneManager.change_scene(MODE_SELECT_PATH)


func _on_settings_pressed() -> void:
	credits_overlay.visible = false
	settings_overlay.visible = not settings_overlay.visible


func _on_credits_pressed() -> void:
	settings_overlay.visible = false
	credits_overlay.visible = not credits_overlay.visible


func _on_settings_close_pressed() -> void:
	settings_overlay.visible = false


func _on_credits_close_pressed() -> void:
	credits_overlay.visible = false
