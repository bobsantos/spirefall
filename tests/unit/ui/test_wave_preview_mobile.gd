extends GdUnitTestSuite

## Unit tests for Task D5: WavePreviewPanel mobile sizing.
## Covers: font sizes for title, boss banner, enemy names, and combat label.

const WAVE_PREVIEW_SCRIPT_PATH: String = "res://scripts/ui/WavePreviewPanel.gd"

var _panel: PanelContainer


# -- Helpers -------------------------------------------------------------------

func _build_wave_preview_node() -> PanelContainer:
	## Build a WavePreviewPanel node tree manually matching WavePreviewPanel.tscn.
	var root := PanelContainer.new()

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	root.add_child(vbox)

	var title := Label.new()
	title.name = "TitleLabel"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var boss_banner := Label.new()
	boss_banner.name = "BossBanner"
	boss_banner.add_theme_font_size_override("font_size", 13)
	boss_banner.visible = false
	vbox.add_child(boss_banner)

	var sep := HSeparator.new()
	sep.name = "Separator"
	vbox.add_child(sep)

	var enemy_list := VBoxContainer.new()
	enemy_list.name = "EnemyList"
	vbox.add_child(enemy_list)

	var combat_label := Label.new()
	combat_label.name = "CombatLabel"
	combat_label.add_theme_font_size_override("font_size", 11)
	combat_label.visible = false
	vbox.add_child(combat_label)

	return root


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	_panel = _build_wave_preview_node()
	add_child(_panel)
	_panel.set_script(load(WAVE_PREVIEW_SCRIPT_PATH))
	# Manually set @onready vars
	_panel.title_label = _panel.get_node("VBoxContainer/TitleLabel")
	_panel.enemy_list = _panel.get_node("VBoxContainer/EnemyList")
	_panel.boss_banner = _panel.get_node("VBoxContainer/BossBanner")
	_panel.combat_label = _panel.get_node("VBoxContainer/CombatLabel")


func after_test() -> void:
	# Disconnect signals
	if GameManager.phase_changed.is_connected(_panel._on_phase_changed):
		GameManager.phase_changed.disconnect(_panel._on_phase_changed)
	UIManager.wave_preview_panel = null
	if is_instance_valid(_panel):
		if _panel.is_inside_tree():
			remove_child(_panel)
		_panel.free()
	_panel = null


# -- Section 1: _apply_mobile_sizing() method exists ---------------------------

func test_apply_mobile_sizing_method_exists() -> void:
	## WavePreviewPanel must have an _apply_mobile_sizing() method.
	assert_bool(_panel.has_method("_apply_mobile_sizing")).is_true()


# -- Section 2: Title font size on mobile --------------------------------------

func test_title_font_size_at_least_16_on_mobile() -> void:
	## After _apply_mobile_sizing(), title label must have font_size >= 16.
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.title_label.get_theme_font_size("font_size")
	assert_bool(font_size >= 16) \
		.override_failure_message("Title font size %d < 16" % font_size) \
		.is_true()


func test_title_font_size_uses_uimanager_constant() -> void:
	## Title label font size should match UIManager.MOBILE_FONT_SIZE_BODY.
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.title_label.get_theme_font_size("font_size")
	assert_int(font_size).is_equal(UIManager.MOBILE_FONT_SIZE_BODY)


# -- Section 3: Boss banner font size on mobile --------------------------------

func test_boss_banner_font_size_at_least_16_on_mobile() -> void:
	## After _apply_mobile_sizing(), boss banner must have font_size >= 16.
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.boss_banner.get_theme_font_size("font_size")
	assert_bool(font_size >= 16) \
		.override_failure_message("Boss banner font size %d < 16" % font_size) \
		.is_true()


# -- Section 4: Combat label font size on mobile -------------------------------

func test_combat_label_font_size_at_least_14_on_mobile() -> void:
	## After _apply_mobile_sizing(), combat label must have font_size >= 14.
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.combat_label.get_theme_font_size("font_size")
	assert_bool(font_size >= 14) \
		.override_failure_message("Combat label font size %d < 14" % font_size) \
		.is_true()


func test_combat_label_font_size_uses_uimanager_constant() -> void:
	## Combat label font size should match UIManager.MOBILE_FONT_SIZE_LABEL.
	_panel._apply_mobile_sizing()
	var font_size: int = _panel.combat_label.get_theme_font_size("font_size")
	assert_int(font_size).is_equal(UIManager.MOBILE_FONT_SIZE_LABEL)


# -- Section 5: Desktop sizes unchanged when not calling mobile sizing ---------

func test_desktop_title_font_size_unchanged() -> void:
	## Without _apply_mobile_sizing(), title should keep desktop font (14).
	var font_size: int = _panel.title_label.get_theme_font_size("font_size")
	assert_int(font_size).is_equal(14)


func test_desktop_combat_label_font_size_unchanged() -> void:
	## Without _apply_mobile_sizing(), combat label should keep desktop font (11).
	var font_size: int = _panel.combat_label.get_theme_font_size("font_size")
	assert_int(font_size).is_equal(11)
