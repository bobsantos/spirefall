extends GdUnitTestSuite

## Tests for MetaProgression integration in ModeSelect and MapSelect.
## Verifies that unlock checks delegate to MetaProgression.is_unlocked(),
## that lock labels show XP progress, and that unlock_overrides still take precedence.

const MODE_SELECT_SCRIPT_PATH: String = "res://scripts/main/ModeSelect.gd"
const MAP_SELECT_SCRIPT_PATH: String = "res://scripts/main/MapSelect.gd"
const TEST_SAVE_PATH: String = "user://test_save_data_unlocks.json"

var _original_save_path: String
var _mode_select: Control
var _map_select: Control


# -- Suite-level setup/teardown ------------------------------------------------

func before() -> void:
	_original_save_path = SaveSystem._save_path


func before_test() -> void:
	SaveSystem._save_path = TEST_SAVE_PATH
	SaveSystem._data = SaveSystem._default_data()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)
	MetaProgression.reset()
	_mode_select = null
	_map_select = null


func after_test() -> void:
	if _mode_select != null:
		_mode_select.free()
		_mode_select = null
	if _map_select != null:
		_map_select.free()
		_map_select = null
	MetaProgression.reset()
	SaveSystem._save_path = TEST_SAVE_PATH
	SaveSystem._data = SaveSystem._default_data()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


func after() -> void:
	SaveSystem._save_path = _original_save_path
	SaveSystem.load_save()


# -- Helpers -------------------------------------------------------------------

func _build_mode_select() -> Control:
	var root := Control.new()

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	center.add_child(vbox)

	var title := Label.new()
	title.name = "TitleLabel"
	vbox.add_child(title)

	var card_container := HBoxContainer.new()
	card_container.name = "CardContainer"
	vbox.add_child(card_container)

	card_container.add_child(_build_mode_card("ClassicCard", "Classic", "", ""))
	card_container.add_child(_build_mode_card("DraftCard", "Draft", "", ""))
	card_container.add_child(_build_mode_card("EndlessCard", "Endless", "", ""))

	var back_btn := Button.new()
	back_btn.name = "BackButton"
	vbox.add_child(back_btn)

	_apply_mode_script(root)
	return root


func _build_mode_card(card_name: String, mode_name: String, desc: String, lock_text: String) -> PanelContainer:
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
	desc_label.text = desc
	card_vbox.add_child(desc_label)

	var lock_label := Label.new()
	lock_label.name = "LockLabel"
	lock_label.text = lock_text
	card_vbox.add_child(lock_label)

	var btn := Button.new()
	btn.name = "SelectButton"
	card_vbox.add_child(btn)

	return card


func _apply_mode_script(node: Control) -> void:
	node.set_script(load(MODE_SELECT_SCRIPT_PATH))
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


func _build_map_select() -> Control:
	var root := Control.new()

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	center.add_child(vbox)

	var title := Label.new()
	title.name = "TitleLabel"
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.name = "MapGrid"
	grid.columns = 2
	vbox.add_child(grid)

	grid.add_child(_build_map_card("ForestCard", "Forest", "", "", Color.GREEN))
	grid.add_child(_build_map_card("MountainCard", "Mountain", "", "", Color.GRAY))
	grid.add_child(_build_map_card("RiverCard", "River", "", "", Color.BLUE))
	grid.add_child(_build_map_card("VolcanoCard", "Volcano", "", "", Color.RED))

	var back_btn := Button.new()
	back_btn.name = "BackButton"
	vbox.add_child(back_btn)

	_apply_map_script(root)
	return root


