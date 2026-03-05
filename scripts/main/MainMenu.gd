extends Control

## Main menu screen. Provides navigation to game modes, settings, and credits.

const MODE_SELECT_PATH: String = "res://scenes/main/ModeSelect.tscn"
const CODEX_SCENE_PATH: String = "res://scenes/ui/CodexPanel.tscn"

@onready var play_button: Button = %PlayButton
@onready var settings_button: Button = %SettingsButton
@onready var credits_button: Button = %CreditsButton
@onready var codex_button: Button = %CodexButton
@onready var collection_button: Button = %CollectionButton
@onready var leaderboards_button: Button = %LeaderboardsButton
@onready var settings_overlay: Control = %SettingsOverlay
@onready var credits_overlay: PanelContainer = %CreditsOverlay
@onready var codex_overlay: Control = %CodexOverlay
@onready var credits_close_button: Button = %CreditsCloseButton
@onready var title_label: Label = %TitleLabel
@onready var version_label: Label = %VersionLabel

var _codex_instance: PanelContainer = null

var _settings_panel_instance: Control = null


func _ready() -> void:
	connect_buttons()
	apply_button_styles()
	version_label.text = "v" + ProjectSettings.get_setting("application/config/version", "0.0.0")
	# On web, AudioContext requires a user gesture before playing audio.
	# Defer music start until the first input event.
	if OS.get_name() == "Web":
		set_process_input(true)
	else:
		AudioManager.play_music("menu")


func _input(event: InputEvent) -> void:
	if OS.get_name() == "Web" and (event is InputEventMouseButton or event is InputEventScreenTouch):
		AudioManager.play_music("menu")
		set_process_input(false)


func connect_buttons() -> void:
	if not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)
	if not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if not credits_button.pressed.is_connected(_on_credits_pressed):
		credits_button.pressed.connect(_on_credits_pressed)
	if not codex_button.pressed.is_connected(_on_codex_pressed):
		codex_button.pressed.connect(_on_codex_pressed)
	if not credits_close_button.pressed.is_connected(_on_credits_close_pressed):
		credits_close_button.pressed.connect(_on_credits_close_pressed)
	# Connect SettingsPanel close signal if the panel is embedded in the overlay
	_settings_panel_instance = settings_overlay.get_node_or_null("SettingsPanel")
	if _settings_panel_instance and _settings_panel_instance.has_signal("close_requested"):
		if not _settings_panel_instance.close_requested.is_connected(_on_settings_close_pressed):
			_settings_panel_instance.close_requested.connect(_on_settings_close_pressed)


func apply_button_styles() -> void:
	var active_buttons: Array[Button] = [
		play_button, settings_button, codex_button, credits_button
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


func _on_credits_pressed() -> void:
	settings_overlay.visible = false
	codex_overlay.visible = false
	credits_overlay.visible = not credits_overlay.visible


func _on_codex_pressed() -> void:
	settings_overlay.visible = false
	credits_overlay.visible = false
	if codex_overlay.visible:
		codex_overlay.visible = false
		return
	# Instantiate codex on first open
	if _codex_instance == null:
		_codex_instance = load(CODEX_SCENE_PATH).instantiate()
		_codex_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		_codex_instance.closed.connect(_on_codex_closed)
		codex_overlay.add_child(_codex_instance)
		_codex_instance.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
		_codex_instance.offset_left = -400
		_codex_instance.offset_top = -350
		_codex_instance.offset_right = 400
		_codex_instance.offset_bottom = 350
	# Override process mode so codex works without pausing the tree
	_codex_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	# Mark that we were already paused so CodexPanel._close() won't call unpause
	_codex_instance._was_paused_before_open = true
	_codex_instance.visible = true
	_codex_instance._build_tab_content(_codex_instance._current_tab)
	codex_overlay.visible = true


func _on_codex_closed() -> void:
	codex_overlay.visible = false


func _on_settings_pressed() -> void:
	credits_overlay.visible = false
	codex_overlay.visible = false
	settings_overlay.visible = not settings_overlay.visible


func _on_settings_close_pressed() -> void:
	settings_overlay.visible = false


func _on_credits_close_pressed() -> void:
	credits_overlay.visible = false
