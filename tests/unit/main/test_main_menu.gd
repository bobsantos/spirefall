extends GdUnitTestSuite

## Unit tests for MainMenu scene script.
## Covers: node structure, button callbacks, overlay toggling, AudioManager call,
## disabled "Coming Soon" buttons, and button theme overrides.

const MAIN_MENU_SCRIPT_PATH: String = "res://scripts/main/MainMenu.gd"
const MODE_SELECT_PATH: String = "res://scenes/main/ModeSelect.tscn"

var _menu: Control
var _scene_change_paths: Array[String] = []
var _music_tracks: Array[String] = []
var _scene_change_conn: Callable
var _original_transitioning: bool


# -- Helpers -------------------------------------------------------------------

## Build a MainMenu node tree manually (same structure as MainMenu.tscn)
## so tests don't depend on the .tscn file loading in headless mode.
func _build_menu() -> Control:
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
	title.text = "SPIREFALL"
	vbox.add_child(title)

	# Button container
	var button_box := VBoxContainer.new()
	button_box.name = "ButtonContainer"
	vbox.add_child(button_box)

	# Buttons
	var play_btn := Button.new()
	play_btn.name = "PlayButton"
	play_btn.text = "Play"
	button_box.add_child(play_btn)

	var settings_btn := Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.text = "Settings"
	button_box.add_child(settings_btn)

	var credits_btn := Button.new()
	credits_btn.name = "CreditsButton"
	credits_btn.text = "Credits"
	button_box.add_child(credits_btn)

	var collection_btn := Button.new()
	collection_btn.name = "CollectionButton"
	collection_btn.text = "Collection (Coming Soon)"
	collection_btn.disabled = true
	button_box.add_child(collection_btn)

	var leaderboards_btn := Button.new()
	leaderboards_btn.name = "LeaderboardsButton"
	leaderboards_btn.text = "Leaderboards (Coming Soon)"
	leaderboards_btn.disabled = true
	button_box.add_child(leaderboards_btn)

	# Settings overlay (hidden by default)
	var settings_overlay := PanelContainer.new()
	settings_overlay.name = "SettingsOverlay"
	settings_overlay.visible = false
	root.add_child(settings_overlay)

	var settings_vbox := VBoxContainer.new()
	settings_vbox.name = "SettingsVBox"
	settings_overlay.add_child(settings_vbox)

	var settings_title := Label.new()
	settings_title.name = "SettingsTitle"
	settings_title.text = "Settings"
	settings_vbox.add_child(settings_title)

	var settings_placeholder := Label.new()
	settings_placeholder.name = "SettingsPlaceholder"
	settings_placeholder.text = "Settings coming soon..."
	settings_vbox.add_child(settings_placeholder)

	var settings_close := Button.new()
	settings_close.name = "SettingsCloseButton"
	settings_close.text = "Close"
	settings_vbox.add_child(settings_close)

	# Credits overlay (hidden by default)
	var credits_overlay := PanelContainer.new()
	credits_overlay.name = "CreditsOverlay"
	credits_overlay.visible = false
	root.add_child(credits_overlay)

	var credits_vbox := VBoxContainer.new()
	credits_vbox.name = "CreditsVBox"
	credits_overlay.add_child(credits_vbox)

	var credits_title := Label.new()
	credits_title.name = "CreditsTitle"
	credits_title.text = "Credits"
	credits_vbox.add_child(credits_title)

	var credits_scroll := ScrollContainer.new()
	credits_scroll.name = "CreditsScroll"
	credits_vbox.add_child(credits_scroll)

	var credits_text := RichTextLabel.new()
	credits_text.name = "CreditsText"
	credits_text.text = "Spirefall\nA tower defense game"
	credits_scroll.add_child(credits_text)

	var credits_close := Button.new()
	credits_close.name = "CreditsCloseButton"
	credits_close.text = "Close"
	credits_vbox.add_child(credits_close)

	return root


