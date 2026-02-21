extends GdUnitTestSuite

## Unit tests for MapSelect scene script.
## Covers: node structure, map descriptions, difficulty display, lock status,
## selection behavior, back button, button connections, styling, unlock overrides.

const MAP_SELECT_SCRIPT_PATH: String = "res://scripts/main/MapSelect.gd"
const MODE_SELECT_PATH: String = "res://scenes/main/ModeSelect.tscn"
const GAME_PATH: String = "res://scenes/main/Game.tscn"

var _map_select: Control
var _scene_change_paths: Array[String] = []
var _scene_change_conn: Callable
var _original_transitioning: bool


# -- Helpers -------------------------------------------------------------------

## Build a MapSelect node tree manually (same structure as MapSelect.tscn)
## so tests don't depend on the .tscn file loading in headless mode.
func _build_map_select() -> Control:
	var root := Control.new()

	# Background
	var bg := ColorRect.new()
	bg.name = "Background"
	root.add_child(bg)

	# CenterContainer for vertical layout
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	center.add_child(vbox)

	# Title label
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Select Map"
	vbox.add_child(title)

	# Map grid container (2 columns)
	var grid := GridContainer.new()
	grid.name = "MapGrid"
	grid.columns = 2
	vbox.add_child(grid)

	# Forest Clearing card
	var forest_card := _build_map_card(
		"ForestCard",
		"Forest Clearing",
		"Open field with a single winding path. Perfect for learning.",
		"Difficulty: \u2605\u2606\u2606\u2606",
		"",
		Color(0.2, 0.5, 0.2)
	)
	grid.add_child(forest_card)

	# Mountain Pass card
	var mountain_card := _build_map_card(
		"MountainCard",
		"Mountain Pass",
		"Pre-built walls create an S-curve maze. Less building freedom.",
		"Difficulty: \u2605\u2605\u2606\u2606",
		"Requires 1000 XP",
		Color(0.4, 0.4, 0.45)
	)
	grid.add_child(mountain_card)

	# River Delta card
	var river_card := _build_map_card(
		"RiverCard",
		"River Delta",
		"River splits the map into islands connected by bridges.",
		"Difficulty: \u2605\u2605\u2605\u2606",
		"Requires 3000 XP",
		Color(0.2, 0.3, 0.5)
	)
	grid.add_child(river_card)

	# Volcanic Caldera card
	var volcano_card := _build_map_card(
		"VolcanoCard",
		"Volcanic Caldera",
		"Enemies spawn from the center and radiate outward to 4 exits.",
		"Difficulty: \u2605\u2605\u2605\u2605",
		"Requires 6000 XP",
		Color(0.5, 0.2, 0.1)
	)
	grid.add_child(volcano_card)

	# Back button
	var back_btn := Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "Back"
	vbox.add_child(back_btn)

	return root


