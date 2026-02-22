extends Control

## Mode selection screen. Displays mode cards for Classic, Draft, and Endless.
## Locked modes are grayed out and cannot be selected until XP requirements are met.

const MAP_SELECT_PATH: String = "res://scenes/main/MapSelect.tscn"
const DRAFT_XP_THRESHOLD: int = 500
const ENDLESS_XP_THRESHOLD: int = 2000

@onready var title_label: Label = %TitleLabel
@onready var classic_card: PanelContainer = %ClassicCard
@onready var draft_card: PanelContainer = %DraftCard
@onready var endless_card: PanelContainer = %EndlessCard
@onready var classic_button: Button = %ClassicSelectButton
@onready var draft_button: Button = %DraftSelectButton
@onready var endless_button: Button = %EndlessSelectButton
@onready var classic_name_label: Label = %ClassicNameLabel
@onready var draft_name_label: Label = %DraftNameLabel
@onready var endless_name_label: Label = %EndlessNameLabel
@onready var classic_desc_label: Label = %ClassicDescriptionLabel
@onready var draft_desc_label: Label = %DraftDescriptionLabel
@onready var endless_desc_label: Label = %EndlessDescriptionLabel
@onready var classic_lock_label: Label = %ClassicLockLabel
@onready var draft_lock_label: Label = %DraftLockLabel
@onready var endless_lock_label: Label = %EndlessLockLabel
@onready var back_button: Button = %BackButton

## Override dictionary for testing. Set unlock_overrides["draft"] = true to
## bypass the XP check for that mode. Will be replaced by MetaProgression later.
var unlock_overrides: Dictionary = {}


func _ready() -> void:
	connect_buttons()
	apply_button_styles()
	update_lock_status()


func connect_buttons() -> void:
	if not classic_button.pressed.is_connected(_on_classic_selected):
		classic_button.pressed.connect(_on_classic_selected)
	if not draft_button.pressed.is_connected(_on_draft_selected):
		draft_button.pressed.connect(_on_draft_selected)
	if not endless_button.pressed.is_connected(_on_endless_selected):
		endless_button.pressed.connect(_on_endless_selected)
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)


func apply_button_styles() -> void:
	var all_buttons: Array[Button] = [
		classic_button, draft_button, endless_button, back_button
	]
	for btn: Button in all_buttons:
		_apply_style_to_button(btn)


func update_lock_status() -> void:
	_update_card_lock("classic", classic_card, classic_button, classic_lock_label, 0)
	_update_card_lock("draft", draft_card, draft_button, draft_lock_label, DRAFT_XP_THRESHOLD)
	_update_card_lock("endless", endless_card, endless_button, endless_lock_label, ENDLESS_XP_THRESHOLD)


func _update_card_lock(mode_key: String, card: PanelContainer, btn: Button, lock_label: Label, xp_threshold: int) -> void:
	var unlocked: bool = _is_mode_unlocked(mode_key)
	btn.disabled = not unlocked
	if unlocked:
		lock_label.text = ""
		card.modulate.a = 1.0
	else:
		lock_label.text = "Requires %d XP" % xp_threshold
		card.modulate.a = 0.5


func _is_mode_unlocked(mode_key: String) -> bool:
	# Check test overrides first
	if unlock_overrides.has(mode_key):
		return unlock_overrides[mode_key]
	# Classic is always unlocked
	if mode_key == "classic":
		return true
	# When MetaProgression is implemented, check XP here.
	# For now, non-classic modes are locked by default.
	return false


func _select_mode(mode_key: String) -> void:
	if not _is_mode_unlocked(mode_key):
		return
	SceneManager.current_game_config = {"mode": mode_key}
	SceneManager.change_scene(MAP_SELECT_PATH)


func _on_classic_selected() -> void:
	_select_mode("classic")


func _on_draft_selected() -> void:
	_select_mode("draft")


func _on_endless_selected() -> void:
	_select_mode("endless")


func _on_back_pressed() -> void:
	SceneManager.go_to_main_menu()


func _apply_style_to_button(btn: Button) -> void:
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.3, 0.3, 0.4, 1.0)
	hover_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.15, 0.15, 0.25, 1.0)
	pressed_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("pressed", pressed_style)