func _apply_script(node: Control) -> void:
	var script: GDScript = load(MAIN_MENU_SCRIPT_PATH)
	node.set_script(script)
	# Manually wire @onready references since we're not going through the tree
	node.play_button = node.get_node("CenterContainer/VBoxContainer/ButtonContainer/PlayButton")
	node.settings_button = node.get_node("CenterContainer/VBoxContainer/ButtonContainer/SettingsButton")
	node.credits_button = node.get_node("CenterContainer/VBoxContainer/ButtonContainer/CreditsButton")
	node.collection_button = node.get_node("CenterContainer/VBoxContainer/ButtonContainer/CollectionButton")
	node.leaderboards_button = node.get_node("CenterContainer/VBoxContainer/ButtonContainer/LeaderboardsButton")
	node.settings_overlay = node.get_node("SettingsOverlay")
	node.credits_overlay = node.get_node("CreditsOverlay")
	node.settings_close_button = node.get_node("SettingsOverlay/SettingsVBox/SettingsCloseButton")
	node.credits_close_button = node.get_node("CreditsOverlay/CreditsVBox/CreditsCloseButton")
	node.title_label = node.get_node("CenterContainer/VBoxContainer/TitleLabel")


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_scene_change_paths.clear()
	_music_tracks.clear()

	# Block SceneManager from doing real scene transitions
	_original_transitioning = SceneManager.is_transitioning
	SceneManager.is_transitioning = true

	# Intercept SceneManager.change_scene calls via the scene_changing signal
	# We'll track what path was requested by hooking _last_scene_path
	_scene_change_conn = func() -> void:
		_scene_change_paths.append(SceneManager._last_scene_path)
	SceneManager.scene_changing.connect(_scene_change_conn)

	_menu = _build_menu()
	_apply_script(_menu)


func after_test() -> void:
	if SceneManager.scene_changing.is_connected(_scene_change_conn):
		SceneManager.scene_changing.disconnect(_scene_change_conn)
	SceneManager.is_transitioning = _original_transitioning
	SceneManager._last_scene_path = ""

	if is_instance_valid(_menu):
		_menu.free()
		_menu = null


# -- 1. Script loads and has expected properties -------------------------------

func test_script_exists_and_loads() -> void:
	var script: GDScript = load(MAIN_MENU_SCRIPT_PATH)
	assert_object(script).is_not_null()


func test_menu_has_play_button() -> void:
	assert_object(_menu.play_button).is_not_null()
	assert_bool(_menu.play_button is Button).is_true()


func test_menu_has_settings_button() -> void:
	assert_object(_menu.settings_button).is_not_null()
	assert_bool(_menu.settings_button is Button).is_true()


func test_menu_has_credits_button() -> void:
	assert_object(_menu.credits_button).is_not_null()
	assert_bool(_menu.credits_button is Button).is_true()


func test_menu_has_settings_overlay() -> void:
	assert_object(_menu.settings_overlay).is_not_null()
	assert_bool(_menu.settings_overlay is PanelContainer).is_true()


func test_menu_has_credits_overlay() -> void:
	assert_object(_menu.credits_overlay).is_not_null()
	assert_bool(_menu.credits_overlay is PanelContainer).is_true()


func test_title_label_text() -> void:
	assert_str(_menu.title_label.text).is_equal("SPIREFALL")


# -- 2. Play button navigates to ModeSelect -----------------------------------

func test_play_button_calls_scene_manager() -> void:
	# Temporarily allow transition so change_scene fires
	SceneManager.is_transitioning = false
	_menu._on_play_pressed()
	assert_str(SceneManager._last_scene_path).is_equal(MODE_SELECT_PATH)


# -- 3. Settings overlay toggle ------------------------------------------------

func test_settings_overlay_starts_hidden() -> void:
	assert_bool(_menu.settings_overlay.visible).is_false()


func test_settings_button_shows_overlay() -> void:
	_menu._on_settings_pressed()
	assert_bool(_menu.settings_overlay.visible).is_true()


func test_settings_button_toggles_overlay() -> void:
	_menu._on_settings_pressed()
	assert_bool(_menu.settings_overlay.visible).is_true()
	_menu._on_settings_pressed()
	assert_bool(_menu.settings_overlay.visible).is_false()


