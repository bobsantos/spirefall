extends Control

## Map selection screen. Displays a 2x2 grid of map cards with name,
## description, difficulty stars, and preview thumbnail.
## Locked maps are grayed out and cannot be selected until XP requirements are met.

const MODE_SELECT_PATH: String = "res://scenes/main/ModeSelect.tscn"
const FOREST_PATH: String = "res://scenes/maps/ForestClearing.tscn"
const MOUNTAIN_PATH: String = "res://scenes/maps/MountainPass.tscn"
const RIVER_PATH: String = "res://scenes/maps/RiverDelta.tscn"
const VOLCANO_PATH: String = "res://scenes/maps/VolcanicCaldera.tscn"

const MOUNTAIN_XP_THRESHOLD: int = 1000
const RIVER_XP_THRESHOLD: int = 3000
const VOLCANO_XP_THRESHOLD: int = 6000

@onready var title_label: Label = %TitleLabel
@onready var forest_card: PanelContainer = %ForestCard
@onready var mountain_card: PanelContainer = %MountainCard
@onready var river_card: PanelContainer = %RiverCard
@onready var volcano_card: PanelContainer = %VolcanoCard
@onready var forest_button: Button = %ForestSelectButton
@onready var mountain_button: Button = %MountainSelectButton
@onready var river_button: Button = %RiverSelectButton
@onready var volcano_button: Button = %VolcanoSelectButton
@onready var forest_name_label: Label = %ForestNameLabel
@onready var mountain_name_label: Label = %MountainNameLabel
@onready var river_name_label: Label = %RiverNameLabel
@onready var volcano_name_label: Label = %VolcanoNameLabel
@onready var forest_desc_label: Label = %ForestDescriptionLabel
@onready var mountain_desc_label: Label = %MountainDescriptionLabel
@onready var river_desc_label: Label = %RiverDescriptionLabel
@onready var volcano_desc_label: Label = %VolcanoDescriptionLabel
@onready var forest_diff_label: Label = %ForestDifficultyLabel
@onready var mountain_diff_label: Label = %MountainDifficultyLabel
@onready var river_diff_label: Label = %RiverDifficultyLabel
@onready var volcano_diff_label: Label = %VolcanoDifficultyLabel
@onready var forest_lock_label: Label = %ForestLockLabel
@onready var mountain_lock_label: Label = %MountainLockLabel
@onready var river_lock_label: Label = %RiverLockLabel
@onready var volcano_lock_label: Label = %VolcanoLockLabel
@onready var forest_preview: ColorRect = %ForestPreviewRect
@onready var mountain_preview: ColorRect = %MountainPreviewRect
@onready var river_preview: ColorRect = %RiverPreviewRect
@onready var volcano_preview: ColorRect = %VolcanoPreviewRect
@onready var back_button: Button = %BackButton

## Override dictionary for testing. Set unlock_overrides["mountain"] = true to
## bypass the XP check for that map. Will be replaced by MetaProgression later.
var unlock_overrides: Dictionary = {}


func _ready() -> void:
	connect_buttons()
	apply_button_styles()
	update_lock_status()


func connect_buttons() -> void:
	if not forest_button.pressed.is_connected(_on_forest_selected):
		forest_button.pressed.connect(_on_forest_selected)
	if not mountain_button.pressed.is_connected(_on_mountain_selected):
		mountain_button.pressed.connect(_on_mountain_selected)
	if not river_button.pressed.is_connected(_on_river_selected):
		river_button.pressed.connect(_on_river_selected)
	if not volcano_button.pressed.is_connected(_on_volcano_selected):
		volcano_button.pressed.connect(_on_volcano_selected)
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)


func apply_button_styles() -> void:
	var all_buttons: Array[Button] = [
		forest_button, mountain_button, river_button, volcano_button, back_button
	]
	for btn: Button in all_buttons:
		_apply_style_to_button(btn)


func update_lock_status() -> void:
	_update_card_lock("forest", forest_card, forest_button, forest_lock_label, 0)
	_update_card_lock("mountain", mountain_card, mountain_button, mountain_lock_label, MOUNTAIN_XP_THRESHOLD)
	_update_card_lock("river", river_card, river_button, river_lock_label, RIVER_XP_THRESHOLD)
	_update_card_lock("volcano", volcano_card, volcano_button, volcano_lock_label, VOLCANO_XP_THRESHOLD)


func _update_card_lock(map_key: String, card: PanelContainer, btn: Button, lock_label: Label, xp_threshold: int) -> void:
	var unlocked: bool = _is_map_unlocked(map_key)
	btn.disabled = not unlocked
	if unlocked:
		lock_label.text = ""
		card.modulate.a = 1.0
	else:
		lock_label.text = "Requires %d XP" % xp_threshold
		card.modulate.a = 0.5


func _is_map_unlocked(map_key: String) -> bool:
	# Check test overrides first
	if unlock_overrides.has(map_key):
		return unlock_overrides[map_key]
	# Forest is always unlocked
	if map_key == "forest":
		return true
	# When MetaProgression is implemented, check XP here.
	# For now, non-forest maps are locked by default.
	return false


func _select_map(map_key: String, scene_path: String) -> void:
	if not _is_map_unlocked(map_key):
		return
	SceneManager.current_game_config["map"] = scene_path
	SceneManager.go_to_game(SceneManager.current_game_config)


func _on_forest_selected() -> void:
	_select_map("forest", FOREST_PATH)


func _on_mountain_selected() -> void:
	_select_map("mountain", MOUNTAIN_PATH)


func _on_river_selected() -> void:
	_select_map("river", RIVER_PATH)


func _on_volcano_selected() -> void:
	_select_map("volcano", VOLCANO_PATH)


func _on_back_pressed() -> void:
	SceneManager.change_scene(MODE_SELECT_PATH)


func _apply_style_to_button(btn: Button) -> void:
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.3, 0.3, 0.4, 1.0)
	hover_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.15, 0.15, 0.25, 1.0)
	pressed_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("pressed", pressed_style)
