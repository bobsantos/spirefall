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
	setup_card_input()
	apply_button_styles()
	apply_card_styles()
	update_lock_status()
	if UIManager.is_mobile():
		_apply_mobile_card_sizing()


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
		var current_xp: int = MetaProgression.get_total_xp()
		lock_label.text = "%d / %d XP" % [current_xp, xp_threshold]
		card.modulate.a = 0.5


func _is_mode_unlocked(mode_key: String) -> bool:
	if unlock_overrides.has(mode_key):
		return unlock_overrides[mode_key]
	if mode_key == "classic":
		return true
	if mode_key == "draft":
		return MetaProgression.is_unlocked("mode_draft")
	if mode_key == "endless":
		return MetaProgression.is_unlocked("mode_endless")
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


func setup_card_input() -> void:
	var cards: Array[Array] = [
		[classic_card, "classic"],
		[draft_card, "draft"],
		[endless_card, "endless"],
	]
	for entry: Array in cards:
		var card: PanelContainer = entry[0]
		var mode_key: String = entry[1]
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		if not card.gui_input.is_connected(_on_card_input):
			card.gui_input.connect(_on_card_input.bind(mode_key))


func _on_card_input(event: InputEvent, mode_key: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_mode(mode_key)
	elif event is InputEventScreenTouch and event.pressed:
		_select_mode(mode_key)


func apply_card_styles() -> void:
	var cards: Array[PanelContainer] = [classic_card, draft_card, endless_card]
	for card: PanelContainer in cards:
		_apply_style_to_card(card)


func _apply_style_to_card(card: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.22, 1.0)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)


func _apply_mobile_card_sizing() -> void:
	var cards: Array[PanelContainer] = [classic_card, draft_card, endless_card]
	for card: PanelContainer in cards:
		var min_size: Vector2 = card.custom_minimum_size
		min_size.y = maxf(min_size.y, UIManagerClass.MOBILE_CARD_MIN_HEIGHT)
		card.custom_minimum_size = min_size

	var buttons: Array[Button] = [classic_button, draft_button, endless_button, back_button]
	for btn: Button in buttons:
		var min_size: Vector2 = btn.custom_minimum_size
		min_size.y = maxf(min_size.y, 56.0)
		btn.custom_minimum_size = min_size


func _apply_style_to_button(btn: Button) -> void:
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.3, 0.3, 0.4, 1.0)
	hover_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.15, 0.15, 0.25, 1.0)
	pressed_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("pressed", pressed_style)