func _build_map_card(card_name: String, map_name: String, desc: String, lock_text: String, preview_color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = card_name

	var card_vbox := VBoxContainer.new()
	card_vbox.name = "CardVBox"
	card.add_child(card_vbox)

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
	desc_label.text = desc
	card_vbox.add_child(desc_label)

	var diff_label := Label.new()
	diff_label.name = "DifficultyLabel"
	card_vbox.add_child(diff_label)

	var lock_label := Label.new()
	lock_label.name = "LockLabel"
	lock_label.text = lock_text
	card_vbox.add_child(lock_label)

	var btn := Button.new()
	btn.name = "SelectButton"
	card_vbox.add_child(btn)

	return card


func _apply_map_script(node: Control) -> void:
	node.set_script(load(MAP_SELECT_SCRIPT_PATH))
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


# -- ModeSelect + MetaProgression tests ---------------------------------------

func test_mode_classic_always_unlocked_at_zero_xp() -> void:
	_mode_select = _build_mode_select()
	assert_bool(_mode_select._is_mode_unlocked("classic")).is_true()


func test_mode_draft_locked_at_zero_xp() -> void:
	_mode_select = _build_mode_select()
	assert_bool(_mode_select._is_mode_unlocked("draft")).is_false()


func test_mode_draft_unlocked_after_500_xp() -> void:
	MetaProgression.award_xp(500)
	_mode_select = _build_mode_select()
	assert_bool(_mode_select._is_mode_unlocked("draft")).is_true()


func test_mode_draft_locked_at_499_xp() -> void:
	MetaProgression.award_xp(499)
	_mode_select = _build_mode_select()
	assert_bool(_mode_select._is_mode_unlocked("draft")).is_false()


func test_mode_endless_locked_at_zero_xp() -> void:
	_mode_select = _build_mode_select()
	assert_bool(_mode_select._is_mode_unlocked("endless")).is_false()


func test_mode_endless_unlocked_after_2000_xp() -> void:
	MetaProgression.award_xp(2000)
	_mode_select = _build_mode_select()
	assert_bool(_mode_select._is_mode_unlocked("endless")).is_true()


func test_mode_endless_locked_at_1999_xp() -> void:
	MetaProgression.award_xp(1999)
	_mode_select = _build_mode_select()
	assert_bool(_mode_select._is_mode_unlocked("endless")).is_false()


func test_mode_unlock_overrides_take_precedence() -> void:
	_mode_select = _build_mode_select()
	# Draft should be locked at 0 XP, but override says unlocked
	_mode_select.unlock_overrides["draft"] = true
	assert_bool(_mode_select._is_mode_unlocked("draft")).is_true()

	# Endless should be unlocked at 2000 XP, but override says locked
	MetaProgression.award_xp(2000)
	_mode_select.unlock_overrides["endless"] = false
	assert_bool(_mode_select._is_mode_unlocked("endless")).is_false()


func test_mode_lock_label_shows_xp_progress() -> void:
	MetaProgression.award_xp(250)
	_mode_select = _build_mode_select()
	_mode_select.update_lock_status()
	assert_str(_mode_select.draft_lock_label.text).is_equal("250 / 500 XP")


func test_mode_lock_label_shows_xp_progress_endless() -> void:
	MetaProgression.award_xp(1500)
	_mode_select = _build_mode_select()
	_mode_select.update_lock_status()
	assert_str(_mode_select.endless_lock_label.text).is_equal("1500 / 2000 XP")


func test_mode_lock_label_cleared_when_unlocked() -> void:
	MetaProgression.award_xp(500)
	_mode_select = _build_mode_select()
	_mode_select.update_lock_status()
	assert_str(_mode_select.draft_lock_label.text).is_equal("")


# -- MapSelect + MetaProgression tests ----------------------------------------

func test_map_forest_always_unlocked_at_zero_xp() -> void:
	_map_select = _build_map_select()
	assert_bool(_map_select._is_map_unlocked("forest")).is_true()


func test_map_mountain_locked_at_zero_xp() -> void:
	_map_select = _build_map_select()
	assert_bool(_map_select._is_map_unlocked("mountain")).is_false()


func test_map_mountain_unlocked_after_1000_xp() -> void:
	MetaProgression.award_xp(1000)
	_map_select = _build_map_select()
	assert_bool(_map_select._is_map_unlocked("mountain")).is_true()


func test_map_mountain_locked_at_999_xp() -> void:
	MetaProgression.award_xp(999)
	_map_select = _build_map_select()
	assert_bool(_map_select._is_map_unlocked("mountain")).is_false()


func test_map_river_locked_at_zero_xp() -> void:
	_map_select = _build_map_select()
	assert_bool(_map_select._is_map_unlocked("river")).is_false()


func test_map_river_unlocked_after_3000_xp() -> void:
	MetaProgression.award_xp(3000)
	_map_select = _build_map_select()
	assert_bool(_map_select._is_map_unlocked("river")).is_true()


func test_map_volcano_locked_at_zero_xp() -> void:
	_map_select = _build_map_select()
	assert_bool(_map_select._is_map_unlocked("volcano")).is_false()


func test_map_volcano_unlocked_after_6000_xp() -> void:
	MetaProgression.award_xp(6000)
	_map_select = _build_map_select()
	assert_bool(_map_select._is_map_unlocked("volcano")).is_true()


func test_map_volcano_locked_at_5999_xp() -> void:
	MetaProgression.award_xp(5999)
	_map_select = _build_map_select()
	assert_bool(_map_select._is_map_unlocked("volcano")).is_false()


func test_map_unlock_overrides_take_precedence() -> void:
	_map_select = _build_map_select()
	# Mountain should be locked at 0 XP, but override says unlocked
	_map_select.unlock_overrides["mountain"] = true
	assert_bool(_map_select._is_map_unlocked("mountain")).is_true()

	# Volcano should be unlocked at 6000 XP, but override says locked
	MetaProgression.award_xp(6000)
	_map_select.unlock_overrides["volcano"] = false
	assert_bool(_map_select._is_map_unlocked("volcano")).is_false()


func test_map_lock_label_shows_xp_progress() -> void:
	MetaProgression.award_xp(750)
	_map_select = _build_map_select()
	_map_select.update_lock_status()
	assert_str(_map_select.mountain_lock_label.text).is_equal("750 / 1000 XP")


func test_map_lock_label_shows_xp_progress_river() -> void:
	MetaProgression.award_xp(2500)
	_map_select = _build_map_select()
	_map_select.update_lock_status()
	assert_str(_map_select.river_lock_label.text).is_equal("2500 / 3000 XP")


func test_map_lock_label_shows_xp_progress_volcano() -> void:
	MetaProgression.award_xp(4000)
	_map_select = _build_map_select()
	_map_select.update_lock_status()
	assert_str(_map_select.volcano_lock_label.text).is_equal("4000 / 6000 XP")


func test_map_lock_label_cleared_when_unlocked() -> void:
	MetaProgression.award_xp(1000)
	_map_select = _build_map_select()
	_map_select.update_lock_status()
	assert_str(_map_select.mountain_lock_label.text).is_equal("")


func test_all_modes_unlocked_at_high_xp() -> void:
	MetaProgression.award_xp(10000)
	_mode_select = _build_mode_select()
	assert_bool(_mode_select._is_mode_unlocked("classic")).is_true()
	assert_bool(_mode_select._is_mode_unlocked("draft")).is_true()
	assert_bool(_mode_select._is_mode_unlocked("endless")).is_true()


func test_all_maps_unlocked_at_high_xp() -> void:
	MetaProgression.award_xp(10000)
	_map_select = _build_map_select()
	assert_bool(_map_select._is_map_unlocked("forest")).is_true()
	assert_bool(_map_select._is_map_unlocked("mountain")).is_true()
	assert_bool(_map_select._is_map_unlocked("river")).is_true()
	assert_bool(_map_select._is_map_unlocked("volcano")).is_true()
