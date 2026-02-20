extends GdUnitTestSuite

## Unit tests for ModeSelect scene script.
## Covers: node structure, mode descriptions, lock status, selection behavior,
## back button, button connections, styling, and unlock overrides.

const MODE_SELECT_SCRIPT_PATH: String = "res://scripts/main/ModeSelect.gd"
const MAP_SELECT_PATH: String = "res://scenes/main/MapSelect.tscn"

var _mode_select: Control
var _scene_change_paths: Array[String] = []
var _scene_change_conn: Callable
var _original_transitioning: bool


# -- Helpers -------------------------------------------------------------------

## Build a ModeSelect node tree manually (same structure as ModeSelect.tscn)
## so tests don't depend on the .tscn file loading in headless mode.
func _build_mode_select() -> Control:
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
	title.text = "Select Mode"
	vbox.add_child(title)

	# Mode cards container
	var card_container := HBoxContainer.new()
	card_container.name = "CardContainer"
	vbox.add_child(card_container)

	# Classic card
	var classic_card := _build_mode_card(
		"ClassicCard",
		"Classic",
		"30 waves of increasing difficulty. Build, maze, and survive.",
		""
	)
	card_container.add_child(classic_card)

	# Draft card
	var draft_card := _build_mode_card(
		"DraftCard",
		"Draft",
		"Start with 1 random element. Draft 2 more across 10 waves.",
		"Requires 500 XP"
	)
	card_container.add_child(draft_card)

	# Endless card
	var endless_card := _build_mode_card(
		"EndlessCard",
		"Endless",
		"Waves never stop. How far can you go?",
		"Requires 2000 XP"
	)
	card_container.add_child(endless_card)

	# Back button
	var back_btn := Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "Back"
	vbox.add_child(back_btn)

	return root