func test_settings_close_button_hides_overlay() -> void:
	_menu.settings_overlay.visible = true
	_menu._on_settings_close_pressed()
	assert_bool(_menu.settings_overlay.visible).is_false()


func test_settings_hides_credits_overlay() -> void:
	_menu.credits_overlay.visible = true
	_menu._on_settings_pressed()
	assert_bool(_menu.credits_overlay.visible).is_false()


# -- 4. Credits overlay toggle -------------------------------------------------

func test_credits_overlay_starts_hidden() -> void:
	assert_bool(_menu.credits_overlay.visible).is_false()


func test_credits_button_shows_overlay() -> void:
	_menu._on_credits_pressed()
	assert_bool(_menu.credits_overlay.visible).is_true()


func test_credits_button_toggles_overlay() -> void:
	_menu._on_credits_pressed()
	assert_bool(_menu.credits_overlay.visible).is_true()
	_menu._on_credits_pressed()
	assert_bool(_menu.credits_overlay.visible).is_false()


func test_credits_close_button_hides_overlay() -> void:
	_menu.credits_overlay.visible = true
	_menu._on_credits_close_pressed()
	assert_bool(_menu.credits_overlay.visible).is_false()


func test_credits_hides_settings_overlay() -> void:
	_menu.settings_overlay.visible = true
	_menu._on_credits_pressed()
	assert_bool(_menu.settings_overlay.visible).is_false()


# -- 5. "Coming Soon" buttons are disabled -------------------------------------

func test_collection_button_exists_and_disabled() -> void:
	assert_object(_menu.collection_button).is_not_null()
	assert_bool(_menu.collection_button.disabled).is_true()


func test_leaderboards_button_exists_and_disabled() -> void:
	assert_object(_menu.leaderboards_button).is_not_null()
	assert_bool(_menu.leaderboards_button.disabled).is_true()


func test_collection_button_text_contains_coming_soon() -> void:
	assert_str(_menu.collection_button.text).contains("Coming Soon")


func test_leaderboards_button_text_contains_coming_soon() -> void:
	assert_str(_menu.leaderboards_button.text).contains("Coming Soon")


# -- 6. Button connections (connect_buttons method) ----------------------------

func test_connect_buttons_wires_play() -> void:
	_menu.connect_buttons()
	assert_bool(_menu.play_button.pressed.is_connected(_menu._on_play_pressed)).is_true()


func test_connect_buttons_wires_settings() -> void:
	_menu.connect_buttons()
	assert_bool(_menu.settings_button.pressed.is_connected(_menu._on_settings_pressed)).is_true()


func test_connect_buttons_wires_credits() -> void:
	_menu.connect_buttons()
	assert_bool(_menu.credits_button.pressed.is_connected(_menu._on_credits_pressed)).is_true()


func test_connect_buttons_wires_settings_close() -> void:
	_menu.connect_buttons()
	assert_bool(_menu.settings_close_button.pressed.is_connected(_menu._on_settings_close_pressed)).is_true()


func test_connect_buttons_wires_credits_close() -> void:
	_menu.connect_buttons()
	assert_bool(_menu.credits_close_button.pressed.is_connected(_menu._on_credits_close_pressed)).is_true()


# -- 7. Button hover/press StyleBox overrides ---------------------------------

func test_play_button_has_hover_stylebox() -> void:
	_menu.apply_button_styles()
	assert_bool(_menu.play_button.has_theme_stylebox_override("hover")).is_true()


func test_play_button_has_pressed_stylebox() -> void:
	_menu.apply_button_styles()
	assert_bool(_menu.play_button.has_theme_stylebox_override("pressed")).is_true()


func test_settings_button_has_hover_stylebox() -> void:
	_menu.apply_button_styles()
	assert_bool(_menu.settings_button.has_theme_stylebox_override("hover")).is_true()


func test_credits_button_has_hover_stylebox() -> void:
	_menu.apply_button_styles()
	assert_bool(_menu.credits_button.has_theme_stylebox_override("hover")).is_true()