func _build_map_card(card_name: String, map_name: String, description: String, difficulty_text: String, lock_text: String, preview_color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = card_name

	var card_vbox := VBoxContainer.new()
	card_vbox.name = "CardVBox"
	card.add_child(card_vbox)

	# Preview thumbnail
	var preview := ColorRect.new()
	preview.name = "PreviewRect"
	preview.color = preview_color
	card_vbox.add_child(preview)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = map_name
	card_vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.name = "DescriptionLabel"
	desc_label.text = description
	card_vbox.add_child(desc_label)

	var diff_label := Label.new()
	diff_label.name = "DifficultyLabel"
	diff_label.text = difficulty_text
	card_vbox.add_child(diff_label)

	var lock_label := Label.new()
	lock_label.name = "LockLabel"
	lock_label.text = lock_text
	card_vbox.add_child(lock_label)

	var select_btn := Button.new()
	select_btn.name = "SelectButton"
	select_btn.text = "Select"
	card_vbox.add_child(select_btn)

	return card


func _apply_script(node: Control) -> void:
	var script: GDScript = load(MAP_SELECT_SCRIPT_PATH)
	node.set_script(script)
	# Manually wire @onready references since we're not going through the tree
	node.title_label = node.get_node("CenterContainer/VBoxContainer/TitleLabel")
	node.forest_card = node.get_node("CenterContainer/VBoxContainer/MapGrid/ForestCard")
	node.mountain_card = node.get_node("CenterContainer/VBoxContainer/MapGrid/MountainCard")
	node.river_card = node.get_node("CenterContainer/VBoxContainer/MapGrid/RiverCard")
	node.volcano_card = node.get_node("CenterContainer/VBoxContainer/MapGrid/VolcanoCard")
	node.forest_button = node.get_node("CenterContainer/VBoxContainer/MapGrid/ForestCard/CardVBox/SelectButton")
	node.mountain_button = node.get_node("CenterContainer/VBoxContainer/MapGrid/MountainCard/CardVBox/SelectButton")
	node.river_button = node.get_node("CenterContainer/VBoxContainer/MapGrid/RiverCard/CardVBox/SelectButton")
	node.volcano_button = node.get_node("CenterContainer/VBoxContainer/MapGrid/VolcanoCard/CardVBox/SelectButton")
	node.forest_name_label = node.get_node("CenterContainer/VBoxContainer/MapGrid/ForestCard/CardVBox/NameLabel")
	node.mountain_name_label = node.get_node("CenterContainer/VBoxContainer/MapGrid/MountainCard/CardVBox/NameLabel")
	node.river_name_label = node.get_node("CenterContainer/VBoxContainer/MapGrid/RiverCard/CardVBox/NameLabel")
	node.volcano_name_label = node.get_node("CenterContainer/VBoxContainer/MapGrid/VolcanoCard/CardVBox/NameLabel")
	node.forest_desc_label = node.get_node("CenterContainer/VBoxContainer/MapGrid/ForestCard/CardVBox/DescriptionLabel")
	node.mountain_desc_label = node.get_node("CenterContainer/VBoxContainer/MapGrid/MountainCard/CardVBox/DescriptionLabel")
	node.river_desc_label = node.get_node("CenterContainer/VBoxContainer/MapGrid/RiverCard/CardVBox/DescriptionLabel")
	node.volcano_desc_label = node.get_node("CenterContainer/VBoxContainer/MapGrid/VolcanoCard/CardVBox/DescriptionLabel")
	node.forest_diff_label = node.get_node("CenterContainer/VBoxContainer/MapGrid/ForestCard/CardVBox/DifficultyLabel")
	node.mountain_diff_label = node.get_node("CenterContainer/VBoxContainer/MapGrid/MountainCard/CardVBox/DifficultyLabel")
	node.river_diff_label = node.get_node("CenterContainer/VBoxContainer/MapGrid/RiverCard/CardVBox/DifficultyLabel")
	node.volcano_diff_label = node.get_node("CenterContainer/VBoxContainer/MapGrid/VolcanoCard/CardVBox/DifficultyLabel")
	node.forest_lock_label = node.get_node("CenterContainer/VBoxContainer/MapGrid/ForestCard/CardVBox/LockLabel")
	node.mountain_lock_label = node.get_node("CenterContainer/VBoxContainer/MapGrid/MountainCard/CardVBox/LockLabel")
	node.river_lock_label = node.get_node("CenterContainer/VBoxContainer/MapGrid/RiverCard/CardVBox/LockLabel")
	node.volcano_lock_label = node.get_node("CenterContainer/VBoxContainer/MapGrid/VolcanoCard/CardVBox/LockLabel")
	node.forest_preview = node.get_node("CenterContainer/VBoxContainer/MapGrid/ForestCard/CardVBox/PreviewRect")
	node.mountain_preview = node.get_node("CenterContainer/VBoxContainer/MapGrid/MountainCard/CardVBox/PreviewRect")
	node.river_preview = node.get_node("CenterContainer/VBoxContainer/MapGrid/RiverCard/CardVBox/PreviewRect")
	node.volcano_preview = node.get_node("CenterContainer/VBoxContainer/MapGrid/VolcanoCard/CardVBox/PreviewRect")
	node.back_button = node.get_node("CenterContainer/VBoxContainer/BackButton")


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_scene_change_paths.clear()

	# Block SceneManager from doing real scene transitions
	_original_transitioning = SceneManager.is_transitioning
	SceneManager.is_transitioning = true

	# Track scene change requests
	_scene_change_conn = func() -> void:
		_scene_change_paths.append(SceneManager._last_scene_path)
	SceneManager.scene_changing.connect(_scene_change_conn)

	_map_select = _build_map_select()
	_apply_script(_map_select)


func after_test() -> void:
	if SceneManager.scene_changing.is_connected(_scene_change_conn):
		SceneManager.scene_changing.disconnect(_scene_change_conn)
	SceneManager.is_transitioning = _original_transitioning
	SceneManager._last_scene_path = ""
	SceneManager.current_game_config = {}

	if is_instance_valid(_map_select):
		_map_select.free()
		_map_select = null


# -- 1. Script loads and has expected structure --------------------------------

func test_script_exists_and_loads() -> void:
	var script: GDScript = load(MAP_SELECT_SCRIPT_PATH)
	assert_object(script).is_not_null()


func test_has_forest_card() -> void:
	assert_object(_map_select.forest_card).is_not_null()
	assert_bool(_map_select.forest_card is PanelContainer).is_true()


func test_has_mountain_card() -> void:
	assert_object(_map_select.mountain_card).is_not_null()
	assert_bool(_map_select.mountain_card is PanelContainer).is_true()


func test_has_river_card() -> void:
	assert_object(_map_select.river_card).is_not_null()
	assert_bool(_map_select.river_card is PanelContainer).is_true()


func test_has_volcano_card() -> void:
	assert_object(_map_select.volcano_card).is_not_null()
	assert_bool(_map_select.volcano_card is PanelContainer).is_true()


func test_has_back_button() -> void:
	assert_object(_map_select.back_button).is_not_null()
	assert_bool(_map_select.back_button is Button).is_true()


func test_title_label_text() -> void:
	assert_str(_map_select.title_label.text).is_equal("Select Map")


func test_forest_card_has_name_label() -> void:
	assert_str(_map_select.forest_name_label.text).is_equal("Forest Clearing")


func test_mountain_card_has_name_label() -> void:
	assert_str(_map_select.mountain_name_label.text).is_equal("Mountain Pass")


# -- 2. Map descriptions ------------------------------------------------------

func test_forest_description() -> void:
	assert_str(_map_select.forest_desc_label.text).is_equal(
		"Open field with a single winding path. Perfect for learning."
	)


func test_mountain_description() -> void:
	assert_str(_map_select.mountain_desc_label.text).is_equal(
		"Pre-built walls create an S-curve maze. Less building freedom."
	)


func test_river_description() -> void:
	assert_str(_map_select.river_desc_label.text).is_equal(
		"River splits the map into islands connected by bridges."
	)


func test_volcano_description() -> void:
	assert_str(_map_select.volcano_desc_label.text).is_equal(
		"Enemies spawn from the center and radiate outward to 4 exits."
	)


# -- 3. Difficulty display -----------------------------------------------------

func test_forest_difficulty_one_star() -> void:
	assert_str(_map_select.forest_diff_label.text).is_equal("Difficulty: \u2605\u2606\u2606\u2606")


func test_mountain_difficulty_two_stars() -> void:
	assert_str(_map_select.mountain_diff_label.text).is_equal("Difficulty: \u2605\u2605\u2606\u2606")


func test_river_difficulty_three_stars() -> void:
	assert_str(_map_select.river_diff_label.text).is_equal("Difficulty: \u2605\u2605\u2605\u2606")


func test_volcano_difficulty_four_stars() -> void:
	assert_str(_map_select.volcano_diff_label.text).is_equal("Difficulty: \u2605\u2605\u2605\u2605")


# -- 4. Lock status ------------------------------------------------------------

func test_forest_is_always_unlocked() -> void:
	_map_select.update_lock_status()
	assert_bool(_map_select.forest_button.disabled).is_false()


func test_mountain_is_locked_by_default() -> void:
	_map_select.update_lock_status()
	assert_bool(_map_select.mountain_button.disabled).is_true()


func test_river_is_locked_by_default() -> void:
	_map_select.update_lock_status()
	assert_bool(_map_select.river_button.disabled).is_true()


func test_volcano_is_locked_by_default() -> void:
	_map_select.update_lock_status()
	assert_bool(_map_select.volcano_button.disabled).is_true()


func test_mountain_lock_label_shows_requirement() -> void:
	_map_select.update_lock_status()
	assert_str(_map_select.mountain_lock_label.text).contains("1000 XP")


func test_river_lock_label_shows_requirement() -> void:
	_map_select.update_lock_status()
	assert_str(_map_select.river_lock_label.text).contains("3000 XP")


func test_volcano_lock_label_shows_requirement() -> void:
	_map_select.update_lock_status()
	assert_str(_map_select.volcano_lock_label.text).contains("6000 XP")


func test_forest_lock_label_is_empty() -> void:
	_map_select.update_lock_status()
	assert_str(_map_select.forest_lock_label.text).is_equal("")


func test_locked_card_is_visually_grayed() -> void:
	_map_select.update_lock_status()
	assert_float(_map_select.mountain_card.modulate.a).is_less(1.0)
	assert_float(_map_select.river_card.modulate.a).is_less(1.0)
	assert_float(_map_select.volcano_card.modulate.a).is_less(1.0)


func test_unlocked_card_is_not_grayed() -> void:
	_map_select.update_lock_status()
	assert_float(_map_select.forest_card.modulate.a).is_equal(1.0)


# -- 5. Selection behavior ----------------------------------------------------

func test_select_forest_stores_map_in_config() -> void:
	SceneManager.current_game_config = {"mode": "classic"}
	SceneManager.is_transitioning = false
	_map_select._on_forest_selected()
	assert_str(SceneManager.current_game_config["map"]).is_equal("res://scenes/maps/ForestClearing.tscn")


func test_select_forest_navigates_to_game() -> void:
	SceneManager.current_game_config = {"mode": "classic"}
	SceneManager.is_transitioning = false
	_map_select._on_forest_selected()
	assert_str(SceneManager._last_scene_path).is_equal(GAME_PATH)


func test_select_forest_preserves_mode_in_config() -> void:
	SceneManager.current_game_config = {"mode": "classic"}
	SceneManager.is_transitioning = false
	_map_select._on_forest_selected()
	assert_str(SceneManager.current_game_config["mode"]).is_equal("classic")


func test_select_locked_map_does_not_navigate() -> void:
	_map_select.update_lock_status()
	SceneManager.is_transitioning = false
	_map_select._on_mountain_selected()
	assert_str(SceneManager._last_scene_path).is_equal("")


func test_select_locked_map_does_not_change_config() -> void:
	SceneManager.current_game_config = {"mode": "classic"}
	_map_select.update_lock_status()
	SceneManager.is_transitioning = false
	_map_select._on_mountain_selected()
	assert_bool(SceneManager.current_game_config.has("map")).is_false()


# -- 6. Back button ------------------------------------------------------------

func test_back_button_navigates_to_mode_select() -> void:
	SceneManager.is_transitioning = false
	_map_select._on_back_pressed()
	assert_str(SceneManager._last_scene_path).is_equal(MODE_SELECT_PATH)


func test_back_button_preserves_config() -> void:
	SceneManager.current_game_config = {"mode": "classic"}
	SceneManager.is_transitioning = false
	_map_select._on_back_pressed()
	assert_str(SceneManager.current_game_config["mode"]).is_equal("classic")


# -- 7. Button connections -----------------------------------------------------

func test_connect_buttons_wires_forest() -> void:
	_map_select.connect_buttons()
	assert_bool(_map_select.forest_button.pressed.is_connected(_map_select._on_forest_selected)).is_true()


func test_connect_buttons_wires_mountain() -> void:
	_map_select.connect_buttons()
	assert_bool(_map_select.mountain_button.pressed.is_connected(_map_select._on_mountain_selected)).is_true()


func test_connect_buttons_wires_river() -> void:
	_map_select.connect_buttons()
	assert_bool(_map_select.river_button.pressed.is_connected(_map_select._on_river_selected)).is_true()


func test_connect_buttons_wires_volcano() -> void:
	_map_select.connect_buttons()
	assert_bool(_map_select.volcano_button.pressed.is_connected(_map_select._on_volcano_selected)).is_true()


func test_connect_buttons_wires_back() -> void:
	_map_select.connect_buttons()
	assert_bool(_map_select.back_button.pressed.is_connected(_map_select._on_back_pressed)).is_true()


# -- 8. Styling ----------------------------------------------------------------

func test_forest_button_has_hover_stylebox() -> void:
	_map_select.apply_button_styles()
	assert_bool(_map_select.forest_button.has_theme_stylebox_override("hover")).is_true()


func test_forest_button_has_pressed_stylebox() -> void:
	_map_select.apply_button_styles()
	assert_bool(_map_select.forest_button.has_theme_stylebox_override("pressed")).is_true()


func test_mountain_button_has_hover_stylebox() -> void:
	_map_select.apply_button_styles()
	assert_bool(_map_select.mountain_button.has_theme_stylebox_override("hover")).is_true()


func test_back_button_has_hover_stylebox() -> void:
	_map_select.apply_button_styles()
	assert_bool(_map_select.back_button.has_theme_stylebox_override("hover")).is_true()


# -- 9. Unlock overrides for testing ------------------------------------------

func test_unlock_override_makes_mountain_selectable() -> void:
	_map_select.unlock_overrides["mountain"] = true
	_map_select.update_lock_status()
	assert_bool(_map_select.mountain_button.disabled).is_false()


func test_unlock_override_mountain_allows_navigation() -> void:
	_map_select.unlock_overrides["mountain"] = true
	_map_select.update_lock_status()
	SceneManager.current_game_config = {"mode": "classic"}
	SceneManager.is_transitioning = false
	_map_select._on_mountain_selected()
	assert_str(SceneManager.current_game_config["map"]).is_equal("res://scenes/maps/MountainPass.tscn")
	assert_str(SceneManager._last_scene_path).is_equal(GAME_PATH)


func test_unlock_override_restores_card_modulate() -> void:
	_map_select.update_lock_status()
	assert_float(_map_select.mountain_card.modulate.a).is_less(1.0)
	_map_select.unlock_overrides["mountain"] = true
	_map_select.update_lock_status()
	assert_float(_map_select.mountain_card.modulate.a).is_equal(1.0)


func test_unlock_override_makes_river_selectable() -> void:
	_map_select.unlock_overrides["river"] = true
	_map_select.update_lock_status()
	assert_bool(_map_select.river_button.disabled).is_false()