func _build_mode_card(card_name: String, mode_name: String, description: String, lock_text: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = card_name

	var card_vbox := VBoxContainer.new()
	card_vbox.name = "CardVBox"
	card.add_child(card_vbox)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = mode_name
	card_vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.name = "DescriptionLabel"
	desc_label.text = description
	card_vbox.add_child(desc_label)

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
	var script: GDScript = load(MODE_SELECT_SCRIPT_PATH)
	node.set_script(script)
	# Manually wire @onready references since we're not going through the tree
	node.title_label = node.get_node("CenterContainer/VBoxContainer/TitleLabel")
	node.classic_card = node.get_node("CenterContainer/VBoxContainer/CardContainer/ClassicCard")
	node.draft_card = node.get_node("CenterContainer/VBoxContainer/CardContainer/DraftCard")
	node.endless_card = node.get_node("CenterContainer/VBoxContainer/CardContainer/EndlessCard")
	node.classic_button = node.get_node("CenterContainer/VBoxContainer/CardContainer/ClassicCard/CardVBox/SelectButton")
	node.draft_button = node.get_node("CenterContainer/VBoxContainer/CardContainer/DraftCard/CardVBox/SelectButton")
	node.endless_button = node.get_node("CenterContainer/VBoxContainer/CardContainer/EndlessCard/CardVBox/SelectButton")
	node.classic_name_label = node.get_node("CenterContainer/VBoxContainer/CardContainer/ClassicCard/CardVBox/NameLabel")
	node.draft_name_label = node.get_node("CenterContainer/VBoxContainer/CardContainer/DraftCard/CardVBox/NameLabel")
	node.endless_name_label = node.get_node("CenterContainer/VBoxContainer/CardContainer/EndlessCard/CardVBox/NameLabel")
	node.classic_desc_label = node.get_node("CenterContainer/VBoxContainer/CardContainer/ClassicCard/CardVBox/DescriptionLabel")
	node.draft_desc_label = node.get_node("CenterContainer/VBoxContainer/CardContainer/DraftCard/CardVBox/DescriptionLabel")
	node.endless_desc_label = node.get_node("CenterContainer/VBoxContainer/CardContainer/EndlessCard/CardVBox/DescriptionLabel")
	node.classic_lock_label = node.get_node("CenterContainer/VBoxContainer/CardContainer/ClassicCard/CardVBox/LockLabel")
	node.draft_lock_label = node.get_node("CenterContainer/VBoxContainer/CardContainer/DraftCard/CardVBox/LockLabel")
	node.endless_lock_label = node.get_node("CenterContainer/VBoxContainer/CardContainer/EndlessCard/CardVBox/LockLabel")
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

	_mode_select = _build_mode_select()
	_apply_script(_mode_select)


func after_test() -> void:
	if SceneManager.scene_changing.is_connected(_scene_change_conn):
		SceneManager.scene_changing.disconnect(_scene_change_conn)
	SceneManager.is_transitioning = _original_transitioning
	SceneManager._last_scene_path = ""
	SceneManager.current_game_config = {}

	if is_instance_valid(_mode_select):
		_mode_select.free()
		_mode_select = null


# -- 1. Script loads and has expected structure --------------------------------

func test_script_exists_and_loads() -> void:
	var script: GDScript = load(MODE_SELECT_SCRIPT_PATH)
	assert_object(script).is_not_null()


func test_has_classic_card() -> void:
	assert_object(_mode_select.classic_card).is_not_null()
	assert_bool(_mode_select.classic_card is PanelContainer).is_true()


func test_has_draft_card() -> void:
	assert_object(_mode_select.draft_card).is_not_null()
	assert_bool(_mode_select.draft_card is PanelContainer).is_true()


func test_has_endless_card() -> void:
	assert_object(_mode_select.endless_card).is_not_null()
	assert_bool(_mode_select.endless_card is PanelContainer).is_true()


func test_has_back_button() -> void:
	assert_object(_mode_select.back_button).is_not_null()
	assert_bool(_mode_select.back_button is Button).is_true()


func test_title_label_text() -> void:
	assert_str(_mode_select.title_label.text).is_equal("Select Mode")


func test_classic_card_has_name_label() -> void:
	assert_str(_mode_select.classic_name_label.text).is_equal("Classic")


func test_draft_card_has_name_label() -> void:
	assert_str(_mode_select.draft_name_label.text).is_equal("Draft")


func test_endless_card_has_name_label() -> void:
	assert_str(_mode_select.endless_name_label.text).is_equal("Endless")


# -- 2. Mode descriptions -----------------------------------------------------

func test_classic_description() -> void:
	assert_str(_mode_select.classic_desc_label.text).is_equal(
		"30 waves of increasing difficulty. Build, maze, and survive."
	)


func test_draft_description() -> void:
	assert_str(_mode_select.draft_desc_label.text).is_equal(
		"Start with 1 random element. Draft 2 more across 10 waves."
	)


func test_endless_description() -> void:
	assert_str(_mode_select.endless_desc_label.text).is_equal(
		"Waves never stop. How far can you go?"
	)


# -- 3. Lock status ------------------------------------------------------------

func test_classic_is_always_unlocked() -> void:
	_mode_select.update_lock_status()
	assert_bool(_mode_select.classic_button.disabled).is_false()


func test_draft_is_locked_by_default() -> void:
	_mode_select.update_lock_status()
	assert_bool(_mode_select.draft_button.disabled).is_true()


func test_endless_is_locked_by_default() -> void:
	_mode_select.update_lock_status()
	assert_bool(_mode_select.endless_button.disabled).is_true()


func test_draft_lock_label_shows_requirement() -> void:
	_mode_select.update_lock_status()
	assert_str(_mode_select.draft_lock_label.text).contains("500 XP")


func test_endless_lock_label_shows_requirement() -> void:
	_mode_select.update_lock_status()
	assert_str(_mode_select.endless_lock_label.text).contains("2000 XP")


func test_classic_lock_label_is_empty() -> void:
	_mode_select.update_lock_status()
	assert_str(_mode_select.classic_lock_label.text).is_equal("")


func test_locked_card_is_visually_grayed() -> void:
	_mode_select.update_lock_status()
	# Locked cards should have reduced modulate alpha
	assert_float(_mode_select.draft_card.modulate.a).is_less(1.0)
	assert_float(_mode_select.endless_card.modulate.a).is_less(1.0)


func test_unlocked_card_is_not_grayed() -> void:
	_mode_select.update_lock_status()
	assert_float(_mode_select.classic_card.modulate.a).is_equal(1.0)


# -- 4. Selection behavior -----------------------------------------------------

func test_select_classic_stores_mode_in_config() -> void:
	SceneManager.is_transitioning = false
	_mode_select._on_classic_selected()
	assert_str(SceneManager.current_game_config["mode"]).is_equal("classic")


func test_select_classic_navigates_to_map_select() -> void:
	SceneManager.is_transitioning = false
	_mode_select._on_classic_selected()
	assert_str(SceneManager._last_scene_path).is_equal(MAP_SELECT_PATH)


func test_select_locked_mode_does_not_navigate() -> void:
	_mode_select.update_lock_status()
	SceneManager.is_transitioning = false
	_mode_select._on_draft_selected()
	assert_str(SceneManager._last_scene_path).is_equal("")


func test_select_locked_mode_does_not_change_config() -> void:
	_mode_select.update_lock_status()
	SceneManager.is_transitioning = false
	_mode_select._on_draft_selected()
	assert_bool(SceneManager.current_game_config.has("mode")).is_false()


func test_select_clears_config_before_setting_mode() -> void:
	SceneManager.current_game_config = {"old_key": "old_value"}
	SceneManager.is_transitioning = false
	_mode_select._on_classic_selected()
	assert_bool(SceneManager.current_game_config.has("old_key")).is_false()
	assert_str(SceneManager.current_game_config["mode"]).is_equal("classic")


# -- 5. Back button ------------------------------------------------------------

func test_back_button_navigates_to_main_menu() -> void:
	SceneManager.is_transitioning = false
	_mode_select._on_back_pressed()
	assert_str(SceneManager._last_scene_path).is_equal(SceneManager.MAIN_MENU_PATH)


func test_back_button_clears_config() -> void:
	SceneManager.current_game_config = {"mode": "classic"}
	SceneManager.is_transitioning = false
	_mode_select._on_back_pressed()
	assert_bool(SceneManager.current_game_config.is_empty()).is_true()


# -- 6. Button connections -----------------------------------------------------

func test_connect_buttons_wires_classic() -> void:
	_mode_select.connect_buttons()
	assert_bool(_mode_select.classic_button.pressed.is_connected(_mode_select._on_classic_selected)).is_true()


func test_connect_buttons_wires_draft() -> void:
	_mode_select.connect_buttons()
	assert_bool(_mode_select.draft_button.pressed.is_connected(_mode_select._on_draft_selected)).is_true()


func test_connect_buttons_wires_endless() -> void:
	_mode_select.connect_buttons()
	assert_bool(_mode_select.endless_button.pressed.is_connected(_mode_select._on_endless_selected)).is_true()


func test_connect_buttons_wires_back() -> void:
	_mode_select.connect_buttons()
	assert_bool(_mode_select.back_button.pressed.is_connected(_mode_select._on_back_pressed)).is_true()


# -- 7. Styling ----------------------------------------------------------------

func test_classic_button_has_hover_stylebox() -> void:
	_mode_select.apply_button_styles()
	assert_bool(_mode_select.classic_button.has_theme_stylebox_override("hover")).is_true()


func test_classic_button_has_pressed_stylebox() -> void:
	_mode_select.apply_button_styles()
	assert_bool(_mode_select.classic_button.has_theme_stylebox_override("pressed")).is_true()


func test_draft_button_has_hover_stylebox() -> void:
	_mode_select.apply_button_styles()
	assert_bool(_mode_select.draft_button.has_theme_stylebox_override("hover")).is_true()


func test_back_button_has_hover_stylebox() -> void:
	_mode_select.apply_button_styles()
	assert_bool(_mode_select.back_button.has_theme_stylebox_override("hover")).is_true()


# -- 8. Unlock overrides for testing -------------------------------------------

func test_unlock_override_makes_draft_selectable() -> void:
	_mode_select.unlock_overrides["draft"] = true
	_mode_select.update_lock_status()
	assert_bool(_mode_select.draft_button.disabled).is_false()


func test_unlock_override_draft_allows_selection() -> void:
	_mode_select.unlock_overrides["draft"] = true
	_mode_select.update_lock_status()
	SceneManager.is_transitioning = false
	_mode_select._on_draft_selected()
	assert_str(SceneManager.current_game_config["mode"]).is_equal("draft")
	assert_str(SceneManager._last_scene_path).is_equal(MAP_SELECT_PATH)


func test_unlock_override_makes_endless_selectable() -> void:
	_mode_select.unlock_overrides["endless"] = true
	_mode_select.update_lock_status()
	assert_bool(_mode_select.endless_button.disabled).is_false()


func test_unlock_override_endless_allows_navigation() -> void:
	_mode_select.unlock_overrides["endless"] = true
	_mode_select.update_lock_status()
	SceneManager.is_transitioning = false
	_mode_select._on_endless_selected()
	assert_str(SceneManager.current_game_config["mode"]).is_equal("endless")
	assert_str(SceneManager._last_scene_path).is_equal(MAP_SELECT_PATH)


func test_unlock_override_restores_card_modulate() -> void:
	_mode_select.update_lock_status()
	assert_float(_mode_select.draft_card.modulate.a).is_less(1.0)
	_mode_select.unlock_overrides["draft"] = true
	_mode_select.update_lock_status()
	assert_float(_mode_select.draft_card.modulate.a).is_equal(1.0)
